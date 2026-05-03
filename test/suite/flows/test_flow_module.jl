"""
# ============================================================================
# Flows Module Exports Tests
# ============================================================================
# This file tests the exports from the `Flows` module. It verifies that
# the expected types, functions, and constructors are properly exported by
# `CTFlows.Flows` and readily accessible to the end user.
"""

module TestFlowModule

import Test
import CTFlows.Flows
import CTFlows.Systems
import CTFlows.Integrators
import CTFlows.Data
import CTFlows.Common
import CTSolvers: CTSolvers

const VERBOSE = isdefined(Main, :TestOptions) ? Main.TestOptions.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestOptions) ? Main.TestOptions.SHOWTIMING : true

const CurrentModule = TestFlowModule

# ==============================================================================
# Fake types for contract testing
# ==============================================================================

"""
Fake system for testing the Flow contract.

This minimal implementation provides the required contract methods to test
routing and default behavior without full system complexity.
"""
struct FakeSystem <: Systems.AbstractSystem{Common.Autonomous, Common.Fixed}
    state_dim::Int
    param_dim::Int
end

# Implement contract: rhs
function Systems.rhs(sys::FakeSystem)
    return (du, u, p, t) -> du .= -u
end

# Implement contract: time_dependence
function Common.time_dependence(sys::FakeSystem)
    return Common.Autonomous
end

# Implement contract: variable_dependence
function Common.variable_dependence(sys::FakeSystem)
    return Common.Fixed
end

"""
Fake integrator for testing the Flow contract.
"""
struct FakeIntegrator <: Integrators.AbstractIntegrator
    options::CTSolvers.Strategies.StrategyOptions
end

function FakeIntegrator()
    return FakeIntegrator(CTSolvers.Strategies.StrategyOptions())
end

# Implement CTSolvers strategy contract
function CTSolvers.Strategies.id(::Type{FakeIntegrator})
    return :fake_integrator
end

function CTSolvers.Strategies.metadata(::Type{FakeIntegrator})
    return CTSolvers.Strategies.StrategyMetadata()
end

function CTSolvers.Strategies.options(integ::FakeIntegrator)
    return integ.options
end

function CTSolvers.Strategies.describe(::Type{FakeIntegrator})
    return "Fake integrator for testing"
end

function (integ::FakeIntegrator)(ode_problem)
    return :fake_solution
end

# ==============================================================================
# Test function
# ==============================================================================

function test_flow_module()
    Test.@testset "Flows Module Exports" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ====================================================================
        # Abstract Types
        # ====================================================================

        Test.@testset "Abstract Types" begin
            Test.@testset "AbstractFlow is exported" begin
                Test.@test isdefined(Flows, :AbstractFlow)
                Test.@test isabstracttype(Flows.AbstractFlow)
            end
        end

        # ====================================================================
        # Concrete Types
        # ====================================================================

        Test.@testset "Concrete Types" begin
            Test.@testset "Flow is exported" begin
                Test.@test isdefined(Flows, :Flow)
                Test.@test Flows.Flow <: Flows.AbstractFlow
            end

            Test.@testset "Flow constructor is exported" begin
                Test.@test isdefined(Flows, :Flow)
                sys = FakeSystem(2, 2)
                integ = FakeIntegrator()
                flow = Flows.Flow(sys, integ)
                Test.@test flow isa Flows.Flow
                Test.@test flow isa Flows.AbstractFlow
            end
        end

        # ====================================================================
        # Accessor Functions
        # ====================================================================

        Test.@testset "Accessor Functions" begin
            Test.@testset "system is exported" begin
                Test.@test isdefined(Flows, :system)
            end

            Test.@testset "system returns the associated system" begin
                sys = FakeSystem(2, 2)
                integ = FakeIntegrator()
                flow = Flows.Flow(sys, integ)
                retrieved_sys = Flows.system(flow)
                Test.@test retrieved_sys === sys
            end

            Test.@testset "integrator is exported" begin
                Test.@test isdefined(Flows, :integrator)
            end

            Test.@testset "integrator returns the associated integrator" begin
                sys = FakeSystem(2, 2)
                integ = FakeIntegrator()
                flow = Flows.Flow(sys, integ)
                retrieved_integ = Flows.integrator(flow)
                Test.@test retrieved_integ === integ
            end
        end

        # ====================================================================
        # Trait Support
        # ====================================================================

        Test.@testset "Trait Support" begin
            Test.@testset "Flow has time dependence trait" begin
                sys = FakeSystem(2, 2)
                integ = FakeIntegrator()
                flow = Flows.Flow(sys, integ)
                Test.@test Common.has_time_dependence_trait(flow)
            end

            Test.@testset "Flow has variable dependence trait" begin
                sys = FakeSystem(2, 2)
                integ = FakeIntegrator()
                flow = Flows.Flow(sys, integ)
                Test.@test Common.has_variable_dependence_trait(flow)
            end

            Test.@testset "time_dependence delegates to system" begin
                sys = FakeSystem(2, 2)
                integ = FakeIntegrator()
                flow = Flows.Flow(sys, integ)
                Test.@test Common.time_dependence(flow) === Common.Autonomous
            end

            Test.@testset "variable_dependence delegates to system" begin
                sys = FakeSystem(2, 2)
                integ = FakeIntegrator()
                flow = Flows.Flow(sys, integ)
                Test.@test Common.variable_dependence(flow) === Common.Fixed
            end
        end

        # ====================================================================
        # Type Hierarchy Verification
        # ====================================================================

        Test.@testset "Type Hierarchy" begin
            Test.@testset "Flow is a subtype of AbstractFlow" begin
                Test.@test Flows.Flow <: Flows.AbstractFlow
            end

            Test.@testset "Concrete Flow instances are AbstractFlow" begin
                sys = FakeSystem(2, 2)
                integ = FakeIntegrator()
                flow = Flows.Flow(sys, integ)
                Test.@test flow isa Flows.AbstractFlow
                Test.@test flow isa Flows.Flow
            end
        end

        # ====================================================================
        # Display Methods
        # ====================================================================

        Test.@testset "Display Methods" begin
            Test.@testset "tree-style display works" begin
                sys = FakeSystem(2, 2)
                integ = FakeIntegrator()
                flow = Flows.Flow(sys, integ)
                # Just verify it doesn't throw
                io = IOBuffer()
                show(io, MIME("text/plain"), flow)
                output = String(take!(io))
                Test.@test !isempty(output)
            end

            Test.@testset "compact display works" begin
                sys = FakeSystem(2, 2)
                integ = FakeIntegrator()
                flow = Flows.Flow(sys, integ)
                # Just verify it doesn't throw
                io = IOBuffer()
                show(io, flow)
                output = String(take!(io))
                Test.@test !isempty(output)
            end
        end
    end
end

end # module TestFlowModule

# CRITICAL: Redefine in outer scope for TestRunner
test_flow_module() = TestFlowModule.test_flow_module()