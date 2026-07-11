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

# scalar LQR with a labelled :path constraint g(x)=x and a :boundary constraint.
# Same dynamics/cost as _build_lqr, so the constrained closed form below applies.
function _build_lqr_constrained()
    pre = CTModels.Building.PreModel()
    CTModels.Building.time_dependence!(pre; autonomous=true)
    CTModels.Building.time!(pre; t0=0.0, tf=1.0)
    CTModels.Building.state!(pre, 1)
    CTModels.Building.control!(pre, 1)
    CTModels.Building.dynamics!(pre, (r, t, x, u, v) -> (r[1]=(-x + u); nothing))
    CTModels.Building.objective!(pre, :min; lagrange=(t, x, u, v) -> 0.5 * u^2)
    CTModels.Building.constraint!(
        pre, :path; f=(r, t, x, u, v) -> (r[1]=x; nothing), lb=[-Inf], ub=[0.0], label=:g
    )
    CTModels.Building.constraint!(
        pre,
        :boundary;
        f=(r, x0, xf, v) -> (r[1]=xf; nothing),
        lb=[0.0],
        ub=[0.0],
        label=:bnd,
    )
    return CTModels.Building.build(pre)
end

const OCP_LQR = _build_lqr()
const OCP_LQR_C = _build_lqr_constrained()
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
        # CONVENIENCE — Flow(ocp, u::Function) ≡ explicit DynClosedLoop, and a raw
        # function `constraint`/`multiplier` ≡ its wrapped MixedConstraint/Multiplier
        # ====================================================================

        Test.@testset "Convenience: Flow(ocp, u::Function) ≡ explicit DynClosedLoop" begin
            # The convenience wraps `u` in a DynClosedLoop with the OCP's time/variable
            # dependence, so it must reproduce the explicit law exactly.

            # autonomous (x,p): inherits is_autonomous=true, is_variable=false
            u = (x, p) -> p[2]
            fconv = Flows.Flow(OCP_DI, u; _opts()...)
            fexpl = Flows.Flow(OCP_DI, Data.DynClosedLoop(u); _opts()...)
            Test.@test fconv isa Flows.OptimalControlFlow
            t0, tf, x0, p0 = 0.0, 1.0, [-1.0, 0.0], [12.0, 6.0]
            xc, pc = fconv(t0, x0, p0, tf)
            xe, pe = fexpl(t0, x0, p0, tf)
            Test.@test xc ≈ xe atol = 1e-10
            Test.@test pc ≈ pe atol = 1e-10

            # non-autonomous (t,x,p): inherits is_autonomous=false
            un = (t, x, p) -> p * (1 + tan(t))
            gconv = Flows.Flow(OCP_NA, un; _opts()...)
            gexpl = Flows.Flow(OCP_NA, Data.DynClosedLoop(un; is_autonomous=false); _opts()...)
            xc2, pc2 = gconv(0.0, 0.0, 1.0, π / 4)
            xe2, pe2 = gexpl(0.0, 0.0, 1.0, π / 4)
            Test.@test xc2 ≈ xe2 atol = 1e-10
            Test.@test pc2 ≈ pe2 atol = 1e-10

            # variable (x,p,v): inherits is_variable=true on the NonFixed OCP_VAR
            uv = (x, p, v) -> p
            hconv = Flows.Flow(OCP_VAR, uv; _opts()...)
            hexpl = Flows.Flow(OCP_VAR, Data.DynClosedLoop(uv; is_variable=true); _opts()...)
            xc3, pc3 = hconv(0.0, 1.0, 0.5, 1.0; variable=0.5)
            xe3, pe3 = hexpl(0.0, 1.0, 0.5, 1.0; variable=0.5)
            Test.@test xc3 ≈ xe3 atol = 1e-10
            Test.@test pc3 ≈ pe3 atol = 1e-10
        end

        Test.@testset "Convenience: function control + function constraint/multiplier" begin
            # all three conveniences (u, constraint, multiplier as raw functions) in one call
            # equal the explicit DynClosedLoop + function constraint/multiplier form
            u = (x, p) -> p
            g = (x, u) -> x
            μ = (x, p) -> 0.7
            fconv = Flows.Flow(OCP_LQR, u; constraint=g, multiplier=μ, _opts()...)
            fexpl = Flows.Flow(
                OCP_LQR, Data.DynClosedLoop(u); constraint=g, multiplier=μ, _opts()...
            )
            t0, tf, x0, p0 = 0.0, 1.0, 1.0, 0.5
            xc, pc = fconv(t0, x0, p0, tf)
            xe, pe = fexpl(t0, x0, p0, tf)
            Test.@test xc ≈ xe atol = 1e-10
            Test.@test pc ≈ pe atol = 1e-10

            # a raw function `constraint` resolves to a mixed-kind PathConstraint (the
            # `MixedConstraint` constructor), a raw function `multiplier` to a Multiplier
            resolved = Flows._resolve_constraint(OCP_LQR, g)
            Test.@test resolved isa Data.PathConstraint
            Test.@test Traits.is_mixed_constraint(resolved)
            Test.@test Flows._resolve_multiplier(OCP_LQR, μ) isa Data.Multiplier
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
        # CONSTRAINED :total flows — H = H̃ + μ·g
        #
        # OCP_LQR: ẋ=-x+u, ℓ=0.5u², :min ⇒ H̃ = p(-x+u) - 0.5u², stationary law u=p.
        # State constraint g(x)=x with a *constant* multiplier μ≡c gives the composed
        # Hamiltonian H(x,p) = -px + 0.5p² + c·x, hence
        #   ṗ = -∂H/∂x = p - c        ⇒ p(t) = c + (p0-c)e^{t}
        #   ẋ = ∂H/∂p  = -x + p       ⇒ x(t) = (x0-p0/2-c/2)e^{-t} + c + (p0-c)/2·e^{t}
        # (c=0 recovers the unconstrained LQR closed form).
        # ====================================================================

        # analytic references for the constrained LQR with constant multiplier c
        _pc(p0, tf, c) = c + (p0 - c) * exp(tf)
        _xc(x0, p0, tf, c) = (x0 - p0 / 2 - c / 2) * exp(-tf) + c + (p0 - c) / 2 * exp(tf)

        Test.@testset "Constrained: Data.StateConstraint + Data.Multiplier (closed form)" begin
            c = 0.3
            g = Data.StateConstraint(x -> x)       # autonomous, fixed: g(x)
            μ = Data.Multiplier((x, p) -> c)        # autonomous, fixed, constant
            law = Data.DynClosedLoop((x, p) -> p)   # stationary for H̃
            f = Flows.Flow(OCP_LQR, law; constraint=g, multiplier=μ, _opts()...)
            t0, tf, x0, p0 = 0.0, 1.0, 1.0, 0.5
            xt, pt = f(t0, x0, p0, tf)
            Test.@test xt isa Number && pt isa Number
            Test.@test pt ≈ _pc(p0, tf, c) atol = 1e-6
            Test.@test xt ≈ _xc(x0, p0, tf, c) atol = 1e-6
        end

        Test.@testset "Constrained: plain functions match the carrier form" begin
            c = 0.3
            law = Data.DynClosedLoop((x, p) -> p)
            # raw function constraint is wrapped as a MixedConstraint with the OCP traits,
            # so its natural arity is (x,u); raw multiplier is (x,p).
            f = Flows.Flow(
                OCP_LQR, law; constraint=(x, u) -> x, multiplier=(x, p) -> c, _opts()...
            )
            t0, tf, x0, p0 = 0.0, 1.0, 1.0, 0.5
            xt, pt = f(t0, x0, p0, tf)
            Test.@test pt ≈ _pc(p0, tf, c) atol = 1e-6
            Test.@test xt ≈ _xc(x0, p0, tf, c) atol = 1e-6
        end

        Test.@testset "Constrained: :path label resolution matches" begin
            c = 0.3
            law = Data.DynClosedLoop((x, p) -> p)
            f = Flows.Flow(
                OCP_LQR_C, law; constraint=:g, multiplier=(x, p) -> c, _opts()...
            )
            t0, tf, x0, p0 = 0.0, 1.0, 1.0, 0.5
            xt, pt = f(t0, x0, p0, tf)
            Test.@test pt ≈ _pc(p0, tf, c) atol = 1e-6
            Test.@test xt ≈ _xc(x0, p0, tf, c) atol = 1e-6
        end

        Test.@testset "Constrained: μ≡0 recovers the unconstrained flow" begin
            law = Data.DynClosedLoop((x, p) -> p)
            f0 = Flows.Flow(
                OCP_LQR,
                law;
                constraint=Data.StateConstraint(x -> x),
                multiplier=Data.Multiplier((x, p) -> 0.0),
                _opts()...,
            )
            fu = Flows.Flow(OCP_LQR, law; _opts()...)
            t0, tf, x0, p0 = 0.0, 1.0, 1.0, 0.5
            Test.@test all(isapprox.(f0(t0, x0, p0, tf), fu(t0, x0, p0, tf); atol=ATOL))
        end

        Test.@testset "Constrained: solution builds (EmptyDualModel, no duals)" begin
            c = 0.3
            law = Data.DynClosedLoop((x, p) -> p)
            f = Flows.Flow(
                OCP_LQR,
                law;
                constraint=Data.StateConstraint(x -> x),
                multiplier=Data.Multiplier((x, p) -> c),
                _opts()...,
            )
            sol = f((0.0, 1.0), 1.0, 0.5)
            Test.@test CTModels.objective(sol) isa Number
            Test.@test !CTModels.Solutions.has_duals(sol)   # flow-built ⇒ no duals
        end

        Test.@testset "Constrained: NonFixed smoke test (variable at call time)" begin
            c = 0.2
            # g depends on state only; μ constant. NonFixed OCP composes untouched.
            g = Data.StateConstraint(x -> x)
            μ = Data.Multiplier((x, p) -> c)
            law = Data.DynClosedLoop((x, p, v) -> p; is_variable=true)
            f = Flows.Flow(OCP_VAR, law; constraint=g, multiplier=μ, _opts()...)
            xt, pt = f(0.0, 1.0, 0.5, 1.0; variable=0.5)
            Test.@test isfinite(xt) && isfinite(pt)
        end

        # ---- getter-based analytic regression tests -----------------------------
        # Recover the (pseudo-)Hamiltonians and their gradients from the flow and check
        # them against hand-derived closed forms, freezing exactly what is computed.
        #   OCP_LQR + g(x)=x + μ≡c + law u=p ⇒
        #     H̃_c(t,x,p,u,v) = p(-x+u) - 0.5u² + c·x            (control explicit)
        #     H(x,p)         = H̃_c(x,p,p)   = -p x + 0.5 p² + c x
        #     ∂ₓH = -p + c,  ∂ₚH = -x + p,  X_H = (∂ₚH,-∂ₓH) = (-x+p, p-c)

        Test.@testset "Constrained: Hamiltonian getters vs analytic derivatives" begin
            c = 0.3
            g = Data.StateConstraint(x -> x)
            μ = Data.Multiplier((x, p) -> c)
            law = Data.DynClosedLoop((x, p) -> p)
            f = Flows.Flow(OCP_LQR, law; constraint=g, multiplier=μ, _opts()...)
            x0, p0, u0 = 0.7, 0.4, -0.2   # u0 ≠ p0 to expose the fixed-u pseudo gradient

            # (1) true Hamiltonian H(x,p) = -p x + 0.5 p² + c x
            H = Systems.hamiltonian(f)
            Test.@test H(x0, p0) ≈ -p0 * x0 + 0.5 * p0^2 + c * x0 atol = 1e-10

            # (2) pseudo-Hamiltonian H̃_c(t,x,p,u,v) = p(-x+u) - 0.5u² + c x
            H̃ = Systems.pseudo_hamiltonian(f)
            Test.@test H̃(0.0, x0, p0, u0, Float64[]) ≈
                p0 * (-x0 + u0) - 0.5 * u0^2 + c * x0 atol = 1e-10
            # the +μ·g term is exactly c·x: difference from the unconstrained H̃
            fu = Flows.Flow(OCP_LQR, law; _opts()...)
            H̃u = Systems.pseudo_hamiltonian(fu)
            Test.@test H̃(0.0, x0, p0, u0, Float64[]) - H̃u(0.0, x0, p0, u0, Float64[]) ≈
                c * x0 atol = 1e-10

            # (3) total gradient ∇H = (∂ₓH, ∂ₚH) = (-p+c, -x+p) — chain-rule through law
            ∇H = Systems.hamiltonian_gradient(f)
            dxH, dpH = ∇H(0.0, x0, p0, Float64[])
            Test.@test dxH ≈ -p0 + c atol = 1e-8
            Test.@test dpH ≈ -x0 + p0 atol = 1e-8

            # (4) pseudo gradient at fixed u: ∂ₓH̃_c = -p+c, ∂ₚH̃_c = -x+u
            ∇H̃ = Systems.pseudo_hamiltonian_gradient(f)
            dxH̃, dpH̃ = ∇H̃(0.0, x0, p0, u0, Float64[])
            Test.@test dxH̃ ≈ -p0 + c atol = 1e-8
            Test.@test dpH̃ ≈ -x0 + u0 atol = 1e-8

            # (5) symplectic gradient X_H = (∂ₚH, -∂ₓH) = (ẋ, ṗ) = (-x+p, p-c),
            # reconstructed from the total gradient getter (the HVF-by-AD getter is for
            # flows built from a scalar Data.Hamiltonian, not a ComposedHamiltonian).
            Test.@test dpH ≈ -x0 + p0 atol = 1e-8    # ẋ = ∂ₚH
            Test.@test -dxH ≈ p0 - c atol = 1e-8     # ṗ = -∂ₓH
        end

        # NonFixed constrained: ∂H/∂v carries no constraint term here (μ const, g=x are
        # v-independent), guarding against a spurious v-coupling from the +μ·g term.
        #   OCP_VAR: ẋ=v(-x)+u, ℓ=0.5u², law u=p ⇒ H(x,p,v) = -v p x + 0.5 p² + c x,
        #   so ∂H/∂v = -p x.
        Test.@testset "Constrained: NonFixed variable gradient (analytic)" begin
            c = 0.25
            g = Data.StateConstraint(x -> x)
            μ = Data.Multiplier((x, p) -> c)
            law = Data.DynClosedLoop((x, p, v) -> p; is_variable=true)
            f = Flows.Flow(OCP_VAR, law; constraint=g, multiplier=μ, _opts()...)
            x0, p0, vv = 0.7, 0.4, 0.5
            ∇vH = Systems.variable_gradient(f)
            Test.@test first(∇vH(0.0, x0, p0, vv)) ≈ -p0 * x0 atol = 1e-8
        end

        # ---- constrained validation matrix --------------------------------------

        Test.@testset "Constrained error: constraint without multiplier" begin
            law = Data.DynClosedLoop((x, p) -> p)
            Test.@test_throws Exceptions.IncorrectArgument Flows.Flow(
                OCP_LQR, law; constraint=Data.StateConstraint(x -> x), _opts()...
            )
        end

        Test.@testset "Constrained error: multiplier without constraint" begin
            law = Data.DynClosedLoop((x, p) -> p)
            Test.@test_throws Exceptions.IncorrectArgument Flows.Flow(
                OCP_LQR, law; multiplier=Data.Multiplier((x, p) -> 0.0), _opts()...
            )
        end

        Test.@testset "Constrained error: non-:path label rejected" begin
            law = Data.DynClosedLoop((x, p) -> p)
            Test.@test_throws Exceptions.IncorrectArgument Flows.Flow(
                OCP_LQR_C, law; constraint=:bnd, multiplier=(x, p) -> 0.0, _opts()...
            )
        end

        # ====================================================================
        # CONSTRAINED :partial flows — H = H̃ + μ·g with BOTH u and μ frozen.
        # Freezing μ ⇒ g is differentiated, μ is not (constrained :partial mode).
        # See .reports/constraints-and-duals/math.md.
        # ====================================================================

        Test.@testset "Constrained :partial: constant μ matches closed form" begin
            c = 0.3
            g = Data.StateConstraint(x -> x)
            μ = Data.Multiplier((x, p) -> c)
            law = Data.DynClosedLoop((x, p) -> p)   # stationary for H̃
            f = Flows.Flow(
                OCP_LQR,
                law;
                constraint=g,
                multiplier=μ,
                hamiltonian_type=:partial,
                _opts()...,
            )
            t0, tf, x0, p0 = 0.0, 1.0, 1.0, 0.5
            xt, pt = f(t0, x0, p0, tf)
            Test.@test xt isa Number && pt isa Number
            # constant μ ⇒ frozen and total agree; closed form of PR 3 applies verbatim
            Test.@test pt ≈ _pc(p0, tf, c) atol = 1e-6
            Test.@test xt ≈ _xc(x0, p0, tf, c) atol = 1e-6
        end

        Test.@testset "Constrained: :total ≡ :partial for constant μ (regression)" begin
            c = 0.3
            g = Data.StateConstraint(x -> x)
            μ = Data.Multiplier((x, p) -> c)
            law = Data.DynClosedLoop((x, p) -> p)   # stationary for H̃
            ft = Flows.Flow(
                OCP_LQR,
                law;
                constraint=g,
                multiplier=μ,
                hamiltonian_type=:total,
                _opts()...,
            )
            fp = Flows.Flow(
                OCP_LQR,
                law;
                constraint=g,
                multiplier=μ,
                hamiltonian_type=:partial,
                _opts()...,
            )
            t0, tf, x0, p0 = 0.0, 1.0, 1.0, 0.5
            # constant μ + stationary law ⇒ the two RHS are mathematically identical
            Test.@test all(isapprox.(ft(t0, x0, p0, tf), fp(t0, x0, p0, tf); atol=1e-9))
        end

        Test.@testset "Constrained :partial: state-dependent μ is frozen (analytic)" begin
            # g(x)=x, μ(x)=x ⇒ μ·g = x². With law u=p (stationary):
            #   :partial freezes μ_=x ⇒ ṗ = -∂ₓ[p(-x+p)-0.5p²+μ_·x] = p - x, ẋ = -x+p.
            #     ẋ = ṗ = p-x is nilpotent ⇒ x(t)=x0-(x0-p0)t, p(t)=p0-(x0-p0)t.
            #   :total differentiates through μ ⇒ ṗ = p - 2x (different system).
            g = Data.StateConstraint(x -> x)
            μ = Data.Multiplier((x, p) -> x)          # state-dependent
            law = Data.DynClosedLoop((x, p) -> p)
            fp = Flows.Flow(
                OCP_LQR,
                law;
                constraint=g,
                multiplier=μ,
                hamiltonian_type=:partial,
                _opts()...,
            )
            ft = Flows.Flow(
                OCP_LQR,
                law;
                constraint=g,
                multiplier=μ,
                hamiltonian_type=:total,
                _opts()...,
            )
            t0, tf, x0, p0 = 0.0, 0.5, 1.0, 0.5
            xp, pp = fp(t0, x0, p0, tf)
            # :partial matches the frozen-μ analytic solution
            Test.@test xp ≈ x0 - (x0 - p0) * tf atol = 1e-6
            Test.@test pp ≈ p0 - (x0 - p0) * tf atol = 1e-6
            # :total genuinely differs (μ not frozen) — proves μ is frozen in :partial
            _, pt = ft(t0, x0, p0, tf)
            Test.@test !isapprox(pp, pt; atol=1e-3)
        end

        Test.@testset "Constrained :partial: variable-costate picks up frozen μ·∂g/∂v" begin
            # v-dependent constraint g(x,v)=x·v, μ≡c. Frozen μ_=c ⇒
            #   ṗv = -∂/∂v[H̃ + c·(x·v)] = -(∂H̃/∂v + c·x) with ∂H̃/∂v = -p·x (OCP_VAR)
            #      = x(p - c).
            c = 0.2
            g = Data.StateConstraint((x, v) -> x * v; is_variable=true)
            μ = Data.Multiplier((x, p) -> c)
            law = Data.DynClosedLoop((x, p, v) -> p; is_variable=true)   # stationary
            fp = Flows.Flow(
                OCP_VAR,
                law;
                constraint=g,
                multiplier=μ,
                hamiltonian_type=:partial,
                _opts()...,
            )
            t0, tf, x0, p0, v = 0.0, 1.0, 1.0, 0.5, 0.5
            _, _, pvf = fp(t0, x0, p0, tf; variable=v, variable_costate=true)
            Test.@test pvf isa Number
            ts = range(t0, tf; length=201)
            ys = map(ts) do t
                x, p = t == t0 ? (x0, p0) : fp(t0, x0, p0, t; variable=v)
                x * (p - c)                       # ṗv along the flow's own trajectory
            end
            Test.@test pvf ≈ _trapz(ts, ys) atol = 1e-3
        end

        Test.@testset "Constrained: :total variable-costate picks up ∂/∂v[H̃+μ·g] (analytic)" begin
            # Same setup as the :partial test above — v-dependent constraint g(x,v)=x·v,
            # μ≡c, stationary AND v-independent law u=p ⇒ the chain term ∂H̃/∂u·∂u/∂v
            # vanishes, so :total's pv coincides with the same frozen-μ analytic formula.
            # Fills the last cell of the {constraint} × {:total,:partial} × {variable,
            # variable_costate} matrix (the other three are covered above/below).
            c = 0.2
            g = Data.StateConstraint((x, v) -> x * v; is_variable=true)
            μ = Data.Multiplier((x, p) -> c)
            law = Data.DynClosedLoop((x, p, v) -> p; is_variable=true)
            ft = Flows.Flow(
                OCP_VAR, law; constraint=g, multiplier=μ, hamiltonian_type=:total, _opts()...
            )
            t0, tf, x0, p0, v = 0.0, 1.0, 1.0, 0.5, 0.5
            _, _, pvt = ft(t0, x0, p0, tf; variable=v, variable_costate=true)
            Test.@test pvt isa Number
            ts = range(t0, tf; length=201)
            ys = map(ts) do t
                x, p = t == t0 ? (x0, p0) : ft(t0, x0, p0, t; variable=v)
                x * (p - c)                       # ∂/∂v[H̃+μ·g] along the flow's own trajectory
            end
            Test.@test pvt ≈ _trapz(ts, ys) atol = 1e-3
        end

        Test.@testset "Constrained :partial: NonFixed smoke (variable at call time)" begin
            c = 0.2
            g = Data.StateConstraint(x -> x)
            μ = Data.Multiplier((x, p) -> c)
            law = Data.DynClosedLoop((x, p, v) -> p; is_variable=true)
            f = Flows.Flow(
                OCP_VAR,
                law;
                constraint=g,
                multiplier=μ,
                hamiltonian_type=:partial,
                _opts()...,
            )
            xt, pt = f(0.0, 1.0, 0.5, 1.0; variable=0.5)
            Test.@test isfinite(xt) && isfinite(pt)
        end

        Test.@testset "Constrained :partial: plain functions and :path label" begin
            c = 0.3
            law = Data.DynClosedLoop((x, p) -> p)
            t0, tf, x0, p0 = 0.0, 1.0, 1.0, 0.5
            ff = Flows.Flow(
                OCP_LQR,
                law;
                constraint=(x, u) -> x,
                multiplier=(x, p) -> c,
                hamiltonian_type=:partial,
                _opts()...,
            )
            xf, pf = ff(t0, x0, p0, tf)
            Test.@test pf ≈ _pc(p0, tf, c) atol = 1e-6
            Test.@test xf ≈ _xc(x0, p0, tf, c) atol = 1e-6
            fl = Flows.Flow(
                OCP_LQR_C,
                law;
                constraint=:g,
                multiplier=(x, p) -> c,
                hamiltonian_type=:partial,
                _opts()...,
            )
            xl, pl = fl(t0, x0, p0, tf)
            Test.@test pl ≈ _pc(p0, tf, c) atol = 1e-6
            Test.@test xl ≈ _xc(x0, p0, tf, c) atol = 1e-6
        end

        Test.@testset "Constrained :partial error: non-:path label rejected" begin
            law = Data.DynClosedLoop((x, p) -> p)
            Test.@test_throws Exceptions.IncorrectArgument Flows.Flow(
                OCP_LQR_C,
                law;
                constraint=:bnd,
                multiplier=(x, p) -> 0.0,
                hamiltonian_type=:partial,
                _opts()...,
            )
        end

        Test.@testset "Constrained :partial error: constraint without multiplier" begin
            law = Data.DynClosedLoop((x, p) -> p)
            Test.@test_throws Exceptions.IncorrectArgument Flows.Flow(
                OCP_LQR,
                law;
                constraint=Data.StateConstraint(x -> x),
                hamiltonian_type=:partial,
                _opts()...,
            )
        end

        Test.@testset "Control-free OCP with constraint/multiplier is rejected" begin
            # constrained flows are only defined with a control law (no control-free case)
            Test.@test_throws Exceptions.PreconditionError Flows.Flow(
                OCP_CF;
                constraint=Data.StateConstraint(x -> x),
                multiplier=Data.Multiplier((x, p) -> 0.0),
            )
            Test.@test_throws Exceptions.PreconditionError Flows.Flow(
                OCP_CF; multiplier=Data.Multiplier((x, p) -> 0.0)
            )
        end

        Test.@testset "Constrained error: unsupported constraint spec type" begin
            law = Data.DynClosedLoop((x, p) -> p)
            Test.@test_throws Exceptions.IncorrectArgument Flows.Flow(
                OCP_LQR, law; constraint=42, multiplier=(x, p) -> 0.0, _opts()...
            )
        end

        # ====================================================================
        # Multiple simultaneous constraints (tuples)
        # ====================================================================

        Test.@testset "Constrained: tuple of constraints ≡ combined vector (both modes)" begin
            # A tuple (g₁,g₂)/(μ₁,μ₂) must give the same flow as a single vector-valued
            # constraint/multiplier — the combined carrier just concatenates.
            law = Data.DynClosedLoop((x, p) -> p[2])
            t0, tf, x0, p0 = 0.0, 1.0, [1.0, 2.0], [0.5, 0.5]
            g1(x, u) = x[1]
            g2(x, u) = x[2]
            μ1(x, p) = 0.3
            μ2(x, p) = 0.7
            for ht in (:total, :partial)
                f_tuple = Flows.Flow(
                    OCP_DI, law; constraint=(g1, g2), multiplier=(μ1, μ2),
                    hamiltonian_type=ht, _opts()...,
                )
                f_vec = Flows.Flow(
                    OCP_DI, law; constraint=(x, u) -> [x[1], x[2]],
                    multiplier=(x, p) -> [0.3, 0.7], hamiltonian_type=ht, _opts()...,
                )
                xt, pt = f_tuple(t0, x0, p0, tf)
                xv, pv = f_vec(t0, x0, p0, tf)
                Test.@test xt ≈ xv atol = ATOL
                Test.@test pt ≈ pv atol = ATOL
            end
        end

        Test.@testset "Constrained: tuple length mismatch / tuple-scalar mix rejected" begin
            law = Data.DynClosedLoop((x, p) -> p[2])
            # matched-length requirement: 2 constraints, 1 multiplier
            Test.@test_throws Exceptions.IncorrectArgument Flows.Flow(
                OCP_DI, law; constraint=((x, u) -> x[1], (x, u) -> x[2]),
                multiplier=((x, p) -> 0.3,), _opts()...,
            )
            # both-must-be-tuples: tuple constraint, scalar multiplier
            Test.@test_throws Exceptions.IncorrectArgument Flows.Flow(
                OCP_DI, law; constraint=((x, u) -> x[1],), multiplier=(x, p) -> 0.3, _opts()...,
            )
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
