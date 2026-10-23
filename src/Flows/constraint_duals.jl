# =============================================================================
# Constraint duals of an OCP flow (issue #472)
#
# `Flow(ocp, law; constraint=:label, multiplier=μ)` adjoins `μ·g` to the
# pseudo-Hamiltonian, with `g ≥ 0` the path constraint `label` normalised on its active
# side and `μ ≥ 0`. The trajectory call rebuilds the duals of the path constraints of the
# model from `μ`, in the sign convention of the ecosystem (ct-conventions SGN1–SGN6, the
# convention of the direct solvers, control-toolbox/CTSolvers.jl#288):
#
#   - a row with a single finite bound (c ≥ lb, or c ≤ ub) has the dual μ ≥ 0;
#   - an equality row, and a row with two finite bounds, has the signed dual
#     y = μU − μL: −μ on the lower side (sign = +1), +μ on the upper side (sign = −1).
#
# The label is the key: the model stores one label per row of the stacked path constraint,
# so the rows of a label are known. A constraint given as a function has no label, and its
# duals cannot be placed: the solution then carries no path dual.
# =============================================================================

"""
$(TYPEDEF)

Dual of one labelled path constraint on the arc of a flow: the rows of the label in the
stacked path constraint of the model, the coefficient of each row (`1` or `∓1`, see
[`CTFlows.Flows._dual_coefficient`](@extref)), and the multiplier `μ` given to the flow.

# Fields
- `rows::Vector{Int}`: the rows of the label in `path_constraints_nl(ocp)`.
- `coef::Vector{Float64}`: the coefficient of `μ` on each row.
- `μ::M`: the resolved multiplier, called uniformly as `μ(t, x, p, v)`.
"""
struct _LabelledDual{M}
    rows::Vector{Int}
    coef::Vector{Float64}
    μ::M
end

"""
$(TYPEDEF)

Duals of the path constraints of the model along the arc of a flow: the labelled
constraints adjoined to the pseudo-Hamiltonian (`parts`), all other rows being `0` (their
constraint is not active on the arc). An unconstrained flow has no part.

# Fields
- `parts::P`: a tuple of [`CTFlows.Flows._LabelledDual`](@extref).
- `dim::Int`: the number of rows of the path constraint of the model.
"""
struct _PathDuals{P<:Tuple}
    parts::P
    dim::Int
end

"""
$(TYPEDEF)

Path duals that cannot be rebuilt: a constraint was given to the flow as a function (or
as a [`CTBase.Data.PathConstraint`](@extref)), with no label to place its multiplier in the
rows of the model.
"""
struct _UnlabelledPathDuals end

"""
$(TYPEDSIGNATURES)

Build the path duals of a flow from its `constraint` and `multiplier` specifications
(already validated): a [`CTFlows.Flows._PathDuals`](@extref) when there is no constraint
or when every constraint is given by its label, a
[`CTFlows.Flows._UnlabelledPathDuals`](@extref) otherwise.
"""
function _path_duals(ocp, cspec, mspec)
    dim = CTModels.Components.dim_path_constraints_nl(ocp)
    cspec === nothing && return _PathDuals((), dim)
    parts = _labelled_duals(ocp, cspec, mspec)
    parts === nothing && return _UnlabelledPathDuals()
    return _PathDuals(parts, dim)
end

"""
$(TYPEDSIGNATURES)

The [`CTFlows.Flows._LabelledDual`](@extref) parts of a constraint specification, as a
tuple, or `nothing` when a constraint has no label.
"""
_labelled_duals(ocp, spec::Symbol, mspec) = (_labelled_dual(ocp, spec, nothing, mspec),)

function _labelled_duals(ocp, spec::Pair{Symbol}, mspec)
    return (_labelled_dual(ocp, first(spec), last(spec), mspec),)
end

function _labelled_duals(ocp, spec::Tuple, mspec::Tuple)
    parts = map((c, m) -> _labelled_duals(ocp, c, m), spec, mspec)
    any(isnothing, parts) && return nothing
    return reduce((a, b) -> (a..., b...), parts)
end

_labelled_duals(ocp, spec, mspec) = nothing

"""
$(TYPEDSIGNATURES)

The [`CTFlows.Flows._LabelledDual`](@extref) of the path constraint `label` on the active
`side` (`nothing`, a `Symbol`, or one per component), with the multiplier `mspec`.
"""
function _labelled_dual(ocp, label::Symbol, side, mspec)
    _, c, lb, ub = CTModels.Models.constraint(ocp, label)
    g = _bounded_constraint(label, c, lb, ub, side)
    rows = findall(==(label), CTModels.Components.path_constraints_nl(ocp)[4])
    coef = Float64[
        _dual_coefficient(l, u, s) for (l, u, s) in zip(vcat(lb), vcat(ub), vcat(g.sign))
    ]
    return _LabelledDual(rows, coef, _resolve_multiplier(ocp, mspec))
end

"""
$(TYPEDSIGNATURES)

Coefficient of the multiplier `μ ≥ 0` of `g = sign·(c - bound) ≥ 0` in the dual of the row
`lb ≤ c ≤ ub`: `1` when the row has a single finite bound (its dual is `μ ≥ 0`), `-sign`
otherwise (equality or two finite bounds: the signed dual `μU − μL`).
"""
_dual_coefficient(lb, ub, sign) = isfinite(lb) == isfinite(ub) ? -Float64(sign) : 1.0

