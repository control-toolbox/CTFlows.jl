# =============================================================================
# OCP Hamiltonians, OptimalControlFlow, and solution builder
#
# The pseudo-Hamiltonian H̃(t,x,p,u,v) = p·f + p⁰ℓ and the Hamiltonian of a control-free
# problem are built by CTModels (control-toolbox/CTModels.jl#532). This file adds the
# constraints given to a flow (μ·g) and the controlled vector field of the state flow.
# =============================================================================

const _CTM_Auton = CTModels.Components.Autonomous
const _CTM_NonAuton = CTModels.Components.NonAutonomous

"""
$(TYPEDSIGNATURES)

The keyword arguments `(; p0)` for the CTModels getters, or none when `p0` is `nothing`:
the getter then uses its default, `p⁰ = -1` for a minimisation and `+1` for a maximisation
(ct-conventions `SGN4`). `p0 = 0` is the abnormal case.
"""
_p0_kwargs(p0) = p0 === nothing ? (;) : (; p0)

"""
$(TYPEDSIGNATURES)

The Hamiltonian of a control-free OCP, a `Data.Hamiltonian` with the uniform `(t, x, p, v)`
interface: built by [`CTModels.Models.hamiltonian`](@extref) (control-toolbox/CTModels.jl#532).

See also: [`CTFlows.Flows.OptimalControlFlow`](@extref), [`CTFlows.Flows.Flow`](@extref).
"""
function _ocp_hamiltonian(ocp; p0=nothing)
    return CTModels.Models.hamiltonian(ocp; _p0_kwargs(p0)...)
end

"""
$(TYPEDSIGNATURES)

The pseudo-Hamiltonian of an OCP, a [`CTBase.Data.PseudoHamiltonian`](@extref) with the
uniform `(t, x, p, u, v)` interface used by the pseudo-Hamiltonian AD pipeline: built by
[`CTModels.Models.pseudo_hamiltonian`](@extref) (control-toolbox/CTModels.jl#532).

See also: `CTFlows.Flows._ocp_hamiltonian`.
"""
function _ocp_pseudo_hamiltonian(ocp; p0=nothing)
    return CTModels.Models.pseudo_hamiltonian(ocp; _p0_kwargs(p0)...)
end


# =============================================================================
# Constrained pseudo-Hamiltonian: H(t,x,p,u,μ,v) = H̃(t,x,p,u,v) + μ·g(t,x,u,v)
#
# The constraint g given to the flow is adjoined to the OCP pseudo-Hamiltonian H̃ with
# the multiplier μ as an explicit argument, as a CTBase.Data.ConstrainedPseudoHamiltonian.
# Both modes share it: :partial freezes μ (Data.freeze_multiplier), :total composes it
# with the law and the multiplier feedback (Data.ComposedConstrainedHamiltonian).
#
# The constraint g is called uniformly as g(t,x,u,v) and the multiplier μ as μ(t,x,p,v);
# both carriers ignore the arguments their traits do not use.
# =============================================================================

"""
$(TYPEDSIGNATURES)

Whether a `constraint` specification gives the constraints by their **label**: a `Symbol`,
or a tuple of `Symbol`s. Labelled constraints are adjoined by CTModels
([`CTModels.Models.pseudo_hamiltonian`](@extref)`(ocp; constraints=labels)`), with the
multiplier in the dual convention of the solution, and their duals are placed in the
solution. A constraint given as a function (or a [`CTBase.Data.PathConstraint`](@extref))
is adjoined here as `μ·g` with `g ≥ 0`, and has no dual in the solution.

# Throws
- [`CTBase.Exceptions.IncorrectArgument`](@extref): for a tuple mixing labels and
  functions, or for the former `label => side` form.

See also: [`CTFlows.Flows._ocp_constrained_pseudo_hamiltonian`](@extref).
"""
_is_labelled(::Symbol) = true
function _is_labelled(spec::Tuple)
    n = count(c -> c isa Symbol, spec)
    n == 0 && return false
    n == length(spec) && return true
    return throw(
        Exceptions.IncorrectArgument(
            "a tuple of constraints mixes labels and functions";
            got="$(n) label(s) and $(length(spec) - n) other constraint(s)",
            expected="only labels, or only functions",
            suggestion="Give every constraint by its label (they all are constraints of the model), or every one as a function",
            context="Flow(ocp, law; constraint=(…,)) — constraint resolution",
        ),
    )
end
_is_labelled(spec::Pair) = _side_removed(spec)
_is_labelled(::Any) = false

"""
$(TYPEDSIGNATURES)

Reject the former `label => side` form: the multiplier of a labelled constraint is now the
dual of the solution, whose sign carries the active side of a two-sided or equality
constraint (ct-conventions `SGN2`, `SGN3`).

# Throws
- [`CTBase.Exceptions.IncorrectArgument`](@extref): always.
"""
function _side_removed(spec::Pair)
    label = first(spec)
    return throw(
        Exceptions.IncorrectArgument(
            "the active side of a constraint is no longer given with `label => side`";
            got="constraint=$(repr(spec))",
            expected="constraint=$(repr(label)), with the multiplier in the dual convention of the solution",
            suggestion="Give constraint=$(repr(label)) and, as multiplier, the dual y of the solution: on a two-sided or equality constraint, y < 0 on the lower bound and y > 0 on the upper bound (so y = -μ for the former `$(repr(label)) => :lower`)",
            context="Flow(ocp, law; constraint=…) — constraint resolution",
        ),
    )
end

"""
$(TYPEDSIGNATURES)

The labels of a labelled `constraint` specification, as a tuple.
"""
_labels(spec::Symbol) = (spec,)
_labels(spec::Tuple) = spec


"""
$(TYPEDSIGNATURES)

Return a `PathConstraint` spec as-is — it is already a resolved
[`CTBase.Data.PathConstraint`](@extref).

See also: [`CTFlows.Flows._resolve_constraint`](@extref), [`CTBase.Data.PathConstraint`](@extref).
"""
_resolve_constraint(::Any, spec::Data.PathConstraint) = spec

"""
$(TYPEDSIGNATURES)

Resolve a `Function` constraint spec into a [`CTBase.Data.MixedConstraint`](@extref),
inferring autonomy and variable-dependence from the OCP.

See also: [`CTFlows.Flows._resolve_constraint`](@extref), [`CTBase.Data.MixedConstraint`](@extref).
"""
function _resolve_constraint(ocp, spec::Function)
    return Data.MixedConstraint(
        spec; is_autonomous=Traits.is_autonomous(ocp), is_variable=Traits.is_variable(ocp)
    )
end

"""
$(TYPEDEF)

Carrier for a tuple of simultaneous path constraints. Its uniform call concatenates the
per-constraint values `gᵢ(t,x,u,v)`, so the downstream `sum(μ .* g)` pairing computes
`Σᵢ μᵢ·gᵢ` with no change to the pseudo-Hamiltonian functors. Paired element-wise with a
[`CTFlows.Flows._CombinedMultiplier`](@extref) built from the matching multiplier tuple.

# Type Parameters
- `G <: Tuple`: type of the tuple of resolved per-constraint carriers.

# Fields
- `parts::G`: the resolved per-constraint carriers (each a [`CTBase.Data.PathConstraint`](@extref)).

See also: [`CTFlows.Flows._resolve_constraint`](@extref), [`CTFlows.Flows._CombinedMultiplier`](@extref).
"""
struct _CombinedConstraint{G<:Tuple}
    parts::G
