"""
Integration tests for control flows: Flow(ocp, law) and Flow(h̃, law), with the
`:total` / `:partial` Hamiltonian modes, on OCPs with a control law.
"""

module TestOCPControl

using Test: Test
import CTBase.Data: Data
import CTBase.Traits: Traits
import CTBase.Exceptions: Exceptions
import CTModels: CTModels
import CTFlows.Flows: Flows
import CTFlows.Systems: Systems
using OrdinaryDiffEqTsit5: Tsit5
using ForwardDiff: ForwardDiff  # triggers the DI ForwardDiff extension (AutoForwardDiff)

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

const ATOL = 1e-8
_opts() = (; alg=Tsit5(), reltol=1e-12, abstol=1e-12)

# Trapezoidal quadrature over a uniform grid — used to cross-check the augmented
# variable costate `pvf = -∫ ∂H/∂v dt` against the flow's own (x,p) trajectory,
# independently of any hand-derived closed form.
function _trapz(ts, ys)
    s = zero(eltype(ys))
    for i in 1:(length(ts) - 1)
        s += 0.5 * (ys[i] + ys[i + 1]) * (ts[i + 1] - ts[i])
    end
    return s
end

# =============================================================================
# OCP fixtures at module top-level
# =============================================================================

# scalar LQR: ẋ = -x + u, ℓ = 0.5u², :min  (autonomous, fixed)
# 1-D quantities are scalars (no [1] indexing): exercises the "1-D = scalar" convention.
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

# double integrator energy: ẋ = [x₂, u], ℓ = 0.5u², :min  (autonomous, fixed)
function _build_double_integrator()
    pre = CTModels.Building.PreModel()
    CTModels.Building.time_dependence!(pre; autonomous=true)
    CTModels.Building.time!(pre; t0=0.0, tf=1.0)
    CTModels.Building.state!(pre, 2)
    CTModels.Building.control!(pre, 1)
    CTModels.Building.dynamics!(pre, (r, t, x, u, v) -> (r.=[x[2], u[1]]; nothing))
    CTModels.Building.objective!(pre, :min; lagrange=(t, x, u, v) -> 0.5 * u[1]^2)
    return CTModels.Building.build(pre)
end

# non-autonomous: ẋ = u(1 + tan t), ℓ = 0.5u², :min  (non-autonomous, fixed)
function _build_nonauton()
    pre = CTModels.Building.PreModel()
    CTModels.Building.time_dependence!(pre; autonomous=false)
    CTModels.Building.time!(pre; t0=0.0, tf=π / 4)
    CTModels.Building.state!(pre, 1)
    CTModels.Building.control!(pre, 1)
    CTModels.Building.dynamics!(pre, (r, t, x, u, v) -> (r[1]=u * (1 + tan(t)); nothing))
    CTModels.Building.objective!(pre, :min; lagrange=(t, x, u, v) -> 0.5 * u^2)
    return CTModels.Building.build(pre)
end

# control-free OCP (for the guard test)
function _build_control_free()
    pre = CTModels.Building.PreModel()
    CTModels.Building.time_dependence!(pre; autonomous=true)
    CTModels.Building.time!(pre; t0=0.0, tf=1.0)
    CTModels.Building.state!(pre, 1)
    CTModels.Building.dynamics!(pre, (r, t, x, u, v) -> (r[1]=x; nothing))
    CTModels.Building.objective!(pre, :min; lagrange=(t, x, u, v) -> x^2)
    return CTModels.Building.build(pre)
end

# Mayer-only control OCP (no Lagrange): ẋ = -x + u, mayer = xf, :min
function _build_mayer_control()
    pre = CTModels.Building.PreModel()
    CTModels.Building.time_dependence!(pre; autonomous=true)
    CTModels.Building.time!(pre; t0=0.0, tf=1.0)
    CTModels.Building.state!(pre, 1)
    CTModels.Building.control!(pre, 1)
    CTModels.Building.dynamics!(pre, (r, t, x, u, v) -> (r[1]=(-x + u); nothing))
    CTModels.Building.objective!(pre, :min; mayer=(x0, xf, v) -> xf)
    return CTModels.Building.build(pre)
