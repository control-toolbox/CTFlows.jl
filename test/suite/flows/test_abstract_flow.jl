module TestAbstractFlow

import Test
import CTBase.Exceptions
import CTFlows.Systems
import CTFlows.Flows
import CTFlows.Common

const VERBOSE = isdefined(Main, :TestOptions) ? Main.TestOptions.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestOptions) ? Main.TestOptions.SHOWTIMING : true

# ==============================================================================
# Fake types for contract testing
# ==============================================================================

"""
Fake system for testing.
"""
struct FakeSystem <: Systems.AbstractSystem
    state_dim::Int
end

function Systems.rhs!(sys::FakeSystem)
    return (du, u, p, t) -> nothing
end

function Systems.build_solution(sys::FakeSystem, ode_sol)
    return ode_sol
end

function Systems.variable_dependence(sys::FakeSystem)
    return Common.Fixed
end

"""
Fake flow for testing the AbstractFlow contract.

This minimal implementation provides the required contract methods to test
routing and default behavior without full flow complexity.
"""
struct FakeFlow{VD<:Systems.VariableDependence} <: Flows.AbstractFlow
    sys::Systems.AbstractSystem
    integ::Any
end

function FakeFlow(sys::Systems.AbstractSystem, integ::Any)
    return FakeFlow{Systems.variable_dependence(sys)}(sys, integ)
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

# Add predicate methods to FakeSystem for testing
function Systems.is_autonomous(sys::FakeSystem)
    return true
end

function Systems.is_nonautonomous(sys::FakeSystem)
    return false
end

function Systems.is_variable(sys::FakeSystem)
    return false
end

function Systems.is_nonvariable(sys::FakeSystem)
    return true
end

function Systems.has_variable(sys::FakeSystem)
    return false
end

"""
Minimal flow that does not implement the contract (for error testing).
"""
struct MinimalFlow <: Flows.AbstractFlow
    sys::Systems.AbstractSystem
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
                Test.@test flow isa FakeFlow{Common.Fixed}
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
                config = Common.PointConfig(0.0, [1.0, 0.0], 1.0)
                result = flow(config)
                Test.@test result === :fake_config_trajectory
            end

            Test.@testset "callable with TrajectoryConfig" begin
                config = Common.TrajectoryConfig((0.0, 1.0), [1.0, 0.0])
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

            Test.@testset "callable with config throws NotImplemented" begin
                config = Common.PointConfig(0.0, [1.0, 0.0], 1.0)
                try
                    flow(config)
                    Test.@test false  # Should not reach here
                catch err
                    Test.@test err isa Exceptions.NotImplemented
                    Test.@test occursin("config", sprint(showerror, err))
                end
            end

            Test.@testset "callable with TrajectoryConfig throws NotImplemented" begin
                config = Common.TrajectoryConfig((0.0, 1.0), [1.0, 0.0])
                try
                    flow(config)
                    Test.@test false  # Should not reach here
                catch err
                    Test.@test err isa Exceptions.NotImplemented
                    Test.@test occursin("config", sprint(showerror, err))
                end
            end
        end

        # ====================================================================
        # UNIT TESTS - Base.show
        # ====================================================================

        Test.@testset "Base.show" begin
            sys = FakeSystem(2)
            flow = FakeFlow(sys, :fake_integ)

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
                flow = FakeFlow(sys, :fake_integ)

                Test.@testset "is_autonomous" begin
                    Test.@test Flows.is_autonomous(flow) === true
                end

                Test.@testset "is_nonautonomous" begin
                    Test.@test Flows.is_nonautonomous(flow) === false
                end

                Test.@testset "is_variable" begin
                    Test.@test Flows.is_variable(flow) === false
                end

                Test.@testset "is_nonvariable" begin
                    Test.@test Flows.is_nonvariable(flow) === true
                end

                Test.@testset "has_variable" begin
                    Test.@test Flows.has_variable(flow) === false
                end
            end

            Test.@testset "MinimalFlow without system() throws NotImplemented" begin
                sys = FakeSystem(2)
                flow = MinimalFlow(sys)

                Test.@testset "is_autonomous throws NotImplemented" begin
                    Test.@test_throws Exceptions.NotImplemented Flows.is_autonomous(flow)
                end

                Test.@testset "is_variable throws NotImplemented" begin
                    Test.@test_throws Exceptions.NotImplemented Flows.is_variable(flow)
                end
            end
        end

        # ====================================================================
        # INTEGRATION TESTS - VectorField Flow
        # ====================================================================

        Test.@testset "VectorField Flow Integration Tests" begin
            Test.@testset "Autonomous Fixed Flow" begin
                vf = Systems.VectorField(x -> -x, Common.Autonomous, Common.Fixed)
                sys = Systems.VectorFieldSystem(vf)
                integ = :fake_integ
                flow = FakeFlow(sys, integ)

                Test.@test flow isa FakeFlow{Common.Fixed}
                Test.@test Flows.is_autonomous(flow) === true
                Test.@test Flows.is_nonautonomous(flow) === false
                Test.@test Flows.is_variable(flow) === false
                Test.@test Flows.is_nonvariable(flow) === true
                Test.@test Flows.has_variable(flow) === false
            end

            Test.@testset "NonAutonomous Fixed Flow" begin
                vf = Systems.VectorField((t, x) -> t .* x, Common.NonAutonomous, Common.Fixed)
                sys = Systems.VectorFieldSystem(vf)
                integ = :fake_integ
                flow = FakeFlow(sys, integ)

                Test.@test flow isa FakeFlow{Common.Fixed}
                Test.@test Flows.is_autonomous(flow) === false
                Test.@test Flows.is_nonautonomous(flow) === true
                Test.@test Flows.is_variable(flow) === false
                Test.@test Flows.is_nonvariable(flow) === true
                Test.@test Flows.has_variable(flow) === false
            end

            Test.@testset "Autonomous NonFixed Flow" begin
                vf = Systems.VectorField((x, v) -> x .+ v, Common.Autonomous, Common.NonFixed)
                sys = Systems.VectorFieldSystem(vf)
                integ = :fake_integ
                flow = FakeFlow(sys, integ)

                Test.@test flow isa FakeFlow{Common.NonFixed}
                Test.@test Flows.is_autonomous(flow) === true
                Test.@test Flows.is_nonautonomous(flow) === false
                Test.@test Flows.is_variable(flow) === true
                Test.@test Flows.is_nonvariable(flow) === false
                Test.@test Flows.has_variable(flow) === true
            end
        end
    end
end

end # module

test_abstract_flow() = TestAbstractFlow.test_abstract_flow()
