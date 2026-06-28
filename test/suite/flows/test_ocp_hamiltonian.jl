"""
Unit tests for OCPHamiltonianFunction and _ocp_hamiltonian.

Tests the four natural-arity call methods (Auton/Fixed, NonAuton/Fixed,
Auton/NonFixed, NonAuton/NonFixed), criterion sign, lagrange === nothing branch,
scalar vs vector inputs, and the _ocp_hamiltonian builder.

No AD extensions required — pure callable evaluation.
"""

module TestOCPHamiltonianFunction

using Test: Test
using CTModels: CTModels
import CTFlows.Flows: Flows
import CTBase.Traits: Traits
import CTBase.Data: Data

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

# =============================================================================
# Shared dynamics (module top-level)
# =============================================================================

const λ_TEST = 2.0

_dyn_auton_fixed!(r, _, x, _, _) = (r[1]=λ_TEST * x[1]; nothing)
_dyn_nonauton_fixed!(r, t, x, _, _) = (r[1]=t * x[1]; nothing)
_dyn_auton_nf!(r, _, x, _, v) = (r[1]=v[1] * x[1]; nothing)
_dyn_nonauton_nf!(r, t, x, _, v) = (r[1]=t * v[1] * x[1]; nothing)

_lagrange(_, x, _, _) = x[1]^2

# =============================================================================
# OCPHamiltonianFunction fixtures (module top-level)
# =============================================================================

const _AU = CTModels.Components.Autonomous
const _NA = CTModels.Components.NonAutonomous

const H_AF_NL = Flows.OCPHamiltonianFunction{
    _AU,Traits.Fixed,typeof(_dyn_auton_fixed!),Nothing
}(
    _dyn_auton_fixed!, nothing, -1.0, 1
)

const H_AF_LAG = Flows.OCPHamiltonianFunction{
    _AU,Traits.Fixed,typeof(_dyn_auton_fixed!),typeof(_lagrange)
}(
    _dyn_auton_fixed!, _lagrange, -1.0, 1
)

const H_AF_LAG_MAX = Flows.OCPHamiltonianFunction{
    _AU,Traits.Fixed,typeof(_dyn_auton_fixed!),typeof(_lagrange)
}(
    _dyn_auton_fixed!, _lagrange, +1.0, 1
)

const H_NAF_NL = Flows.OCPHamiltonianFunction{
    _NA,Traits.Fixed,typeof(_dyn_nonauton_fixed!),Nothing
}(
    _dyn_nonauton_fixed!, nothing, -1.0, 1
)

const H_ANF_NL = Flows.OCPHamiltonianFunction{
    _AU,Traits.NonFixed,typeof(_dyn_auton_nf!),Nothing
}(
    _dyn_auton_nf!, nothing, -1.0, 1
)

const H_NANF_NL = Flows.OCPHamiltonianFunction{
    _NA,Traits.NonFixed,typeof(_dyn_nonauton_nf!),Nothing
}(
    _dyn_nonauton_nf!, nothing, -1.0, 1
)

# =============================================================================
# OCP fixtures for _ocp_hamiltonian
# =============================================================================

function _build_ocp_auton_fixed_mayer()
    pre = CTModels.Building.PreModel()
    CTModels.Building.time_dependence!(pre; autonomous=true)
    CTModels.Building.time!(pre; t0=0.0, tf=1.0)
    CTModels.Building.state!(pre, 1)
    CTModels.Building.dynamics!(pre, _dyn_auton_fixed!)
    CTModels.Building.objective!(pre, :min; mayer=(x0, xf, v) -> xf[1])
    return CTModels.Building.build(pre)
end

function _build_ocp_auton_fixed_lagrange_min()
    pre = CTModels.Building.PreModel()
    CTModels.Building.time_dependence!(pre; autonomous=true)
    CTModels.Building.time!(pre; t0=0.0, tf=1.0)
    CTModels.Building.state!(pre, 1)
    CTModels.Building.dynamics!(pre, _dyn_auton_fixed!)
    CTModels.Building.objective!(pre, :min; lagrange=_lagrange)
    return CTModels.Building.build(pre)
end

function _build_ocp_auton_fixed_lagrange_max()
    pre = CTModels.Building.PreModel()
    CTModels.Building.time_dependence!(pre; autonomous=true)
    CTModels.Building.time!(pre; t0=0.0, tf=1.0)
    CTModels.Building.state!(pre, 1)
    CTModels.Building.dynamics!(pre, _dyn_auton_fixed!)
    CTModels.Building.objective!(pre, :max; lagrange=_lagrange)
    return CTModels.Building.build(pre)
end

function _build_ocp_nonauton_nonfixed_mayer()
    pre = CTModels.Building.PreModel()
    CTModels.Building.time_dependence!(pre; autonomous=false)
    CTModels.Building.time!(pre; t0=0.0, tf=1.0)
    CTModels.Building.state!(pre, 1)
    CTModels.Building.variable!(pre, 1)
    CTModels.Building.dynamics!(pre, _dyn_nonauton_nf!)
    CTModels.Building.objective!(pre, :min; mayer=(x0, xf, v) -> xf[1])
    return CTModels.Building.build(pre)
end

const OCP_AF_MAYER = _build_ocp_auton_fixed_mayer()
const OCP_AF_LAG_MIN = _build_ocp_auton_fixed_lagrange_min()
const OCP_AF_LAG_MAX = _build_ocp_auton_fixed_lagrange_max()
const OCP_NANF_MAYER = _build_ocp_nonauton_nonfixed_mayer()

