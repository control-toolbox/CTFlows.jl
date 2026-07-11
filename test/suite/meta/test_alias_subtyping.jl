"""
Regression guard for the parametric-alias bound-dropping pitfall (see
`.reports/2026-07-11_alias-where-bounds-audit.md` and the Handbook rule in
`philosophy/types-traits-interfaces.md#aliases-and-where`).

A `const Alias{...} = Parent{...}` that names a free type parameter without
repeating its original bound silently widens it to `<:Any`. This breaks
`Alias <: Parent` — invisible via `isa` on concrete instances, but it breaks
Julia's method-specificity ranking the moment a competing method exists,
either mis-dispatching silently or throwing `MethodError: ... is ambiguous`.

This test asserts the subtype relation directly for every parametric alias in
the package, so a future edit that drops a bound again fails loudly here
instead of surfacing as a mysterious dispatch bug elsewhere.
"""

module TestAliasSubtyping

using Test: Test
import CTFlows.Configs
import CTFlows.Flows
import CTFlows.Systems
import CTFlows.MultiPhase

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

function test_alias_subtyping()
    Test.@testset "Alias <: Parent (bound-dropping regression guard)" verbose = VERBOSE showtiming =
        SHOWTIMING begin
        Test.@testset "Configs" begin
            Test.@test Configs.AbstractEndPointConfig <: Configs.AbstractConfigWithMaC
            Test.@test Configs.AbstractTrajectoryConfig <: Configs.AbstractConfigWithMaC
            Test.@test Configs.AbstractStateConfig <: Configs.AbstractConfigWithMaC
            Test.@test Configs.AbstractHamiltonianConfig <: Configs.AbstractConfigWithMaC
            Test.@test Configs.AbstractAugmentedHamiltonianConfig <:
                Configs.AbstractConfigWithMaC
        end

        Test.@testset "Flows" begin
            Test.@test Flows.AbstractStateFlow <: Flows.AbstractFlow
            Test.@test Flows.AbstractHamiltonianFlow <: Flows.AbstractFlow
            Test.@test Flows.StateFlow <: Flows.Flow
            Test.@test Flows.HamiltonianFlow <: Flows.Flow
            Test.@test Flows.StateFlow <: Flows.AbstractFlow
            Test.@test Flows.HamiltonianFlow <: Flows.AbstractFlow
        end

        Test.@testset "Systems" begin
            Test.@test Systems.AbstractStateSystem <: Systems.AbstractSystem
            Test.@test Systems.AbstractHamiltonianSystem <: Systems.AbstractSystem
        end

        Test.@testset "MultiPhase" begin
            Test.@test MultiPhase.MultiPhaseStateFlow <: MultiPhase.MultiPhaseFlow
            Test.@test MultiPhase.MultiPhaseHamiltonianFlow <: MultiPhase.MultiPhaseFlow
            Test.@test MultiPhase.MultiPhaseStateFlow <: Flows.AbstractFlow
            Test.@test MultiPhase.MultiPhaseHamiltonianFlow <: Flows.AbstractFlow
        end
    end
end

end # module

test_alias_subtyping() = TestAliasSubtyping.test_alias_subtyping()
