"""
Integration tests for on_update callback during flow integration.
Tests that the callback is invoked when cache type mismatches occur during ODE integration.
"""

module TestUpdateCallback

import Test
import CTFlows: CTFlows
import CTFlows.Data: Data
import CTFlows.Differentiation: Differentiation
import CTFlows.Flows: Flows
import ADTypes

using SciMLBase: SciMLBase
using OrdinaryDiffEqTsit5: OrdinaryDiffEqTsit5, Tsit5

const VERBOSE = isdefined(Main, :TestOptions) ? Main.TestOptions.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestOptions) ? Main.TestOptions.SHOWTIMING : true

# ==============================================================================
# Fake Hamiltonian for testing (module top-level, not inside test functions)
# ==============================================================================

# Autonomous Fixed Hamiltonian: H(x,p) = 0.5*(x² + p²)
const FAKE_HAMILTONIAN_AUTO_FIXED = Data.Hamiltonian(
    (x, p) -> 0.5 * (sum(abs2, x) + sum(abs2, p));
    is_autonomous=true, is_variable=false)

# ==============================================================================
# Test function
# ==============================================================================

function test_update_callback()
    Test.@testset "Update Callback Tests" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ====================================================================
        # INTEGRATION TESTS - Flow integration with on_update callback
        # ====================================================================

        Test.@testset "Integration: flow with Float x0 does not trigger on_update" begin
            # Test that on_update is NOT called when types match
            count = Ref(0)
            flow = Flows.Flow(FAKE_HAMILTONIAN_AUTO_FIXED;
                ad_backend=ADTypes.AutoForwardDiff(),
                prepare_cache=true,
                on_update=(c, t, x, p, v) -> (count[] += 1)
            )

            # Integrate with Float initial condition (types match)
            flow(0.0, 1.0, 1.0, 1.0)
            Test.@test count[] == 0  # on_update should NOT be called
        end
    end
end

end # module

# CRITICAL: Redefine in outer scope for TestRunner
test_update_callback() = TestUpdateCallback.test_update_callback()
