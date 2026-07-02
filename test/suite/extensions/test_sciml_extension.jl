module TestSciMLExtension

import Test
import CTBase.Data: Data
import CTFlows: CTFlows
import CTFlows.Common: Common
import CTFlows.Configs: Configs
import CTFlows.Systems: Systems
import CTFlows.Integrators: Integrators
import CTFlows.Trajectories: Trajectories
import CommonSolve

# Get extensions to check they are loaded
using SciMLBase: SciMLBase, ODEProblem
using OrdinaryDiffEqTsit5: OrdinaryDiffEqTsit5, Tsit5
import StaticArrays: SA
const CTFlowsSciMLIntegrator = Base.get_extension(CTFlows, :CTFlowsSciMLIntegrator)
const CTFlowsSciMLFlows      = Base.get_extension(CTFlows, :CTFlowsSciMLFlows)

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

# ==============================================================================
# CTFlows-side glue tests for the SciML integrator.
#
# The generic integrator machinery (metadata, construction/validation,
# CommonSolve.solve, the result accessors, and merge) is owned and unit-tested by
# CTSolvers. Here we test the CTFlows glue — `build_problem` (Systems/Configs → an
# `ODEProblem`) and `build_options` (config-dependent option selection) — plus a few
# CTFlows-level integration workflows that exercise the whole chain.
# ==============================================================================

