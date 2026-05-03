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

# Get extension to access SciML integrator
using OrdinaryDiffEqTsit5: OrdinaryDiffEqTsit5, ODEProblem, Tsit5
using SciMLBase: SciMLBase
const CTFlowsSciMLExt = Base.get_extension(CTFlows, :CTFlowsSciMLExt)

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
                Test.@test !isnothing(CTFlowsSciMLExt)
            end

            Test.@testset "extension is a Module" begin
                Test.@test CTFlowsSciMLExt isa Module
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
                Test.@test_throws Exceptions.IncorrectArgument Integrators.SciML(reltol=-1.0)
                Test.@test_throws Exceptions.IncorrectArgument Integrators.SciML(reltol=0.0)
            end
            
            Test.@testset "abstol must be positive" begin
                Test.@test_throws Exceptions.IncorrectArgument Integrators.SciML(abstol=-1.0)
                Test.@test_throws Exceptions.IncorrectArgument Integrators.SciML(abstol=0.0)
            end
            
            Test.@testset "maxiters must be positive" begin
                Test.@test_throws Exceptions.IncorrectArgument Integrators.SciML(maxiters=-1)
                Test.@test_throws Exceptions.IncorrectArgument Integrators.SciML(maxiters=0)
            end
            
            Test.@testset "dt must be positive" begin
                Test.@test_throws Exceptions.IncorrectArgument Integrators.SciML(dt=-0.1)
                Test.@test_throws Exceptions.IncorrectArgument Integrators.SciML(dt=0.0)
            end
            
            Test.@testset "dtmax must be positive" begin
                Test.@test_throws Exceptions.IncorrectArgument Integrators.SciML(dtmax=-0.1)
                Test.@test_throws Exceptions.IncorrectArgument Integrators.SciML(dtmax=0.0)
            end
            
            Test.@testset "dtmin must be positive" begin
                Test.@test_throws Exceptions.IncorrectArgument Integrators.SciML(dtmin=-1e-5)
                Test.@test_throws Exceptions.IncorrectArgument Integrators.SciML(dtmin=0.0)
            end
        end

        # ====================================================================
        # UNIT TESTS - Problem Building
        # ====================================================================

        Test.@testset "Problem Building" begin
            Test.@testset "builds ODEProblem without variable" begin
                # Create a simple system
                sys = Systems.VectorFieldSystem(
                    Data.VectorField(x -> -x; autonomous=true, variable=false)
                )

                config = Common.PointConfig(0.0, [1.0, 2.0], 1.0)
                integ = Integrators.SciML()

                # Build ODE problem
                prob = Integrators.build_problem(integ, sys, config; variable=nothing)

                Test.@test prob isa SciMLBase.AbstractODEProblem
                Test.@test prob.p === nothing
            end
            
            Test.@testset "builds ODEProblem with variable parameter" begin
                # Create a simple system that takes a variable
                sys = Systems.VectorFieldSystem(
                    Data.VectorField((x, v) -> x .+ v; autonomous=true, variable=true)
                )

                config = Common.PointConfig(0.0, [1.0, 2.0], 1.0)
                integ = Integrators.SciML()

                # Build ODE problem with variable
                prob = Integrators.build_problem(integ, sys, config; variable=0.5)

                Test.@test prob isa SciMLBase.AbstractODEProblem
                Test.@test prob.p == 0.5
            end
        end

        # ====================================================================
        # UNIT TESTS - Solving
        # ====================================================================

        Test.@testset "Solving" begin
            # Create a simple system
            sys = Systems.VectorFieldSystem(
                Data.VectorField(x -> -x; autonomous=true, variable=false)
            )

            config = Common.PointConfig(0.0, [1.0, 2.0], 1.0)
            integ = Integrators.SciML(maxiters=1000, reltol=1e-6)

            # Build ODE problem
            prob = Integrators.build_problem(integ, sys, config; variable=nothing)

            # Solve
            result = Integrators.solve_problem(integ, prob)

            Test.@test result isa CTFlowsSciMLExt.SciMLIntegrationResult
            Test.@test result isa Solutions.AbstractIntegrationResult
        end

        # ====================================================================
        # UNIT TESTS - Semantic Accessors
        # ====================================================================

        Test.@testset "Semantic Accessors" begin
            sys = Systems.VectorFieldSystem(
                Data.VectorField(x -> -x; autonomous=true, variable=false)
            )

            config = Common.TrajectoryConfig((0.0, 1.0), [1.0, 2.0])
            integ = Integrators.SciML(maxiters=1000, reltol=1e-6)

            prob = Integrators.build_problem(integ, sys, config; variable=nothing)
            result = Integrators.solve_problem(integ, prob)

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
            Test.@testset "PointConfig workflow" begin
                sys = Systems.VectorFieldSystem(
                    Data.VectorField(x -> -x; autonomous=true, variable=false)
                )

                config = Common.PointConfig(0.0, 1.0, 1.0)
                integ = Integrators.SciML(maxiters=1000, reltol=1e-6)

                # Build problem
                prob = Integrators.build_problem(integ, sys, config; variable=nothing)

                # Solve
                result = Integrators.solve_problem(integ, prob)

                # Build solution
                flow_sol = Solutions.build_solution(result, sys, config)

                Test.@test flow_sol isa Number
            end

            Test.@testset "TrajectoryConfig workflow" begin
                sys = Systems.VectorFieldSystem(
                    Data.VectorField(x -> -x; autonomous=true, variable=false)
                )

                config = Common.TrajectoryConfig((0.0, 1.0), [1.0, 2.0])
                integ = Integrators.SciML(maxiters=1000, reltol=1e-6)

                # Build problem
                prob = Integrators.build_problem(integ, sys, config; variable=nothing)

                # Solve
                result = Integrators.solve_problem(integ, prob)

                # Build solution
                flow_sol = Solutions.build_solution(result, sys, config)

                Test.@test flow_sol isa Solutions.VectorFieldSolution
            end
        end
    end
end

end # module

test_sciml_extension() = TestSciMLExtension.test_sciml_extension()