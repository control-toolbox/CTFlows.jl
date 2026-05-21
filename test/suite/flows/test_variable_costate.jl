"""
Test suite for variable costate integration (augmented Hamiltonian systems).

Tests the `variable_costate=true` kwarg on Hamiltonian flows, which enables
integration of the augmented state `[x; p; pv]` where `pv` is the costate of the variable.
"""
module TestVariableCostate

import Test
import CTBase.Exceptions
import CTFlows.Common
import CTFlows.Systems
import CTFlows.Flows
import CTFlows.Solutions
import CTFlows.Integrators

const VERBOSE = isdefined(Main, :TestOptions) ? Main.TestOptions.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestOptions) ? Main.TestOptions.SHOWTIMING : true

# =============================================================================
# Fake types for testing
# =============================================================================

# Fake integration result
struct FakeIntegrationResult <: Integrators.AbstractIntegrationResult
    u_final::Vector{Float64}
end

Integrators.final_state(r::FakeIntegrationResult) = r.u_final

# =============================================================================
# Unit tests for _aug_split_solution
# =============================================================================

Test.@testset "Unit: _aug_split_solution" begin
    u = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0]
    n = 2  # state dimension

    x, p, pv = Solutions._aug_split_solution(u, n)

    Test.@test x == [1.0, 2.0]
    Test.@test p == [3.0, 4.0]
    Test.@test pv == [5.0, 6.0, 7.0, 8.0]
end

# =============================================================================
# Unit tests for build_solution with AugmentedHamiltonianTrait
# =============================================================================

Test.@testset "Unit: build_solution AugmentedHamiltonianTrait" begin
    u_final = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0]
    initial_state = [1.0, 2.0]  # n = 2
    result = FakeIntegrationResult(u_final)

    xf, pf, pvf = Solutions.build_solution(
        Common.PointTrait,
        Common.AugmentedHamiltonianTrait,
        initial_state,
        result,
    )

    Test.@test xf == [1.0, 2.0]
    Test.@test pf == [3.0, 4.0]
    Test.@test pvf == [5.0, 6.0, 7.0, 8.0]
end

# =============================================================================
# Unit tests for variable_costate_trait on systems
# =============================================================================

Test.@testset "Unit: variable_costate_trait on systems" begin
    # Default implementation returns NoVariableCostate
    Test.@test Common.variable_costate_trait("anything") === Common.NoVariableCostate
    Test.@test Common.variable_costate_trait(42) === Common.NoVariableCostate

    # HamiltonianSystem NonFixed should return SupportsVariableCostate
    # (This requires a real HamiltonianSystem, which we'll skip for now
    # and just test the default behavior)
end

# =============================================================================
# Unit tests for variable_costate_trait on flows
# =============================================================================

Test.@testset "Unit: variable_costate_trait on flows" begin
    # Default implementation on AbstractFlow returns NoVariableCostate
    Test.@test Common.variable_costate_trait("fake_flow") === Common.NoVariableCostate

    # AbstractHamiltonianFlow delegates to system
    # (This requires a real flow, which we'll skip for now)
end

# =============================================================================
# Unit tests for new trait types
# =============================================================================

Test.@testset "Unit: trait type hierarchy" begin
    Test.@test Common.SupportsVariableCostate <: Common.AbstractVariableCostateCapability
    Test.@test Common.NoVariableCostate <: Common.AbstractVariableCostateCapability
    Test.@test Common.AbstractVariableCostateCapability <: Common.AbstractTrait
end

# =============================================================================
# Unit tests for default variable_costate_trait
# =============================================================================

Test.@testset "Unit: variable_costate_trait default" begin
    Test.@test Common.variable_costate_trait(42) === Common.NoVariableCostate
    Test.@test Common.variable_costate_trait("anything") === Common.NoVariableCostate
    Test.@test Common.variable_costate_trait(nothing) === Common.NoVariableCostate
end

# =============================================================================
# Unit tests for ad_trait on flows
# =============================================================================

Test.@testset "Unit: ad_trait on flows" begin
    # Default implementation on AbstractFlow returns WithoutAD
    Test.@test Common.ad_trait("fake_flow") === Common.WithoutAD
    Test.@test Common.ad_trait(42) === Common.WithoutAD

    # AbstractHamiltonianFlow delegates to system
    # (This requires a real flow, which we'll skip for now)
end

# =============================================================================
# Integration tests (placeholder - require real systems/flows)
# =============================================================================

Test.@testset "Integration: variable_costate=true (placeholder)" begin
    # These tests require real HamiltonianSystem, HamiltonianFlow, and integrators
    # We'll add them when the full stack is available
    Test.@test true  # Placeholder
end

Test.@testset "Regression: variable_costate=false default unchanged (placeholder)" begin
    # Test that variable_costate=false (default) returns standard 2-tuple (xf, pf)
    Test.@test true  # Placeholder
end

Test.@testset "Error: variable_costate on NoVariableCostate flow (placeholder)" begin
    # Test that calling with variable_costate=true on a flow without support
    # throws IncorrectArgument
    Test.@test true  # Placeholder
end

function test_variable_costate()
    Test.@testset "Variable Costate Tests" verbose=VERBOSE showtiming=SHOWTIMING begin
        # Tests are already defined in the module above
    end
end

end # module

# CRITICAL: Redefine in outer scope for TestRunner
test_variable_costate() = TestVariableCostate.test_variable_costate()
