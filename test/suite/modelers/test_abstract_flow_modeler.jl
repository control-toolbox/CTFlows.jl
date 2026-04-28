module TestAbstractFlowModeler

import Test
import CTBase.Exceptions
import CTFlows.Systems
import CTFlows.Modelers
import CTFlows.ADBackends
import CTSolvers: CTSolvers

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

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

function Systems.dimensions(sys::FakeSystem)
    return (n_x=sys.state_dim, n_p=sys.state_dim, n_u=0, n_v=0)
end

function Systems.build_solution(sys::FakeSystem, ode_sol)
    return ode_sol
end

"""
Fake modeler for testing the AbstractFlowModeler contract.
"""
struct FakeModeler <: Modelers.AbstractFlowModeler
    options::CTSolvers.Strategies.StrategyOptions
end

function FakeModeler()
    return FakeModeler(CTSolvers.Strategies.StrategyOptions())
end

function (modeler::FakeModeler)(input, ad_backend)
    return FakeSystem(2)
end

"""
Minimal modeler that does not implement the contract (for error testing).
"""
struct MinimalModeler <: Modelers.AbstractFlowModeler
    options::CTSolvers.Strategies.StrategyOptions
end

function MinimalModeler()
    return MinimalModeler(CTSolvers.Strategies.StrategyOptions())
end

"""
Fake AD backend for testing.
"""
struct FakeADBackend <: ADBackends.AbstractADBackend
    options::CTSolvers.Strategies.StrategyOptions
end

function FakeADBackend()
    return FakeADBackend(CTSolvers.Strategies.StrategyOptions())
end

# ==============================================================================
# Test function
# ==============================================================================

function test_abstract_flow_modeler()
    Test.@testset "Abstract Flow Modeler Tests" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ====================================================================
        # UNIT TESTS - Abstract Types
        # ====================================================================

        Test.@testset "Abstract Types" begin
            modeler = FakeModeler()
            Test.@test modeler isa Modelers.AbstractFlowModeler
            Test.@test modeler isa CTSolvers.Strategies.AbstractStrategy

            minimal = MinimalModeler()
            Test.@test minimal isa Modelers.AbstractFlowModeler
        end

        # ====================================================================
        # UNIT TESTS - Contract Implementation
        # ====================================================================

        Test.@testset "Contract Implementation" begin
            modeler = FakeModeler()
            ad_backend = FakeADBackend()

            Test.@testset "callable returns AbstractSystem" begin
                result = modeler(:fake_input, ad_backend)
                Test.@test result isa Systems.AbstractSystem
                Test.@test result isa FakeSystem
            end
        end

        # ====================================================================
        # UNIT TESTS - NotImplemented Errors
        # ====================================================================

        Test.@testset "NotImplemented Errors" begin
            modeler = MinimalModeler()
            ad_backend = FakeADBackend()

            Test.@testset "callable throws NotImplemented" begin
                Test.@test_throws Exceptions.NotImplemented modeler(:fake_input, ad_backend)
            end
        end
    end
end

end # module

test_abstract_flow_modeler() = TestAbstractFlowModeler.test_abstract_flow_modeler()
