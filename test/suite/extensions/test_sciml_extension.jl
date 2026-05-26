module TestSciMLExtension

import Test
import CTBase.Exceptions: Exceptions
import CTFlows: CTFlows
import CTFlows.Common: Common
import CTFlows.Configs: Configs
import CTFlows.Data: Data
import CTFlows.Systems: Systems
import CTFlows.Integrators: Integrators
import CTFlows.Solutions: Solutions
import CTSolvers.Strategies: Strategies
import CTSolvers.Options: Options

# Fake tag type for testing stub behavior
struct FakeTag <: Common.AbstractTag end

# Get extension to access SciML integrator
using SciMLBase: SciMLBase, ODEProblem
using OrdinaryDiffEqTsit5: OrdinaryDiffEqTsit5, Tsit5
import StaticArrays: SA
const CTFlowsSciML = Base.get_extension(CTFlows, :CTFlowsSciML)
const CTFlowsOrdinaryDiffEqTsit5 = Base.get_extension(CTFlows, :CTFlowsOrdinaryDiffEqTsit5)

const VERBOSE = isdefined(Main, :TestOptions) ? Main.TestOptions.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestOptions) ? Main.TestOptions.SHOWTIMING : true

# ==============================================================================
# Test function
# ==============================================================================

function test_sciml_extension()
    Test.@testset "SciML Extension" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ====================================================================
        # UNIT TESTS - Extension Loading
        # ====================================================================

        Test.@testset "Extension Loading" begin
            Test.@testset "extension is loaded" begin
                Test.@test !isnothing(CTFlowsSciML)
            end

            Test.@testset "extension is a Module" begin
                Test.@test CTFlowsSciML isa Module
            end

            Test.@testset "Tsit5 extension is loaded" begin
                Test.@test !isnothing(CTFlowsOrdinaryDiffEqTsit5)
            end
        end

        # ====================================================================
        # UNIT TESTS - Stub Behavior
        # ====================================================================

        Test.@testset "Stub Behavior" begin
            Test.@testset "__default_sciml_algorithm returns missing for fake tag" begin
                result = Integrators.__default_sciml_algorithm(FakeTag)
                Test.@test result === missing
            end

            Test.@testset "__default_sciml_algorithm returns Tsit5 for Tsit5Tag" begin
                result = Integrators.__default_sciml_algorithm(Integrators.Tsit5Tag)
                Test.@test result isa SciMLBase.AbstractDEAlgorithm
                Test.@test result == Tsit5()
            end
        end

        # ====================================================================
        # UNIT TESTS - Metadata
        # ====================================================================

        Test.@testset "Metadata" begin
            meta = Strategies.metadata(Integrators.SciML)

            Test.@test meta isa Strategies.StrategyMetadata
            Test.@test length(meta) > 0

            # Test that key options are defined
            Test.@test :alg in keys(meta)
            Test.@test :reltol in keys(meta)
            Test.@test :abstol in keys(meta)
            Test.@test :maxiters in keys(meta)

            # Test option types
            Test.@test Options.type(meta[:alg]) == SciMLBase.AbstractDEAlgorithm
            Test.@test Options.type(meta[:reltol]) == Real
            Test.@test Options.type(meta[:abstol]) == Real
            Test.@test Options.type(meta[:maxiters]) == Integer

            # Test default values exist
            Test.@test Options.default(meta[:alg]) isa SciMLBase.AbstractDEAlgorithm
            Test.@test Options.default(meta[:reltol]) isa Real
            Test.@test Options.default(meta[:abstol]) isa Real
        end

        # ====================================================================
        # UNIT TESTS - Constructor
        # ====================================================================

        Test.@testset "Constructor" begin
            # Default constructor
            integ = Integrators.SciML()
            Test.@test integ isa Integrators.SciML
            Test.@test integ isa Integrators.AbstractIntegrator

            # Constructor with options
            integ_custom = Integrators.SciML(reltol=1e-6, abstol=1e-8)
            Test.@test integ_custom isa Integrators.SciML

            # Test Strategies.options() returns StrategyOptions
            opts = Strategies.options(integ)
            Test.@test opts isa Strategies.StrategyOptions

            opts_custom = Strategies.options(integ_custom)
            Test.@test opts_custom isa Strategies.StrategyOptions
        end

        # ====================================================================
        # UNIT TESTS - Options Extraction
        # ====================================================================

        Test.@testset "Options Extraction" begin
            integ = Integrators.SciML(reltol=1e-8, abstol=1e-10, maxiters=1000)
            opts = Strategies.options(integ)

            # Extract raw options (returns NamedTuple)
            raw_opts = Options.extract_raw_options(Strategies._raw_options(opts))
            Test.@test raw_opts isa NamedTuple
            Test.@test haskey(raw_opts, :reltol)
            Test.@test haskey(raw_opts, :abstol)
            Test.@test haskey(raw_opts, :maxiters)

            # Verify values
            Test.@test raw_opts[:reltol] == 1e-8
            Test.@test raw_opts[:abstol] == 1e-10
            Test.@test raw_opts[:maxiters] == 1000
        end

        # ====================================================================
        # UNIT TESTS - Validation Error Throws
        # ====================================================================

        Test.@testset "Validation Error Throws" begin
            Test.@testset "reltol must be positive" begin
                redirect_stderr(devnull) do
                    Test.@test_throws Exceptions.IncorrectArgument Integrators.SciML(reltol=-1.0)
                    Test.@test_throws Exceptions.IncorrectArgument Integrators.SciML(reltol=0.0)
                end
            end
            
            Test.@testset "abstol must be positive" begin
                redirect_stderr(devnull) do
                    Test.@test_throws Exceptions.IncorrectArgument Integrators.SciML(abstol=-1.0)
                    Test.@test_throws Exceptions.IncorrectArgument Integrators.SciML(abstol=0.0)
                end
            end
            
            Test.@testset "maxiters must be positive" begin
                redirect_stderr(devnull) do
                    Test.@test_throws Exceptions.IncorrectArgument Integrators.SciML(maxiters=-1)
                    Test.@test_throws Exceptions.IncorrectArgument Integrators.SciML(maxiters=0)
                end
            end
            
            Test.@testset "dt must be positive" begin
                redirect_stderr(devnull) do
                    Test.@test_throws Exceptions.IncorrectArgument Integrators.SciML(dt=-0.1)
                    Test.@test_throws Exceptions.IncorrectArgument Integrators.SciML(dt=0.0)
                end
            end
            
            Test.@testset "dtmax must be positive" begin
                redirect_stderr(devnull) do
                    Test.@test_throws Exceptions.IncorrectArgument Integrators.SciML(dtmax=-0.1)
                    Test.@test_throws Exceptions.IncorrectArgument Integrators.SciML(dtmax=0.0)
                end
            end
            
            Test.@testset "dtmin must be positive" begin
                redirect_stderr(devnull) do
                    Test.@test_throws Exceptions.IncorrectArgument Integrators.SciML(dtmin=-1e-5)
                    Test.@test_throws Exceptions.IncorrectArgument Integrators.SciML(dtmin=0.0)
                end
            end
        end

        # ====================================================================
        # UNIT TESTS - Problem Building
        # ====================================================================

        Test.@testset "Problem Building" begin
            Test.@testset "builds ODEProblem without variable" begin
                # Create a simple system
                sys = Systems.VectorFieldSystem(
                    Data.VectorField(x -> -x; is_autonomous=true, is_variable=false)
                )

                config = Configs.StatePointConfig(0.0, [1.0, 2.0], 1.0)
                integ = Integrators.SciML()

                # Build ODE problem
                prob = Integrators.build_problem(integ, sys, config; variable=nothing, cache=nothing)

                Test.@test prob isa SciMLBase.AbstractODEProblem
                Test.@test prob.p isa Common.ODEParameters
                Test.@test Common.variable(prob.p) === nothing
            end
            
            Test.@testset "builds ODEProblem with variable parameter" begin
                # Create a simple system that takes a variable
                sys = Systems.VectorFieldSystem(
                    Data.VectorField((x, v) -> x .+ v; is_autonomous=true, is_variable=true)
                )

                config = Configs.StatePointConfig(0.0, [1.0, 2.0], 1.0)
                integ = Integrators.SciML()

                # Build ODE problem with variable
                prob = Integrators.build_problem(integ, sys, config; variable=0.5, cache=nothing)

                Test.@test prob isa SciMLBase.AbstractODEProblem
                Test.@test prob.p isa Common.ODEParameters
                Test.@test Common.variable(prob.p) == 0.5
            end
        end

        # ====================================================================
        # UNIT TESTS - Solving
        # ====================================================================

        Test.@testset "Solving" begin
            # Create a simple system
            sys = Systems.VectorFieldSystem(
                Data.VectorField(x -> -x; is_autonomous=true, is_variable=false)
            )

            config = Configs.StatePointConfig(0.0, [1.0, 2.0], 1.0)
            integ = Integrators.SciML(maxiters=1000, reltol=1e-6)

            # Build ODE problem
            prob = Integrators.build_problem(integ, sys, config; variable=nothing, cache=nothing)

            # Build options
            opts = Integrators.build_options(integ, config)

            # Solve
            result = Integrators.solve_problem(integ, prob, opts)

            Test.@test result isa CTFlowsSciML.SciMLIntegrationResult
            Test.@test result isa Integrators.AbstractIntegrationResult
        end

        redirect_stderr(devnull) do
            Test.@testset "SolverFailure on failed retcode" begin
                # Create a simple ODE problem that will fail with maxiters=1
                prob = ODEProblem((du, u, p, t) -> du .= u, [1.0], (0.0, 1.0))
                integ = Integrators.SciML(maxiters=1)
                config = Configs.StatePointConfig(0.0, [1.0], 1.0)
                opts = Integrators.build_options(integ, config)

                # Test that solve_problem throws SolverFailure when unsafe=false
                Test.@test_throws Exceptions.SolverFailure Integrators.solve_problem(integ, prob, opts; unsafe=false)

                # Test the exception contains correct fields
                try
                    Integrators.solve_problem(integ, prob, opts; unsafe=false)
                catch e
                    Test.@test e isa Exceptions.SolverFailure
                    Test.@test occursin("MaxIters", e.retcode)
                    Test.@test e.context == "SciML solve_problem"
                end
            end
        end

        redirect_stderr(devnull) do
            Test.@testset "unsafe=true bypasses retcode check" begin
                # Create a simple ODE problem that will fail with maxiters=1
                prob = ODEProblem((du, u, p, t) -> du .= u, [1.0], (0.0, 1.0))
                integ = Integrators.SciML(maxiters=1)
                config = Configs.StatePointConfig(0.0, [1.0], 1.0)
                opts = Integrators.build_options(integ, config)

                # With unsafe=true, should not throw even with bad retcode
                result = Integrators.solve_problem(integ, prob, opts; unsafe=true)
                Test.@test result isa CTFlowsSciML.SciMLIntegrationResult
            end
        end

        # ====================================================================
        # UNIT TESTS - Semantic Accessors
        # ====================================================================

        Test.@testset "Semantic Accessors" begin
            sys = Systems.VectorFieldSystem(
                Data.VectorField(x -> -x; is_autonomous=true, is_variable=false)
            )

            config = Configs.StateTrajectoryConfig((0.0, 1.0), [1.0, 2.0])
            integ = Integrators.SciML(maxiters=1000, reltol=1e-6)

            prob = Integrators.build_problem(integ, sys, config; variable=nothing, cache=nothing)
            opts = Integrators.build_options(integ, config)
            result = Integrators.solve_problem(integ, prob, opts)

            Test.@test Integrators.final_state(result) isa Vector{Float64}
            Test.@test length(Integrators.final_state(result)) == 2
            
            ts = Integrators.times(result)
            Test.@test ts isa Vector{Float64}
            Test.@test ts[1] == 0.0
            Test.@test ts[end] == 1.0

            Test.@test Integrators.evaluate_at(result, 0.5) isa Vector{Float64}
        end

        # ====================================================================
        # INTEGRATION TESTS - Full Workflow
        # ====================================================================

        Test.@testset "Full Workflow" begin
            Test.@testset "StatePointConfig workflow" begin
                sys = Systems.VectorFieldSystem(
                    Data.VectorField(x -> -x; is_autonomous=true, is_variable=false)
                )

                config = Configs.StatePointConfig(0.0, 1.0, 1.0)
                integ = Integrators.SciML(maxiters=1000, reltol=1e-6)

                # Build problem
                prob = Integrators.build_problem(integ, sys, config; variable=nothing, cache=nothing)

                # Build options
                opts = Integrators.build_options(integ, config)

                # Solve
                result = Integrators.solve_problem(integ, prob, opts)

                # Build solution
                flow_sol = Solutions.build_solution(Configs.mode_trait(config), Configs.content_trait(config), config, result)

                Test.@test flow_sol isa Number
            end

            Test.@testset "StateTrajectoryConfig workflow" begin
                sys = Systems.VectorFieldSystem(
                    Data.VectorField(x -> -x; is_autonomous=true, is_variable=false)
                )

                config = Configs.StateTrajectoryConfig((0.0, 1.0), [1.0, 2.0])
                integ = Integrators.SciML(maxiters=1000, reltol=1e-6)

                # Build problem
                prob = Integrators.build_problem(integ, sys, config; variable=nothing, cache=nothing)

                # Build options
                opts = Integrators.build_options(integ, config)

                # Solve
                result = Integrators.solve_problem(integ, prob, opts)

                # Build solution
                flow_sol = Solutions.build_solution(Configs.mode_trait(config), Configs.content_trait(config), config, result)

                Test.@test flow_sol isa Solutions.VectorFieldSolution
            end
        end

        # ====================================================================
        # INTEGRATION TESTS - InPlace VF × mutable/immutable u0
        # ====================================================================

        Test.@testset "InPlace VF — SciML integration" begin
            integ = Integrators.SciML(maxiters=10000, reltol=1e-8, abstol=1e-10)
            # ODE: dx/dt = -x  →  x(t) = x₀ · e^{-t}

            Test.@testset "OOP VF + mutable Vector u0" begin
                vf  = Data.VectorField(x -> -x; is_autonomous=true, is_variable=false)
                sys = Systems.VectorFieldSystem(vf)
                u0  = [1.0, 2.0]
                config = Configs.StatePointConfig(0.0, u0, 1.0)
                prob = Integrators.build_problem(integ, sys, config; variable=nothing, cache=nothing)
                opts = Integrators.build_options(integ, config)
                result = Integrators.solve_problem(integ, prob, opts)
                xf = Integrators.final_state(result)
                Test.@test xf ≈ exp(-1.0) .* [1.0, 2.0]  atol=1e-5
            end

            Test.@testset "OOP VF + SVector u0" begin
                vf  = Data.VectorField(x -> -x; is_autonomous=true, is_variable=false)
                sys = Systems.VectorFieldSystem(vf)
                u0  = SA[1.0, 2.0]
                config = Configs.StatePointConfig(0.0, u0, 1.0)
                prob = Integrators.build_problem(integ, sys, config; variable=nothing, cache=nothing)
                opts = Integrators.build_options(integ, config)
                result = Integrators.solve_problem(integ, prob, opts)
                xf = Integrators.final_state(result)
                Test.@test xf ≈ exp(-1.0) .* [1.0, 2.0]  atol=1e-5
            end

            Test.@testset "IP VF + mutable Vector u0" begin
                vf  = Data.VectorField((du, x) -> (du .= -x); is_autonomous=true, is_variable=false)
                sys = Systems.VectorFieldSystem(vf)
                u0  = [1.0, 2.0]
                config = Configs.StatePointConfig(0.0, u0, 1.0)
                prob = Integrators.build_problem(integ, sys, config; variable=nothing, cache=nothing)
                opts = Integrators.build_options(integ, config)
                result = Integrators.solve_problem(integ, prob, opts)
                xf = Integrators.final_state(result)
                Test.@test xf ≈ exp(-1.0) .* [1.0, 2.0]  atol=1e-5
            end

            Test.@testset "IP VF + SVector u0 (warns, uses rhs_oop_finalize)" begin
                vf  = Data.VectorField((du, x) -> (du .= -x); is_autonomous=true, is_variable=false)
                sys = Systems.VectorFieldSystem(vf)
                u0  = SA[1.0, 2.0]
                config = Configs.StatePointConfig(0.0, u0, 1.0)
                prob = Test.@test_logs (:warn, r"InPlace VectorField") Integrators.build_problem(integ, sys, config; variable=nothing, cache=nothing)
                opts = Integrators.build_options(integ, config)
                result = Integrators.solve_problem(integ, prob, opts)
                xf = Integrators.final_state(result)
                Test.@test xf ≈ exp(-1.0) .* [1.0, 2.0]  atol=1e-5
            end
        end

        # ====================================================================
        # INTEGRATION TESTS - InPlace HVF × mutable/immutable u0
        # ====================================================================

        Test.@testset "InPlace HVF — SciML integration" begin
            integ = Integrators.SciML(maxiters=10000, reltol=1e-8, abstol=1e-10)
            # ODE: dx/dt = x, dp/dt = -p  →  x(t)=x₀·eᵗ, p(t)=p₀·e^{-t}

            Test.@testset "OOP HVF + mutable Vector u0" begin
                hvf = Data.HamiltonianVectorField((x, p) -> (x, -p); is_autonomous=true, is_variable=false)
                sys = Systems.HamiltonianVectorFieldSystem(hvf)
                x0  = 1.0
                p0  = 0.5
                config = Configs.HamiltonianPointConfig(0.0, x0, p0, 1.0)
                prob = Integrators.build_problem(integ, sys, config; variable=nothing, cache=nothing)
                opts = Integrators.build_options(integ, config)
                result = Integrators.solve_problem(integ, prob, opts)
                xf = Integrators.final_state(result)
                Test.@test xf[1] ≈ exp(1.0)       atol=1e-5
                Test.@test xf[2] ≈ 0.5*exp(-1.0)  atol=1e-5
            end

            Test.@testset "OOP HVF + SVector u0" begin
                hvf = Data.HamiltonianVectorField((x, p) -> (x, -p); is_autonomous=true, is_variable=false)
                sys = Systems.HamiltonianVectorFieldSystem(hvf)
                x0  = SA[1.0]
                p0  = SA[0.5]
                config = Configs.HamiltonianPointConfig(0.0, x0, p0, 1.0)
                prob = Integrators.build_problem(integ, sys, config; variable=nothing, cache=nothing)
                opts = Integrators.build_options(integ, config)
                result = Integrators.solve_problem(integ, prob, opts)
                xf = Integrators.final_state(result)
                Test.@test xf[1] ≈ exp(1.0)       atol=1e-5
                Test.@test xf[2] ≈ 0.5*exp(-1.0)  atol=1e-5
            end

            Test.@testset "IP HVF + mutable Vector u0" begin
                hvf = Data.HamiltonianVectorField((dx, dp, x, p) -> (dx .= x; dp .= -p); is_autonomous=true, is_variable=false)
                sys = Systems.HamiltonianVectorFieldSystem(hvf)
                x0  = 1.0
                p0  = 0.5
                config = Configs.HamiltonianPointConfig(0.0, x0, p0, 1.0)
                prob = Integrators.build_problem(integ, sys, config; variable=nothing, cache=nothing)
                opts = Integrators.build_options(integ, config)
                result = Integrators.solve_problem(integ, prob, opts)
                xf = Integrators.final_state(result)
                Test.@test xf[1] ≈ exp(1.0)       atol=1e-5
                Test.@test xf[2] ≈ 0.5*exp(-1.0)  atol=1e-5
            end

            Test.@testset "IP HVF + SVector u0 (warns, uses rhs_oop_finalize)" begin
                hvf = Data.HamiltonianVectorField((dx, dp, x, p) -> (dx .= x; dp .= -p); is_autonomous=true, is_variable=false)
                sys = Systems.HamiltonianVectorFieldSystem(hvf)
                x0  = SA[1.0]
                p0  = SA[0.5]
                config = Configs.HamiltonianPointConfig(0.0, x0, p0, 1.0)
                prob = Test.@test_logs (:warn, r"InPlace HamiltonianVectorField") Integrators.build_problem(integ, sys, config; variable=nothing, cache=nothing)
                opts = Integrators.build_options(integ, config)
                result = Integrators.solve_problem(integ, prob, opts)
                xf = Integrators.final_state(result)
                Test.@test xf[1] ≈ exp(1.0)       atol=1e-5
                Test.@test xf[2] ≈ 0.5*exp(-1.0)  atol=1e-5
            end
        end

        # ====================================================================
        # UNIT TESTS - Config-Dependent Options
        # ====================================================================

        Test.@testset "Config-Dependent Options" begin
            integ = Integrators.SciML()
            config_point = Configs.StatePointConfig(0.0, [1.0, 0.0], 1.0)
            config_traj = Configs.StateTrajectoryConfig((0.0, 1.0), [1.0, 0.0])

            Test.@testset "auto defaults resolve correctly for StatePointConfig" begin
                opts = Integrators.build_options(integ, config_point)
                Test.@test opts[:dense] === false
                Test.@test opts[:save_everystep] === false
                Test.@test opts[:save_start] === false
            end

            Test.@testset "auto defaults resolve correctly for StateTrajectoryConfig" begin
                opts = Integrators.build_options(integ, config_traj)
                Test.@test opts[:dense] === true
                Test.@test opts[:save_everystep] === true
                Test.@test opts[:save_start] === true
            end

            Test.@testset "explicit values override auto" begin
                integ_explicit = Integrators.SciML(dense=false, save_everystep=true, save_start=false)
                opts = Integrators.build_options(integ_explicit, config_traj)
                Test.@test opts[:dense] === false
                Test.@test opts[:save_everystep] === true
                Test.@test opts[:save_start] === false
            end

            Test.@testset "build_options dispatch returns correct cached dicts" begin
                opts_point = Integrators.build_options(integ, config_point)
                opts_traj = Integrators.build_options(integ, config_traj)
                Test.@test opts_point === integ.options_point
                Test.@test opts_traj === integ.options_trajectory
                Test.@test opts_point !== opts_traj
            end
        end

        # ====================================================================
        # UNIT TESTS - Integrators.merge
        # ====================================================================

        Test.@testset "Integrators.merge" begin
            Test.@testset "merge of single segment returns same result" begin
                sys = Systems.VectorFieldSystem(
                    Data.VectorField(x -> -x; is_autonomous=true, is_variable=false)
                )
                config = Configs.StatePointConfig(0.0, [1.0], 0.5)
                integ = Integrators.SciML(reltol=1e-8)
                prob = Integrators.build_problem(integ, sys, config; variable=nothing, cache=nothing)
                opts = Integrators.build_options(integ, config)
                result = Integrators.solve_problem(integ, prob, opts)
                merged = Integrators.merge([result])
                Test.@test merged === result
            end

            Test.@testset "merge of two segments concatenates t and u" begin
                sys = Systems.VectorFieldSystem(
                    Data.VectorField(x -> -x; is_autonomous=true, is_variable=false)
                )
                integ = Integrators.SciML(reltol=1e-8)
                
                # First segment: [0, 0.5]
                config1 = Configs.StatePointConfig(0.0, [1.0], 0.5)
                prob1 = Integrators.build_problem(integ, sys, config1; variable=nothing, cache=nothing)
                opts1 = Integrators.build_options(integ, config1)
                result1 = Integrators.solve_problem(integ, prob1, opts1)
                
                # Second segment: [0.5, 1.0]
                xf1 = Integrators.final_state(result1)
                config2 = Configs.StatePointConfig(0.5, xf1, 1.0)
                prob2 = Integrators.build_problem(integ, sys, config2; variable=nothing, cache=nothing)
                opts2 = Integrators.build_options(integ, config2)
                result2 = Integrators.solve_problem(integ, prob2, opts2)
                
                merged = Integrators.merge([result1, result2])
                Test.@test length(merged.ode_sol.t) > 1
                xf_merged = Integrators.final_state(merged)
                Test.@test xf_merged[1] ≈ exp(-1.0) atol=1e-5
            end

            Test.@testset "merge of empty vector throws IncorrectArgument" begin
                Test.@test_throws Exceptions.IncorrectArgument Integrators.merge(CTFlowsSciML.SciMLIntegrationResult[])
            end
        end
    end
end

end # module

test_sciml_extension() = TestSciMLExtension.test_sciml_extension()