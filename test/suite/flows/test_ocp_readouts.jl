"""
Unit tests for the shared OCP readout helper `CTFlows.Flows._control_of`: the
feedback-dispatched control reconstruction shared by the Hamiltonian (`OptimalControlFlow`)
and state (`ControlledFlow`) objective paths. The objective core
`CTFlows.Flows._flow_objective` is covered indirectly by the OCP-flow objective
integration tests (`test_ocp_control`, `test_optimal_control_flow`, `test_ocp_concatenation`).
"""

module TestOCPReadouts

using Test: Test
import CTBase.Data: Data
import CTFlows.Flows: Flows

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

function test_ocp_readouts()
    Test.@testset "OCP readouts — _control_of" verbose=VERBOSE showtiming=SHOWTIMING begin
        x = _ -> 2.0    # constant state callable  x(t) = 2
        p = _ -> 3.0    # constant costate callable p(t) = 3
        v = nothing

        # no law → empty control, for both the state (x,v) and Hamiltonian (x,p,v) shapes
        Test.@testset "no law → empty control" begin
            Test.@test Flows._control_of(nothing, x, v)(0.0) == Float64[]
            Test.@test Flows._control_of(nothing, x, p, v)(0.0) == Float64[]
        end

        # DynClosedLoop (Hamiltonian path): u(t, x, p, v) — uses the costate
        Test.@testset "DynClosedLoop uses the costate" begin
            law = Data.DynClosedLoop((x, p) -> -p)
            u = Flows._control_of(law, x, p, v)
            Test.@test u(0.0) ≈ -3.0            # -p(0)
        end

        # ClosedLoop (state path): u(t, x, v) — uses the state, no costate
        Test.@testset "ClosedLoop uses the state" begin
            law = Data.ClosedLoop(x -> -x)
            u = Flows._control_of(law, x, v)
            Test.@test u(0.0) ≈ -2.0            # -x(0)
        end

        # OpenLoop (state path): u(t, v) — ignores the state
        Test.@testset "OpenLoop ignores the state" begin
            law = Data.OpenLoop(() -> 1.0)
            u = Flows._control_of(law, x, v)
            Test.@test u(0.0) ≈ 1.0
        end
    end
end

end # module TestOCPReadouts

# Redefine in the outer scope so the runner can call it
test_ocp_readouts() = TestOCPReadouts.test_ocp_readouts()
