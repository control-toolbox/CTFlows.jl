module TestSciMLExtension

import Test
import CTBase.Exceptions: Exceptions
import CTFlows: CTFlows
import CTFlows.Common: Common
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

                config = Common.StatePointConfig(0.0, [1.0, 2.0], 1.0)
                integ = Integrators.SciML()

                # Build ODE problem
                prob = Integrators.build_problem(integ, sys, config; variable=nothing)

                Test.@test prob isa SciMLBase.AbstractODEProblem
                Test.@test prob.p isa Common.ODEParameters
                Test.@test prob.p.variable === nothing
            end
            
            Test.@testset "builds ODEProblem with variable parameter" begin
                # Create a simple system that takes a variable
                sys = Systems.VectorFieldSystem(
                    Data.VectorField((x, v) -> x .+ v; is_autonomous=true, is_variable=true)
                )

                config = Common.StatePointConfig(0.0, [1.0, 2.0], 1.0)
                integ = Integrators.SciML()

                # Build ODE problem with variable
                prob = Integrators.build_problem(integ, sys, config; variable=0.5)

                Test.@test prob isa SciMLBase.AbstractODEProblem
                Test.@test prob.p isa Common.ODEParameters
                Test.@test prob.p.variable == 0.5
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

            config = Common.StatePointConfig(0.0, [1.0, 2.0], 1.0)
            integ = Integrators.SciML(maxiters=1000, reltol=1e-6)

            # Build ODE problem
            prob = Integrators.build_problem(integ, sys, config; variable=nothing)

            # Build options
            opts = Integrators.build_options(integ, config)

            # Solve
            result = Integrators.solve_problem(integ, prob, opts)

            Test.@test result isa CTFlowsSciML.SciMLIntegrationResult
            Test.@test result isa Solutions.AbstractIntegrationResult
        end

        redirect_stderr(devnull) do
            Test.@testset "SolverFailure on failed retcode" begin
                # Create a simple ODE problem that will fail with maxiters=1
                prob = ODEProblem((du, u, p, t) -> du .= u, [1.0], (0.0, 1.0))
                integ = Integrators.SciML(maxiters=1)
                config = Common.StatePointConfig(0.0, [1.0], 1.0)
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
                config = Common.StatePointConfig(0.0, [1.0], 1.0)
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

            config = Common.StateTrajectoryConfig((0.0, 1.0), [1.0, 2.0])
            integ = Integrators.SciML(maxiters=1000, reltol=1e-6)

            prob = Integrators.build_problem(integ, sys, config; variable=nothing)
            opts = Integrators.build_options(integ, config)
            result = Integrators.solve_problem(integ, prob, opts)

            Test.@test Solutions.final_state(result) isa Vector{Float64}
            Test.@test length(Solutions.final_state(result)) == 2
            
            ts = Solutions.times(result)
            Test.@test ts isa Vector{Float64}
            Test.@test ts[1] == 0.0
            Test.@test ts[end] == 1.0

            Test.@test Solutions.evaluate_at(result, 0.5) isa Vector{Float64}
        end

        # ====================================================================
        # INTEGRATION TESTS - Full Workflow
        # ====================================================================

        Test.@testset "Full Workflow" begin
            Test.@testset "StatePointConfig workflow" begin
                sys = Systems.VectorFieldSystem(
                    Data.VectorField(x -> -x; is_autonomous=true, is_variable=false)
                )

                config = Common.StatePointConfig(0.0, 1.0, 1.0)
                integ = Integrators.SciML(maxiters=1000, reltol=1e-6)

                # Build problem
                prob = Integrators.build_problem(integ, sys, config; variable=nothing)

                # Build options
                opts = Integrators.build_options(integ, config)

                # Solve
                result = Integrators.solve_problem(integ, prob, opts)

                # Build solution
                flow_sol = Solutions.build_solution(result, sys, config)

                Test.@test flow_sol isa Number
            end

            Test.@testset "StateTrajectoryConfig workflow" begin
                sys = Systems.VectorFieldSystem(
                    Data.VectorField(x -> -x; is_autonomous=true, is_variable=false)
                )

                config = Common.StateTrajectoryConfig((0.0, 1.0), [1.0, 2.0])
                integ = Integrators.SciML(maxiters=1000, reltol=1e-6)

                # Build problem
                prob = Integrators.build_problem(integ, sys, config; variable=nothing)

                # Build options
                opts = Integrators.build_options(integ, config)

                # Solve
                result = Integrators.solve_problem(integ, prob, opts)

                # Build solution
                flow_sol = Solutions.build_solution(result, sys, config)

                Test.@test flow_sol isa Solutions.VectorFieldSolution
            end
        end

        # ====================================================================
        # UNIT TESTS - Config-Dependent Options
        # ====================================================================

        Test.@testset "Config-Dependent Options" begin
            integ = Integrators.SciML()
            config_point = Common.StatePointConfig(0.0, [1.0, 0.0], 1.0)
            config_traj = Common.StateTrajectoryConfig((0.0, 1.0), [1.0, 0.0])

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
    end
end

end # module

test_sciml_extension() = TestSciMLExtension.test_sciml_extension()