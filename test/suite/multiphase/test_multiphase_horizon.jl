"""
The horizon of a multi-phase flow (issue #547): the calls integrate only the phases met by
`[t0, tf]`, wherever it lies with respect to the switching times, and backward too. A jump is
applied only at a switching time strictly inside the horizon, inverted on a backward one. A
trajectory is returned in increasing time, whatever the direction of integration, and so is
the trajectory of a single flow integrated backward.

Reference problems, with phases that do not commute (so that applying a phase on the wrong
interval shows): `ẋ = 1` on `[0, 1]`, then `ẋ = x` on `[1, 2]`, from `x(0) = 1`:
`x(t) = 1 + t` on `[0, 1]`, `x(t) = 2 e^{t-1}` on `[1, 2]`, so `x(2) = 2e`.
"""
module TestMultiphaseHorizon

using Test: Test
using CTBase: Data
using CTBase: Exceptions
using CTModels: CTModels
using CTFlows: Flows
using CTFlows: MultiPhase
using CTFlows: Trajectories
using OrdinaryDiffEqTsit5: Tsit5
using SciMLBase: ContinuousCallback, terminate!
using ForwardDiff: ForwardDiff  # triggers the DI ForwardDiff extension (AutoForwardDiff)

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

const TOL = 1e-9
const E = exp(1.0)

_o() = (; alg=Tsit5(), reltol=1e-12, abstol=1e-12)

# ── plain state flows ────────────────────────────────────────────────────────
_one(; kw...) = Flows.Flow(Data.VectorField(x -> 1.0); _o()..., kw...)       # ẋ = 1
_lin(; kw...) = Flows.Flow(Data.VectorField(x -> x); _o()..., kw...)         # ẋ = x
_x(t) = t <= 1 ? 1 + t : 2 * exp(t - 1)                                     # from x(0) = 1

# ── Hamiltonian flows: H = p, then H = p x (ẋ = 1, ṗ = 0, then ẋ = x, ṗ = -p) ──
_h1() = Flows.Flow(Data.Hamiltonian((x, p) -> p); _o()...)
_h2() = Flows.Flow(Data.Hamiltonian((x, p) -> p * x); _o()...)

# ── OCP: double integrator, u = ±1, ∫ 1 (minimum time written as Lagrange) ───
function _di()
    pre = CTModels.Building.PreModel()
    CTModels.Building.time_dependence!(pre; autonomous=true)
    CTModels.Building.time!(pre; t0=0.0, tf=2.0)
    CTModels.Building.state!(pre, 2)
    CTModels.Building.control!(pre, 1)
    CTModels.Building.dynamics!(pre, (r, t, x, u, v) -> (r[1]=x[2]; r[2]=u; nothing))
    CTModels.Building.objective!(pre, :min; lagrange=(t, x, u, v) -> 1.0)
    return CTModels.Building.build(pre)
end

# ── OCP with a Mayer term that is not symmetric, to check its order ──────────
function _di_mayer()
    pre = CTModels.Building.PreModel()
    CTModels.Building.time_dependence!(pre; autonomous=true)
    CTModels.Building.time!(pre; t0=0.0, tf=1.0)
    CTModels.Building.state!(pre, 2)
    CTModels.Building.control!(pre, 1)
    CTModels.Building.dynamics!(pre, (r, t, x, u, v) -> (r[1]=x[2]; r[2]=u; nothing))
    CTModels.Building.objective!(
        pre, :min; mayer=(x0, xf, v) -> xf[1] - 2x0[1], lagrange=(t, x, u, v) -> 0.5u^2
    )
    return CTModels.Building.build(pre)
end

const DI = _di()
const DIM = _di_mayer()

_plus(; label="+") = Flows.Flow(DI, (x, p) -> 1.0; label=label, _o()...)
_minus(; label="-") = Flows.Flow(DI, (x, p) -> -1.0; label=label, _o()...)
_xbb(t) = t <= 1 ? [-1 + t^2 / 2, t] : [-0.5 + (t - 1) - (t - 1)^2 / 2, 2 - t]   # bang-bang

