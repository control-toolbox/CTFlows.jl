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
using OrdinaryDiffEqTsit5: Tsit5
using ForwardDiff: ForwardDiff  # triggers the DI ForwardDiff extension (AutoForwardDiff)

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

const ATOL = 1e-8
_opts() = (; alg = Tsit5(), reltol = 1e-12, abstol = 1e-12)

# =============================================================================
# OCP fixtures at module top-level
# =============================================================================

# scalar LQR: ẋ = -x + u, ℓ = 0.5u², :min  (autonomous, fixed)
function _build_lqr()
    pre = CTModels.Building.PreModel()
    CTModels.Building.time_dependence!(pre; autonomous = true)
    CTModels.Building.time!(pre; t0 = 0.0, tf = 1.0)
    CTModels.Building.state!(pre, 1)
    CTModels.Building.control!(pre, 1)
    CTModels.Building.dynamics!(pre, (r, t, x, u, v) -> (r[1] = -x[1] + u[1]; nothing))
    CTModels.Building.objective!(pre, :min; lagrange = (t, x, u, v) -> 0.5 * u[1]^2)
    return CTModels.Building.build(pre)
end

# double integrator energy: ẋ = [x₂, u], ℓ = 0.5u², :min  (autonomous, fixed)
function _build_double_integrator()
    pre = CTModels.Building.PreModel()
    CTModels.Building.time_dependence!(pre; autonomous = true)
    CTModels.Building.time!(pre; t0 = 0.0, tf = 1.0)
    CTModels.Building.state!(pre, 2)
    CTModels.Building.control!(pre, 1)
    CTModels.Building.dynamics!(pre, (r, t, x, u, v) -> (r .= [x[2], u[1]]; nothing))
    CTModels.Building.objective!(pre, :min; lagrange = (t, x, u, v) -> 0.5 * u[1]^2)
    return CTModels.Building.build(pre)
end

# non-autonomous: ẋ = u(1 + tan t), ℓ = 0.5u², :min  (non-autonomous, fixed)
function _build_nonauton()
    pre = CTModels.Building.PreModel()
    CTModels.Building.time_dependence!(pre; autonomous = false)
    CTModels.Building.time!(pre; t0 = 0.0, tf = π / 4)
    CTModels.Building.state!(pre, 1)
    CTModels.Building.control!(pre, 1)
    CTModels.Building.dynamics!(
        pre,
        (r, t, x, u, v) -> (r[1] = u[1] * (1 + tan(t)); nothing),
    )
    CTModels.Building.objective!(pre, :min; lagrange = (t, x, u, v) -> 0.5 * u[1]^2)
    return CTModels.Building.build(pre)
end

# control-free OCP (for the guard test)
function _build_control_free()
    pre = CTModels.Building.PreModel()
    CTModels.Building.time_dependence!(pre; autonomous = true)
    CTModels.Building.time!(pre; t0 = 0.0, tf = 1.0)
    CTModels.Building.state!(pre, 1)
    CTModels.Building.dynamics!(pre, (r, t, x, u, v) -> (r[1] = x[1]; nothing))
    CTModels.Building.objective!(pre, :min; lagrange = (t, x, u, v) -> x[1]^2)
    return CTModels.Building.build(pre)
end

const OCP_LQR = _build_lqr()
const OCP_DI = _build_double_integrator()
const OCP_NA = _build_nonauton()
const OCP_CF = _build_control_free()

function test_ocp_control()
    Test.@testset "OCP control flows" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ====================================================================
        # INTEGRATION — scalar LQR, stationary law u = p (:min ⇒ ∂H̃/∂u = p - u)
        # ====================================================================

        Test.@testset "Integration: LQR — :total and :partial agree (stationary)" begin
            law = Data.DynClosedLoop((x, p) -> p)
            ft = Flows.Flow(OCP_LQR, law; hamiltonian_type = :total, _opts()...)
            fp = Flows.Flow(OCP_LQR, law; hamiltonian_type = :partial, _opts()...)
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

            fp = Flows.Flow(OCP_DI, law; hamiltonian_type = :partial, _opts()...)
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
            ft = Flows.Flow(OCP_DI, law; hamiltonian_type = :total, _opts()...)
            fp = Flows.Flow(OCP_DI, law; hamiltonian_type = :partial, _opts()...)
            t0, tf, x0, p0 = 0.0, 1.0, [-1.0, 0.0], [12.0, 6.0]
            xt, pt = ft(t0, x0, p0, tf)
            xp, pp = fp(t0, x0, p0, tf)
            Test.@test !isapprox(xt, xp; atol = 1e-4)   # genuinely different flows
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
            fp = Flows.Flow(OCP_DI, law; hamiltonian_type = :partial, _opts()...)
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
            ft = Flows.Flow(h̃, law; hamiltonian_type = :total, _opts()...)
            fp = Flows.Flow(h̃, law; hamiltonian_type = :partial, _opts()...)
            t0, tf, x0, p0 = 0.0, 1.0, 1.0, 0.5
            Test.@test all(isapprox.(ft(t0, x0, p0, tf), fp(t0, x0, p0, tf); atol = ATOL))
            # costate ṗ = -∂H̃/∂x = p ⇒ p(tf) = p0 e^{tf}
            _, pf = ft(t0, x0, p0, tf)
            Test.@test pf ≈ p0 * exp(tf) atol = 1e-6
        end

        # ====================================================================
        # ERROR paths
        # ====================================================================

        Test.@testset "Error: invalid hamiltonian_type" begin
            law = Data.DynClosedLoop((x, p) -> p)
            Test.@test_throws Exceptions.IncorrectArgument Flows.Flow(
                OCP_LQR,
                law;
                hamiltonian_type = :foo,
                _opts()...,
            )
        end

        Test.@testset "Error: control-free OCP with a law" begin
            law = Data.DynClosedLoop((x, p) -> p)
            Test.@test_throws Exceptions.PreconditionError Flows.Flow(
                OCP_CF,
                law;
                _opts()...,
            )
        end

        Test.@testset "Error: OpenLoop/ClosedLoop law into Flow(ocp, law) → NotImplemented" begin
            Test.@test_throws Exceptions.NotImplemented Flows.Flow(
                OCP_LQR,
                Data.ClosedLoop(x -> -x[1]);
                _opts()...,
            )
        end

        Test.@testset "Error: OpenLoop law into Flow(h̃, law) → PreconditionError" begin
            h̃ = Data.PseudoHamiltonian((x, p, u) -> p * u)
            Test.@test_throws Exceptions.PreconditionError Flows.Flow(
                h̃,
                Data.OpenLoop(() -> 1.0);
                _opts()...,
            )
        end
    end
end

end # module

test_ocp_control() = TestOCPControl.test_ocp_control()
