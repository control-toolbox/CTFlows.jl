"""
`Flow(ocp, law; multipliers=:label => y)` adjoins the constraint from its bounds,
with `y` the dual of the solution (issue #440, control-toolbox/CTModels.jl#536).

The model stores `lb ≤ c(t,x,u,v) ≤ ub`; the term adjoined to the pseudo-Hamiltonian is, in
the dual convention (ct-conventions `SGN2`, `SGN3`): `y (c - lb)` for a lower bound only,
`y (ub - c)` for an upper bound only, `-y (c - b)` for two bounds or an equality, with
`b = ub` if `y > 0` and `b = lb` otherwise. The sign of `y` carries the active side; the
former `:label => :side` is rejected. A state box gives the same term as the equivalent
path constraint (`SGN5`).

Issue example (Bonnard, Faubourg, Launay & Trélat 2003): ẋ = u, |u| ≤ 1, x ≥ lb = 0.1,
∫₀² x² → min, x(0) = 1, x(2) = 1/2. On the boundary arc [0.9, 1.6], u = 0 and μ = 2x, so
ṗ = 2x - (2g + 2x) = 0 at x = lb: p stays 0.
"""

module TestConstraintLabelBounds

using Test: Test
using CTBase: Data
using CTBase: Exceptions
using CTModels: CTModels
using CTFlows: Flows
using CTFlows: Systems
using OrdinaryDiffEqTsit5: OrdinaryDiffEqTsit5  # SciML integrator for Flow(...)
using ForwardDiff: ForwardDiff  # triggers the DI ForwardDiff extension (AutoForwardDiff)

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

const LB = 0.1
const ATOL = 1e-8
_opts() = (; reltol=1e-10, abstol=1e-10)

# ── models ───────────────────────────────────────────────────────────────────

"""Issue model: ẋ = u, ∫ x² → min, with the path constraints `cons = [(f!, lb, ub, label)]`."""
function _ocp(cons...)
    pre = CTModels.Building.PreModel()
    CTModels.Building.time_dependence!(pre; autonomous=true)
    CTModels.Building.time!(pre; t0=0.0, tf=2.0)
    CTModels.Building.state!(pre, 1)
    CTModels.Building.control!(pre, 1)
    CTModels.Building.dynamics!(pre, (r, t, x, u, v) -> (r[1]=u; nothing))
    CTModels.Building.objective!(pre, :min; lagrange=(t, x, u, v) -> x^2)
    for (f!, lb, ub, label) in cons
        CTModels.Building.constraint!(pre, :path; f=f!, lb=lb, ub=ub, label=label)
    end
    return CTModels.Building.build(pre)
end

# x ≥ lb, written three ways (the issue's table)
const SPELLINGS = (
    ("x - lb ≥ 0", (r, t, x, u, v) -> (r[1]=x - LB; nothing), 0.0, Inf),
    ("x + 0 ≥ lb", (r, t, x, u, v) -> (r[1]=x; nothing), LB, Inf),
    ("lb - x ≤ 0", (r, t, x, u, v) -> (r[1]=LB - x; nothing), -Inf, 0.0),
)

"""Issue model with the state constraint `x ≥ lb` written as a state box `:xbox`."""
function _ocp_box()
    pre = CTModels.Building.PreModel()
    CTModels.Building.time_dependence!(pre; autonomous=true)
    CTModels.Building.time!(pre; t0=0.0, tf=2.0)
    CTModels.Building.state!(pre, 1)
    CTModels.Building.control!(pre, 1)
    CTModels.Building.dynamics!(pre, (r, t, x, u, v) -> (r[1]=u; nothing))
    CTModels.Building.objective!(pre, :min; lagrange=(t, x, u, v) -> x^2)
    CTModels.Building.constraint!(pre, :state; rg=1:1, lb=[LB], ub=[Inf], label=:xbox)
    return CTModels.Building.build(pre)