end

"""
$(TYPEDSIGNATURES)

Uniform call: concatenate (`vcat`) the per-constraint values `gᵢ(t,x,u,v)` in tuple order.
"""
(c::_CombinedConstraint)(t, x, u, v) = reduce(vcat, map(g -> g(t, x, u, v), c.parts))

"""
$(TYPEDSIGNATURES)

Resolve a `Tuple` of constraint specs into a [`CTFlows.Flows._CombinedConstraint`](@extref),
rejecting an empty tuple with [`CTBase.Exceptions.IncorrectArgument`](@extref).

# Throws
- [`CTBase.Exceptions.IncorrectArgument`](@extref): when `spec` is an empty tuple.

See also: [`CTFlows.Flows._resolve_constraint`](@extref),
[`CTFlows.Flows._CombinedConstraint`](@extref).
"""
function _resolve_constraint(ocp, spec::Tuple)
    isempty(spec) && throw(
        Exceptions.IncorrectArgument(
            "empty constraint tuple";
            got="()",
            expected="a non-empty tuple of constraints",
            context="Flow(ocp, law; constraint=(…,)) — constraint resolution",
        ),
    )
    return _CombinedConstraint(map(s -> _resolve_constraint(ocp, s), spec))
end

"""
$(TYPEDSIGNATURES)

Throw an [`CTBase.Exceptions.IncorrectArgument`](@extref) for an unsupported constraint
spec type. Only a `Function`, a `Tuple` of them, or a [`CTBase.Data.PathConstraint`](@extref)
reach this resolution; labels go to CTModels (see [`CTFlows.Flows._is_labelled`](@extref)).

# Throws
- [`CTBase.Exceptions.IncorrectArgument`](@extref): when `spec` is not a supported type.

See also: [`CTFlows.Flows._resolve_constraint`](@extref).
"""
function _resolve_constraint(::Any, spec)
    return throw(
        Exceptions.IncorrectArgument(
            "unsupported constraint specification";
            got="$(typeof(spec))",
            expected="a constraint label (Symbol), a tuple of labels, a CTBase.Data.PathConstraint, a Function, or a tuple of them",
            context="Flow(ocp, law; constraint=…) — constraint resolution",
        ),
    )
end

"""
$(TYPEDSIGNATURES)

Resolve a `multiplier` specification into a [`CTBase.Data.Multiplier`](@extref).

- `spec::CTBase.Data.Multiplier` is used as-is.
- `spec::Function` is a raw function with the OCP's natural arity (`(x,p)`, `(t,x,p)`,
  `(x,p,v)` or `(t,x,p,v)`), wrapped in a [`CTBase.Data.Multiplier`](@extref) with the OCP's
  time/variable dependence.
- `spec::Tuple` is a non-empty tuple of multipliers, each resolved recursively and wrapped in
  a [`CTFlows.Flows._CombinedMultiplier`](@extref) — matched element-wise with the constraint
  tuple (empty tuple rejected with [`CTBase.Exceptions.IncorrectArgument`](@extref)).

See also: [`CTFlows.Flows._resolve_constraint`](@extref), `CTFlows.Flows._ocp_constrained_pseudo_hamiltonian`.
"""
_resolve_multiplier(::Any, spec::Data.Multiplier) = spec

"""
$(TYPEDSIGNATURES)

Resolve a `Function` multiplier spec into a [`CTBase.Data.Multiplier`](@extref),
inferring autonomy and variable-dependence from the OCP.

See also: [`CTFlows.Flows._resolve_multiplier`](@extref), [`CTBase.Data.Multiplier`](@extref).
"""
function _resolve_multiplier(ocp, spec::Function)
    return Data.Multiplier(
        spec; is_autonomous=Traits.is_autonomous(ocp), is_variable=Traits.is_variable(ocp)
    )
end

"""
$(TYPEDEF)

Carrier for a tuple of multipliers, paired element-wise with a
[`CTFlows.Flows._CombinedConstraint`](@extref). Its value concatenates the per-multiplier
values `μᵢ(t,x,p,v)` in the same order, so `sum(μ .* g)` = `Σᵢ μᵢ·gᵢ`. The traits are
those of the parts joined: non-autonomous if one part is, variable-dependent if one
part is; the natural calls follow them.

# Type Parameters
- `TD`, `VD`: joined time- and variable-dependence traits.
- `M <: Tuple`: type of the tuple of resolved per-multiplier carriers.

# Fields
- `parts::M`: the resolved per-multiplier carriers (each a [`CTBase.Data.Multiplier`](@extref)).

See also: [`CTFlows.Flows._resolve_multiplier`](@extref), [`CTFlows.Flows._CombinedConstraint`](@extref).
"""
struct _CombinedMultiplier{
    TD<:Traits.TimeDependence,VD<:Traits.VariableDependence,M<:Tuple
} <: Function
    parts::M
end

"""
$(TYPEDSIGNATURES)

Build a [`CTFlows.Flows._CombinedMultiplier`](@extref) with the joined traits of `parts`.
"""
function _CombinedMultiplier(parts::Tuple)
    TD = if all(μ -> Traits.time_dependence(μ) === Traits.Autonomous, parts)
        Traits.Autonomous
    else
        Traits.NonAutonomous
    end
    VD = if all(μ -> Traits.variable_dependence(μ) === Traits.Fixed, parts)
        Traits.Fixed
    else
        Traits.NonFixed
    end
    return _CombinedMultiplier{TD,VD,typeof(parts)}(parts)
end

"""
$(TYPEDSIGNATURES)

The joined traits `(TD, VD)` of a [`CTFlows.Flows._CombinedMultiplier`](@extref).
"""
_traits(::_CombinedMultiplier{TD,VD}) where {TD,VD} = (TD, VD)

"""
$(TYPEDSIGNATURES)

Value: concatenate (`vcat`) the per-multiplier values `μᵢ(t,x,p,v)` in tuple order.
"""
function _combined_value(m::_CombinedMultiplier, t, x, p, v)
    return reduce(vcat, map(μ -> μ(t, x, p, v), m.parts))
end

"""
$(TYPEDSIGNATURES)

Natural calls of a [`CTFlows.Flows._CombinedMultiplier`](@extref), one per pair of traits:
`(x, p)`, `(t, x, p)`, `(x, p, v)`, `(t, x, p, v)`. A missing time is `0.0`, a missing
variable an empty vector.
"""
(m::_CombinedMultiplier{Traits.Autonomous,Traits.Fixed})(x, p) =
    _combined_value(m, 0.0, x, p, Float64[])
(m::_CombinedMultiplier{Traits.NonAutonomous,Traits.Fixed})(t, x, p) =
    _combined_value(m, t, x, p, Float64[])
