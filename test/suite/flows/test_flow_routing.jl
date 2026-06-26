"""
Unit and integration tests for flow routing via CTBase.Strategies.
"""

module TestFlowRouting

import Test
import CTBase.Exceptions
import CTBase.Strategies
import CTFlows.Flows
import CTBase.Differentiation
import CTFlows.Integrators
import CTBase.Data
import CTFlows.Systems
import CTBase.Traits
import CTFlows.Common
import ADTypes
using OrdinaryDiffEqTsit5

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

# ==============================================================================
# Fake Hamiltonian for Testing (at module top-level)
# ==============================================================================

const _TEST_H = Data.Hamiltonian(
    (t, x, p, v) -> 0.5 * (x[1]^2 + p[1]^2);
    is_autonomous=true, is_variable=false
)

function test_flow_routing()
    Test.@testset "Flow Routing Tests" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ====================================================================
        # UNIT TESTS - Registry and Families
        # ====================================================================

        Test.@testset "Unit: _flow_families" begin
            families = Flows._flow_families()
            Test.@test haskey(families, :backend)
            Test.@test haskey(families, :integrator)
            Test.@test families.backend === Differentiation.AbstractADBackend
            Test.@test families.integrator === Integrators.AbstractIntegrator
        end

        Test.@testset "Unit: _FLOW_DESCRIPTION" begin
            Test.@test Flows._FLOW_DESCRIPTION === (:di, :sciml)
        end

        Test.@testset "Unit: flow_registry" begin
            registry = Flows.flow_registry()
            Test.@test registry isa Strategies.StrategyRegistry
            # Check that strategies are registered
            backend_ids = Strategies.strategy_ids(Differentiation.AbstractADBackend, registry)
            Test.@test :di in backend_ids
            integrator_ids = Strategies.strategy_ids(Integrators.AbstractIntegrator, registry)
            Test.@test :sciml in integrator_ids
        end

        # ====================================================================
        # UNIT TESTS - Option Routing
        # ====================================================================

        Test.@testset "Unit: _route_flow_options — empty kwargs" begin
            routed = Flows._route_flow_options(NamedTuple())
            Test.@test haskey(routed, :strategies)
            Test.@test haskey(routed.strategies, :backend)
            Test.@test haskey(routed.strategies, :integrator)
            Test.@test isempty(routed.strategies.backend)
            Test.@test isempty(routed.strategies.integrator)
        end

        Test.@testset "Unit: _route_flow_options — integrator option" begin
            routed = Flows._route_flow_options((; reltol=1e-10))
            Test.@test haskey(routed.strategies, :integrator)
            Test.@test haskey(routed.strategies.integrator, :reltol)
            Test.@test routed.strategies.integrator.reltol == 1e-10
        end

        Test.@testset "Unit: _route_flow_options — backend alias" begin
            routed = Flows._route_flow_options((; ad_backend=ADTypes.AutoForwardDiff()))
            Test.@test haskey(routed.strategies, :backend)
            Test.@test haskey(routed.strategies.backend, :ad_backend)
            Test.@test routed.strategies.backend.ad_backend === ADTypes.AutoForwardDiff()
        end

        # ====================================================================
        # ERROR TESTS
        # ====================================================================

        Test.@testset "Error: _route_flow_options — unknown option" begin
            Test.@test_throws Exceptions.IncorrectArgument Flows._route_flow_options((; unknown_option=42))
        end

        # ====================================================================
        # UNIT TESTS - Component Building
        # ====================================================================

        Test.@testset "Unit: _build_flow_components — defaults" begin
            routed = Flows._route_flow_options(NamedTuple())
            components = Flows._build_flow_components(routed)
            Test.@test haskey(components, :backend)
            Test.@test haskey(components, :integrator)
            Test.@test components.backend isa Differentiation.DifferentiationInterface
            Test.@test components.integrator isa Integrators.SciML
        end

        # ====================================================================
        # INTEGRATION TESTS
        # ====================================================================

        Test.@testset "Integration: Flow(h) — end-to-end" begin
            flow = Flows.Flow(_TEST_H)
            Test.@test flow isa Flows.HamiltonianFlow
            Test.@test flow isa Flows.AbstractFlow
            Test.@test Flows.system(flow) isa Systems.AbstractHamiltonianSystem
            Test.@test Flows.integrator(flow) isa Integrators.AbstractIntegrator
        end


        Test.@testset "Integration: Flow(h; reltol=1e-9)" begin
            flow = Flows.Flow(_TEST_H; reltol=1e-9)
            Test.@test flow isa Flows.HamiltonianFlow
            Test.@test Flows.integrator(flow) isa Integrators.SciML
        end

        # ====================================================================
        # REGRESSION TESTS
        # ====================================================================

        Test.@testset "Regression: Flow(h) sans kwargs" begin
            flow = Flows.Flow(_TEST_H)
            Test.@test flow isa Flows.HamiltonianFlow
            Test.@test Flows.system(flow) isa Systems.AbstractHamiltonianSystem
        end

    end
end

end # module

# CRITICAL: Redefine in outer scope for TestRunner
test_flow_routing() = TestFlowRouting.test_flow_routing()