end

# variable (NonFixed) control OCP: ẋ = v·(-x) + u, ℓ = 0.5u², :min
function _build_variable_control()
    pre = CTModels.Building.PreModel()
    CTModels.Building.time_dependence!(pre; autonomous=true)
    CTModels.Building.time!(pre; t0=0.0, tf=1.0)
    CTModels.Building.state!(pre, 1)
    CTModels.Building.control!(pre, 1)
    CTModels.Building.variable!(pre, 1)
    CTModels.Building.dynamics!(pre, (r, t, x, u, v) -> (r[1]=v * (-x) + u; nothing))
    CTModels.Building.objective!(pre, :min; lagrange=(t, x, u, v) -> 0.5 * u^2)
    return CTModels.Building.build(pre)
end

# Type-recording (fake) dynamics: capture the argument types the dynamics is called
# with, to verify the "1-D = scalar, n-D = vector" boundary convention. `x[1]`/`u[1]`
# work for both scalars and vectors, so the compute is correct either way.
const _DYN_SEEN = Ref{Any}(nothing)
_typed_dyn_1d!(r, t, x, u, v) = (_DYN_SEEN[]=(x, u, v); r[1]=(-x[1] + u[1]); nothing)
_typed_dyn_2d!(r, t, x, u, v) = (_DYN_SEEN[]=(x, u, v); r.=[x[2], u[1]]; nothing)

function _build_typed_1d()
    pre = CTModels.Building.PreModel()
    CTModels.Building.time_dependence!(pre; autonomous=true)
    CTModels.Building.time!(pre; t0=0.0, tf=1.0)
    CTModels.Building.state!(pre, 1)
    CTModels.Building.control!(pre, 1)
    CTModels.Building.dynamics!(pre, _typed_dyn_1d!)
    CTModels.Building.objective!(pre, :min; lagrange=(t, x, u, v) -> 0.5 * u[1]^2)
    return CTModels.Building.build(pre)
end

function _build_typed_2d()
    pre = CTModels.Building.PreModel()
    CTModels.Building.time_dependence!(pre; autonomous=true)
    CTModels.Building.time!(pre; t0=0.0, tf=1.0)
    CTModels.Building.state!(pre, 2)
    CTModels.Building.control!(pre, 1)
    CTModels.Building.dynamics!(pre, _typed_dyn_2d!)
    CTModels.Building.objective!(pre, :min; lagrange=(t, x, u, v) -> 0.5 * u[1]^2)
    return CTModels.Building.build(pre)
end

const OCP_LQR = _build_lqr()
const OCP_DI = _build_double_integrator()
const OCP_NA = _build_nonauton()
const OCP_CF = _build_control_free()
const OCP_MAYER = _build_mayer_control()
const OCP_VAR = _build_variable_control()
const OCP_TYPED_1D = _build_typed_1d()
const OCP_TYPED_2D = _build_typed_2d()

