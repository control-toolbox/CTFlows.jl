module TestAbstractFlow

import Test
import CTBase.Exceptions
import CTFlows.Systems
import CTFlows.Flows
import CTFlows.Common
import CTFlows.Traits
import CTFlows.Integrators
import CTFlows.Data
import CTSolvers

const VERBOSE = isdefined(Main, :TestOptions) ? Main.TestOptions.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestOptions) ? Main.TestOptions.SHOWTIMING : true

# ==============================================================================
# Fake types for contract testing
# ==============================================================================

"""
Fake system for testing the AbstractFlow contract.

This minimal implementation provides the required contract methods for AbstractSystem
to test flow behavior without full system complexity.
"""
struct FakeSystem <: Systems.AbstractStateSystem{Traits.Autonomous, Traits.Fixed}
    state_dim::Int
end

function Systems.rhs(sys::FakeSystem)
    return (du, u, p, t) -> nothing
end

struct FakeIntegrator <: Integrators.AbstractIntegrator
    result::Any
end

CTSolvers.Strategies.id(::Type{FakeIntegrator}) = :fake_integrator
CTSolvers.Strategies.metadata(::Type{FakeIntegrator}) = CTSolvers.Strategies.StrategyMetadata()
CTSolvers.Strategies.options(integ::FakeIntegrator) = CTSolvers.Strategies.StrategyOptions()

"""
Fake flow for testing the AbstractFlow contract.

This minimal implementation provides the required contract methods to test
routing and default behavior without full flow complexity.
"""
struct FakeFlow{TD<:Traits.TimeDependence, VD<:Traits.VariableDependence} <: Flows.AbstractFlow{TD, VD}
    sys::Systems.AbstractSystem{TD, VD}
    integ::Any
    function FakeFlow(sys::Systems.AbstractSystem, integ::Any)
        return new{Traits.time_dependence(sys), Traits.variable_dependence(sys)}(sys, integ)
    end
end

function Flows.system(f::FakeFlow)
    return f.sys
end

function Flows.integrator(f::FakeFlow)
    return f.integ
end

function (f::FakeFlow)(t0, x0, tf)
    return :fake_trajectory
end

function (f::FakeFlow)(t0, x0, p0, tf)
    return :fake_trajectory_with_costate
end

function (f::FakeFlow)(config::Common.AbstractConfig)
    return :fake_config_trajectory
end

"""
Minimal flow that does not implement the contract (for error testing).
"""
struct MinimalFlow <: Flows.AbstractFlow{Traits.Autonomous, Traits.Fixed}
    sys::Systems.AbstractSystem{Traits.Autonomous, Traits.Fixed}
end

# ==============================================================================
# Test function
# ==============================================================================

