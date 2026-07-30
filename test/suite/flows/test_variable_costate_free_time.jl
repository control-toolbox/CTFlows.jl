"""
Variable-costate with free times (issues #231, #183).

The flow always integrates the **naive** augmented adjoint `ṗv = -∂H/∂v` with
`pv(t0) = 0`, uniformly, for any variable — time or not. When the variable is a
free time, the boundary term is a **mitigated transversality condition** written in
the shooting method, not computed by the flow (issue #231):

    p_{t0}(tf) = -H(t0, x0, p0, v),   p_{tf}(tf) = H(tf, xf, pf, v).

These tests exercise the mechanism at the raw Hamiltonian-flow level (the level the
documented indirect free-time shooting uses, e.g. Goddard): the augmented `pvf`, the
`hamiltonian(flow)` getter used to form the transversality residual, the eval-time ≠
variable-value distinction (#183), and 2-D (t0, tf) variables. Analytic references,
autonomous / NonFixed Hamiltonians.
"""

module TestVariableCostateFreeTime

using Test: Test
using CTBase: Data
using CTBase: Traits
using CTBase: Exceptions
using CTFlows: Flows
using CTFlows: Systems
using OrdinaryDiffEqTsit5: Tsit5
using ForwardDiff: ForwardDiff  # triggers the DI ForwardDiff extension (AutoForwardDiff)

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true
const ATOL = 1e-6

# Autonomous, variable Hamiltonians (natural signature (x, p, v)).
# H0: does NOT depend on v (the free time is the endpoint only) ⇒ ∂H/∂v = 0.
const H_INDEP = Data.Hamiltonian((x, p, v) -> p^2 / 2; is_variable=true)
# H1: depends on the scalar variable v ⇒ ∂H/∂v = p²/2.
const H_SCALED = Data.Hamiltonian((x, p, v) -> v * p^2 / 2; is_variable=true)
# H2: 2-D variable, depends on v[1] only ⇒ ∂H/∂v = (p, 0).
const H_2VAR = Data.Hamiltonian((x, p, v) -> v[1] * p; is_variable=true)
# H3: linear in p, scaled by v (v plays t0) ⇒ ∂H/∂v = p.
const H_T0 = Data.Hamiltonian((x, p, v) -> v * p; is_variable=true)
# H4: 2-D variable, v[1] plays t0 (linear term) and v[2] plays tf (quadratic term)
# ⇒ ∂H/∂v = (p, p²/2).
const H_T0TF = Data.Hamiltonian((x, p, v) -> v[1] * p + v[2] * p^2 / 2; is_variable=true)

