module TestConcatenationHeterogeneous

import Test
import CTBase.Exceptions
import CTFlows.MultiPhase
import CTFlows.Systems
import CTFlows.Integrators
import CTFlows.Flows
import CTFlows.Traits
import CTBase.Strategies
import CTBase.Options

const VERBOSE    = isdefined(Main, :TestOptions) ? Main.TestOptions.VERBOSE    : true
const SHOWTIMING = isdefined(Main, :TestOptions) ? Main.TestOptions.SHOWTIMING : true

# ==============================================================================
# Fake types — two DISTINCT system types with the same TD/VD but different F
# (this is the heterogeneous case that was impossible before Phase F)
# ==============================================================================

struct HeteroSysA <: Systems.AbstractStateSystem{Traits.Autonomous, Traits.Fixed}
    state_dim::Int
end
Systems.get_ip_rhs(::HeteroSysA, _) = (du, u, _, _) -> (du .= -u)

struct HeteroSysB <: Systems.AbstractStateSystem{Traits.Autonomous, Traits.Fixed}
    state_dim::Int
end
Systems.get_ip_rhs(::HeteroSysB, _) = (du, u, _, _) -> (du .= 2 .* u)

struct HeteroHamSysA <: Systems.AbstractHamiltonianSystem{Traits.Autonomous, Traits.Fixed}
    state_dim::Int
end

struct HeteroHamSysB <: Systems.AbstractHamiltonianSystem{Traits.Autonomous, Traits.Fixed}
    state_dim::Int
end

struct HeteroIntegA <: Integrators.AbstractIntegrator end
struct HeteroIntegB <: Integrators.AbstractIntegrator end

Strategies.id(::Type{HeteroIntegA}) = :hetero_integ_a
Strategies.id(::Type{HeteroIntegB}) = :hetero_integ_b
Strategies.metadata(::Type{HeteroIntegA}) = Strategies.StrategyMetadata()
Strategies.metadata(::Type{HeteroIntegB}) = Strategies.StrategyMetadata()
Strategies.options(::HeteroIntegA) = Strategies.StrategyOptions()
Strategies.options(::HeteroIntegB) = Strategies.StrategyOptions()

function test_concatenation_heterogeneous()
    Test.@testset "Heterogeneous Flow Concatenation" verbose=VERBOSE showtiming=SHOWTIMING begin

        sysA = HeteroSysA(2)
        sysB = HeteroSysB(2)
        hamA = HeteroHamSysA(2)
        hamB = HeteroHamSysB(2)
        integA = HeteroIntegA()
        integB = HeteroIntegB()

        flowA = Flows.StateFlow(sysA, integA)  # Flow{Autonomous,Fixed,StateDynamics,HeteroSysA,HeteroIntegA}
        flowB = Flows.StateFlow(sysB, integB)  # Flow{Autonomous,Fixed,StateDynamics,HeteroSysB,HeteroIntegB}
        hamFlowA = Flows.HamiltonianFlow(hamA, integA)
        hamFlowB = Flows.HamiltonianFlow(hamB, integB)

        # ====================================================================
        # UNIT TESTS — Tuple structure
        # ====================================================================

        Test.@testset "get_flows returns 1-tuple for single-phase" begin
            result = MultiPhase.get_flows(flowA)
            Test.@test result isa Tuple
            Test.@test length(result) == 1
            Test.@test result[1] === flowA
        end

        Test.@testset "Heterogeneous StateFlow: direct construction via tuple" begin
            mpf = MultiPhase.MultiPhaseStateFlow((flowA, flowB), [1.0], [nothing])
            Test.@test mpf isa MultiPhase.MultiPhaseStateFlow
            Test.@test mpf.flows isa Tuple
            Test.@test length(mpf.flows) == 2
            Test.@test mpf.flows[1] === flowA
            Test.@test mpf.flows[2] === flowB
        end

        Test.@testset "Heterogeneous StateFlow: different system types S1 ≠ S2" begin
            mpf = flowA * (1.0, flowB)
            Test.@test mpf isa MultiPhase.MultiPhaseStateFlow
            Test.@test mpf.flows isa Tuple
            Test.@test length(mpf.flows) == 2
            # Verify both system types are preserved (the key test of Phase F)
            Test.@test Flows.system(mpf.flows[1]) isa HeteroSysA
            Test.@test Flows.system(mpf.flows[2]) isa HeteroSysB
        end

        Test.@testset "Heterogeneous StateFlow: different integrator types I1 ≠ I2" begin
            mpf = flowA * (1.0, flowB)
            Test.@test Flows.integrator(mpf.flows[1]) isa HeteroIntegA
            Test.@test Flows.integrator(mpf.flows[2]) isa HeteroIntegB
        end

        Test.@testset "Heterogeneous StateFlow: three phases S1, S2, S1" begin
            mpf = flowA * (1.0, flowB) * (2.0, flowA)
            Test.@test length(mpf.flows) == 3
            Test.@test Flows.system(mpf.flows[1]) isa HeteroSysA
            Test.@test Flows.system(mpf.flows[2]) isa HeteroSysB
            Test.@test Flows.system(mpf.flows[3]) isa HeteroSysA
            Test.@test mpf.switching_times == [1.0, 2.0]
        end

        Test.@testset "Heterogeneous StateFlow: with jump at switch" begin
            jump = x -> 2 .* x
            mpf = flowA * (1.0, jump, flowB)
            Test.@test mpf isa MultiPhase.MultiPhaseStateFlow
            Test.@test mpf.flows isa Tuple
            Test.@test length(mpf.flows) == 2
            Test.@test mpf.jumps[1] === jump
        end

        Test.@testset "Heterogeneous HamiltonianFlow: different system types" begin
            mpf = hamFlowA * (1.0, hamFlowB)
            Test.@test mpf isa MultiPhase.MultiPhaseHamiltonianFlow
            Test.@test mpf.flows isa Tuple
            Test.@test length(mpf.flows) == 2
            Test.@test Flows.system(mpf.flows[1]) isa HeteroHamSysA
            Test.@test Flows.system(mpf.flows[2]) isa HeteroHamSysB
        end

        Test.@testset "Heterogeneous: dynamics_trait preserved" begin
            mpf_state = flowA * (1.0, flowB)
            Test.@test mpf_state isa Flows.AbstractStateFlow
            mpf_ham = hamFlowA * (1.0, hamFlowB)
            Test.@test mpf_ham isa Flows.AbstractHamiltonianFlow
        end

        # ====================================================================
        # Error cases
        # ====================================================================

        Test.@testset "Error: StateFlow * HamiltonianFlow → PreconditionError" begin
            Test.@test_throws Exceptions.PreconditionError flowA * (1.0, hamFlowA)
        end

        Test.@testset "Error: HamiltonianFlow * StateFlow → PreconditionError" begin
            Test.@test_throws Exceptions.PreconditionError hamFlowA * (1.0, flowA)
        end

        Test.@testset "Error: StateFlow * (t, jump, HamiltonianFlow) → PreconditionError" begin
            Test.@test_throws Exceptions.PreconditionError flowA * (1.0, identity, hamFlowA)
        end

        Test.@testset "Error: non-increasing switching times → PreconditionError" begin
            # Three-phase with bad switching times
            Test.@test_throws Exceptions.PreconditionError begin
                flowA * (2.0, flowB) * (1.0, flowA)  # 1.0 < 2.0 → invalid
            end
        end
    end
end

end # module

test_concatenation_heterogeneous() = TestConcatenationHeterogeneous.test_concatenation_heterogeneous()