function test_sciml_extension()
    Test.@testset "SciML Extension" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ====================================================================
        # Extension loading
        # ====================================================================

        Test.@testset "Extension Loading" begin
            Test.@test !isnothing(CTFlowsSciMLIntegrator)
            Test.@test CTFlowsSciMLIntegrator isa Module
            Test.@test !isnothing(CTFlowsSciMLFlows)
            Test.@test CTFlowsSciMLFlows isa Module
        end

        # ====================================================================
        # build_problem — Systems/Configs → ODEProblem (problem-first glue)
        # ====================================================================

        Test.@testset "Problem Building" begin
            Test.@testset "builds ODEProblem without variable" begin
                sys = Systems.VectorFieldSystem(
                    Data.VectorField(x -> -x; is_autonomous=true, is_variable=false)
                )
                config = Configs.StateEndPointConfig(0.0, [1.0, 2.0], 1.0)
                integ = Integrators.SciML()

                prob = Integrators.build_problem(sys, config, integ; variable=nothing)

                Test.@test prob isa SciMLBase.AbstractODEProblem
                Test.@test prob.p isa Common.ODEParameters
                Test.@test Common.variable(prob.p) === nothing
            end

            Test.@testset "builds ODEProblem with variable parameter" begin
                sys = Systems.VectorFieldSystem(
                    Data.VectorField((x, v) -> x .+ v; is_autonomous=true, is_variable=true)
                )
                config = Configs.StateEndPointConfig(0.0, [1.0, 2.0], 1.0)
                integ = Integrators.SciML()

                prob = Integrators.build_problem(sys, config, integ; variable=0.5)

                Test.@test prob isa SciMLBase.AbstractODEProblem
                Test.@test prob.p isa Common.ODEParameters
                Test.@test Common.variable(prob.p) == 0.5
            end
        end

        # ====================================================================
        # build_options — config-dependent option selection (glue dispatch)
        # ====================================================================

        Test.@testset "Config-Dependent Options" begin
            integ = Integrators.SciML()
            config_point = Configs.StateEndPointConfig(0.0, [1.0, 0.0], 1.0)
            config_traj = Configs.StateTrajectoryConfig((0.0, 1.0), [1.0, 0.0])

            Test.@testset "point config selects the point option bundle" begin
                opts = Integrators.build_options(integ, config_point)
                Test.@test opts === Integrators.options_point(integ)
                Test.@test opts[:dense] === false
                Test.@test opts[:save_everystep] === false
                Test.@test opts[:save_start] === false
            end

            Test.@testset "trajectory config selects the trajectory option bundle" begin
                opts = Integrators.build_options(integ, config_traj)
                Test.@test opts === Integrators.options_trajectory(integ)
                Test.@test opts[:dense] === true
                Test.@test opts[:save_everystep] === true
                Test.@test opts[:save_start] === true
            end

            Test.@testset "nothing config falls back to the trajectory bundle" begin
                opts = Integrators.build_options(integ, nothing)
                Test.@test opts === Integrators.options_trajectory(integ)
            end

            Test.@testset "point and trajectory bundles differ" begin
                opts_point = Integrators.build_options(integ, config_point)
                opts_traj = Integrators.build_options(integ, config_traj)
                Test.@test opts_point !== opts_traj
            end
        end

        # ====================================================================
        # Integration workflows — build_problem + CommonSolve.solve + trajectory
        # ====================================================================

        Test.@testset "InPlace VF — SciML integration" begin
            integ = Integrators.SciML(maxiters=10000, reltol=1e-8, abstol=1e-10)
            # ODE: dx/dt = -x  →  x(t) = x₀ · e^{-t}

            Test.@testset "OOP VF + mutable Vector u0" begin
                vf  = Data.VectorField(x -> -x; is_autonomous=true, is_variable=false)
                sys = Systems.VectorFieldSystem(vf)
                config = Configs.StateEndPointConfig(0.0, [1.0, 2.0], 1.0)
                prob = Integrators.build_problem(sys, config, integ; variable=nothing)
                opts = Integrators.build_options(integ, config)
                result = CommonSolve.solve(prob, integ; options=opts)
                Test.@test Integrators.final_state(result) ≈ exp(-1.0) .* [1.0, 2.0]  atol=1e-5
            end

            Test.@testset "OOP VF + SVector u0" begin
                vf  = Data.VectorField(x -> -x; is_autonomous=true, is_variable=false)
                sys = Systems.VectorFieldSystem(vf)
                config = Configs.StateEndPointConfig(0.0, SA[1.0, 2.0], 1.0)
                prob = Integrators.build_problem(sys, config, integ; variable=nothing)
                opts = Integrators.build_options(integ, config)
                result = CommonSolve.solve(prob, integ; options=opts)
                Test.@test Integrators.final_state(result) ≈ exp(-1.0) .* [1.0, 2.0]  atol=1e-5
            end

            Test.@testset "IP VF + mutable Vector u0" begin
                vf  = Data.VectorField((du, x) -> (du .= -x); is_autonomous=true, is_variable=false)
                sys = Systems.VectorFieldSystem(vf)
                config = Configs.StateEndPointConfig(0.0, [1.0, 2.0], 1.0)
                prob = Integrators.build_problem(sys, config, integ; variable=nothing)
                opts = Integrators.build_options(integ, config)
                result = CommonSolve.solve(prob, integ; options=opts)
                Test.@test Integrators.final_state(result) ≈ exp(-1.0) .* [1.0, 2.0]  atol=1e-5
            end

            Test.@testset "IP VF + SVector u0 (warns, uses rhs_oop_finalize)" begin
                vf  = Data.VectorField((du, x) -> (du .= -x); is_autonomous=true, is_variable=false)
                sys = Systems.VectorFieldSystem(vf)
                config = Configs.StateEndPointConfig(0.0, SA[1.0, 2.0], 1.0)
                prob = Test.@test_logs (:warn, r"InPlace VectorField") Integrators.build_problem(sys, config, integ; variable=nothing)
                opts = Integrators.build_options(integ, config)
                result = CommonSolve.solve(prob, integ; options=opts)
                Test.@test Integrators.final_state(result) ≈ exp(-1.0) .* [1.0, 2.0]  atol=1e-5
            end
        end

        Test.@testset "InPlace HVF — SciML integration" begin
            integ = Integrators.SciML(maxiters=10000, reltol=1e-8, abstol=1e-10)
            # ODE: dx/dt = x, dp/dt = -p  →  x(t)=x₀·eᵗ, p(t)=p₀·e^{-t}

            Test.@testset "OOP HVF + mutable Vector u0" begin
                hvf = Data.HamiltonianVectorField((x, p) -> (x, -p); is_autonomous=true, is_variable=false)
                sys = Systems.HamiltonianVectorFieldSystem(hvf)
                config = Configs.HamiltonianEndPointConfig(0.0, 1.0, 0.5, 1.0)
                prob = Integrators.build_problem(sys, config, integ; variable=nothing)
                opts = Integrators.build_options(integ, config)
                result = CommonSolve.solve(prob, integ; options=opts)
                xf = Integrators.final_state(result)
                Test.@test xf[1] ≈ exp(1.0)       atol=1e-5
                Test.@test xf[2] ≈ 0.5*exp(-1.0)  atol=1e-5
            end

            Test.@testset "IP HVF + SVector u0 (warns)" begin
                hvf = Data.HamiltonianVectorField((dx, dp, x, p) -> (dx .= x; dp .= -p); is_autonomous=true, is_variable=false)
                sys = Systems.HamiltonianVectorFieldSystem(hvf)
                config = Configs.HamiltonianEndPointConfig(0.0, SA[1.0], SA[0.5], 1.0)
                prob = Test.@test_logs (:warn, r"InPlace HamiltonianVectorField") Integrators.build_problem(sys, config, integ; variable=nothing)
                opts = Integrators.build_options(integ, config)
                result = CommonSolve.solve(prob, integ; options=opts)
                xf = Integrators.final_state(result)
                Test.@test xf[1] ≈ exp(1.0)       atol=1e-5
                Test.@test xf[2] ≈ 0.5*exp(-1.0)  atol=1e-5
            end
        end

        Test.@testset "Full Workflow" begin
            Test.@testset "StateEndPointConfig workflow" begin
                sys = Systems.VectorFieldSystem(
                    Data.VectorField(x -> -x; is_autonomous=true, is_variable=false)
                )
                config = Configs.StateEndPointConfig(0.0, 1.0, 1.0)
                integ = Integrators.SciML(maxiters=1000, reltol=1e-6)

                prob = Integrators.build_problem(sys, config, integ; variable=nothing)
                opts = Integrators.build_options(integ, config)
                result = CommonSolve.solve(prob, integ; options=opts)
                flow_sol = Trajectories.build_trajectory(Configs.mode_trait(config), Configs.dynamics_trait(config), config, result)

                Test.@test flow_sol isa Number
            end

            Test.@testset "StateTrajectoryConfig workflow" begin
                sys = Systems.VectorFieldSystem(
                    Data.VectorField(x -> -x; is_autonomous=true, is_variable=false)
                )
                config = Configs.StateTrajectoryConfig((0.0, 1.0), [1.0, 2.0])
                integ = Integrators.SciML(maxiters=1000, reltol=1e-6)

                prob = Integrators.build_problem(sys, config, integ; variable=nothing)
                opts = Integrators.build_options(integ, config)
                result = CommonSolve.solve(prob, integ; options=opts)
                flow_sol = Trajectories.build_trajectory(Configs.mode_trait(config), Configs.dynamics_trait(config), config, result)

                Test.@test flow_sol isa Trajectories.VectorFieldTrajectory
            end
        end
    end
end

end # module

test_sciml_extension() = TestSciMLExtension.test_sciml_extension()