function test_variable_costate_free_time()
    Test.@testset "variable_costate — free times" verbose=VERBOSE showtiming=SHOWTIMING begin

        # =====================================================================
        # H independent of the time-variable ⇒ pvf = 0, transversality ⇒ H(tf)=0
        # =====================================================================

        Test.@testset "Free tf, H⊥v: pvf ≈ 0 and transversality reduces to H(tf)" begin
            φ = Flows.Flow(H_INDEP; alg=Tsit5())
            t0, tf, x0, p0, v = 0.0, 2.0, 1.0, 0.5, 2.0   # v plays the role of tf
            xf, pf, pvf = φ(t0, x0, p0, tf; variable=v, variable_costate=true)
            # ẋ = p, ṗ = 0 ⇒ x(t) = x0 + p0(t-t0), p ≡ p0
            Test.@test xf ≈ x0 + p0 * (tf - t0) atol=ATOL
            Test.@test pf ≈ p0 atol=ATOL
            # ∂H/∂v = 0 ⇒ pvf = 0
            Test.@test pvf ≈ 0.0 atol=ATOL
            # mitigated transversality residual p_{tf}(tf) - H(tf) reduces to -H(tf)
            H = Systems.hamiltonian(φ)
            res = pvf - H(tf, xf, pf, v)
            Test.@test res ≈ -pf^2 / 2 atol=ATOL
        end

        # =====================================================================
        # H depends on the variable ⇒ non-zero pvf, analytic reference
        # =====================================================================

        Test.@testset "Variable-dependent H: pvf = -(p0²/2)(tf-t0)" begin
            φ = Flows.Flow(H_SCALED; alg=Tsit5())
            t0, tf, x0, p0, v = 0.0, 2.0, 1.0, 0.5, 0.7
            xf, pf, pvf = φ(t0, x0, p0, tf; variable=v, variable_costate=true)
            # ẋ = v·p, ṗ = 0 ⇒ x(t) = x0 + v·p0(t-t0)
            Test.@test xf ≈ x0 + v * p0 * (tf - t0) atol=ATOL
            Test.@test pf ≈ p0 atol=ATOL
            # ∂H/∂v = p²/2 = p0²/2 (const) ⇒ pvf = -(p0²/2)(tf-t0)
            Test.@test pvf ≈ -(p0^2 / 2) * (tf - t0) atol=ATOL
        end

        # =====================================================================
        # #183 — evaluation time t1 may differ from the variable value tf
        # =====================================================================

        Test.@testset "#183: eval time t1 ≠ variable value tf is accepted" begin
            φ = Flows.Flow(H_SCALED; alg=Tsit5())
            t0, x0, p0 = 0.0, 1.0, 0.5
            t1, tf = 1.3, 2.0                      # positional eval time ≠ variable value
            xf, pf, pvf = φ(t0, x0, p0, t1; variable=tf, variable_costate=true)
            # integration runs to t1, with the Hamiltonian scaled by the variable tf
            Test.@test xf ≈ x0 + tf * p0 * (t1 - t0) atol=ATOL
            Test.@test pf ≈ p0 atol=ATOL
            Test.@test pvf ≈ -(p0^2 / 2) * (t1 - t0) atol=ATOL
        end

        # =====================================================================
        # 2-D variable (t0, tf) — vector variable costate
        # =====================================================================

        Test.@testset "2-D variable: pvf = [-p0(tf-t0), 0]" begin
            φ = Flows.Flow(H_2VAR; alg=Tsit5())
            t0, tf, x0, p0 = 0.0, 2.0, 1.0, 0.5
            v = [0.7, 0.3]
            xf, pf, pvf = φ(t0, x0, p0, tf; variable=v, variable_costate=true)
            # ẋ = v[1], ṗ = 0 ⇒ x(t) = x0 + v[1](t-t0)
            Test.@test xf ≈ x0 + v[1] * (tf - t0) atol=ATOL
            Test.@test pf ≈ p0 atol=ATOL
            # ∂H/∂v = (p, 0) ⇒ pvf = (-p0(tf-t0), 0)
            Test.@test pvf isa AbstractVector && length(pvf) == 2
            Test.@test pvf[1] ≈ -p0 * (tf - t0) atol=ATOL
            Test.@test pvf[2] ≈ 0.0 atol=ATOL
        end

        # =====================================================================
        # Free t0 — same mechanism, transversality residual evaluated at t0
        # (asymmetric sign vs. the free-tf case: p_{t0}(tf) = -H(t0, x0, p0, v))
        # =====================================================================

        Test.@testset "Free t0: pvf = -p0(tf-t0)" begin
            φ = Flows.Flow(H_T0; alg=Tsit5())
            t0, tf, x0, p0 = 0.3, 2.0, 1.0, 0.5
            v = t0                                  # v plays the role of t0
            xf, pf, pvf = φ(t0, x0, p0, tf; variable=v, variable_costate=true)
            # ẋ = v, ṗ = 0 ⇒ x(t) = x0 + v(t-t0), p ≡ p0
            Test.@test xf ≈ x0 + v * (tf - t0) atol=ATOL
            Test.@test pf ≈ p0 atol=ATOL
            # ∂H/∂v = p = p0 (const) ⇒ pvf = -p0(tf-t0)
            Test.@test pvf ≈ -p0 * (tf - t0) atol=ATOL
            # mitigated transversality residual: p_{t0}(tf) = -H(t0,x0,p0,v)
            H = Systems.hamiltonian(φ)
            res = pvf + H(t0, x0, p0, v)
            Test.@test res ≈ -p0 * (tf - t0) + v * p0 atol=ATOL
        end

        # =====================================================================
        # Both t0 and tf free — 2-D variable, one residual per endpoint, with
        # opposite signs (p_{t0}(tf) = -H(t0,…), p_{tf}(tf) = H(tf,…))
        # =====================================================================

        Test.@testset "2-D (t0,tf) free: one transversality residual per endpoint" begin
            φ = Flows.Flow(H_T0TF; alg=Tsit5())
            t0, tf, x0, p0 = 0.3, 2.0, 1.0, 0.5
            v = [t0, tf]                            # v[1] plays t0, v[2] plays tf
            xf, pf, pvf = φ(t0, x0, p0, tf; variable=v, variable_costate=true)
            # ẋ = v[1] + v[2]·p, ṗ = 0 ⇒ x(t) = x0 + (v[1]+v[2]p0)(t-t0)
            Test.@test xf ≈ x0 + (v[1] + v[2] * p0) * (tf - t0) atol=ATOL
            Test.@test pf ≈ p0 atol=ATOL
            # ∂H/∂v = (p, p²/2) ⇒ pvf = (-p0(tf-t0), -(p0²/2)(tf-t0))
            Test.@test pvf isa AbstractVector && length(pvf) == 2
            Test.@test pvf[1] ≈ -p0 * (tf - t0) atol=ATOL
            Test.@test pvf[2] ≈ -(p0^2 / 2) * (tf - t0) atol=ATOL
            # one residual per endpoint, opposite sign convention
            H = Systems.hamiltonian(φ)
            res_t0 = pvf[1] + H(t0, x0, p0, v)
            res_tf = pvf[2] - H(tf, xf, pf, v)
            Hval = v[1] * p0 + v[2] * p0^2 / 2   # H doesn't depend on (t,x) ⇒ same at t0/tf
            Test.@test res_t0 ≈ -p0 * (tf - t0) + Hval atol=ATOL
            Test.@test res_tf ≈ -(p0^2 / 2) * (tf - t0) - Hval atol=ATOL
        end
    end
end

end # module TestVariableCostateFreeTime

# Redefine in the outer scope so the runner can call it
function test_variable_costate_free_time()
    return TestVariableCostateFreeTime.test_variable_costate_free_time()
end