(m::_CombinedMultiplier{Traits.Autonomous,Traits.NonFixed})(x, p, v) =
    _combined_value(m, 0.0, x, p, v)
(m::_CombinedMultiplier{Traits.NonAutonomous,Traits.NonFixed})(t, x, p, v) =
    _combined_value(m, t, x, p, v)

"""
$(TYPEDSIGNATURES)

Resolve a `Tuple` of multiplier specs into a [`CTBase.Data.Multiplier`](@extref) wrapping a
[`CTFlows.Flows._CombinedMultiplier`](@extref), with the joined traits; rejects an empty
tuple with [`CTBase.Exceptions.IncorrectArgument`](@extref).

# Throws
- [`CTBase.Exceptions.IncorrectArgument`](@extref): when `spec` is an empty tuple.

See also: [`CTFlows.Flows._resolve_multiplier`](@extref),
[`CTFlows.Flows._CombinedMultiplier`](@extref).
"""
function _resolve_multiplier(ocp, spec::Tuple)
    isempty(spec) && throw(
        Exceptions.IncorrectArgument(
            "empty multiplier tuple";
            got="()",
            expected="a non-empty tuple of multipliers",
            context="Flow(ocp, law; multiplier=(…,)) — multiplier resolution",
        ),
    )
    m = _CombinedMultiplier(map(s -> _resolve_multiplier(ocp, s), spec))
    return Data.Multiplier(m, _traits(m)...)
end

"""
$(TYPEDSIGNATURES)

Throw an [`CTBase.Exceptions.IncorrectArgument`](@extref) for an unsupported multiplier
spec type. Only `Function`, `Tuple`, and [`CTBase.Data.Multiplier`](@extref) are accepted.

# Throws
- [`CTBase.Exceptions.IncorrectArgument`](@extref): when `spec` is not a supported type.

See also: [`CTFlows.Flows._resolve_multiplier`](@extref).
"""
function _resolve_multiplier(::Any, spec)
    return throw(
        Exceptions.IncorrectArgument(
            "unsupported multiplier specification";
            got="$(typeof(spec))",
            expected="a CTBase.Data.Multiplier or a Function",
            context="Flow(ocp, law; multiplier=…) — multiplier resolution",
        ),
    )
end

"""
$(TYPEDEF)

The constrained pseudo-Hamiltonian of a flow, with the multiplier as an explicit argument:
`H(t,x,p,u,μ,v) = H̃(t,x,p,u,v) + μ·g(t,x,u,v)`, where `H̃` is the pseudo-Hamiltonian of
the OCP ([`CTModels.Models.pseudo_hamiltonian`](@extref)) and `g` the constraint given to
the flow (uniform call `g(t,x,u,v)`). Wrapped in a
[`CTBase.Data.ConstrainedPseudoHamiltonian`](@extref) by
[`CTFlows.Flows._ocp_constrained_pseudo_hamiltonian`](@extref).

# Type Parameters
- `TD`, `VD`: time- and variable-dependence traits of the OCP (natural-arity dispatch).
- `H`: type of the pseudo-Hamiltonian `H̃`.
- `G`: type of the constraint carrier.

# Fields
- `h̃::H`: pseudo-Hamiltonian `H̃`, called uniformly as `H̃(t,x,p,u,v)`.
- `g::G`: constraint `g(t,x,u,v)`.

See also: [`CTFlows.Flows._resolve_constraint`](@extref).
"""
struct _AdjoinedConstraint{TD<:Traits.TimeDependence,VD<:Traits.VariableDependence,H,G} <:
       Function
    h̃::H
    g::G
end

"""
$(TYPEDSIGNATURES)

Value `H̃(t,x,p,u,v) + μ·g(t,x,u,v)`. The pairing `μ·g` uses `sum(μ .* g)`, for a scalar
or a vector constraint. When `v === nothing` (Fixed problems) an empty variable vector is
forwarded; the Fixed-trait uniform calls ignore it.

See also: [`CTFlows.Flows._AdjoinedConstraint`](@extref).
"""
function _adjoined_H(h::_AdjoinedConstraint, t, x, p, u, μ, v)
    vv = v === nothing ? Float64[] : v
    return h.h̃(t, x, p, u, vv) + sum(μ .* h.g(t, x, u, vv))
end

"""
$(TYPEDSIGNATURES)

Natural calls of a [`CTFlows.Flows._AdjoinedConstraint`](@extref), one per pair of traits:
`(x, p, u, μ)`, `(t, x, p, u, μ)`, `(x, p, u, μ, v)`, `(t, x, p, u, μ, v)`. An autonomous
problem is evaluated at `t = 0`.
"""
(h::_AdjoinedConstraint{_CTM_Auton,Traits.Fixed})(x, p, u, μ) =
    _adjoined_H(h, 0.0, x, p, u, μ, nothing)
(h::_AdjoinedConstraint{_CTM_NonAuton,Traits.Fixed})(t, x, p, u, μ) =
    _adjoined_H(h, t, x, p, u, μ, nothing)
(h::_AdjoinedConstraint{_CTM_Auton,Traits.NonFixed})(x, p, u, μ, v) =
    _adjoined_H(h, 0.0, x, p, u, μ, v)
(h::_AdjoinedConstraint{_CTM_NonAuton,Traits.NonFixed})(t, x, p, u, μ, v) =
    _adjoined_H(h, t, x, p, u, μ, v)

"""
$(TYPEDSIGNATURES)

The constrained pseudo-Hamiltonian `H(t,x,p,u,μ,v)` of a flow, from its `constraint`
specification:

- **labels** (a `Symbol` or a tuple of them; path constraints, state boxes and control
  boxes): built by [`CTModels.Models.pseudo_hamiltonian`](@extref)`(ocp; constraints=labels)`,
  with `μ` the dual of the solution (ct-conventions `SGN2`, `SGN3`), stacked in the order of
  the labels;
- **functions** (or [`CTBase.Data.PathConstraint`](@extref)s): `H̃ + μ·g` with `g ≥ 0` and
  `μ ≥ 0`, see [`CTFlows.Flows._ocp_constrained_pseudo_hamiltonian`](@extref).

See also: [`CTFlows.Flows._is_labelled`](@extref).
"""
function _constrained_pseudo_hamiltonian(ocp, cspec; p0=nothing)
    _is_labelled(cspec) && return CTModels.Models.pseudo_hamiltonian(
        ocp; constraints=_labels(cspec), _p0_kwargs(p0)...
    )
    return _ocp_constrained_pseudo_hamiltonian(ocp, _resolve_constraint(ocp, cspec); p0)
end