"""
$(TYPEDSIGNATURES)

Value of the path duals at time `t`, from the state `x`, the costate `p` and the variable
`v` there: one entry per row of the path constraint of the model.
"""
function _path_dual_value(d::_PathDuals, t, x, p, v)
    out = zeros(d.dim)
    for part in d.parts
        out[part.rows] .+= part.coef .* vcat(part.μ(t, x, p, v))
    end
    return out
end

"""
$(TYPEDEF)

The path duals of a solution as a function of time, `t -> D(t)`, passed to
[`CTModels.Solutions.build_solution`](@extref) as `path_constraints_dual`.

# Fields
- `duals::D`: the path duals ([`CTFlows.Flows._PathDuals`](@extref), or the piecewise
  duals of a multi-phase flow).
- `x::X`, `p::P`: the state and costate, callables `t -> x(t)`, `t -> p(t)`.
- `v::V`: the variable.
"""
struct _PathDualFunction{D,X,P,V} <: Function
    duals::D
    x::X
    p::P
    v::V
end

(f::_PathDualFunction)(t) = _path_dual_value(f.duals, t, f.x(t), f.p(t), f.v)

"""
$(TYPEDSIGNATURES)

The `path_constraints_dual` of a solution: `nothing` when there is no path constraint, or
when the duals cannot be rebuilt (a constraint without a label), a
[`CTFlows.Flows._PathDualFunction`](@extref) otherwise.
"""
_path_constraints_dual(::Nothing, x, p, v) = nothing
_path_constraints_dual(::_UnlabelledPathDuals, x, p, v) = nothing
function _path_constraints_dual(d, x, p, v)
    _path_dual_dim(d) == 0 && return nothing
    return _PathDualFunction(d, x, p, v)
end

_path_dual_dim(d::_PathDuals) = d.dim

"""
$(TYPEDSIGNATURES)

Left and right limits of the path duals at the switching times `taus`, one row per
switching time, for the switching model of the solution: the left limit from the duals of
the phase that ends, at the state `xl` and costate `pl` before the jump; the right limit from
those of the next phase, at `xr` and `pr` after it (see
[`CTFlows.Flows._right_path_dual`](@extref)). No column when the duals are not known.
"""
function _switching_path_duals(d, taus, xl, xr, pl, pr, v)
    n = length(taus)
    (d isa Union{Nothing,_UnlabelledPathDuals} || _path_dual_dim(d) == 0) &&
        return (zeros(n, 0), zeros(n, 0))
    left = _limit_rows([_path_dual_value(d, taus[i], xl[i], pl[i], v) for i in 1:n])
    right = _limit_rows([_right_path_dual(d, i, taus[i], xr[i], pr[i], v) for i in 1:n])
    return (left, right)
end

"""
$(TYPEDSIGNATURES)

Path duals just after the `i`-th switching time `t`, from the state `x` and costate `p` after
the jump. A single flow has one set of duals; `CTFlows.MultiPhase` adds the method of the
piecewise duals of a multi-phase flow (those of the next phase).
"""
_right_path_dual(d, ::Integer, t, x, p, v) = _path_dual_value(d, t, x, p, v)

"""
$(TYPEDSIGNATURES)

Warn (once per session) that a constraint given to `Flow(ocp, law; constraint=…)` as a
function, while the problem has labelled path constraints, leaves the solution of the flow
without duals: `dual(sol, ocp, :label)` will throw. The fix is to give the constraint by its
label.
"""
function _warn_unlabelled_constraint(ocp)
    CTModels.Components.dim_path_constraints_nl(ocp) == 0 && return nothing
    labels = unique(CTModels.Components.path_constraints_nl(ocp)[4])
    l = first(labels)
    @warn "A constraint given to Flow(ocp, law; constraint=…) as a function has no " *
        "label: the solution will carry no constraint dual, and dual(sol, ocp, :label) " *
        "will throw. Give it by its label to get its dual, e.g. constraint=:$l (or " *
        "constraint=:$l => :upper for a two-sided constraint). Path constraints of the " *
        "problem: $(join(":" .* string.(labels), ", "))." maxlog = 1
    return nothing
end

"""
$(TYPEDSIGNATURES)

The note stored in `infos(sol)[:missing_duals]` of the solution of a flow: CTModels uses it
as the suggestion of the `PreconditionError` that `dual(sol, ocp, :label)` throws for a
dual the flow did not rebuild. It says why the dual is missing and how to get it.
"""
function _missing_duals_note(::_UnlabelledPathDuals)::String
    return "This solution comes from a CTFlows flow with a constraint given as a function: " *
           "it has no label, so its multiplier cannot be placed in the rows of the model, " *
           "and the solution carries no dual. Give the path constraints by their label: " *
           "Flow(ocp, law; constraint=:label, multiplier=μ), or :label => :upper for a " *
           "two-sided constraint."
end

function _missing_duals_note(::Nothing)::String
    return "This solution comes from a CTFlows flow of a control-free problem, which " *
           "carries no constraint dual."
end

function _missing_duals_note(::Any)::String
    return "This solution comes from a CTFlows flow, which rebuilds the duals of the path " *
           "constraints only, from the multiplier given with constraint=:label. The duals " *
           "of the boundary and box constraints are not computed by a flow (see " *
           "control-toolbox/CTFlows.jl#495)."
end
