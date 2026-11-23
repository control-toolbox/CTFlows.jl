# =============================================================================
# Constraint duals of an OCP flow (issue #472, control-toolbox/CTModels.jl#536)
#
# `Flow(ocp, law; constraint=:label, multiplier=y)` adjoins the constraint `label` (a path
# constraint, a state box or a control box) to the pseudo-Hamiltonian through CTModels,
# with the multiplier `y` in the dual convention of the solution (ct-conventions SGN1–SGN6,
# the convention of the direct solvers, control-toolbox/CTSolvers.jl#288):
#
#   - a row with a single finite bound (c ≥ lb, or c ≤ ub) has the dual y ≥ 0;
#   - an equality row, and a row with two finite bounds, has the signed dual
#     y = μU − μL: y < 0 on the lower bound, y > 0 on the upper bound.
#
# The trajectory call places these duals in the solution, by label: the multiplier is the
# dual itself. The path labels that are not adjoined get a zero dual (their constraint is
# not active on the arc); the box labels that are not adjoined stay unknown (a saturated
# control, for instance, has a nonzero box dual that the flow does not compute). A
# constraint given as a function has no label, and its duals cannot be placed: the
# solution then carries no constraint dual.
# =============================================================================

"""
$(TYPEDEF)

Dual of one labelled constraint on the arc of a flow: its label and the multiplier `μ`
given to the flow, which is the dual itself.

# Fields
- `label::Symbol`: the label of the constraint in the model.
- `μ::M`: the resolved multiplier, called uniformly as `μ(t, x, p, v)`.
"""
struct _LabelledDual{M}
    label::Symbol
    μ::M
end

"""
$(TYPEDEF)

Duals of the constraints of the model along the arc of a flow, by label: the labelled
constraints adjoined to the pseudo-Hamiltonian (`parts`), and the path labels of the model
that are not adjoined, whose dual is zero. An unconstrained flow has no part.

# Fields
- `parts::P`: a tuple of [`CTFlows.Flows._LabelledDual`](@extref).
- `labels::Vector{Symbol}`: every label with a known dual: the adjoined labels, then the
  other path labels.
- `dims::Dict{Symbol,Int}`: the number of rows (or components) of each label.
"""
struct _FlowDuals{P<:Tuple}
    parts::P
    labels::Vector{Symbol}
    dims::Dict{Symbol,Int}
end

"""
$(TYPEDEF)

Constraint duals that cannot be rebuilt: a constraint was given to the flow as a function
(or as a [`CTBase.Data.PathConstraint`](@extref)), with no label to place its multiplier
in the model.
"""
struct _UnlabelledPathDuals end

"""
$(TYPEDSIGNATURES)

The path labels of `ocp`, in the order of the stacked path constraint, with their number
of rows.
"""
function _path_labels(ocp)
    CTModels.Components.dim_path_constraints_nl(ocp) == 0 && return Pair{Symbol,Int}[]
    rows = CTModels.Components.path_constraints_nl(ocp)[4]
    return [l => count(==(l), rows) for l in unique(rows)]
end

"""
$(TYPEDSIGNATURES)

Build the duals of a flow from its `constraint` and `multiplier` specifications (already
validated): a [`CTFlows.Flows._FlowDuals`](@extref) when there is no constraint or when
every constraint is given by its label, a [`CTFlows.Flows._UnlabelledPathDuals`](@extref)
otherwise.
"""
function _flow_duals(ocp, cspec, mspec)
    path = _path_labels(ocp)
    if cspec === nothing
        return _FlowDuals((), first.(path), Dict{Symbol,Int}(path))
    end
    _is_labelled(cspec) || return _UnlabelledPathDuals()
    labels = _labels(cspec)
    ms = cspec isa Tuple ? mspec : (mspec,)
    parts = map((l, m) -> _LabelledDual(l, _resolve_multiplier(ocp, m)), labels, ms)
    dims = Dict{Symbol,Int}(path)
    for l in labels
        dims[l] = length(last(CTModels.Models.constraint_rows(ocp, l)))
    end
    others = [l for l in first.(path) if !(l in labels)]
    return _FlowDuals(parts, vcat(collect(labels), others), dims)
end

"""
$(TYPEDSIGNATURES)

The kind of the constraint `label` of `ocp`: `:path`, `:state`, `:control`, `:boundary` or
`:variable`.
"""
_constraint_kind(ocp, label::Symbol) = first(CTModels.Models.constraint_rows(ocp, label))

"""
$(TYPEDSIGNATURES)

The labels with a known dual (see [`CTFlows.Flows._FlowDuals`](@extref)); none when the
duals cannot be rebuilt or the problem is control-free.
"""
_dual_labels(d::_FlowDuals) = d.labels
_dual_labels(::Union{Nothing,_UnlabelledPathDuals}) = Symbol[]