end

"""Two-dimensional state, one 2-D path constraint `:c` = (x₁, x₂) with bounds `lb`, `ub`."""
function _ocp2(lb, ub)
    pre = CTModels.Building.PreModel()
    CTModels.Building.time_dependence!(pre; autonomous=true)
    CTModels.Building.time!(pre; t0=0.0, tf=1.0)
    CTModels.Building.state!(pre, 2)
    CTModels.Building.control!(pre, 1)
    CTModels.Building.dynamics!(pre, (r, t, x, u, v) -> (r[1]=x[2]; r[2]=u; nothing))
    CTModels.Building.objective!(pre, :min; lagrange=(t, x, u, v) -> 0.5 * u^2)
    CTModels.Building.constraint!(
        pre, :path; f=(r, t, x, u, v) -> (r.=x; nothing), lb=lb, ub=ub, label=:c
    )
    return CTModels.Building.build(pre)
end

# The term adjoined for the labels `spec` with the dual `y`, at the state `x`: the
# constrained pseudo-Hamiltonian of the flow at p = 0, u = 0, minus its value at y = 0.
function _term(ocp, spec, x, y)
    f = Flows.Flow(ocp, (x, p) -> 0.0; multipliers=spec => _y0(spec), _opts()...)
    H = Systems.pseudo_hamiltonian(f)
    p0 = zero(x)
    return H(x, p0, 0.0, y) - H(x, p0, 0.0, zero(y))
end
_y0(::Symbol) = (x, p) -> 0.0
_y0(spec::Tuple) = map(_ -> (x, p) -> 0.0, spec)

const μ = (x, p) -> 2x

"""2-D state, a path constraint `:a` of one row (x₁ ≥ 0.1) and a path constraint `:b` of two rows (x ≥ 0)."""
function _ocp_dims()
    pre = CTModels.Building.PreModel()
    CTModels.Building.time_dependence!(pre; autonomous=true)
    CTModels.Building.time!(pre; t0=0.0, tf=1.0)
    CTModels.Building.state!(pre, 2)
    CTModels.Building.control!(pre, 1)
    CTModels.Building.dynamics!(pre, (r, t, x, u, v) -> (r[1]=x[2]; r[2]=u; nothing))
    CTModels.Building.objective!(pre, :min; lagrange=(t, x, u, v) -> 0.5 * u^2)
    CTModels.Building.constraint!(
        pre, :path; f=(r, t, x, u, v) -> (r[1]=x[1]; nothing), lb=[0.1], ub=[Inf], label=:a
    )
    CTModels.Building.constraint!(
        pre,
        :path;
        f=(r, t, x, u, v) -> (r.=x; nothing),
        lb=[0.0, 0.0],
        ub=[Inf, Inf],
        label=:b,
    )
    return CTModels.Building.build(pre)
end

# Batched states (control-toolbox/CTModels.jl#536, point 6): every function of the model is
# written on the columns, so that it is valid for a vector state and for a matrix state, one
# column per point; the law and the multipliers dispatch on the shape of the costate.
const A_BATCH = [0.0 1.0; -1.0 0.0]
const B_BATCH = [0.0, 1.0]
_dyn_batch!(r, t, x, u, v) = (r.=A_BATCH * x .+ B_BATCH .* u; nothing)
_lag_batch(t, x, u, v) = 0.5 * sum(abs2, u)
_pc_batch!(r, t, x, u, v) = (r[1:1, :].=x[1:1, :] .+ u; nothing)