# =============================================================================

function test_ocp_hamiltonian()
    Test.@testset "OCP Hamiltonian Function" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ── call methods ──────────────────────────────────────────────────────

        Test.@testset "Unit: Auton/Fixed (x,p) — no lagrange" begin
            x = [2.0];
            p = [3.0]
            val = H_AF_NL(x, p)
            Test.@test val ≈ p[1] * λ_TEST * x[1]
        end

        Test.@testset "Unit: Auton/Fixed (x,p) — with lagrange (min, sp0=-1)" begin
            x = [2.0];
            p = [3.0]
            expected = p[1] * λ_TEST * x[1] + (-1.0) * x[1]^2
            Test.@test H_AF_LAG(x, p) ≈ expected
        end

        Test.@testset "Unit: Auton/Fixed (x,p) — with lagrange (max, sp0=+1)" begin
            x = [2.0];
            p = [3.0]
            expected = p[1] * λ_TEST * x[1] + (+1.0) * x[1]^2
            Test.@test H_AF_LAG_MAX(x, p) ≈ expected
        end

        Test.@testset "Unit: NonAuton/Fixed (t,x,p)" begin
            t = 2.0;
            x = [3.0];
            p = [5.0]
            Test.@test H_NAF_NL(t, x, p) ≈ p[1] * t * x[1]
        end

        Test.@testset "Unit: Auton/NonFixed (x,p,v)" begin
            x = [2.0];
            p = [3.0];
            v = [4.0]
            Test.@test H_ANF_NL(x, p, v) ≈ p[1] * v[1] * x[1]
        end

        Test.@testset "Unit: NonAuton/NonFixed (t,x,p,v)" begin
            t = 2.0;
            x = [3.0];
            p = [5.0];
            v = [4.0]
            Test.@test H_NANF_NL(t, x, p, v) ≈ p[1] * t * v[1] * x[1]
        end

        # ── scalar inputs (n_x=1 — _asvec rewraps) ──────────────────────────

        Test.@testset "Unit: scalar x and p give same result as 1-vector" begin
            x_s = 2.0;
            p_s = 3.0
            x_v = [2.0];
            p_v = [3.0]
            Test.@test H_AF_NL(x_s, p_s) ≈ H_AF_NL(x_v, p_v)
        end

        Test.@testset "Unit: scalar x,p,v give same result as 1-vectors (NonFixed)" begin
            x_s = 2.0;
            p_s = 3.0;
            v_s = 4.0
            x_v = [2.0];
            p_v = [3.0];
            v_v = [4.0]
            Test.@test H_ANF_NL(x_s, p_s, v_s) ≈ H_ANF_NL(x_v, p_v, v_v)
        end

        # ── lagrange=nothing branch ───────────────────────────────────────────

        Test.@testset "Unit: lagrange=nothing → H = p·f exactly" begin
            x = [1.5];
            p = [2.5]
            Test.@test H_AF_NL(x, p) == p[1] * λ_TEST * x[1]
        end

        # ── criterion sign ────────────────────────────────────────────────────

        Test.@testset "Unit: min criterion → sp0 = -1.0" begin
            x = [1.0];
            p = [0.0]
            Test.@test H_AF_LAG(x, p) ≈ -1.0 * x[1]^2
        end

        Test.@testset "Unit: max criterion → sp0 = +1.0" begin
            x = [1.0];
            p = [0.0]
            Test.@test H_AF_LAG_MAX(x, p) ≈ +1.0 * x[1]^2
        end

        # ── OCPHamiltonianFunction <: Function ────────────────────────────────────────

        Test.@testset "Unit: OCPHamiltonianFunction isa Function" begin
            Test.@test H_AF_NL isa Function
            Test.@test H_AF_LAG isa Function
            Test.@test H_NAF_NL isa Function
            Test.@test H_ANF_NL isa Function
            Test.@test H_NANF_NL isa Function
        end

        # ── _ocp_hamiltonian builder ──────────────────────────────────────────

        Test.@testset "Unit: _ocp_hamiltonian returns Data.Hamiltonian" begin
            h = Flows._ocp_hamiltonian(OCP_AF_MAYER)
            Test.@test h isa Data.Hamiltonian
        end

        Test.@testset "Unit: _ocp_hamiltonian TD/VD match OCP (Auton/Fixed)" begin
            h = Flows._ocp_hamiltonian(OCP_AF_MAYER)
            Test.@test h isa
                Data.AbstractHamiltonian{CTModels.Components.Autonomous,Traits.Fixed}
        end

        Test.@testset "Unit: _ocp_hamiltonian TD/VD match OCP (NonAuton/NonFixed)" begin
            h = Flows._ocp_hamiltonian(OCP_NANF_MAYER)
            Test.@test h isa Data.AbstractHamiltonian{
                CTModels.Components.NonAutonomous,Traits.NonFixed
            }
        end

        Test.@testset "Unit: _ocp_hamiltonian min vs max sp0" begin
            h_min = Flows._ocp_hamiltonian(OCP_AF_LAG_MIN)
            h_max = Flows._ocp_hamiltonian(OCP_AF_LAG_MAX)
            x = [2.0];
            p = [0.0]
            val_min = h_min.f(x, p)
            val_max = h_max.f(x, p)
            Test.@test val_min ≈ -1.0 * x[1]^2
            Test.@test val_max ≈ +1.0 * x[1]^2
        end
    end
end

end # module

test_ocp_hamiltonian() = TestOCPHamiltonianFunction.test_ocp_hamiltonian()