function test_abstract_flow()
    Test.@testset "Abstract Flow Tests" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ====================================================================
        # UNIT TESTS - Abstract Types
        # ====================================================================

        Test.@testset "Abstract Types" begin
            sys = FakeSystem(2)
            Test.@test FakeFlow(sys, :fake_integ) isa Flows.AbstractFlow
            Test.@test MinimalFlow(sys) isa Flows.AbstractFlow
        end

        Test.@testset "Hierarchy" begin
            sys = FakeSystem(2)
            Test.@test isdefined(Flows, :AbstractStateFlow)
            Test.@test isdefined(Flows, :AbstractHamiltonianFlow)
            Test.@test isdefined(Flows, :StateFlow)
            Test.@test isdefined(Flows, :HamiltonianFlow)
        end

        # ====================================================================
        # UNIT TESTS - Contract Implementation
        # ====================================================================

        Test.@testset "Contract Implementation" begin
            sys = FakeSystem(2)
            flow = FakeFlow(sys, :fake_integ)

            Test.@testset "system returns system" begin
                Test.@test Flows.system(flow) === sys
            end

            Test.@testset "integrator returns integrator" begin
                Test.@test Flows.integrator(flow) === :fake_integ
            end

            Test.@testset "FakeFlow has correct VD parameter" begin
                Test.@test flow isa FakeFlow{Traits.Autonomous, Traits.Fixed}
            end

            Test.@testset "callable (t0, x0, tf)" begin
                result = flow(0.0, [1.0, 0.0], 1.0)
                Test.@test result === :fake_trajectory
            end

            Test.@testset "callable (t0, x0, p0, tf)" begin
                result = flow(0.0, [1.0, 0.0], [0.0, 0.0], 1.0)
                Test.@test result === :fake_trajectory_with_costate
            end

            Test.@testset "callable with config" begin
                config = Common.StatePointConfig(0.0, [1.0, 0.0], 1.0)
                result = flow(config)
                Test.@test result === :fake_config_trajectory
            end

            Test.@testset "callable with StateTrajectoryConfig" begin
                config = Common.StateTrajectoryConfig((0.0, 1.0), [1.0, 0.0])
                result = flow(config)
                Test.@test result === :fake_config_trajectory
            end
        end

        # ====================================================================
        # UNIT TESTS - NotImplemented Errors
        # ====================================================================

        Test.@testset "NotImplemented Errors" begin
            sys = FakeSystem(2)
            flow = MinimalFlow(sys)

            Test.@testset "system throws NotImplemented" begin
                try
                    Flows.system(flow)
                    Test.@test false  # Should not reach here
                catch err
                    Test.@test err isa Exceptions.NotImplemented
                    Test.@test occursin("system", sprint(showerror, err))
                end
            end

            Test.@testset "integrator throws NotImplemented" begin
                try
                    Flows.integrator(flow)
                    Test.@test false  # Should not reach here
                catch err
                    Test.@test err isa Exceptions.NotImplemented
                    Test.@test occursin("integrator", sprint(showerror, err))
                end
            end
        end

        # ====================================================================
        # UNIT TESTS - Base.show
        # ====================================================================

        Test.@testset "Base.show" begin
            sys = FakeSystem(2)
            flow = FakeFlow(sys, FakeIntegrator(0))

            Test.@testset "MIME text/plain" begin
                io = IOBuffer()
                show(io, MIME("text/plain"), flow)
                output = String(take!(io))
                Test.@test occursin("FakeFlow", output)
            end

            Test.@testset "compact" begin
                io = IOBuffer()
                show(io, flow)
                output = String(take!(io))
                Test.@test occursin("FakeFlow", output)
            end
        end

        # ====================================================================
        # UNIT TESTS - Predicate Methods
        # ====================================================================

        Test.@testset "Predicate Methods" begin
            Test.@testset "FakeFlow with FakeSystem" begin
                sys = FakeSystem(2)
                int = FakeIntegrator(0)
                flow = FakeFlow(sys, int)

                Test.@testset "is_autonomous" begin
                    Test.@test Traits.is_autonomous(flow) === true
                end

                Test.@testset "is_nonautonomous" begin
                    Test.@test Traits.is_nonautonomous(flow) === false
                end

                Test.@testset "is_variable" begin
                    Test.@test Traits.is_variable(flow) === false
                end

                Test.@testset "is_nonvariable" begin
                    Test.@test Traits.is_nonvariable(flow) === true
                end

                Test.@testset "has_variable" begin
                    Test.@test Traits.has_variable(flow) === false
                end
            end

            Test.@testset "MinimalFlow without system() - predicates work from type parameters" begin
                sys = FakeSystem(2)
                flow = MinimalFlow(sys)

                Test.@testset "is_autonomous works from type parameter" begin
                    # Predicates now read directly from type parameters, not from system
                    Test.@test Traits.is_autonomous(flow) === true
                end

                Test.@testset "is_variable works from type parameter" begin
                    # Predicates now read directly from type parameters, not from system
                    Test.@test Traits.is_variable(flow) === false
                end
            end
        end

        # ====================================================================
        # INTEGRATION TESTS - VectorField Flow
        # ====================================================================

        Test.@testset "VectorField Flow Integration Tests" begin
            Test.@testset "Autonomous Fixed Flow" begin
                vf = Data.VectorField(x -> -x; is_autonomous=true, is_variable=false)
                sys = Systems.VectorFieldSystem(vf)
                integ = :fake_integ
                flow = FakeFlow(sys, integ)

                Test.@test flow isa FakeFlow{Traits.Autonomous, Traits.Fixed}
                Test.@test Traits.is_autonomous(flow) === true
                Test.@test Traits.is_nonautonomous(flow) === false
                Test.@test Traits.is_variable(flow) === false
                Test.@test Traits.is_nonvariable(flow) === true
                Test.@test Traits.has_variable(flow) === false
            end

            Test.@testset "NonAutonomous Fixed Flow" begin
                vf = Data.VectorField((t, x) -> t .* x; is_autonomous=false, is_variable=false)
                sys = Systems.VectorFieldSystem(vf)
                integ = :fake_integ
                flow = FakeFlow(sys, integ)

                Test.@test flow isa FakeFlow{Traits.NonAutonomous, Traits.Fixed}
                Test.@test Traits.is_autonomous(flow) === false
                Test.@test Traits.is_nonautonomous(flow) === true
                Test.@test Traits.is_variable(flow) === false
                Test.@test Traits.is_nonvariable(flow) === true
                Test.@test Traits.has_variable(flow) === false
            end

            Test.@testset "Autonomous NonFixed Flow" begin
                vf = Data.VectorField((x, v) -> x .+ v; is_autonomous=true, is_variable=true)
                sys = Systems.VectorFieldSystem(vf)
                integ = :fake_integ
                flow = FakeFlow(sys, integ)

                Test.@test flow isa FakeFlow{Traits.Autonomous, Traits.NonFixed}
                Test.@test Traits.is_autonomous(flow) === true
                Test.@test Traits.is_nonautonomous(flow) === false
                Test.@test Traits.is_variable(flow) === true
                Test.@test Traits.is_nonvariable(flow) === false
                Test.@test Traits.has_variable(flow) === true
            end
        end
    end
end

end # module

test_abstract_flow() = TestAbstractFlow.test_abstract_flow()