"""
$(TYPEDSIGNATURES)

The constrained pseudo-Hamiltonian `H(t,x,p,u,μ,v) = H̃(t,x,p,u,v) + μ·g(t,x,u,v)` of an
OCP and a resolved constraint `g`, as a [`CTBase.Data.ConstrainedPseudoHamiltonian`](@extref)
with the traits of the OCP. The `:partial` mode freezes the multiplier in it; the `:total`
mode composes it with the law and the multiplier.

See also: [`CTFlows.Flows._AdjoinedConstraint`](@extref),
[`CTFlows.Flows._resolve_constraint`](@extref).
"""
function _ocp_constrained_pseudo_hamiltonian(ocp, g; p0=nothing)
    TD = Traits.time_dependence(ocp)
    VD = Traits.variable_dependence(ocp)
    h̃ = _ocp_pseudo_hamiltonian(ocp; p0)
    raw = _AdjoinedConstraint{TD,VD,typeof(h̃),typeof(g)}(h̃, g)
    return Data.ConstrainedPseudoHamiltonian(raw, TD, VD)
end

# =============================================================================
# OCPControlledVectorFieldFunction — OCP controlled dynamics fc(t,x,u,v) = f(t,x,u,v)
#
# Out-of-place wrapper of the OCP in-place dynamics, for the OpenLoop/ClosedLoop
# (state-flow) path. Returns the state derivative (scalar for 1-D per convention).
# =============================================================================

"""
$(TYPEDEF)

Internal callable representing the controlled dynamics of an OCP, out-of-place:
`fc(t,x,u,v) = f(t,x,u,v)`. Wraps the OCP in-place dynamics; used (composed with an
open-loop or closed-loop control law) to build the state flow of the closed-loop system.

# Type Parameters
- `TD`, `VD`: time- and variable-dependence traits (compile-time dispatch on arity).
- `DF`: type of the in-place dynamics function.

# Fields
- `dynamics!::DF`: in-place dynamics `f!(r, t, x, u, v)` from the OCP.
- `n::Int`: state dimension.
- `cx::CX`, `cu::CU`, `cv::CV`: state / control / variable coercions (`only` for a 1-D
  quantity, `identity` otherwise), **precomputed once** from the OCP dimensions so the
  hot RHS path never tests a length at run time.

See also: [`CTBase.Data.ControlledVectorField`](@extref), `_ocp_controlled_vector_field`.
"""
struct OCPControlledVectorFieldFunction{
    TD<:Traits.TimeDependence,
    VD<:Traits.VariableDependence,
    DF<:Function,
    CX<:Union{typeof(Systems._safe_only),typeof(identity)},
    CU<:Union{typeof(Systems._safe_only),typeof(identity)},
    CV<:Union{typeof(Systems._safe_only),typeof(identity)},
} <: Function
    dynamics!::DF
    n::Int
    cx::CX
    cu::CU
    cv::CV
end

# 1-D = scalar: return a scalar when the state is a scalar, a vector otherwise.
"""
$(TYPEDSIGNATURES)

Collapse a length-1 result buffer to a scalar (1-D state convention).
"""
_finalize_vf(r, ::Number) = Systems._safe_only(r)
"""
$(TYPEDSIGNATURES)

Return the result buffer as-is for a `Vector` state — `r` already has this exact type
(see [`CTFlows.Systems._buffer_like`](@extref)), so this is an identity, no-allocation path.
"""
_finalize_vf(r, ::Vector) = r
"""
$(TYPEDSIGNATURES)

Reconstruct the result buffer in the state's own container type (e.g. `Vector` →
`SVector`/`MVector`), mirroring `Systems.OoPVFIpFinalizeRHS`. The internal buffer `r` is
always a plain `Vector` (see [`CTFlows.Systems._buffer_like`](@extref)); for an immutable
state container this conversion is required for OrdinaryDiffEq's out-of-place
type-constancy.
"""
_finalize_vf(r, xs::AbstractVector) = typeof(xs)(r)

"""
$(TYPEDSIGNATURES)

Return the result buffer as-is for a batched `Matrix` state (each column an independent
trajectory) — `r` already has this exact type (see [`CTFlows.Systems._buffer_like`](@extref)),
so this is an identity, no-allocation path.
"""
_finalize_vf(r, ::Matrix) = r
"""
$(TYPEDSIGNATURES)

Reconstruct the result buffer in the state's own container type (e.g. `Matrix` →
`SMatrix`/`MMatrix`) for a batched immutable-matrix state, for the same
out-of-place type-constancy reason as the `AbstractVector` method above.
"""
_finalize_vf(r, xs::AbstractMatrix) = typeof(xs)(r)

# Precomputed coercion from a declared dimension: `only` collapses a 1-D quantity to a
# scalar (accepting both a scalar and a length-1 vector), `identity` leaves n-D untouched.
"""
$(TYPEDSIGNATURES)

Precomputed coercion from a declared dimension: `only` collapses a 1-D quantity to a
scalar (accepting both a scalar and a length-1 vector), `identity` leaves n-D untouched.
"""
_dim_coerce(dim::Int) = dim == 1 ? Systems._safe_only : identity

"""
$(TYPEDSIGNATURES)

Apply a precomputed per-dimension coercion (`_dim_coerce`), except on a batched `Matrix`
value, which is always left untouched regardless of the declared dimension. `_dim_coerce`
is baked in once from the OCP's *declared* dimension, at flow-construction time, before
the shape of any future call-site value is known — it cannot itself special-case `Matrix`.
This guard is the runtime check that closes that gap, mirroring
`Systems._coerce_state(::AbstractMatrix) = identity`.

See also: [`CTFlows.Flows._dim_coerce`](@extref).
"""
_apply_dim_coerce(coerce, x::AbstractMatrix) = x

"""
$(TYPEDSIGNATURES)

Apply a precomputed per-dimension coercion to a non-batched value: returns `coerce(x)`
(`only` for 1-D, `identity` otherwise).

See also: [`CTFlows.Flows._apply_dim_coerce`](@extref), [`CTFlows.Flows._dim_coerce`](@extref).
"""
_apply_dim_coerce(coerce, x) = coerce(x)

"""
$(TYPEDSIGNATURES)

Core computation of the OCP controlled dynamics `fc(t,x,u,v)`: coerce `x`/`u`/`v` with
the precomputed per-dimension coercions (scalar for 1-D; a batched `Matrix` is always left
untouched via [`CTFlows.Flows._apply_dim_coerce`](@extref)), fill a buffer with the in-place
dynamics (`n_x × batch` for a `Matrix` state — see
[`CTFlows.Systems._buffer_like`](@extref)), and return it (scalar for a 1-D state).

See also: [`CTFlows.Flows.OCPControlledVectorFieldFunction`](@extref).
"""
function _ocp_controlled_vf(h::OCPControlledVectorFieldFunction, t, x, u, v)
    xs = _apply_dim_coerce(h.cx, x)
    us = _apply_dim_coerce(h.cu, u)
    if v === nothing
        T = Base.promote_op(*, eltype(xs), eltype(us))
        vv = Systems._buffer_like(xs, T, 0)
    else
        vs = _apply_dim_coerce(h.cv, v)
        T = Base.promote_op(*, Base.promote_op(*, eltype(xs), eltype(us)), eltype(vs))
        vv = vs
    end
    r = Systems._buffer_like(xs, T, h.n)
    h.dynamics!(r, t, xs, us, vv)
    return _finalize_vf(r, xs)
end

