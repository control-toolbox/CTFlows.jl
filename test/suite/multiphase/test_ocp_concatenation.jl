"""
Integration tests for the concatenation (`*`) of OCP Hamiltonian flows (`DynClosedLoop`
laws): a multi-phase `OptimalControlFlow` must return the SAME type a single-phase OCP flow
returns — a `CTModels.Solution` with a PIECEWISE control reconstructed from the per-phase
laws.

The core property exercised here is *split invariance*: cutting a flow at an interior time
with the SAME law and no jump reproduces the single-phase flow (state, costate, control and
objective all agree). Complementary testsets cover a genuinely piecewise control (two laws),
a costate jump between phases, and the same-OCP requirement.
"""

module TestOCPConcatenation

using Test: Test
import CTBase.Data: Data
import CTBase.Exceptions: Exceptions
import CTModels: CTModels
import CTFlows.Flows: Flows
import CTFlows.Trajectories: Trajectories
import CTFlows.MultiPhase: MultiPhase
using OrdinaryDiffEqTsit5: Tsit5
using ForwardDiff: ForwardDiff  # triggers the DI ForwardDiff extension (AutoForwardDiff)

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

_opts() = (; alg=Tsit5(), reltol=1e-12, abstol=1e-12)

# scalar helper (control may come back as a Number or a 1-vector)
_uval(u, t) = (val=u(t); val isa Number ? val : val[1])

# LQR: ẋ = -x + u, ℓ = 0.5u², :min (1-D). With DynClosedLoop u(x,p) = p the maximized flow
# is p(t) = p0 eᵗ and x(t) = (x0 - p0/2)e⁻ᵗ + (p0/2)eᵗ.
function _build_lqr()
    pre = CTModels.Building.PreModel()
    CTModels.Building.time_dependence!(pre; autonomous=true)
    CTModels.Building.time!(pre; t0=0.0, tf=1.0)
    CTModels.Building.state!(pre, 1)
    CTModels.Building.control!(pre, 1)
    CTModels.Building.dynamics!(pre, (r, t, x, u, v) -> (r[1]=(-x + u); nothing))
    CTModels.Building.objective!(pre, :min; lagrange=(t, x, u, v) -> 0.5 * u^2)
    return CTModels.Building.build(pre)
end

const OCP = _build_lqr()