"""2-D model with a path constraint `:pc` (|x₁ + u| ≤ 1) and a state box `:vmax` (x₂ ≤ 1.2)."""
function _ocp_batch()
    pre = CTModels.Building.PreModel()
    CTModels.Building.time_dependence!(pre; autonomous=true)
    CTModels.Building.time!(pre; t0=0.0, tf=1.0)
    CTModels.Building.state!(pre, 2)
    CTModels.Building.control!(pre, 1)
    CTModels.Building.dynamics!(pre, _dyn_batch!)
    CTModels.Building.objective!(pre, :min; lagrange=_lag_batch)
    CTModels.Building.constraint!(pre, :path; f=_pc_batch!, lb=[-1.0], ub=[1.0], label=:pc)
    CTModels.Building.constraint!(pre, :state; rg=2:2, lb=[-Inf], ub=[1.2], label=:vmax)
    return CTModels.Building.build(pre)
end

_law_batch(x, p::AbstractVector) = p[2]
_law_batch(x, p::AbstractMatrix) = p[2:2, :]
_μ_pc_batch(x, p::AbstractVector) = 0.3 * x[1]
_μ_pc_batch(x, p::AbstractMatrix) = 0.3 .* x[1:1, :]
_μ_vmax_batch(x, p::AbstractVector) = 0.5 + p[1]^2
_μ_vmax_batch(x, p::AbstractMatrix) = 0.5 .+ p[1:1, :] .^ 2