"""
$(TYPEDSIGNATURES)

Call operators for [`CTFlows.Flows.OCPControlledVectorFieldFunction`](@extref), dispatching on the
`(TD, VD)` trait pair for the correct arity:

| `TD` / `VD` | Call signature | Effective call |
|---|---|---|
| `Auton` / `Fixed` | `fc(x, u)` | `f(0, x, u)` |
| `NonAuton` / `Fixed` | `fc(t, x, u)` | `f(t, x, u)` |
| `Auton` / `NonFixed` | `fc(x, u, v)` | `f(0, x, u, v)` |
| `NonAuton` / `NonFixed` | `fc(t, x, u, v)` | `f(t, x, u, v)` |

See also: [`CTFlows.Flows.OCPControlledVectorFieldFunction`](@extref), [`CTFlows.Flows._ocp_controlled_vf`](@extref).
"""
function (h::OCPControlledVectorFieldFunction{_CTM_Auton,Traits.Fixed,DF})(
    x, u
) where {DF<:Function}
    return _ocp_controlled_vf(h, 0.0, x, u, nothing)
end

function (h::OCPControlledVectorFieldFunction{_CTM_NonAuton,Traits.Fixed,DF})(
    t, x, u
) where {DF<:Function}
    return _ocp_controlled_vf(h, t, x, u, nothing)
end

function (h::OCPControlledVectorFieldFunction{_CTM_Auton,Traits.NonFixed,DF})(
    x, u, v
) where {DF<:Function}
    return _ocp_controlled_vf(h, 0.0, x, u, v)
end

function (h::OCPControlledVectorFieldFunction{_CTM_NonAuton,Traits.NonFixed,DF})(
    t, x, u, v
) where {DF<:Function}
    return _ocp_controlled_vf(h, t, x, u, v)
end

"""
$(TYPEDSIGNATURES)

Build an [`CTFlows.Flows.OCPControlledVectorFieldFunction`](@extref) from an OCP and wrap it in a
[`CTBase.Data.ControlledVectorField`](@extref).

See also: [`CTFlows.Flows.OCPControlledVectorFieldFunction`](@extref), `CTFlows.Flows._ocp_pseudo_hamiltonian`.
"""
function _ocp_controlled_vector_field(ocp)
    n = CTModels.Models.state_dimension(ocp)
    dyn! = CTModels.Models.dynamics(ocp)
    cx = _dim_coerce(n)                                        # precomputed once
    cu = _dim_coerce(CTModels.Models.control_dimension(ocp))
    cv = _dim_coerce(CTModels.Models.variable_dimension(ocp))
    TD = Traits.time_dependence(ocp)
    VD = Traits.variable_dependence(ocp)
    fc_raw = OCPControlledVectorFieldFunction{
        TD,VD,typeof(dyn!),typeof(cx),typeof(cu),typeof(cv)
    }(
        dyn!, n, cx, cu, cv
    )
    return Data.ControlledVectorField(fc_raw, TD, VD)
end

# =============================================================================
# OCPStateVectorFieldFunction — OCP state dynamics without control g(t,x,v) = f(t,x,∅,v)
#
# Out-of-place wrapper of the OCP in-place dynamics with an empty control, for the basic
# (non-Hamiltonian, no costate) flow of a control-free OCP — direct-shooting use case
# (issue #230). Mirrors OCPControlledVectorFieldFunction with the control eliminated.
# =============================================================================

"""
$(TYPEDEF)

Internal callable representing the state dynamics of a control-free OCP, out-of-place:
`g(t,x,v) = f(t,x,∅,v)`. Used to build the basic state flow of `Flow(ocp)` for a
control-free problem — point evaluation and trajectory calls with **no costate**.

# Type Parameters
- `TD`, `VD`: time- and variable-dependence traits (compile-time dispatch on arity).
- `DF`: type of the in-place dynamics function.

# Fields
- `dynamics!::DF`: in-place dynamics `f!(r, t, x, u, v)` from the OCP (called with an
  empty `u`).
- `n::Int`: state dimension.
- `cx::CX`, `cv::CV`: state / variable coercions (`only` for a 1-D quantity, `identity`
  otherwise), precomputed once from the OCP dimensions.

See also: [`CTBase.Data.VectorField`](@extref), `CTFlows.Flows._ocp_state_vector_field`,
[`CTFlows.Flows.OCPControlledVectorFieldFunction`](@extref).
"""
struct OCPStateVectorFieldFunction{
    TD<:Traits.TimeDependence,
    VD<:Traits.VariableDependence,
    DF<:Function,
    CX<:Union{typeof(Systems._safe_only),typeof(identity)},
    CV<:Union{typeof(Systems._safe_only),typeof(identity)},
} <: Function
    dynamics!::DF
    n::Int
    cx::CX
    cv::CV
end

"""
$(TYPEDSIGNATURES)

Core computation of the control-free OCP state dynamics `g(t,x,v) = f(t,x,∅,v)`: coerce
`x`/`v` with the precomputed per-dimension coercions (scalar for 1-D; a batched `Matrix`
is always left untouched via [`CTFlows.Flows._apply_dim_coerce`](@extref)), fill a buffer
with the in-place dynamics called with an empty control (`n_x × batch` for a `Matrix`
state), and return it (scalar for a 1-D state).

See also: [`CTFlows.Flows.OCPStateVectorFieldFunction`](@extref).
"""
function _ocp_state_vf(h::OCPStateVectorFieldFunction, t, x, v)
    xs = _apply_dim_coerce(h.cx, x)
    if v === nothing
        T = eltype(xs)
        u = Systems._buffer_like(xs, T, 0)
        vv = u
    else
        vs = _apply_dim_coerce(h.cv, v)
        T = Base.promote_op(*, eltype(xs), eltype(vs))
        u = Systems._buffer_like(xs, T, 0)
        vv = vs
    end
    r = Systems._buffer_like(xs, T, h.n)
    h.dynamics!(r, t, xs, u, vv)
    return _finalize_vf(r, xs)
end

"""
$(TYPEDSIGNATURES)

Call operators for [`CTFlows.Flows.OCPStateVectorFieldFunction`](@extref), dispatching on the
`(TD, VD)` trait pair for the correct arity:

| `TD` / `VD` | Call signature | Effective call |
|---|---|---|
| `Auton` / `Fixed` | `g(x)` | `f(0, x, ∅)` |
| `NonAuton` / `Fixed` | `g(t, x)` | `f(t, x, ∅)` |
| `Auton` / `NonFixed` | `g(x, v)` | `f(0, x, ∅, v)` |
| `NonAuton` / `NonFixed` | `g(t, x, v)` | `f(t, x, ∅, v)` |

See also: [`CTFlows.Flows.OCPStateVectorFieldFunction`](@extref), [`CTFlows.Flows._ocp_state_vf`](@extref).
"""
function (h::OCPStateVectorFieldFunction{_CTM_Auton,Traits.Fixed,DF})(
    x
) where {DF<:Function}
    return _ocp_state_vf(h, 0.0, x, nothing)
end

function (h::OCPStateVectorFieldFunction{_CTM_NonAuton,Traits.Fixed,DF})(
    t, x
) where {DF<:Function}
    return _ocp_state_vf(h, t, x, nothing)