function test_ocp_control()
    Test.@testset "OCP control flows" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ====================================================================
        # INTEGRATION — scalar LQR, stationary law u = p (:min ⇒ ∂H̃/∂u = p - u)
        # ====================================================================

        Test.@testset "Integration: LQR — :total and :partial agree (stationary)" begin
            law = Data.DynClosedLoop((x, p) -> p)
            ft = Flows.Flow(OCP_LQR, law; hamiltonian_type=:total, _opts()...)
            fp = Flows.Flow(OCP_LQR, law; hamiltonian_type=:partial, _opts()...)
            t0, tf, x0, p0 = 0.0, 1.0, 1.0, 0.5
            xt, pt = ft(t0, x0, p0, tf)
            xp, pp = fp(t0, x0, p0, tf)
            Test.@test xt isa Number   # 1-D = scalar convention
            Test.@test pt isa Number
            Test.@test xt ≈ xp atol = ATOL
            Test.@test pt ≈ pp atol = ATOL
            # costate: ṗ = p ⇒ p(tf) = p0·e^{tf}
            Test.@test pt ≈ p0 * exp(tf) atol = 1e-6
            # state (analytic): x(t) = (x0 - p0/2)e^{-t} + (p0/2)e^{t}
            Test.@test xt ≈ (x0 - p0 / 2) * exp(-tf) + (p0 / 2) * exp(tf) atol = 1e-6
        end

        # ====================================================================
        # INTEGRATION — double integrator energy (reference from save/test)
        # ====================================================================

        Test.@testset "Integration: double integrator energy → xf ≈ [0,0]" begin
            law = Data.DynClosedLoop((x, p) -> p[2])   # stationary for :min
            f = Flows.Flow(OCP_DI, law; _opts()...)
            t0, tf, x0, p0 = 0.0, 1.0, [-1.0, 0.0], [12.0, 6.0]
            xf, pf = f(t0, x0, p0, tf)
            Test.@test xf isa AbstractVector && length(xf) == 2
            Test.@test xf ≈ [0.0, 0.0] atol = 1e-6

            fp = Flows.Flow(OCP_DI, law; hamiltonian_type=:partial, _opts()...)
            xfp, pfp = fp(t0, x0, p0, tf)
            Test.@test xf ≈ xfp atol = ATOL   # agree at stationarity
        end

        # ====================================================================
        # INTEGRATION — non-autonomous + convenience Flow(ocp, u::Function)
        # ====================================================================

        Test.@testset "Integration: non-autonomous, convenience constructor" begin
            # law u(t,x,p) = p(1 + tan t) is stationary; reference xf value.
            # OCP_NA is non-autonomous, so the convenience law inherits (t,x,p) arity.
            f = Flows.Flow(OCP_NA, (t, x, p) -> p * (1 + tan(t)); _opts()...)
            t0, tf, x0, p0 = 0.0, π / 4, 0.0, 1.0
            xf, pf = f(t0, x0, p0, tf)
            xf_ref = tan(π / 4) - 2 * log(√(2) / 2)
            Test.@test xf ≈ xf_ref atol = 1e-6
        end

        # ====================================================================
        # INTEGRATION — non-stationary law ⇒ :total ≠ :partial (mandatory)
        # ====================================================================

        Test.@testset "Integration: non-stationary law separates :total and :partial" begin
            # double integrator, stationary law is u = p[2]; use u = p[2] + 1.
            law = Data.DynClosedLoop((x, p) -> p[2] + 1.0)
            ft = Flows.Flow(OCP_DI, law; hamiltonian_type=:total, _opts()...)
            fp = Flows.Flow(OCP_DI, law; hamiltonian_type=:partial, _opts()...)
            t0, tf, x0, p0 = 0.0, 1.0, [-1.0, 0.0], [12.0, 6.0]
            xt, pt = ft(t0, x0, p0, tf)
            xp, pp = fp(t0, x0, p0, tf)
            Test.@test !isapprox(xt, xp; atol=1e-4)   # genuinely different flows
        end

        # ====================================================================
        # SOLUTION — trajectory call builds a CTModels.Solution with control
        # ====================================================================

        Test.@testset "Solution: objective and reconstructed control" begin
            law = Data.DynClosedLoop((x, p) -> p[2])
            f = Flows.Flow(OCP_DI, law; _opts()...)
            t0, tf, x0, p0 = 0.0, 1.0, [-1.0, 0.0], [12.0, 6.0]
            sol = f((t0, tf), x0, p0)
            obj = CTModels.objective(sol)
            Test.@test obj > 0                       # ∫0.5u² dt > 0
            # reconstructed control u(t) = p₂(t); positive Lagrange cost is consistent
            u = CTModels.control(sol)
            Test.@test u(t0) isa Union{Number,AbstractVector}
            # :total and :partial give the same objective at stationarity
            fp = Flows.Flow(OCP_DI, law; hamiltonian_type=:partial, _opts()...)
            solp = fp((t0, tf), x0, p0)
            Test.@test obj ≈ CTModels.objective(solp) atol = 1e-6
        end

        # ====================================================================
        # INTEGRATION — Flow(h̃, law) directly (no OCP)
        # ====================================================================

        Test.@testset "Integration: Flow(h̃, law) direct" begin
            # H̃(x,p,u) = p(-x+u) + 0.5u² ; law u = -p (stationary for this h̃)
            h̃ = Data.PseudoHamiltonian((x, p, u) -> p * (-x + u) + 0.5 * u^2)
            law = Data.DynClosedLoop((x, p) -> -p)
            ft = Flows.Flow(h̃, law; hamiltonian_type=:total, _opts()...)
            fp = Flows.Flow(h̃, law; hamiltonian_type=:partial, _opts()...)
            t0, tf, x0, p0 = 0.0, 1.0, 1.0, 0.5
            Test.@test all(isapprox.(ft(t0, x0, p0, tf), fp(t0, x0, p0, tf); atol=ATOL))
            # costate ṗ = -∂H̃/∂x = p ⇒ p(tf) = p0 e^{tf}
            _, pf = ft(t0, x0, p0, tf)
            Test.@test pf ≈ p0 * exp(tf) atol = 1e-6
        end

        # ====================================================================
        # INTEGRATION — variable (NonFixed) control OCP
        # ====================================================================

        Test.@testset "Integration: variable (NonFixed) control flow" begin
            # ẋ = v(-x) + u, ℓ = 0.5u², :min ⇒ ∂H̃/∂u = p - u ; stationary law u = p.
            law = Data.DynClosedLoop((x, p, v) -> p; is_variable=true)
            ft = Flows.Flow(OCP_VAR, law; hamiltonian_type=:total, _opts()...)
            fp = Flows.Flow(OCP_VAR, law; hamiltonian_type=:partial, _opts()...)
            t0, tf, x0, p0, vval = 0.0, 1.0, 1.0, 0.5, 0.5
            xt, pt = ft(t0, x0, p0, tf; variable=vval)
            xp, pp = fp(t0, x0, p0, tf; variable=vval)
            Test.@test xt ≈ xp atol = ATOL             # agree at stationarity
            Test.@test pt ≈ pp atol = ATOL
            # costate: ṗ = -∂H̃/∂x = p·v ⇒ p(tf) = p0·e^{v·tf}
            Test.@test pt ≈ p0 * exp(vval * tf) atol = 1e-6
        end

        # ====================================================================
        # INTEGRATION — variable_costate on a control flow (:partial / :total)
        #   OCP_VAR: ẋ = v(-x)+u, ℓ=0.5u², :min ⇒ H̃ = p(-vx+u) - 0.5u².
        #   ∂H̃/∂u = p - u ; law u=p is stationary, law u=v·p is not.
        # ====================================================================

        Test.@testset "Integration: :partial variable_costate — quadrature cross-check" begin
            law = Data.DynClosedLoop((x, p, v) -> p; is_variable=true)   # stationary
            fp = Flows.Flow(OCP_VAR, law; hamiltonian_type=:partial, _opts()...)
            t0, tf, x0, p0, v = 0.0, 1.0, 1.0, 0.5, 0.5
            _, _, pvf = fp(t0, x0, p0, tf; variable=v, variable_costate=true)
            Test.@test pvf isa Number
            # pvf = -∫ ∂H̃/∂v dt (u held at the law value) — quadrature on the flow's own
            # (x(t), p(t)) trajectory, using the pseudo variable-gradient getter.
            ∇ṽ = Systems.pseudo_variable_gradient(fp)
            ts = range(t0, tf; length=101)
            ys = map(ts) do t
                x, p = t == t0 ? (x0, p0) : fp(t0, x0, p0, t; variable=v)
                first(∇ṽ(t, x, p, p, v))          # u = law(x,p,v) = p
            end
            Test.@test pvf ≈ -_trapz(ts, ys) atol = 1e-3
        end

        Test.@testset "Integration: :total vs :partial variable_costate agree (stationary)" begin
            law = Data.DynClosedLoop((x, p, v) -> p; is_variable=true)   # u=p stationary
            ft = Flows.Flow(OCP_VAR, law; hamiltonian_type=:total, _opts()...)
            fp = Flows.Flow(OCP_VAR, law; hamiltonian_type=:partial, _opts()...)
            t0, tf, x0, p0, v = 0.0, 1.0, 1.0, 0.5, 0.5
            _, _, pvt = ft(t0, x0, p0, tf; variable=v, variable_costate=true)
            _, _, pvp = fp(t0, x0, p0, tf; variable=v, variable_costate=true)
            # stationary law ⇒ chain term ∂H̃/∂u·∂u/∂v = 0 ⇒ pv identical in both modes
            Test.@test pvt ≈ pvp atol = 1e-6
        end

        Test.@testset "Integration: :total vs :partial variable_costate differ (non-stationary)" begin
            law = Data.DynClosedLoop((x, p, v) -> v * p; is_variable=true)   # non-stationary
            ft = Flows.Flow(OCP_VAR, law; hamiltonian_type=:total, _opts()...)
            fp = Flows.Flow(OCP_VAR, law; hamiltonian_type=:partial, _opts()...)
            t0, tf, x0, p0, v = 0.0, 1.0, 1.0, 0.5, 0.5
            _, _, pvt = ft(t0, x0, p0, tf; variable=v, variable_costate=true)
            _, _, pvp = fp(t0, x0, p0, tf; variable=v, variable_costate=true)
            # non-stationary law ⇒ chain term ≠ 0 ⇒ the two modes give different pv
            Test.@test !isapprox(pvt, pvp; atol=1e-4)
            # absolute check on :total via quadrature of the total ∂H/∂v (through the law)
            ∇v = Systems.variable_gradient(ft)
            ts = range(t0, tf; length=101)
            ys = map(ts) do t
                x, p = t == t0 ? (x0, p0) : ft(t0, x0, p0, t; variable=v)
                first(∇v(t, x, p, v))
            end
            Test.@test pvt ≈ -_trapz(ts, ys) atol = 1e-3
        end

        # ====================================================================
        # UNIT — Hamiltonian / pseudo-Hamiltonian / control-law getters
        # ====================================================================

        Test.@testset "Unit: getters expose H, H̃ and the law (both modes)" begin
            law = Data.DynClosedLoop((x, p, v) -> p; is_variable=true)
            fp = Flows.Flow(OCP_VAR, law; hamiltonian_type=:partial, _opts()...)
            ft = Flows.Flow(OCP_VAR, law; hamiltonian_type=:total, _opts()...)
            # :partial → PseudoHamiltonianSystem exposes H̃ and the law directly
            Test.@test Systems.pseudo_hamiltonian(fp) isa Data.AbstractPseudoHamiltonian
            Test.@test Systems.control_law(fp) isa Data.ControlLaw
            # :total → HamiltonianSystem wraps a ComposedHamiltonian; H̃ and law recovered
            Test.@test Systems.pseudo_hamiltonian(ft) isa Data.AbstractPseudoHamiltonian
            Test.@test Systems.control_law(ft) isa Data.ControlLaw
            # both expose the true (composed) Hamiltonian
            Test.@test Systems.hamiltonian(fp) isa Data.AbstractHamiltonian
            Test.@test Systems.hamiltonian(ft) isa Data.AbstractHamiltonian
            # gradient getters return callable functors (not closures)
            Test.@test Systems.pseudo_hamiltonian_gradient(fp) isa
                Systems.PseudoHamiltonianGradient
            Test.@test Systems.hamiltonian_gradient(ft) isa Systems.HamiltonianGradient
            # the AD backend can be provided explicitly (forwarded flow → system)
            be = Systems.backend(Flows.system(ft))
            g_default = Systems.hamiltonian_gradient(ft)
            g_custom = Systems.hamiltonian_gradient(ft; ad_backend=be)
            Test.@test g_custom isa Systems.HamiltonianGradient
            Test.@test all(g_default(0.0, 1.0, 0.5, 0.5) .≈ g_custom(0.0, 1.0, 0.5, 0.5))
        end

        # ====================================================================
        # INTEGRATION — Mayer-only control OCP (exercises lagrange === nothing)
        # ====================================================================

        Test.@testset "Integration: Mayer-only control flow (no Lagrange)" begin
            # ẋ = -x + u, mayer only ; H̃ = p(-x+u) (no running cost).
            law = Data.DynClosedLoop((x, p) -> p)
            f = Flows.Flow(OCP_MAYER, law; _opts()...)
            t0, tf, x0, p0 = 0.0, 1.0, 1.0, 0.5
            xf, pf = f(t0, x0, p0, tf)
            Test.@test xf isa Number && isfinite(xf)
            Test.@test pf isa Number && isfinite(pf)
            # ṗ = -∂H̃/∂x = p ⇒ p(tf) = p0·e^{tf}
            Test.@test pf ≈ p0 * exp(tf) atol = 1e-6
            # objective is the Mayer term x(tf); solution builds without a Lagrange integral
            sol = f((t0, tf), x0, p0)
            Test.@test CTModels.objective(sol) ≈ xf atol = 1e-6
        end

        # ====================================================================
        # CONTRACT — the dynamics receives scalars for 1-D, vectors for n-D
        # ====================================================================

        Test.@testset "Contract: dynamics sees scalar x,u for 1-D" begin
            _DYN_SEEN[] = nothing
            f = Flows.Flow(OCP_TYPED_1D, Data.DynClosedLoop((x, p) -> p); _opts()...)
            f(0.0, 1.0, 0.5, 1.0)
            xseen, useen, _ = _DYN_SEEN[]
            Test.@test xseen isa Number   # 1-D state → scalar (Dual during AD, still a Number)
            Test.@test useen isa Number   # 1-D control → scalar
        end

        Test.@testset "Contract: dynamics sees vector x for n-D" begin
            _DYN_SEEN[] = nothing
            f = Flows.Flow(OCP_TYPED_2D, Data.DynClosedLoop((x, p) -> p[2]); _opts()...)
            f(0.0, [1.0, 0.0], [1.0, 1.0], 1.0)
            xseen, useen, _ = _DYN_SEEN[]
            Test.@test xseen isa AbstractVector && length(xseen) == 2   # 2-D state → vector
            Test.@test useen isa Number   # 1-D control → scalar even when the state is a vector
        end

        # ====================================================================
        # ERROR paths
        # ====================================================================

        Test.@testset "Error: invalid hamiltonian_type" begin
            law = Data.DynClosedLoop((x, p) -> p)
            Test.@test_throws Exceptions.IncorrectArgument Flows.Flow(
                OCP_LQR, law; hamiltonian_type=:foo, _opts()...
            )
        end

        Test.@testset "Error: control-free OCP with a law" begin
            law = Data.DynClosedLoop((x, p) -> p)
            Test.@test_throws Exceptions.PreconditionError Flows.Flow(
                OCP_CF, law; _opts()...
            )
        end

        Test.@testset "OpenLoop/ClosedLoop law into Flow(ocp, law) → ControlledFlow (state)" begin
            # OpenLoop/ClosedLoop laws now build a state flow (see test_state_control_flows.jl).
            f = Flows.Flow(OCP_LQR, Data.ClosedLoop(x -> -x); _opts()...)
            Test.@test f isa Flows.ControlledFlow
        end

        Test.@testset "Error: OpenLoop law into Flow(h̃, law) → PreconditionError" begin
            h̃ = Data.PseudoHamiltonian((x, p, u) -> p * u)
            Test.@test_throws Exceptions.PreconditionError Flows.Flow(
                h̃, Data.OpenLoop(() -> 1.0); _opts()...
            )
        end
    end
end

end # module

test_ocp_control() = TestOCPControl.test_ocp_control()