function test_constraint_label_bounds()
    Test.@testset "multipliers=:label => y bounds (issue #440)" verbose = VERBOSE showtiming =
        SHOWTIMING begin

        # ====================================================================
        # the term of each kind of constraint, in the dual convention
        # ====================================================================

        Test.@testset "x ≥ lb written three ways, and as a state box: one term" begin
            for (name, f!, lb, ub) in SPELLINGS
                ocp = _ocp((f!, lb, ub, :xcon))
                Test.@test _term(ocp, :xcon, 0.5, 2.0) ≈ 2.0 * (0.5 - LB)   # y (x - lb)
            end
            Test.@test _term(_ocp_box(), :xbox, 0.5, 2.0) ≈ 2.0 * (0.5 - LB)
        end

        Test.@testset "upper bound only: y (ub - c)" begin
            ocp = _ocp(((r, t, x, u, v) -> (r[1]=2x; nothing), -Inf, 1.0, :up))
            Test.@test _term(ocp, :up, 0.25, 3.0) ≈ 3.0 * (1.0 - 0.5)
        end

        Test.@testset "equality: -y (c - b), either sign of y" begin
            ocp = _ocp(((r, t, x, u, v) -> (r[1]=x; nothing), 0.3, 0.3, :eq))
            Test.@test _term(ocp, :eq, 0.5, 2.0) ≈ -2.0 * 0.2
            Test.@test _term(ocp, :eq, 0.5, -2.0) ≈ 2.0 * 0.2
        end

        Test.@testset "two-sided: the sign of y gives the active bound" begin
            ocp = _ocp(((r, t, x, u, v) -> (r[1]=x; nothing), 0.1, 0.9, :box))
            Test.@test _term(ocp, :box, 0.5, -2.0) ≈ 2.0 * (0.5 - 0.1)   # lower: y < 0
            Test.@test _term(ocp, :box, 0.5, 2.0) ≈ 2.0 * (0.9 - 0.5)    # upper: y > 0
            Test.@test _term(ocp, :box, 0.5, 0.0) == 0.0
        end

        Test.@testset "vector constraint: one dual per component" begin
            x = [0.5, 0.2]
            ocp = _ocp2([0.1, -Inf], [Inf, 0.6])
            Test.@test _term(ocp, :c, x, [2.0, 3.0]) ≈ 2.0 * 0.4 + 3.0 * 0.4
            ocp = _ocp2([0.1, 0.0], [0.9, 0.6])
            Test.@test _term(ocp, :c, x, [-2.0, 3.0]) ≈ 2.0 * 0.4 + 3.0 * 0.4
        end

        Test.@testset "tuple of labels: the duals stacked in their order" begin
            ocp = _ocp(
                ((r, t, x, u, v) -> (r[1]=x; nothing), LB, Inf, :lo),
                ((r, t, x, u, v) -> (r[1]=x; nothing), 0.0, 0.9, :box),
            )
            Test.@test _term(ocp, (:lo, :box), 0.5, [2.0, 3.0]) ≈ 2.0 * 0.4 + 3.0 * 0.4
        end

        Test.@testset "multipliers of a tuple of labels: the dimension of each is checked" begin
            ocp = _ocp_dims()
            x, p = [0.5, 0.2], [0.3, -0.1]
            μ1, μ2 = (x, p) -> 2.0, (x, p) -> [1.0, 3.0]
            m = Flows._resolve_multiplier(ocp, (μ1, μ2), (:a, :b))
            Test.@test m(x, p) == [2.0, 1.0, 3.0]
            # the total has the right number of components (3), each part does not: the
            # check is per label, so the swap is caught
            bad1, bad2 = (x, p) -> [2.0, 1.0], (x, p) -> 3.0
            mbad = Flows._resolve_multiplier(ocp, (bad1, bad2), (:a, :b))
            err = try
                mbad(x, p)
            catch e
                e
            end
            Test.@test err isa Exceptions.IncorrectArgument
            Test.@test occursin(":a", err.msg)
            Test.@test occursin("2 component", err.got)
            Test.@test occursin("1 component", err.expected)
            err = try
                Flows._resolve_multiplier(ocp, (μ1, (x, p) -> 3.0), (:a, :b))(x, p)
            catch e
                e
            end
            Test.@test err isa Exceptions.IncorrectArgument
            Test.@test occursin(":b", err.msg)
            # a one-component multiplier may be a vector of length 1
            Test.@test Flows._resolve_multiplier(ocp, ((x, p) -> [2.0], μ2), (:a, :b))(
                x, p
            ) == [2.0, 1.0, 3.0]
            # without the constraint spec, or for a constraint given as a function, that
            # part is not checked
            Test.@test Flows._resolve_multiplier(ocp, (bad1, bad2))(x, p) == [2.0, 1.0, 3.0]
            Test.@test Flows._resolve_multiplier(ocp, (bad1, μ2), (x -> x, :b))(x, p) ==
                [2.0, 1.0, 1.0, 3.0]
        end

        Test.@testset "wrong multiplier dimension for a label is rejected [$ht]" for ht in (
            :total, :partial
        )
            f = Flows.Flow(
                _ocp_dims(),
                (x, p) -> 0.0;
                multipliers=(:a => ((x, p) -> [2.0, 1.0]), :b => ((x, p) -> 3.0)),
                hamiltonian_type=ht,
                _opts()...,
            )
            err = try
                f(0.0, [0.5, 0.2], [0.3, -0.1], 0.5)
            catch e
                e
            end
            Test.@test err isa Exceptions.IncorrectArgument
            Test.@test occursin(":a", err.msg)
        end

        Test.@testset "Error: the former label => side" begin
            ocp = _ocp(((r, t, x, u, v) -> (r[1]=x; nothing), 0.1, 0.9, :box))
            spec = :box => :lower
            Test.@test_throws Exceptions.IncorrectArgument Flows.Flow(
                ocp, (x, p) -> 0.0; multipliers=spec => μ, _opts()...
            )
            err = try
                Flows.Flow(ocp, (x, p) -> 0.0; multipliers=spec => μ, _opts()...)
            catch e
                e
            end
            Test.@test occursin("y = -μ", err.suggestion)
        end

        Test.@testset "Error: a tuple mixing labels and functions" begin
            ocp = _ocp(((r, t, x, u, v) -> (r[1]=x; nothing), LB, Inf, :xcon))
            Test.@test_throws Exceptions.IncorrectArgument Flows.Flow(
                ocp, (x, p) -> 0.0; multipliers=(:xcon => μ, ((x, u) -> x) => μ), _opts()...
            )
        end

        # ====================================================================
        # the issue: the boundary arc, and the three arcs
        # ====================================================================

        Test.@testset "boundary arc [$name, $ht]" for (name, f!, lb, ub) in SPELLINGS,
            ht in (:total, :partial)

            ocp = _ocp((f!, lb, ub, :xcon))
            f_sym = Flows.Flow(
                ocp, (x, p) -> 0; multipliers=:xcon => μ, hamiltonian_type=ht, _opts()...
            )
            f_fun = Flows.Flow(
                ocp,
                (x, p) -> 0;
                multipliers=((x, u) -> x - LB) => μ,
                hamiltonian_type=ht,
                _opts()...,
            )
            x2, p2 = f_sym(0.9, LB, 0.0, 1.6)
            Test.@test x2 ≈ LB atol = ATOL
            Test.@test p2 ≈ 0.0 atol = ATOL
            Test.@test all(
                isapprox.(f_sym(0.9, LB, 0.0, 1.6), f_fun(0.9, LB, 0.0, 1.6); atol=ATOL)
            )
        end

        Test.@testset "boundary arc with the state box [$ht]" for ht in (:total, :partial)
            f = Flows.Flow(
                _ocp_box(),
                (x, p) -> 0;
                multipliers=:xbox => μ,
                hamiltonian_type=ht,
                _opts()...,
            )
            x2, p2 = f(0.9, LB, 0.0, 1.6)
            Test.@test x2 ≈ LB atol = ATOL
            Test.@test p2 ≈ 0.0 atol = ATOL
        end

        Test.@testset "batched (Matrix) state: one trajectory per column [$ht]" for ht in (
            :total, :partial
        )
            f = Flows.Flow(
                _ocp_batch(),
                _law_batch;
                multipliers=(:pc => _μ_pc_batch, :vmax => _μ_vmax_batch),
                hamiltonian_type=ht,
                _opts()...,
            )
            X0 = [0.2 -0.5 1.0; 0.1 0.4 -0.3]
            P0 = [0.3 -0.2 0.6; -0.4 0.5 0.1]
            Xf, Pf = f(0.0, X0, P0, 1.0)
            Test.@test size(Xf) == size(X0)
            Test.@test size(Pf) == size(P0)
            for j in 1:3
                xf, pf = f(0.0, X0[:, j], P0[:, j], 1.0)
                Test.@test Xf[:, j] ≈ xf atol = 1e-7
                Test.@test Pf[:, j] ≈ pf atol = 1e-7
            end
        end

        Test.@testset "three arcs [$name]" for (name, f!, lb, ub) in SPELLINGS
            ocp = _ocp((f!, lb, ub, :xcon))
            f_minus = Flows.Flow(ocp, (x, p) -> -1; _opts()...)
            f_bound = Flows.Flow(ocp, (x, p) -> 0; multipliers=:xcon => μ, _opts()...)
            f_plus = Flows.Flow(ocp, (x, p) -> 1; _opts()...)
            φ = f_minus * (0.9, f_bound) * (1.6, f_plus)
            # exact costate: p(0) = -0.99 makes p vanish at the entry t₁ = 0.9; it stays 0 on
            # the arc (ṗ = 2x - μ = 0), then ṗ = 2x with x = 0.1 + (t - 1.6), so p(2) = 0.24
            p0 = -0.99
            xf, pf = φ(0.0, 1.0, p0, 2.0)
            Test.@test xf ≈ 0.5 atol = 1e-8
            Test.@test pf ≈ 0.24 atol = 1e-8
            p = CTModels.costate(φ((0.0, 2.0), 1.0, p0))
            Test.@test p(0.9) ≈ 0 atol = 1e-8
            Test.@test p(1.2) ≈ 0 atol = 1e-8
            Test.@test p(1.6) ≈ 0 atol = 1e-8
        end
    end
end

end # module

test_constraint_label_bounds() = TestConstraintLabelBounds.test_constraint_label_bounds()
