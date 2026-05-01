module TestSciMLExtension

import Test
import CTFlows: CTFlows
import CTFlows.Common: Common
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
        # UNIT TESTS - Callable: Problem Building
        # ====================================================================

        Test.@testset "Problem Building" begin
            # Create a simple system
            sys = Systems.VectorFieldSystem(
                Common.Data.VectorField(x -> -x; autonomous=true, variable=false)
            )

            config = Common.PointConfig(0.0, [1.0, 2.0], 1.0)
            integ = Integrators.SciML()

            # Build ODE problem
            prob = integ(sys, config; variable=nothing)

            Test.@test prob isa SciMLBase.AbstractODEProblem
        end

        # ====================================================================
        # UNIT TESTS - Callable: Solving
        # ====================================================================

        Test.@testset "Solving" begin
            # Create a simple system
            sys = Systems.VectorFieldSystem(
                Common.Data.VectorField(x -> -x; autonomous=true, variable=false)
            )

            config = Common.PointConfig(0.0, [1.0, 2.0], 1.0)
            integ = Integrators.SciML(maxiters=1000, reltol=1e-6)

            # Build ODE problem
            prob = integ(sys, config; variable=nothing)

            # Solve
            ode_sol = integ(prob)

            Test.@test ode_sol isa SciMLBase.AbstractODESolution
        end

        # ====================================================================
        # UNIT TESTS - Callable: Solution Building
        # ====================================================================

        Test.@testset "Solution Building" begin
            # Create a simple system
            sys = Systems.VectorFieldSystem(
                Common.Data.VectorField(x -> -x; autonomous=true, variable=false)
            )

            config = Common.TrajectoryConfig((0.0, 1.0), [1.0, 2.0])
            integ = Integrators.SciML(maxiters=1000, reltol=1e-6)

            # Build ODE problem
            prob = integ(sys, config; variable=nothing)

            # Solve
            ode_sol = integ(prob)

            # Build flow solution
            flow_sol = integ(ode_sol, sys, config)

            Test.@test flow_sol isa Solutions.VectorFieldSolution
        end

        # ====================================================================
        # INTEGRATION TESTS - Full Workflow
        # ====================================================================

        Test.@testset "Full Workflow" begin
            Test.@testset "PointConfig workflow" begin
                sys = Systems.VectorFieldSystem(
                    Common.Data.VectorField(x -> -x; autonomous=true, variable=false)
                )

                config = Common.PointConfig(0.0, [1.0, 2.0], 1.0)
                integ = Integrators.SciML(maxiters=1000, reltol=1e-6)

                # Build problem
                prob = integ(sys, config; variable=nothing)

                # Solve
                ode_sol = integ(prob)

                # Build solution
                flow_sol = integ(ode_sol, sys, config)

                Test.@test flow_sol isa Number
            end

            Test.@testset "TrajectoryConfig workflow" begin
                sys = Systems.VectorFieldSystem(
                    Common.Data.VectorField(x -> -x; autonomous=true, variable=false)
                )

                config = Common.TrajectoryConfig((0.0, 1.0), [1.0, 2.0])
                integ = Integrators.SciML(maxiters=1000, reltol=1e-6)

                # Build problem
                prob = integ(sys, config; variable=nothing)

                # Solve
                ode_sol = integ(prob)

                # Build solution
                flow_sol = integ(ode_sol, sys, config)

                Test.@test flow_sol isa Solutions.VectorFieldSolution
            end
        end
    end
end

end # module

test_sciml_extension() = TestSciMLExtension.test_sciml_extension()