"""
$(TYPEDSIGNATURES)

The zero dual of a constraint of `n` rows: a scalar for one row, a vector otherwise.
"""
_zero_dual(n::Int) = n == 1 ? 0.0 : zeros(n)

"""
$(TYPEDSIGNATURES)

Dual of the constraint `label` at time `t`, from the state `x`, the costate `p` and the
variable `v` there: the multiplier given to the flow when `label` is adjoined, zero
otherwise.
"""
function _dual_value(d::_FlowDuals, label::Symbol, t, x, p, v)
    for part in d.parts
        part.label === label && return part.μ(t, x, p, v)
    end
    return _zero_dual(d.dims[label])
end

"""
$(TYPEDSIGNATURES)

Dual of the constraint `label` just after the `i`-th switching time `t`, from the state `x`
and costate `p` after the jump. A single flow has one set of duals; `CTFlows.MultiPhase`
adds the method of the piecewise duals of a multi-phase flow (those of the next phase).
"""
_right_dual_value(d, label::Symbol, ::Integer, t, x, p, v) = _dual_value(d, label, t, x, p, v)

"""
$(TYPEDEF)

The dual of the constraint `label` of a solution as a function of time, `t -> y(t)`,
passed to [`CTModels.Solutions.build_solution`](@extref) in `duals`.

# Fields
- `duals::D`: the duals of the flow ([`CTFlows.Flows._FlowDuals`](@extref), or the
  piecewise duals of a multi-phase flow).
- `label::Symbol`: the label of the constraint.
- `x::X`, `p::P`: the state and costate, callables `t -> x(t)`, `t -> p(t)`.
- `v::V`: the variable.
"""
struct _LabelDualFunction{D,X,P,V} <: Function
    duals::D
    label::Symbol
    x::X
    p::P
    v::V
end
(f::_LabelDualFunction)(t) = _dual_value(f.duals, f.label, t, f.x(t), f.p(t), f.v)

"""
$(TYPEDSIGNATURES)

The `duals` of a solution, by label: a [`CTFlows.Flows._LabelDualFunction`](@extref) for
each label with a known dual; empty when the duals cannot be rebuilt.
"""
function _solution_duals(d, x, p, v)::Dict{Symbol,Any}
    return Dict{Symbol,Any}(l => _LabelDualFunction(d, l, x, p, v) for l in _dual_labels(d))
end

"""
$(TYPEDSIGNATURES)

Left and right limits of the duals at the switching times `taus`, by label (one row per
switching time), for the switching model of the solution: the left limit from the duals of
the phase that ends, at the state `xl` and costate `pl` before the jump; the right limit from
those of the next phase, at `xr` and `pr` after it (see
[`CTFlows.Flows._right_dual_value`](@extref)). Empty when the duals are not known.
"""
function _switching_duals(d, taus, xl, xr, pl, pr, v)
    out = Dict{Symbol,NTuple{2,Matrix{Float64}}}()
    n = length(taus)
    n == 0 && return out
    for l in _dual_labels(d)
        left = _limit_rows([_dual_value(d, l, taus[i], xl[i], pl[i], v) for i in 1:n])
        right = _limit_rows([
            _right_dual_value(d, l, i, taus[i], xr[i], pr[i], v) for i in 1:n
        ])
        out[l] = (left, right)
    end
    return out
end

"""
$(TYPEDSIGNATURES)

Warn (once per session) that a constraint given to `Flow(ocp, law; constraint=…)` as a
function, while the problem has labelled constraints, leaves the solution of the flow
without duals: `dual(sol, ocp, :label)` will throw. The fix is to give the constraint by its
label.
"""
function _warn_unlabelled_constraint(ocp)
    path = _path_labels(ocp)
    isempty(path) && return nothing
    labels = first.(path)
    l = first(labels)
    @warn "A constraint given to Flow(ocp, law; constraint=…) as a function has no " *
        "label: the solution will carry no constraint dual, and dual(sol, ocp, :label) " *
        "will throw. Give it by its label to get its dual, e.g. constraint=:$l, with the " *
        "multiplier in the dual convention of the solution. Path constraints of the " *
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
           "it has no label, so its multiplier cannot be placed in the model, and the " *
           "solution carries no dual. Give the constraints by their label: " *
           "Flow(ocp, law; constraint=:label, multiplier=y), with y the dual."
end
function _missing_duals_note(::Nothing)::String
    return "This solution comes from a CTFlows flow of a control-free problem, which " *
           "carries no constraint dual."
end
function _missing_duals_note(::Any)::String
    return "This solution comes from a CTFlows flow, which rebuilds the duals of the " *
           "constraints given with constraint=:label (path constraints, state and control " *
           "boxes) and the zero duals of the other path constraints. The duals of the " *
           "boundary constraints, of the variable boxes and of the boxes not given to the " *
           "flow are not computed (see control-toolbox/CTFlows.jl#495)."
end