_err(f) =
    try
        f()
        nothing
    catch e
        e
    end

function test_multiphase_horizon()
    Test.@testset "Multi-phase horizon" verbose = VERBOSE showtiming = SHOWTIMING begin

        # ====================================================================
        # UNIT TESTS - the phase plan
        # ====================================================================

        Test.@testset "Unit: _phase_plan, forward" begin
            s = [1.0, 2.0]
            Test.@test MultiPhase._phase_plan(s, 0.0, 3.0) ==
                [(1, 0.0, 1.0, 0), (2, 1.0, 2.0, 1), (3, 2.0, 3.0, 2)]
            # starts after the first switching time, ends before the last one
            Test.@test MultiPhase._phase_plan(s, 1.5, 1.8) == [(2, 1.5, 1.8, 0)]
            Test.@test MultiPhase._phase_plan(s, 0.5, 1.5) ==
                [(1, 0.5, 1.0, 0), (2, 1.0, 1.5, 1)]
            # bounds on a switching time: the phases of the side of the horizon, no crossing
            Test.@test MultiPhase._phase_plan(s, 1.0, 2.0) == [(2, 1.0, 2.0, 0)]
            Test.@test MultiPhase._phase_plan(s, 1.0, 3.0) ==
                [(2, 1.0, 2.0, 0), (3, 2.0, 3.0, 2)]
            # before the first switching time, after the last one
            Test.@test MultiPhase._phase_plan(s, -1.0, 0.5) == [(1, -1.0, 0.5, 0)]
            Test.@test MultiPhase._phase_plan(s, 2.5, 4.0) == [(3, 2.5, 4.0, 0)]
            # a single phase: the whole real line
            Test.@test MultiPhase._phase_plan(Float64[], 0.0, 1.0) == [(1, 0.0, 1.0, 0)]
            # a zero-length horizon
            Test.@test MultiPhase._phase_plan(s, 1.5, 1.5) == [(2, 1.5, 1.5, 0)]
        end

        Test.@testset "Unit: _phase_plan, backward" begin
            s = [1.0, 2.0]
            Test.@test MultiPhase._phase_plan(s, 3.0, 0.0) ==
                [(3, 3.0, 2.0, 0), (2, 2.0, 1.0, 2), (1, 1.0, 0.0, 1)]
            Test.@test MultiPhase._phase_plan(s, 1.8, 1.5) == [(2, 1.8, 1.5, 0)]
            Test.@test MultiPhase._phase_plan(s, 1.5, 0.5) ==
                [(2, 1.5, 1.0, 0), (1, 1.0, 0.5, 1)]
            Test.@test MultiPhase._phase_plan(s, 2.0, 1.0) == [(2, 2.0, 1.0, 0)]
            Test.@test MultiPhase._phase_plan(s, 3.0, 1.0) ==
                [(3, 3.0, 2.0, 0), (2, 2.0, 1.0, 2)]
        end

        Test.@testset "Unit: inverse jumps" begin
            Test.@test MultiPhase._inverse_component_jump([3.0, 4.0], [1.0, 1.0], 1) ==
                [2.0, 3.0]
            Test.@test MultiPhase._inverse_component_jump(2.0, nothing, 1) == 2.0
            Test.@test_throws Exceptions.IncorrectArgument MultiPhase._inverse_component_jump(
                2.0, x -> 2x, 1
            )
        end

        # ====================================================================
        # INTEGRATION - point calls of state flows
        # ====================================================================

        Test.@testset "Point call, forward, anywhere in the horizon" begin
            φ = _one() * (1.0, _lin())
            Test.@test φ(0.0, 1.0, 2.0) ≈ 2E atol = TOL
            Test.@test φ(0.0, 1.0, 0.5) ≈ 1.5 atol = TOL                    # before the switch
            Test.@test φ(0.0, 1.0, 1.0) ≈ 2.0 atol = TOL                    # on the switch
            Test.@test φ(1.5, 1.0, 2.0) ≈ exp(0.5) atol = TOL               # after the switch
            Test.@test φ(0.25, 1.25, 1.75) ≈ _x(1.75) atol = TOL            # across it
            Test.@test φ(1.0, 2.0, 2.0) ≈ 2E atol = TOL                     # from the switch
            Test.@test φ(-1.0, 0.0, 0.0) ≈ 1.0 atol = TOL                   # before t₁, first phase
            Test.@test φ(2.0, 2E, 3.0) ≈ 2 * exp(2.0) atol = 1e-8           # after, last phase
        end

        Test.@testset "Point call, backward" begin
            φ = _one() * (1.0, _lin())
            Test.@test φ(2.0, 2E, 0.0) ≈ 1.0 atol = TOL
            Test.@test φ(2.0, 2E, 1.5) ≈ _x(1.5) atol = TOL
            Test.@test φ(2.0, 2E, 1.0) ≈ 2.0 atol = TOL                     # ends on the switch
            Test.@test φ(1.0, 2.0, 0.0) ≈ 1.0 atol = TOL                    # starts on the switch
            Test.@test φ(0.8, _x(0.8), 0.2) ≈ _x(0.2) atol = TOL            # in one phase
            # the round trip gives the initial state back
            for (t0, tf) in ((0.0, 2.0), (0.3, 1.7), (1.0, 2.0), (0.0, 1.0), (1.2, 1.8))
                Test.@test φ(tf, φ(t0, _x(t0), tf), t0) ≈ _x(t0) atol = 1e-8
            end
        end

        Test.@testset "Jumps: only strictly inside the horizon, inverted backward" begin
            φ = _one() * (1.0, 10.0, _lin())       # x ← x + 10 at t = 1
            Test.@test φ(0.0, 1.0, 2.0) ≈ 12E atol = 1e-8
            Test.@test φ(2.0, 12E, 0.0) ≈ 1.0 atol = 1e-8
            # a bound on the switching time: no jump
            Test.@test φ(0.0, 1.0, 1.0) ≈ 2.0 atol = TOL
            Test.@test φ(1.0, 12.0, 2.0) ≈ 12E atol = 1e-8
            Test.@test φ(2.0, 12E, 1.0) ≈ 12.0 atol = 1e-8
            # a jump given as a function crosses forward, not backward
            ψ = _one() * (1.0, x -> 2x, _lin())
            Test.@test ψ(0.0, 1.0, 2.0) ≈ 4E atol = 1e-8
            Test.@test ψ(1.5, 3.0, 2.0) ≈ 3exp(0.5) atol = 1e-8      # not crossed: fine
            err = _err(() -> ψ(2.0, 4E, 0.0))
            Test.@test err isa Exceptions.IncorrectArgument
            Test.@test occursin("cannot be crossed backward", err.msg)
            Test.@test ψ(2.0, 4E, 1.0) ≈ 4.0 atol = 1e-8             # ends on it: not crossed
        end

        # ====================================================================
        # INTEGRATION - trajectory calls of state flows
        # ====================================================================

        Test.@testset "Trajectory: a horizon before or after the switch" begin
            φ = _one() * (1.0, _lin())
            s = φ((0.0, 0.5), 1.0)
            Test.@test Trajectories.state(s)(0.5) ≈ 1.5 atol = TOL
            Test.@test isempty(Trajectories.switching_times(s))
            s = φ((1.5, 2.0), _x(1.5))
            Test.@test Trajectories.state(s)(2.0) ≈ 2E atol = TOL
            Test.@test isempty(Trajectories.switching_times(s))
            s = φ((0.5, 1.5), 1.5)
            Test.@test Trajectories.switching_times(s) == [1.0]
            Test.@test Trajectories.state(s)(1.5) ≈ _x(1.5) atol = TOL
        end

        Test.@testset "Trajectory: backward, in increasing time" begin
            φ = (_one(; label="one") * (1.0, 10.0, _lin(; label="lin")))
            s = φ((2.0, 0.0), 12E)
            ts = Trajectories.time_grid(s)
            Test.@test issorted(ts)
            Test.@test first(ts) == 0.0 && last(ts) == 2.0
            Test.@test Trajectories.switching_times(s) == [1.0]
            Test.@test Trajectories.phase_labels(s) == ["one", "lin"]
            Test.@test Trajectories.state(s)(0.0) ≈ 1.0 atol = 1e-8
            Test.@test Trajectories.state(s)(2.0) ≈ 12E atol = 1e-8
            # left-continuous in increasing time: before the jump, then after
            Test.@test Trajectories.left_limit(s, :state, 1) ≈ 2.0 atol = 1e-8
            Test.@test Trajectories.right_limit(s, :state, 1) ≈ 12.0 atol = 1e-8
            Test.@test Trajectories.state(s)(1.0) ≈ 2.0 atol = 1e-8
            # the same trajectory as the forward call
            sf = φ((0.0, 2.0), 1.0)
            for t in (0.0, 0.3, 1.0, 1.4, 2.0)
                Test.@test Trajectories.state(s)(t) ≈ Trajectories.state(sf)(t) atol = 1e-8
            end
        end

        Test.@testset "Trajectory: a grid of times, backward" begin
            φ = _one() * (1.0, _lin())
            s = φ((2.0, 1.5, 1.0, 0.5, 0.0), 2E)
            Test.@test Trajectories.time_grid(s) == [0.0, 0.5, 1.0, 1.5, 2.0]
            Test.@test Trajectories.state(s)(0.5) ≈ 1.5 atol = 1e-8
        end

        Test.@testset "Trajectory: a generated grid, backward" begin
            φ = _one() * (1.0, _lin())
            s = φ((2.0, 0.0), 2E; grid=21)
            ts = Trajectories.time_grid(s)
            Test.@test issorted(ts) && first(ts) == 0.0 && last(ts) == 2.0
            Test.@test 1.0 in ts
        end

        Test.@testset "Trajectory: a backward early stop" begin
            # ẋ = x backward from x(2) = 2e, stopped at x = 3 (t = 1 + log(1.5)), in phase 2:
            # phase 1 is not integrated
            stop = ContinuousCallback((u, t, int) -> u[1] - 3.0, terminate!)
            φ = _one() * (1.0, Flows.Flow(Data.VectorField(x -> x); callback=stop, _o()...))
            ts_stop = 1 + log(1.5)
            Test.@test φ(2.0, 2E, 0.0) ≈ 3.0 atol = 1e-6
            s = φ((2.0, 0.0), 2E)
            ts = Trajectories.time_grid(s)
            Test.@test issorted(ts)
            Test.@test first(ts) ≈ ts_stop atol = 1e-6
            Test.@test last(ts) == 2.0
            Test.@test isempty(Trajectories.switching_times(s))
        end

        # ====================================================================
        # INTEGRATION - Hamiltonian flows
        # ====================================================================

        Test.@testset "Hamiltonian: point and trajectory, with a costate jump" begin
            # phase 1: x' = 1, p' = 0; phase 2: x' = x, p' = -p; costate jump +1 at t = 1
            φ = _h1() * (1.0, 1.0, _h2())
            x2, p2 = φ(0.0, 1.0, 1.0, 2.0)
            Test.@test x2 ≈ 2E atol = 1e-8
            Test.@test p2 ≈ 2 / E atol = 1e-8
            # backward, the inverse costate jump
            x0, p0 = φ(2.0, x2, p2, 0.0)
            Test.@test x0 ≈ 1.0 atol = 1e-8
            Test.@test p0 ≈ 1.0 atol = 1e-8
            # a per-component jump (state, costate)
            ψ = _h1() * (1.0, (2.0, nothing), _h2())
            xb, pb = ψ(2.0, ψ(0.0, 1.0, 1.0, 2.0)..., 0.0)
            Test.@test xb ≈ 1.0 atol = 1e-8
            Test.@test pb ≈ 1.0 atol = 1e-8
            # in a single phase
            Test.@test φ(1.5, 1.0, 1.0, 2.0)[1] ≈ exp(0.5) atol = 1e-8
            # trajectory, backward, in increasing time
            s = φ((2.0, 0.0), x2, p2)
            Test.@test issorted(Trajectories.time_grid(s))
            Test.@test Trajectories.costate(s)(0.5) ≈ 1.0 atol = 1e-8
            Test.@test Trajectories.right_limit(s, :costate, 1) ≈ 2.0 atol = 1e-8
        end

        Test.@testset "Hamiltonian: variable_costate through the phases" begin
            # H = p² / (2v): ẋ = p / v, ṗ = 0, ṗv = p² / (2v²), the same in both phases
            hv() = Flows.Flow(
                Data.Hamiltonian((x, p, v) -> p^2 / (2v); is_variable=true); _o()...
            )
            φ = hv() * (1.0, hv())
            v, p = 2.0, 3.0
            xf, pf, pvf = φ(0.0, 0.0, p, 2.0; variable=v, variable_costate=true)
            Test.@test xf ≈ 2p / v atol = 1e-8
            Test.@test pvf ≈ 2p^2 / (2v^2) atol = 1e-8
            # a horizon in one phase, and backward
            Test.@test φ(1.2, 0.0, p, 1.8; variable=v, variable_costate=true)[3] ≈
                0.6p^2 / (2v^2) atol = 1e-8
            Test.@test φ(2.0, 0.0, p, 0.0; variable=v, variable_costate=true)[3] ≈
                -2p^2 / (2v^2) atol = 1e-8
            # not on a trajectory call, as for a single flow
            Test.@test_throws Exceptions.PreconditionError φ(
                (0.0, 2.0), 0.0, p; variable=v, variable_costate=true
            )
            # nor without the variable
            Test.@test_throws Exceptions.PreconditionError φ(
                0.0, 0.0, p, 2.0; variable_costate=true
            )
        end

        # ====================================================================
        # INTEGRATION - flows of an OCP: Solution, objective, switching structure
        # ====================================================================

        Test.@testset "OCP: a single flow backward gives the forward Solution" begin
            f = Flows.Flow(DIM, (x, p) -> p[2]; _o()...)
            x0, p0 = [-1.0, 0.0], [12.0, 6.0]
            sf = f((0.0, 1.0), x0, p0)
            xf, pf = f(0.0, x0, p0, 1.0)
            sb = f((1.0, 0.0), xf, pf)
            T = CTModels.time_grid(sb)
            Test.@test issorted(T) && first(T) == 0.0 && last(T) == 1.0
            # the cost of the arc, Mayer term in its order: x(1)₁ - 2 x(0)₁ + ∫ u²/2 = 0 + 2 + 6
            Test.@test CTModels.objective(sf) ≈ 8 atol = 1e-8
            Test.@test CTModels.objective(sb) ≈ 8 atol = 1e-8
            Test.@test CTModels.state(sb)(0.0) ≈ x0 atol = 1e-8
            Test.@test CTModels.control(sb)(0.25) ≈ CTModels.control(sf)(0.25) atol = 1e-8
        end

        Test.@testset "OCP: multi-phase, backward and on a part of the horizon" begin
            φ = _plus() * (1.0, _minus())
            s = φ((2.0, 0.0), [0.0, 0.0], [1.0, -1.0])
            Test.@test issorted(CTModels.time_grid(s))
            Test.@test CTModels.switching_times(s) == [1.0]
            Test.@test CTModels.phase_labels(s) == ["+", "-"]
            Test.@test CTModels.objective(s) ≈ 2 atol = 1e-8
            for t in (0.0, 0.5, 1.0, 1.5, 2.0)
                Test.@test CTModels.state(s)(t) ≈ _xbb(t) atol = 1e-8
            end
            Test.@test CTModels.left_limit(s, :control, 1) ≈ 1
            Test.@test CTModels.right_limit(s, :control, 1) ≈ -1
            # a horizon in the second phase only
            s2 = φ((1.5, 2.0), _xbb(1.5), [1.0, -0.5])
            Test.@test CTModels.phase_labels(s2) == ["-"]
            Test.@test isempty(CTModels.switching_times(s2))
            Test.@test CTModels.state(s2)(2.0) ≈ [0, 0] atol = 1e-8
            Test.@test CTModels.objective(s2) ≈ 0.5 atol = 1e-8
            # a horizon across the switch, starting in the first phase
            s3 = φ((0.5, 1.5), _xbb(0.5), [1.0, 0.5])
            Test.@test CTModels.switching_times(s3) == [1.0]
            Test.@test CTModels.state(s3)(1.5) ≈ _xbb(1.5) atol = 1e-8
        end

        Test.@testset "OCP: controlled flows, backward" begin
            fp = Flows.Flow(DI, Data.OpenLoop(t -> 1.0); label="+", _o()...)
            fm = Flows.Flow(DI, Data.OpenLoop(t -> -1.0); label="-", _o()...)
            φ = fp * (1.0, fm)
            s = φ((2.0, 0.0), [0.0, 0.0])
            T = Trajectories.time_grid(s)
            Test.@test issorted(T)
            Test.@test Trajectories.state(s)(0.0) ≈ [-1, 0] atol = 1e-8
            Test.@test Trajectories.control(s)(0.5) ≈ 1
            Test.@test Trajectories.control(s)(1.5) ≈ -1
            Test.@test Trajectories.objective(s) ≈ 2 atol = 1e-8
        end

        # ====================================================================
        # INTEGRATION - automatic differentiation through a switching time
        # ====================================================================

        Test.@testset "Unit: _reached_end with a differentiated end time" begin
            # 0.8 >= Dual(0.8, 1.0) is false in ForwardDiff: compared on primal values
            D = ForwardDiff.Dual{:t}(0.8, 1.0)
            Test.@test MultiPhase._reached_end(0.8, 0.0, D)
            Test.@test MultiPhase._reached_end(D, 0.0, 0.8)
            Test.@test !MultiPhase._reached_end(0.5, 0.0, D)
            Test.@test MultiPhase._reached_end(0.8, 2.0, D)
        end

        Test.@testset "ForwardDiff through the switching time, any horizon" begin
            # x(2) = (1 + t₁) e^{2 - t₁} for ẋ = 1 then ẋ = x, from x(0) = 1: d/dt₁ = -t₁ e^{2-t₁}
            g(t1) = (_one() * (t1, _lin()))(0.0, 1.0, 2.0)
            t1 = 0.8
            Test.@test ForwardDiff.derivative(g, t1) ≈ -t1 * exp(2 - t1) atol = 1e-6
            # backward: x(0) from x(2) = 2e
            h(t1) = (_one() * (t1, _lin()))(2.0, 2E, 0.0)
            # x(t₁) = 2e e^{t₁-2}, x(0) = x(t₁) - t₁: d/dt₁ = 2e e^{t₁-2} - 1
            Test.@test ForwardDiff.derivative(h, t1) ≈ 2E * exp(t1 - 2) - 1 atol = 1e-6
            # the trajectory call too: the final state of the solution
            k(t1) = Trajectories.state((_one() * (t1, _lin()))((0.0, 2.0), 1.0))(2.0)
            Test.@test ForwardDiff.derivative(k, t1) ≈ -t1 * exp(2 - t1) atol = 1e-6
            # and the Hamiltonian point call, as in a shooting function
            s(t1) = (_h1() * (t1, _h2()))(0.0, 1.0, 1.0, 2.0)[1]
            Test.@test ForwardDiff.derivative(s, t1) ≈ -t1 * exp(2 - t1) atol = 1e-6
        end
    end
end

end # module

test_multiphase_horizon() = TestMultiphaseHorizon.test_multiphase_horizon()
