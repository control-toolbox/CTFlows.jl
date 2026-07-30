"""
Unit tests for OCPPseudoHamiltonianFunction and _ocp_pseudo_hamiltonian.

Mirrors test_ocp_hamiltonian.jl for the with-control pseudo-Hamiltonian
`H̃(t,x,p,u,v) = p·f(t,x,u,v) + sp0·ℓ(t,x,u,v)`: the four natural-arity call methods,
criterion sign (min ⇒ sp0=-1, max ⇒ sp0=+1), the `lagrange === nothing` branch,
scalar vs vector inputs, and the `_ocp_pseudo_hamiltonian` builder.

No AD extensions required — pure callable evaluation.
"""

module TestOCPPseudoHamiltonianFunction

using Test: Test
using CTModels: CTModels
using CTFlows: Flows
using CTBase: Traits
using CTBase: Data

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

# =============================================================================
# Shared dynamics (with control) and cost — module top-level
# =============================================================================

const λ_TEST = 2.0

# f(t,x,u,v) for each (TD, VD); all depend on the control u
_dyn_af!(r, _, x, u, _) = (r[1]=λ_TEST * x[1] + u[1]; nothing)
_dyn_naf!(r, t, x, u, _) = (r[1]=t * x[1] + u[1]; nothing)
_dyn_anf!(r, _, x, u, v) = (r[1]=v[1] * x[1] + u[1]; nothing)
_dyn_nanf!(r, t, x, u, v) = (r[1]=t * v[1] * x[1] + u[1]; nothing)

# ℓ(t,x,u,v) — depends on both x and u
_lag(_, x, u, _) = x[1]^2 + u[1]^2

const _AU = CTModels.Components.Autonomous
const _NA = CTModels.Components.NonAutonomous

# =============================================================================
# OCPPseudoHamiltonianFunction fixtures (module top-level)
# =============================================================================

const HT_AF_NL = Flows.OCPPseudoHamiltonianFunction{
    _AU,Traits.Fixed,typeof(_dyn_af!),Nothing
}(
    _dyn_af!, nothing, -1.0, 1
)
const HT_AF_LAG_MIN = Flows.OCPPseudoHamiltonianFunction{
    _AU,Traits.Fixed,typeof(_dyn_af!),typeof(_lag)
}(
    _dyn_af!, _lag, -1.0, 1
)
const HT_AF_LAG_MAX = Flows.OCPPseudoHamiltonianFunction{
    _AU,Traits.Fixed,typeof(_dyn_af!),typeof(_lag)
}(
    _dyn_af!, _lag, +1.0, 1
)
const HT_NAF_NL = Flows.OCPPseudoHamiltonianFunction{
    _NA,Traits.Fixed,typeof(_dyn_naf!),Nothing
}(
    _dyn_naf!, nothing, -1.0, 1
)
const HT_ANF_NL = Flows.OCPPseudoHamiltonianFunction{
    _AU,Traits.NonFixed,typeof(_dyn_anf!),Nothing
}(
    _dyn_anf!, nothing, -1.0, 1
)
const HT_NANF_NL = Flows.OCPPseudoHamiltonianFunction{
    _NA,Traits.NonFixed,typeof(_dyn_nanf!),Nothing
}(
    _dyn_nanf!, nothing, -1.0, 1
)

# =============================================================================
# OCP fixtures for _ocp_pseudo_hamiltonian
# =============================================================================

function _build_ocp(criterion; autonomous=true, variable=false, lagrange=nothing)
    pre = CTModels.Building.PreModel()
    CTModels.Building.time_dependence!(pre; autonomous=autonomous)
    CTModels.Building.time!(pre; t0=0.0, tf=1.0)
    CTModels.Building.state!(pre, 1)
    CTModels.Building.control!(pre, 1)
    variable && CTModels.Building.variable!(pre, 1)
    CTModels.Building.dynamics!(pre, (r, t, x, u, v) -> (r[1]=x[1] + u[1]; nothing))
    if lagrange === nothing
        CTModels.Building.objective!(pre, criterion; mayer=(x0, xf, v) -> xf[1])
    else
        CTModels.Building.objective!(pre, criterion; lagrange=lagrange)
    end
    return CTModels.Building.build(pre)