end

function (h::OCPStateVectorFieldFunction{_CTM_Auton,Traits.NonFixed,DF})(
    x, v
) where {DF<:Function}
    return _ocp_state_vf(h, 0.0, x, v)
end

function (h::OCPStateVectorFieldFunction{_CTM_NonAuton,Traits.NonFixed,DF})(
    t, x, v
) where {DF<:Function}
    return _ocp_state_vf(h, t, x, v)
end

"""
$(TYPEDSIGNATURES)

Build an [`CTFlows.Flows.OCPStateVectorFieldFunction`](@extref) from a control-free OCP and
wrap it in a [`CTBase.Data.VectorField`](@extref) (out-of-place).

See also: [`CTFlows.Flows.OCPStateVectorFieldFunction`](@extref), `CTFlows.Flows._ocp_controlled_vector_field`.
"""
function _ocp_state_vector_field(ocp)
    n = CTModels.Models.state_dimension(ocp)
    dyn! = CTModels.Models.dynamics(ocp)
    cx = _dim_coerce(n)                                        # precomputed once
    cv = _dim_coerce(CTModels.Models.variable_dimension(ocp))
    TD = Traits.time_dependence(ocp)
    VD = Traits.variable_dependence(ocp)
    g_raw = OCPStateVectorFieldFunction{TD,VD,typeof(dyn!),typeof(cx),typeof(cv)}(
        dyn!, n, cx, cv
    )
    return Data.VectorField(g_raw, TD, VD, Traits.OutOfPlace)
end

# =============================================================================
# OptimalControlFlow — thin AbstractFlow wrapper that carries the ocp reference
#
# The inner HamiltonianFlow handles all point-eval + variable_costate logic.
# This wrapper exists solely so the trajectory call can build a CTModels.Solution.
# =============================================================================

"""
$(TYPEDEF)

Flow of the Hamiltonian system associated with a (control-free) optimal control
problem, built by [`CTFlows.Flows.Flow`](@extref) from a
[`CTModels.Models.Model`](@extref).

It is a thin [`CTFlows.Flows.AbstractFlow`](@extref) wrapper around an inner
`HamiltonianFlow`: point evaluation delegates to the inner flow (returning the
final state–costate pair), while a trajectory call integrates the system and
rebuilds a full [`CTModels.Solutions.Solution`](@extref) from the problem.

# Type Parameters
- `TD <: TimeDependence`: time-dependence trait, inherited from the problem.
- `VD <: VariableDependence`: variable-dependence trait, inherited from the problem.
- `IF`: type of the inner `HamiltonianFlow`.
- `M`: type of the wrapped optimal control problem model.
- `CL`: type of the control law (`Nothing` for a control-free OCP, a
  `CTBase.Data.ControlLaw` when the flow was built from an OCP and a control law).
- `SF`: type of the inner control-free state flow (`Nothing` unless the OCP is
  control-free — see `state_flow`).
- `D`: type of the constraint duals (see `duals`).

# Fields
- `flow::IF`: the inner Hamiltonian flow doing the integration.
- `ocp::M`: the optimal control problem, kept so trajectory calls can build a solution.
- `law::CL`: the control law, used to reconstruct `u(t)` along the trajectory (or
  `nothing` for control-free problems).
- `state_flow::SF`: inner state flow of `ẋ = f(t,x,∅,v)`, built only for a control-free
  OCP (`Flow(ocp)`, no law); `nothing` otherwise. Backs the basic (no-costate) call
  arities `f(t0,x0,tf)` / `f((t0,tf),x0)` — see [`CTFlows.Flows._ocp_state_vector_field`](@extref).
- `label::String`: the label of the phase (`""` for no label), see [`CTFlows.Flows.label`](@extref).
- `duals::D`: the constraint duals of the flow, by label, rebuilt along a trajectory from
  the multiplier given to `Flow(ocp, law; constraint, multiplier)` (see
  [`CTFlows.Flows._flow_duals`](@extref)), or `nothing` for a control-free OCP.

See also: [`CTFlows.Flows.Flow`](@extref), [`CTModels.Solutions.Solution`](@extref).
"""
struct OptimalControlFlow{
    TD<:Traits.TimeDependence,VD<:Traits.VariableDependence,IF,M,CL,SF,D
} <: AbstractFlow{TD,VD,Traits.HamiltonianDynamics}
    flow::IF    # inner HamiltonianFlow
    ocp::M
    law::CL
    state_flow::SF
    label::String
    duals::D
end

"""
$(TYPEDSIGNATURES)

Construct a [`CTFlows.Flows.OptimalControlFlow`](@extref) from an inner Hamiltonian
[`CTFlows.Flows.Flow`](@extref), the OCP, an optional control law, an optional
control-free `state_flow` (see the `state_flow` field), and the optional path `duals`.
"""
function OptimalControlFlow(
    flow::Flow{TD,VD,Traits.HamiltonianDynamics},
    ocp,
    law=nothing;
    state_flow=nothing,
    label::AbstractString=__label(),
    duals=nothing,
) where {TD<:Traits.TimeDependence,VD<:Traits.VariableDependence}
    return OptimalControlFlow{
        TD,VD,typeof(flow),typeof(ocp),typeof(law),typeof(state_flow),typeof(duals)
    }(
        flow, ocp, law, state_flow, String(label), duals
    )
end

"""
$(TYPEDSIGNATURES)

Return the label of an [`CTFlows.Flows.OptimalControlFlow`](@extref).
"""
label(F::OptimalControlFlow)::String = F.label

"""
$(TYPEDSIGNATURES)

Return a copy of an [`CTFlows.Flows.OptimalControlFlow`](@extref) with the label `label`.
"""
function with_label(F::OptimalControlFlow, label::AbstractString)
    isempty(label) && return F
    return OptimalControlFlow(
        F.flow, F.ocp, F.law; state_flow=F.state_flow, label=label, duals=F.duals
    )
end

"""
$(TYPEDSIGNATURES)

Return the inner Hamiltonian system of an [`CTFlows.Flows.OptimalControlFlow`](@extref),
delegating to the inner flow.

See also: [`CTFlows.Flows.OptimalControlFlow`](@extref), [`CTFlows.Flows.system`](@extref).
"""
system(F::OptimalControlFlow) = system(F.flow)

"""
$(TYPEDSIGNATURES)

Return the integrator of an [`CTFlows.Flows.OptimalControlFlow`](@extref), delegating to
the inner flow.

See also: [`CTFlows.Flows.OptimalControlFlow`](@extref), [`CTFlows.Flows.integrator`](@extref).
"""
integrator(F::OptimalControlFlow) = integrator(F.flow)

# ── point eval — pure delegation ────────────────────────────────────────────