function test_ocp_concatenation()
    Test.@testset "OCP flow concatenation" verbose=VERBOSE showtiming=SHOWTIMING begin
        x0, p0, t0, tf, ts = 1.0, 0.5, 0.0, 1.0, 0.5

        # ── split invariance: split a flow at ts with the same law ⇒ single flow ──

        for ht in (:total, :partial)
            Test.@testset "split invariance [$ht]" begin
                law = Data.DynClosedLoop((x, p) -> p)
                f = Flows.Flow(OCP, law; hamiltonian_type=ht, _opts()...)
                Test.@test f isa Flows.OptimalControlFlow
                φ = f * (ts, f)   # split at ts, same law, no jump

                # point-eval: the multi-phase result (vector [x; p]) reproduces the single
                # flow (tuple (x, p)), and matches the analytic solution
                xf, pf = f(t0, x0, p0, tf)
                res = φ(t0, x0, p0, tf)
                Test.@test res[1] ≈ xf atol = 1e-8
                Test.@test res[end] ≈ pf atol = 1e-8
                Test.@test pf ≈ p0 * exp(tf) atol = 1e-6
                Test.@test xf ≈ (x0 - p0 / 2) * exp(-tf) + (p0 / 2) * exp(tf) atol = 1e-6

                # trajectory: same type as a single-phase OCP flow, agreeing with it
                sol = φ((t0, tf), x0, p0)
                sol1 = f((t0, tf), x0, p0)
                Test.@test sol isa CTModels.Solutions.Solution
                xs, ps, us = CTModels.state(sol),
                CTModels.costate(sol),
                CTModels.control(sol)
                xs1, ps1, us1 = CTModels.state(sol1),
                CTModels.costate(sol1),
                CTModels.control(sol1)
                # merged trajectory interpolates linearly (SciML merge is `dense=false`)
                for t in (0.2, 0.5, 0.8)
                    Test.@test xs(t) ≈ xs1(t) atol = 1e-3
                    Test.@test ps(t) ≈ ps1(t) atol = 1e-3
                    Test.@test _uval(us, t) ≈ _uval(us1, t) atol = 1e-3
                end
                Test.@test CTModels.objective(sol) ≈ CTModels.objective(sol1) atol = 1e-3
                # objective = ∫₀¹ 0.5 p² dt = 0.25 p0² (e^{2tf} - 1)
                Test.@test CTModels.objective(sol) ≈ 0.25 * p0^2 * (exp(2tf) - 1) atol =
                    1e-3
            end
        end

        # ── genuinely piecewise control: phase 1 law u = p, phase 2 law u = 0 ─────

        Test.@testset "piecewise control (two laws)" begin
            f1 = Flows.Flow(
                OCP, Data.DynClosedLoop((x, p) -> p); hamiltonian_type=:total, _opts()...
            )
            f2 = Flows.Flow(
                OCP, Data.DynClosedLoop((x, p) -> 0.0); hamiltonian_type=:total, _opts()...
            )
            φ = f1 * (ts, f2)
            sol = φ((t0, tf), x0, p0)
            Test.@test sol isa CTModels.Solutions.Solution
            u = CTModels.control(sol)
            Test.@test abs(_uval(u, 0.75)) < 1e-8   # phase 2: u ≡ 0
            Test.@test abs(_uval(u, 0.25)) > 1e-3   # phase 1: u = p ≠ 0
        end

        # ── costate jump between phases (additive on the costate) ────────────────
        # A scalar jump keeps the 1-D scalar convention (state/costate stay scalars through
        # the point path); the trajectory endpoint is exact (not interpolated).

        Test.@testset "costate jump" begin
            law = Data.DynClosedLoop((x, p) -> p)
            f = Flows.Flow(OCP, law; hamiltonian_type=:total, _opts()...)
            Δp = 0.4
            # by-hand reference across the two arcs with the jump on the costate
            p1 = p0 * exp(ts)
            x1 = (x0 - p0 / 2) * exp(-ts) + (p0 / 2) * exp(ts)
            p1p = p1 + Δp
            dt = tf - ts
            p_ref = p1p * exp(dt)
            x_ref = (x1 - p1p / 2) * exp(-dt) + (p1p / 2) * exp(dt)
            φ = f * (ts, Δp, f)
            res = φ(t0, x0, p0, tf)
            Test.@test res[1] ≈ x_ref atol = 1e-6
            Test.@test res[end] ≈ p_ref atol = 1e-6
            sol = φ((t0, tf), x0, p0)
            Test.@test sol isa CTModels.Solutions.Solution
            Test.@test _uval(CTModels.state(sol), tf) ≈ x_ref atol = 1e-6
            Test.@test _uval(CTModels.costate(sol), tf) ≈ p_ref atol = 1e-6
        end

        # ── different OCP objects ⇒ reconstruction rejects ───────────────────────

        Test.@testset "Error: phases from different OCPs" begin
            ocp2 = _build_lqr()   # structurally identical, distinct object
            law = Data.DynClosedLoop((x, p) -> p)
            f1 = Flows.Flow(OCP, law; hamiltonian_type=:total, _opts()...)
            f2 = Flows.Flow(ocp2, law; hamiltonian_type=:total, _opts()...)
            φ = f1 * (ts, f2)
            Test.@test_throws Exceptions.IncorrectArgument φ((t0, tf), x0, p0)
        end
    end
end

end # module

test_ocp_concatenation() = TestOCPConcatenation.test_ocp_concatenation()