end

const OCP_MIN_LAG = _build_ocp(:min; lagrange=(t, x, u, v) -> 0.5 * u[1]^2)
const OCP_MAX_LAG = _build_ocp(:max; lagrange=(t, x, u, v) -> 0.5 * u[1]^2)
const OCP_MIN_MAYER = _build_ocp(:min)
const OCP_NANF = _build_ocp(
    :min; autonomous=false, variable=true, lagrange=(t, x, u, v) -> u[1]^2
)

function test_ocp_pseudo_hamiltonian()
    Test.@testset "OCP PseudoHamiltonian Function" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ── call methods, all four (TD, VD) arities ──────────────────────────

        Test.@testset "Unit: Auton/Fixed (x,p,u) — no lagrange" begin
            x = [2.0]
            p = [3.0]
            u = [4.0]
            Test.@test HT_AF_NL(x, p, u) ≈ p[1] * (λ_TEST * x[1] + u[1])
        end

        Test.@testset "Unit: NonAuton/Fixed (t,x,p,u)" begin
            t = 2.0
            x = [3.0]
            p = [5.0]
            u = [1.5]
            Test.@test HT_NAF_NL(t, x, p, u) ≈ p[1] * (t * x[1] + u[1])
        end

        Test.@testset "Unit: Auton/NonFixed (x,p,u,v)" begin
            x = [2.0]
            p = [3.0]
            u = [1.0]
            v = [4.0]
            Test.@test HT_ANF_NL(x, p, u, v) ≈ p[1] * (v[1] * x[1] + u[1])
        end

        Test.@testset "Unit: NonAuton/NonFixed (t,x,p,u,v)" begin
            t = 2.0
            x = [3.0]
            p = [5.0]
            u = [1.0]
            v = [4.0]
            Test.@test HT_NANF_NL(t, x, p, u, v) ≈ p[1] * (t * v[1] * x[1] + u[1])
        end

        # ── criterion sign (min ⇒ sp0=-1, max ⇒ sp0=+1) ──────────────────────

        Test.@testset "Unit: min criterion ⇒ sp0 = -1" begin
            x = [2.0]
            p = [3.0]
            u = [4.0]
            Test.@test HT_AF_LAG_MIN(x, p, u) ≈
                p[1] * (λ_TEST * x[1] + u[1]) - (x[1]^2 + u[1]^2)
        end

        Test.@testset "Unit: max criterion ⇒ sp0 = +1" begin
            x = [2.0]
            p = [3.0]
            u = [4.0]
            Test.@test HT_AF_LAG_MAX(x, p, u) ≈
                p[1] * (λ_TEST * x[1] + u[1]) + (x[1]^2 + u[1]^2)
        end

        Test.@testset "Unit: lagrange === nothing ⇒ H̃ = p·f exactly" begin
            x = [1.5]
            p = [2.5]
            u = [0.5]
            Test.@test HT_AF_NL(x, p, u) == p[1] * (λ_TEST * x[1] + u[1])
        end

        # ── scalar vs vector inputs (n_x=1) ──────────────────────────────────

        Test.@testset "Unit: scalar x,p,u give same result as 1-vectors" begin
            Test.@test HT_AF_LAG_MIN(2.0, 3.0, 4.0) ≈ HT_AF_LAG_MIN([2.0], [3.0], [4.0])
        end

        Test.@testset "Unit: scalar x,p,u,v give same result as 1-vectors (NonFixed)" begin
            Test.@test HT_ANF_NL(2.0, 3.0, 1.0, 4.0) ≈ HT_ANF_NL([2.0], [3.0], [1.0], [4.0])
        end

        # ── _ocp_pseudo_hamiltonian builder ──────────────────────────────────

        Test.@testset "Unit: _ocp_pseudo_hamiltonian returns a Data.PseudoHamiltonian" begin
            h̃ = Flows._ocp_pseudo_hamiltonian(OCP_MIN_LAG)
            Test.@test h̃ isa Data.PseudoHamiltonian
            Test.@test h̃ isa Data.AbstractPseudoHamiltonian{
                CTModels.Components.Autonomous,Traits.Fixed
            }
        end

        Test.@testset "Unit: _ocp_pseudo_hamiltonian TD/VD match OCP (NonAuton/NonFixed)" begin
            h̃ = Flows._ocp_pseudo_hamiltonian(OCP_NANF)
            Test.@test h̃ isa Data.AbstractPseudoHamiltonian{
                CTModels.Components.NonAutonomous,Traits.NonFixed
            }
        end

        Test.@testset "Unit: _ocp_pseudo_hamiltonian min vs max sp0" begin
            h̃_min = Flows._ocp_pseudo_hamiltonian(OCP_MIN_LAG)
            h̃_max = Flows._ocp_pseudo_hamiltonian(OCP_MAX_LAG)
            # f(x,u)=x+u, ℓ=0.5u² ; H̃ = p(x+u) + sp0·0.5u²
            x = [2.0]
            p = [0.0]
            u = [3.0]   # p=0 isolates the sp0·ℓ term
            Test.@test h̃_min(x, p, u) ≈ -0.5 * u[1]^2
            Test.@test h̃_max(x, p, u) ≈ +0.5 * u[1]^2
        end

        Test.@testset "Unit: _ocp_pseudo_hamiltonian without lagrange ⇒ H̃ = p·f" begin
            h̃ = Flows._ocp_pseudo_hamiltonian(OCP_MIN_MAYER)   # Mayer only, no lagrange
            x = [2.0]
            p = [3.0]
            u = [4.0]
            Test.@test h̃(x, p, u) ≈ p[1] * (x[1] + u[1])   # f(x,u)=x+u, no running cost
        end

        # ── ComposedHamiltonian from an OCP (the :total Hamiltonian value) ────

        Test.@testset "Unit: ComposedHamiltonian from OCP — :total Hamiltonian value (min)" begin
            # OCP_MIN_LAG: f(x,u)=x+u, ℓ=0.5u², :min ⇒ H̃(x,p,u)=p(x+u)-0.5u²
            # law u(x,p)=-p ⇒ H(x,p)=H̃(x,p,-p)=p(x-p)-0.5p²
            h̃ = Flows._ocp_pseudo_hamiltonian(OCP_MIN_LAG)
            law = Data.DynClosedLoop((x, p) -> -p)
            H = Data.ComposedHamiltonian(h̃, law)
            Test.@test H isa Data.AbstractHamiltonian
            x = [2.0]
            p = [3.0]
            Test.@test H(x, p) ≈ p[1] * (x[1] - p[1]) - 0.5 * p[1]^2
        end

        Test.@testset "Unit: ComposedHamiltonian from OCP — sign flips with :max" begin
            # OCP_MAX_LAG: same f, ℓ, but :max ⇒ H̃=p(x+u)+0.5u² ; H(x,p)=p(x-p)+0.5p²
            h̃ = Flows._ocp_pseudo_hamiltonian(OCP_MAX_LAG)
            law = Data.DynClosedLoop((x, p) -> -p)
            H = Data.ComposedHamiltonian(h̃, law)
            x = [2.0]
            p = [3.0]
            Test.@test H(x, p) ≈ p[1] * (x[1] - p[1]) + 0.5 * p[1]^2
        end

        Test.@testset "Unit: ComposedHamiltonian from OCP — NonAuton/NonFixed value" begin
            # OCP_NANF: f(x,u)=x+u (autonomous dynamics but declared NonAuton/NonFixed),
            # ℓ=u², :min ⇒ H̃(t,x,p,u,v)=p(x+u)-u² ; law u(t,x,p,v)=v·p
            h̃ = Flows._ocp_pseudo_hamiltonian(OCP_NANF)
            law = Data.DynClosedLoop(
                (t, x, p, v) -> v[1] * p; is_autonomous=false, is_variable=true
            )
            H = Data.ComposedHamiltonian(h̃, law)
            t = 0.7
            x = [2.0]
            p = [3.0]
            v = [1.5]
            u = v[1] * p[1]
            Test.@test H(t, x, p, v) ≈ p[1] * (x[1] + u) - u^2
        end
    end
end

end # module

function test_ocp_pseudo_hamiltonian()
    return TestOCPPseudoHamiltonianFunction.test_ocp_pseudo_hamiltonian()
end