"""
$(TYPEDSIGNATURES)

Point-evaluation call for [`CTFlows.Flows.OptimalControlFlow`](@extref): delegate to the
inner Hamiltonian flow, returning `(xf, pf)` (and `pvf` when `variable_costate=true`).

# Throws
- [`CTBase.Exceptions.PreconditionError`](@extref): when the pre-v2.1.0-beta `augment`
  keyword is passed — it was renamed to `variable_costate`.

See also: [`CTFlows.Flows.OptimalControlFlow`](@extref).
"""
function (F::OptimalControlFlow)(
    t0::Real,
    x0,
    p0,
    tf::Real;
    variable=Core.NotProvided,
    variable_costate::Bool=false,
    unsafe::Bool=false,
    augment::Union{Nothing,Bool}=nothing,
)
    augment === nothing || throw(
        Exceptions.PreconditionError(
            "augment=$augment is not supported (removed in v2.1.0-beta)";
            reason="the `augment` keyword was renamed to `variable_costate`, with the same behaviour",
            suggestion="use variable_costate=$augment instead of augment=$augment",
            context="OptimalControlFlow point evaluation — deprecated `augment` keyword guard",
        ),
    )
    return F.flow(t0, x0, p0, tf; variable, variable_costate, unsafe)
end

# ── trajectory call — builds a CTModels.Solution ────────────────────────────

"""
$(TYPEDSIGNATURES)

Trajectory call for [`CTFlows.Flows.OptimalControlFlow`](@extref): integrate the inner
Hamiltonian flow over `tspan` and build a full [`CTModels.Solutions.Solution`](@extref)
via [`CTFlows.Flows._build_ocp_solution`](@extref).

# Keyword arguments
- `grid`: Output grid generated from the span: an integer `n`, `UniformGrid(n)` or `AdaptiveGrid(n)` (see [`CTFlows.Configs.AbstractGrid`](@extref)). Default: an [`CTFlows.Configs.AutomaticGrid`](@extref) (`AdaptiveGrid(250)` when the integration is dense and the solver returns fewer than 250 times), unless `saveat` or a grid of times already shapes the output; `grid=nothing` keeps the solver steps.
  The grid is generated once, by this call, over the inner trajectory (the inner flow is
  called with `grid=nothing`); the control is part of the plotted curves.
- `variable_costate::Bool=false`: accepted only so that `true` is rejected with a clear
  error; the variable costate is only available at point evaluation.

# Throws
- [`CTBase.Exceptions.PreconditionError`](@extref): when `variable_costate=true` is
  passed — the variable costate is only available at point evaluation,
  `F(t0, x0, p0, tf; variable_costate=true)`, not on a trajectory call.
- [`CTBase.Exceptions.PreconditionError`](@extref): when the pre-v2.1.0-beta `augment`
  keyword is passed — it is not supported on a trajectory call.

See also: [`CTFlows.Flows.OptimalControlFlow`](@extref),
[`CTFlows.Flows._build_ocp_solution`](@extref).
"""
function (F::OptimalControlFlow)(
    tspan::Configs.TimeSpec,
    x0,
    p0;
    variable=Core.NotProvided,
    variable_costate::Bool=false,
    unsafe::Bool=false,
    augment::Union{Nothing,Bool}=nothing,
    grid=__grid(),
)
    augment === nothing || throw(
        Exceptions.PreconditionError(
            "augment=$augment is not supported on a trajectory call";
            reason="augmentation was, and still is, only available at point evaluation — " *
                   "F(t0, x0, p0, tf; variable_costate=true) — not on a trajectory call; " *
                   "this matches v2.0, where `augment` had no effect here either",
            suggestion="use the point-evaluation call F(t0, x0, p0, tf; variable_costate=$augment) instead",
            context="OptimalControlFlow trajectory call — deprecated `augment` keyword guard",
        ),
    )
    spec = _call_grid_spec(tspan, grid, F)
    sol = F.flow(tspan, x0, p0; variable, variable_costate, unsafe, grid=nothing)   # HamiltonianVectorFieldTrajectory
    sol = _regrid_hamiltonian(sol, spec, F.law, variable, collect(float.(tspan)))
    switching = _ocp_switching_model(sol, F.law, variable, [label(F)]; duals=F.duals)
    return _build_ocp_solution(
        F.ocp, sol, variable, integrator(F.flow), F.law; switching=switching, duals=F.duals
    )
end

# ── basic (no-costate) point eval / trajectory — control-free OCP only ─────

"""
$(TYPEDSIGNATURES)

Return `F.state_flow`, or throw a [`CTBase.Exceptions.PreconditionError`](@extref) when
the flow was not built from a control-free OCP (`Flow(ocp)`) — a flow built with a
`DynClosedLoop` control law (`Flow(ocp, law)`) has no state-only flow, since its dynamics
depend on the costate `p(t)`.

See also: [`CTFlows.Flows.OptimalControlFlow`](@extref), [`CTFlows.Flows._ocp_state_vector_field`](@extref).
"""
function _require_state_flow(F::OptimalControlFlow)
    F.state_flow === nothing && throw(
        Exceptions.PreconditionError(
            "basic (no-costate) call requires a control-free OCP";
            reason="this flow was built from Flow(ocp, law) with a DynClosedLoop control " *
                   "law u(t,x,p,v); its dynamics depend on the costate p(t), so there is " *
                   "no state-only flow to call without one",
            suggestion="use f(t0, x0, p0, tf) — or f((t0,tf), x0, p0) for a trajectory",
            context="OptimalControlFlow(t0,x0,tf) — basic call, no costate",
        ),
    )
    return F.state_flow
end

"""
$(TYPEDSIGNATURES)

Basic (non-Hamiltonian) point evaluation, without a costate: `f(t0, x0, tf; variable)`.
Delegates to the inner control-free state flow — see
[`CTFlows.Flows._ocp_state_vector_field`](@extref). This is the direct-shooting use case
([#230](https://github.com/control-toolbox/CTFlows.jl/issues/230)).

# Throws
- [`CTBase.Exceptions.PreconditionError`](@extref): if the flow was built with a control
  law (`Flow(ocp, law)`) — use `f(t0,x0,p0,tf)` instead.
"""
function (F::OptimalControlFlow)(
    t0::Real, x0, tf::Real; variable=Core.NotProvided, unsafe::Bool=false
)
    xf = _require_state_flow(F)(t0, x0, tf; variable, unsafe)
    return _flow_state_coerce(F.ocp, x0)(xf)   # 1-D = scalar
end

"""
$(TYPEDSIGNATURES)

Basic (non-Hamiltonian) trajectory call, without a costate: `f((t0,tf), x0; variable)`.
Integrates the inner control-free state flow and builds a
[`CTFlows.Trajectories.StateFlowTrajectory`](@extref) (`law = nothing`: state and objective,
no control, no costate — `control`/`costate` throw a `PreconditionError`).

# Keyword arguments
- `grid`: Output grid generated from the span: an integer `n`, `UniformGrid(n)` or `AdaptiveGrid(n)` (see [`CTFlows.Configs.AbstractGrid`](@extref)). Default: an [`CTFlows.Configs.AutomaticGrid`](@extref) (`AdaptiveGrid(250)` when the integration is dense and the solver returns fewer than 250 times), unless `saveat` or a grid of times already shapes the output; `grid=nothing` keeps the solver steps.
  The grid is generated once, by this call (the inner flow is called with `grid=nothing`).

# Throws
- [`CTBase.Exceptions.PreconditionError`](@extref): if the flow was built with a control
  law (`Flow(ocp, law)`) — use `f((t0,tf),x0,p0)` instead.

See also: [`CTFlows.Trajectories.StateFlowTrajectory`](@extref), `CTFlows.Flows._state_flow_objective`.
"""
function (F::OptimalControlFlow)(
    tspan::Configs.TimeSpec,
    x0;
    variable=Core.NotProvided,
    unsafe::Bool=false,
    grid=__grid(),
)
    sf = _require_state_flow(F)
    spec = _call_grid_spec(tspan, grid, sf)
    traj = sf(tspan, x0; variable, unsafe, grid=nothing)   # VectorFieldTrajectory
    coerce = _flow_state_coerce(F.ocp, x0)   # precomputed once (only / identity)
    traj = _regrid_state(traj, spec, nothing, variable, coerce, collect(float.(tspan)))
    obj = _state_flow_objective(F.ocp, traj, nothing, variable, integrator(sf), coerce)
    traj = Trajectories.with_labels(traj, [label(F)])
    return Trajectories.StateFlowTrajectory(traj, nothing, variable, obj, coerce, F.ocp)
end

# =============================================================================
# Solution helpers
# =============================================================================

"""
$(TYPEDSIGNATURES)

Convert a variable argument into a `Vector{Float64}`.

Returns an empty vector when the variable was not provided (`Core.NotProvided`),
a 1-element vector for scalars, and a copy for vectors.

See also: `_build_ocp_solution`, `CTFlows.Flows._flow_objective`.
"""
_variable_vector(::Core.NotProvidedType) = Float64[]
"""
$(TYPEDSIGNATURES)

Wrap a scalar variable into a 1-element `Vector{Float64}`.

See also: [`CTFlows.Flows._variable_vector`](@extref).
"""
_variable_vector(v::Number) = [Float64(v)]
"""
$(TYPEDSIGNATURES)

Copy a vector variable into a `Vector{Float64}`.

See also: [`CTFlows.Flows._variable_vector`](@extref).
"""
_variable_vector(v::AbstractVector) = Float64.(v)

"""
$(TYPEDSIGNATURES)

Build a `CTModels.Solution` from a `HamiltonianVectorFieldTrajectory`.

Extracts the time grid, state/costate projections, and variable vector from the
trajectory, computes the objective via `CTFlows.Flows._flow_objective`, and assembles a
full `CTModels.Solution` with empty control (control-free OCP).

See also: [`CTFlows.Flows.OptimalControlFlow`](@extref), `CTFlows.Flows._flow_objective`, `CTFlows.Flows._control_of`, `CTFlows.Flows._variable_vector`, [`CTModels.Solutions.Solution`](@extref).
"""
function _build_ocp_solution(
    ocp,
    sol::Trajectories.HamiltonianVectorFieldTrajectory,
    variable,
    integ,
    law=nothing;
    switching::CTModels.Solutions.AbstractSwitchingModel=CTModels.Solutions.EmptySwitchingModel(),
    duals=nothing,
)
    T = collect(Float64, Trajectories.time_grid(sol))
    x = Trajectories.state(sol)    # callable StateProjection: t -> x(t)
    p = Trajectories.costate(sol)  # callable CostateProjection: t -> p(t)
    t0, tf = first(T), last(T)
    v = _variable_vector(variable)
    u = _control_of(law, x, p, v)  # empty for control-free; law(t,x,p,v) otherwise
    _warn_not_dense(sol)
    obj = _flow_objective(ocp, x, u, v, t0, tf, integ)
    return CTModels.Solutions.build_solution(
        ocp,
        T,
        x,
        u,
        v,
        p;
        objective=obj,
        message="Solution computed by CTFlows OCP flow",
        status=Integrators.status(sol),
        successful=Integrators.successful(sol),
        control_interpolation=:linear,
        switching=switching,
        duals=_solution_duals(duals, x, p, v),
        infos=Dict{Symbol,Any}(:missing_duals => _missing_duals_note(duals)),
    )
end

"""
$(TYPEDSIGNATURES)

Build the switching structure of the `Solution` of an OCP flow from its Hamiltonian
trajectory: the switching times of the trajectory, the phase labels `labels` (one per
phase), and the left and right limits of the state, costate and control at every switching
time. The control limits come from the law: the left limit from the law of the phase that
ends (at the values before the jump), the right one from the law of the next phase (at the
values after it), see [`CTFlows.Flows._right_ocp_control`](@extref). The limits of the duals
of the constraints, by label, come from the `duals` of the flow in the same way, see
[`CTFlows.Flows._switching_duals`](@extref).

Returns an [`CTModels.Solutions.EmptySwitchingModel`](@extref) when there is no switching
time and no label.
"""
function _ocp_switching_model(
    sol::Trajectories.HamiltonianVectorFieldTrajectory,
    law,
    variable,
    labels::AbstractVector{<:AbstractString};
    duals=nothing,
)
    taus = Trajectories.switching_times(sol)
    n = length(taus)
    n == 0 && all(isempty, labels) && return CTModels.Solutions.EmptySwitchingModel()
    v = _variable_vector(variable)
    xl = [Trajectories.left_limit(sol, :state, i) for i in 1:n]
    xr = [Trajectories.right_limit(sol, :state, i) for i in 1:n]
    pl = [Trajectories.left_limit(sol, :costate, i) for i in 1:n]
    pr = [Trajectories.right_limit(sol, :costate, i) for i in 1:n]
    control = if law === nothing
        (zeros(n, 0), zeros(n, 0))   # control-free: no control component
    else
        (
            _limit_rows([law(taus[i], xl[i], pl[i], v) for i in 1:n]),
            _limit_rows([
                _right_ocp_control(law, i, taus[i], xr[i], pr[i], v) for i in 1:n
            ]),
        )
    end
    return CTModels.Solutions.SwitchingModel(;
        times=taus,
        labels=labels,
        state=(_limit_rows(xl), _limit_rows(xr)),
        costate=(_limit_rows(pl), _limit_rows(pr)),
        control=control,
        duals=_switching_duals(duals, taus, xl, xr, pl, pr, v),
    )
end

"""
$(TYPEDSIGNATURES)

Control just after the `i`-th switching time `t`, from the state `x` and costate `p` after
the jump. A single law has no phase, so it is the law itself; `CTFlows.MultiPhase` adds the
method of the piecewise law of a multi-phase flow (the law of the next phase).
"""
_right_ocp_control(law, ::Integer, t, x, p, v) = law(t, x, p, v)

"""
$(TYPEDSIGNATURES)

Stack values (scalars for one component, vectors otherwise) as the rows of a matrix: one
row per switching time. No value gives a `0 × 0` matrix.
"""
function _limit_rows(values::AbstractVector)::Matrix{Float64}
    isempty(values) && return zeros(0, 0)
    return Matrix{Float64}(permutedims(reduce(hcat, (vcat(x) for x in values))))
end
