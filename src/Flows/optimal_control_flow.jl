# =============================================================================
# OCPHamiltonianFunctionFunction, OptimalControlFlow, and solution builder
# =============================================================================

# =============================================================================
# OCPHamiltonianFunction — OCP Hamiltonian H(t,x,p,v) = p·f(t,x,∅,v) + sp0·ℓ(t,x,∅,v)
#
# TD/VD are compile-time parameters so dispatch selects the right natural-arity
# method without runtime branches.  A single _ocp_H core does the work; the state
# (and variable) are passed to the dynamics as received — scalar for 1-D, vector for
# n-D — per the "1-D = scalar" convention (CTModels stores the dynamics verbatim and
# imposes no shape). The derivative buffer r is always a length-n_x vector.
#
# sp0 = s·p⁰ where p⁰=-1: sp0=-1 for :min, sp0=+1 for :max.
# =============================================================================

"""
$(TYPEDEF)

Internal callable representing the Hamiltonian of a control-free optimal control problem.

Computes `H(t,x,p,v) = p·f(t,x,∅,v) + sp0·ℓ(t,x,∅,v)` where `sp0 = s·p⁰` with `p⁰=-1`
(`sp0=-1` for `:min`, `sp0=+1` for `:max`). The time-dependence (`TD`) and
variable-dependence (`VD`) traits are compile-time parameters so that dispatch
selects the correct natural-arity call signature without runtime branches.

# Type Parameters
- `TD`: time-dependence trait (`Autonomous` or `NonAutonomous`).
- `VD`: variable-dependence trait (`Fixed` or `NonFixed`).
- `DF`: type of the in-place dynamics function.
- `LF`: type of the Lagrange cost function (or `Nothing`).

# Fields
- `dynamics!::DF`: in-place dynamics `f!(r, t, x, u, v)` from the OCP.
- `lagrange::LF`: Lagrange cost `ℓ(t, x, u, v)` or `nothing` if absent.
- `sp0::Float64`: sign-weighted multiplier `s·p⁰`.
- `n::Int`: state dimension.

See also: [`CTFlows.Flows.OptimalControlFlow`](@ref), `CTFlows.Flows._ocp_H`, `CTFlows.Flows._ocp_hamiltonian`.
"""
struct OCPHamiltonianFunction{
    TD<:Traits.TimeDependence,
    VD<:Traits.VariableDependence,
    DF<:Function,
    LF<:Union{Function,Nothing},
} <: Function
    dynamics!::DF
    lagrange::LF
    sp0::Float64
    n::Int
end

# Aliases to keep method signatures concise
const _CTM_Auton = CTModels.Components.Autonomous
const _CTM_NonAuton = CTModels.Components.NonAutonomous

"""
$(TYPEDSIGNATURES)

Core computation of the OCP Hamiltonian value `H(t,x,p,v)`.

Passes `x` (and the variable `v`) to the in-place dynamics **as received** — a scalar
for a 1-dimensional quantity, a vector otherwise (the ecosystem "1-D = scalar"
convention) — and accumulates `p·f + sp0·ℓ`. The derivative buffer `r` is always a
length-`n_x` vector. When `v === nothing` the variable is an empty vector (used by
`Fixed`-trait call paths).

See also: [`CTFlows.Flows.OCPHamiltonianFunction`](@ref).
"""
function _ocp_H(h::OCPHamiltonianFunction, t, x, p, v)
    if v === nothing
        T = eltype(x)
        u = Vector{T}(undef, 0)          # empty control (control-free) and variable (Fixed)
        r = Vector{T}(undef, h.n)
        h.dynamics!(r, t, x, u, u)       # x passed as-is (scalar for 1-D per convention)
        val = sum(p .* r)
        h.lagrange === nothing || (val += h.sp0 * h.lagrange(t, x, u, u))
    else
        T = Base.promote_op(*, eltype(x), eltype(v))
        u = Vector{T}(undef, 0)          # empty control (control-free)
        r = Vector{T}(undef, h.n)
        h.dynamics!(r, t, x, u, v)       # x, v passed as-is
        val = sum(p .* r)
        h.lagrange === nothing || (val += h.sp0 * h.lagrange(t, x, u, v))
    end
    return val
end

function (h::OCPHamiltonianFunction{_CTM_Auton,Traits.Fixed,DF,LF})(
    x, p
) where {DF<:Function,LF<:Union{Function,Nothing}}
    return _ocp_H(h, 0.0, x, p, nothing)
end
function (h::OCPHamiltonianFunction{_CTM_NonAuton,Traits.Fixed,DF,LF})(
    t, x, p
) where {DF<:Function,LF<:Union{Function,Nothing}}
    return _ocp_H(h, t, x, p, nothing)
end
function (h::OCPHamiltonianFunction{_CTM_Auton,Traits.NonFixed,DF,LF})(
    x, p, v
) where {DF<:Function,LF<:Union{Function,Nothing}}
    return _ocp_H(h, 0.0, x, p, v)
end
function (h::OCPHamiltonianFunction{_CTM_NonAuton,Traits.NonFixed,DF,LF})(
    t, x, p, v
) where {DF<:Function,LF<:Union{Function,Nothing}}
    return _ocp_H(h, t, x, p, v)
end

# =============================================================================
# _ocp_hamiltonian — builds an OCPHamiltonianFunction wrapped in Data.Hamiltonian
# =============================================================================

"""
$(TYPEDSIGNATURES)

Build an `OCPHamiltonianFunction` from a control-free OCP and wrap it in a
`Data.Hamiltonian`.

Extracts the state dimension, dynamics, criterion sign, Lagrange cost, and
time/variable-dependence traits from the OCP, then constructs a typed
`OCPHamiltonianFunction` and wraps it so the downstream AD pipeline receives a
uniform `(t, x, p, v)` interface.

See also: [`CTFlows.Flows.OCPHamiltonianFunction`](@ref), [`CTFlows.Flows.OptimalControlFlow`](@ref), [`CTFlows.Flows.Flow`](@ref).
"""
function _ocp_hamiltonian(ocp)
    n = CTModels.Models.state_dimension(ocp)
    dyn! = CTModels.Models.dynamics(ocp)
    sp0 = CTModels.Components.criterion(ocp) === :min ? -1.0 : 1.0   # s*p⁰, p⁰=-1
    lag = if CTModels.Components.has_lagrange_cost(ocp)
        CTModels.Components.lagrange(ocp)
    else
        nothing
    end
    TD = Traits.time_dependence(ocp)       # Traits.Autonomous or NonAutonomous
    VD = Traits.variable_dependence(ocp)   # Traits.Fixed or Traits.NonFixed
    h_raw = OCPHamiltonianFunction{TD,VD,typeof(dyn!),typeof(lag)}(dyn!, lag, sp0, n)
    return Data.Hamiltonian(h_raw, TD, VD)   # typed ctor → uniform (t,x,p,v) interface for AD
end

# =============================================================================
# OCPPseudoHamiltonianFunction — OCP pseudo-Hamiltonian
#   H̃(t,x,p,u,v) = p·f(t,x,u,v) + sp0·ℓ(t,x,u,v)
#
# Same pattern as OCPHamiltonianFunction, but the control u is an explicit argument
# (not eliminated). Used for both the :total path (composed with a control law via
# Data.ComposedHamiltonian) and the :partial path (PseudoHamiltonianSystem).
# =============================================================================

"""
$(TYPEDEF)

Internal callable representing the pseudo-Hamiltonian of an optimal control problem:
`H̃(t,x,p,u,v) = p·f(t,x,u,v) + sp0·ℓ(t,x,u,v)` with `sp0 = s·p⁰` (`p⁰=-1`). Unlike
[`OCPHamiltonianFunction`](@ref), the control `u` is an explicit argument.

# Type Parameters
- `TD`, `VD`: time- and variable-dependence traits (compile-time dispatch on arity).
- `DF`: type of the in-place dynamics function.
- `LF`: type of the Lagrange cost function (or `Nothing`).

# Fields
- `dynamics!::DF`: in-place dynamics `f!(r, t, x, u, v)` from the OCP.
- `lagrange::LF`: Lagrange cost `ℓ(t, x, u, v)` or `nothing`.
- `sp0::Float64`: sign-weighted multiplier `s·p⁰`.
- `n::Int`: state dimension.

See also: [`CTFlows.Flows.OCPHamiltonianFunction`](@ref), `CTFlows.Flows._ocp_pseudo_hamiltonian`,
[`CTBase.Data.PseudoHamiltonian`](@extref).
"""
struct OCPPseudoHamiltonianFunction{
    TD<:Traits.TimeDependence,
    VD<:Traits.VariableDependence,
    DF<:Function,
    LF<:Union{Function,Nothing},
} <: Function
    dynamics!::DF
    lagrange::LF
    sp0::Float64
    n::Int
end

"""
$(TYPEDSIGNATURES)

Core computation of the OCP pseudo-Hamiltonian value `H̃(t,x,p,u,v)`. Passes `x`, `u`
(and the variable `v`) to the in-place dynamics **as received** — scalar for a
1-dimensional quantity, vector otherwise ("1-D = scalar" convention) — and accumulates
`p·f + sp0·ℓ`. The derivative buffer `r` is always a length-`n_x` vector.

See also: [`CTFlows.Flows.OCPPseudoHamiltonianFunction`](@ref).
"""
function _ocp_pseudo_H(h::OCPPseudoHamiltonianFunction, t, x, p, u, v)
    if v === nothing
        T = Base.promote_op(*, eltype(x), eltype(u))
        vv = Vector{T}(undef, 0)   # empty variable for Fixed problems
    else
        T = Base.promote_op(*, Base.promote_op(*, eltype(x), eltype(u)), eltype(v))
        vv = v
    end
    r = Vector{T}(undef, h.n)      # in-place derivative buffer (always length n_x)
    h.dynamics!(r, t, x, u, vv)    # x, u, v passed as-is (scalar for 1-D per convention)
    val = sum(p .* r)             # p·f — sum handles scalar p (1-D) or vector p (n-D)
    h.lagrange === nothing || (val += h.sp0 * h.lagrange(t, x, u, vv))
    return val
end

function (h::OCPPseudoHamiltonianFunction{_CTM_Auton,Traits.Fixed,DF,LF})(
    x, p, u
) where {DF<:Function,LF<:Union{Function,Nothing}}
    return _ocp_pseudo_H(h, 0.0, x, p, u, nothing)
end
function (h::OCPPseudoHamiltonianFunction{_CTM_NonAuton,Traits.Fixed,DF,LF})(
    t, x, p, u
) where {DF<:Function,LF<:Union{Function,Nothing}}
    return _ocp_pseudo_H(h, t, x, p, u, nothing)
end
function (h::OCPPseudoHamiltonianFunction{_CTM_Auton,Traits.NonFixed,DF,LF})(
    x, p, u, v
) where {DF<:Function,LF<:Union{Function,Nothing}}
    return _ocp_pseudo_H(h, 0.0, x, p, u, v)
end
function (h::OCPPseudoHamiltonianFunction{_CTM_NonAuton,Traits.NonFixed,DF,LF})(
    t, x, p, u, v
) where {DF<:Function,LF<:Union{Function,Nothing}}
    return _ocp_pseudo_H(h, t, x, p, u, v)
end

"""
$(TYPEDSIGNATURES)

Build an [`CTFlows.Flows.OCPPseudoHamiltonianFunction`](@ref) from an OCP and wrap it in a
[`CTBase.Data.PseudoHamiltonian`](@extref), giving the uniform `(t,x,p,u,v)` interface
used by the pseudo-Hamiltonian AD pipeline.

See also: [`CTFlows.Flows.OCPPseudoHamiltonianFunction`](@ref), `CTFlows.Flows._ocp_hamiltonian`.
"""
function _ocp_pseudo_hamiltonian(ocp)
    n = CTModels.Models.state_dimension(ocp)
    dyn! = CTModels.Models.dynamics(ocp)
    sp0 = CTModels.Components.criterion(ocp) === :min ? -1.0 : 1.0
    lag = if CTModels.Components.has_lagrange_cost(ocp)
        CTModels.Components.lagrange(ocp)
    else
        nothing
    end
    TD = Traits.time_dependence(ocp)
    VD = Traits.variable_dependence(ocp)
    h_raw = OCPPseudoHamiltonianFunction{TD,VD,typeof(dyn!),typeof(lag)}(dyn!, lag, sp0, n)
    return Data.PseudoHamiltonian(h_raw, TD, VD)
end

# =============================================================================
# Constrained pseudo-Hamiltonian: H(t,x,p,u,v) = H̃(t,x,p,u,v) + μ(t,x,p,v)·g(t,x,u,v)
#
# Wraps an OCPPseudoHamiltonianFunction with a path constraint g and a multiplier μ.
# Used only for the :total differentiation mode: the whole functor is composed with the
# control law via Data.ComposedHamiltonian, so AD differentiates through H̃, μ, g and the
# law (total derivative). For :partial, μ must be frozen in the RHS functor (PR 4).
#
# The constraint g is called uniformly as g(t,x,u,v) and the multiplier μ as μ(t,x,p,v);
# both carriers ignore the arguments their traits do not use.
# =============================================================================

"""
$(TYPEDSIGNATURES)

Resolve a `constraint` specification into a [`CTBase.Data.PathConstraint`](@extref).

- `spec::Symbol` is a `:path` constraint **label**: resolved via
  [`CTModels.Models.constraint`](@extref), which returns an out-of-place `g(t,x,u,v)`.
  Rejected with [`CTBase.Exceptions.IncorrectArgument`](@extref) if the label is not a
  `:path` constraint (e.g. `:boundary` or a box constraint). The functor is wrapped as a
  **non-autonomous, non-fixed** [`CTBase.Data.MixedConstraint`](@extref) so its uniform
  call `g(t,x,u,v)` forwards verbatim to the resolved functor.
- `spec::CTBase.Data.PathConstraint` is used as-is.
- `spec::Function` is a raw function with the OCP's natural arity (`(x,u)`, `(t,x,u)`,
  `(x,u,v)` or `(t,x,u,v)`), wrapped in a [`CTBase.Data.MixedConstraint`](@extref) with the
  OCP's time/variable dependence.
- `spec::Tuple` is a non-empty tuple of simultaneous constraints, each resolved recursively
  and wrapped in a [`CTFlows.Flows._CombinedConstraint`](@ref) (empty tuple rejected with
  [`CTBase.Exceptions.IncorrectArgument`](@extref)).

See also: [`CTFlows.Flows._resolve_multiplier`](@ref), `CTFlows.Flows._ocp_constrained_pseudo_hamiltonian`.
"""
function _resolve_constraint(ocp, spec::Symbol)
    kind, g_oop, _, _ = CTModels.Models.constraint(ocp, spec)
    kind === :path || throw(
        Exceptions.IncorrectArgument(
            "constraint label :$spec is not a path constraint";
            got=":$kind constraint",
            expected="a :path constraint label",
            context="Flow(ocp, law; constraint=:$spec) — label resolution",
        ),
    )
    # The label functor is always the full uniform arity g(t,x,u,v); wrap it as a
    # non-autonomous, non-fixed MixedConstraint so its uniform call forwards verbatim.
    return Data.MixedConstraint(g_oop; is_autonomous=false, is_variable=true)
end

_resolve_constraint(::Any, spec::Data.PathConstraint) = spec

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
[`CTFlows.Flows._CombinedMultiplier`](@ref) built from the matching multiplier tuple.

# Type Parameters
- `G <: Tuple`: type of the tuple of resolved per-constraint carriers.

# Fields
- `parts::G`: the resolved per-constraint carriers (each a [`CTBase.Data.PathConstraint`](@extref)).

See also: [`CTFlows.Flows._resolve_constraint`](@ref), [`CTFlows.Flows._CombinedMultiplier`](@ref).
"""
struct _CombinedConstraint{G<:Tuple}
    parts::G
end

"""
$(TYPEDSIGNATURES)

Uniform call: concatenate (`vcat`) the per-constraint values `gᵢ(t,x,u,v)` in tuple order.
"""
(c::_CombinedConstraint)(t, x, u, v) = reduce(vcat, map(g -> g(t, x, u, v), c.parts))

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

function _resolve_constraint(::Any, spec)
    return throw(
        Exceptions.IncorrectArgument(
            "unsupported constraint specification";
            got="$(typeof(spec))",
            expected="a :path label (Symbol), a CTBase.Data.PathConstraint, or a Function",
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
  a [`CTFlows.Flows._CombinedMultiplier`](@ref) — matched element-wise with the constraint
  tuple (empty tuple rejected with [`CTBase.Exceptions.IncorrectArgument`](@extref)).

See also: [`CTFlows.Flows._resolve_constraint`](@ref), `CTFlows.Flows._ocp_constrained_pseudo_hamiltonian`.
"""
_resolve_multiplier(::Any, spec::Data.Multiplier) = spec

function _resolve_multiplier(ocp, spec::Function)
    return Data.Multiplier(
        spec; is_autonomous=Traits.is_autonomous(ocp), is_variable=Traits.is_variable(ocp)
    )
end

"""
$(TYPEDEF)

Carrier for a tuple of multipliers, paired element-wise with a
[`CTFlows.Flows._CombinedConstraint`](@ref). Its uniform call concatenates the per-multiplier
values `μᵢ(t,x,p,v)` in the same order, so `sum(μ .* g)` = `Σᵢ μᵢ·gᵢ`.

# Type Parameters
- `M <: Tuple`: type of the tuple of resolved per-multiplier carriers.

# Fields
- `parts::M`: the resolved per-multiplier carriers (each a [`CTBase.Data.Multiplier`](@extref)).

See also: [`CTFlows.Flows._resolve_multiplier`](@ref), [`CTFlows.Flows._CombinedConstraint`](@ref).
"""
struct _CombinedMultiplier{M<:Tuple}
    parts::M
end

"""
$(TYPEDSIGNATURES)

Uniform call: concatenate (`vcat`) the per-multiplier values `μᵢ(t,x,p,v)` in tuple order.
"""
(m::_CombinedMultiplier)(t, x, p, v) = reduce(vcat, map(μ -> μ(t, x, p, v), m.parts))

function _resolve_multiplier(ocp, spec::Tuple)
    isempty(spec) && throw(
        Exceptions.IncorrectArgument(
            "empty multiplier tuple";
            got="()",
            expected="a non-empty tuple of multipliers",
            context="Flow(ocp, law; multiplier=(…,)) — multiplier resolution",
        ),
    )
    return _CombinedMultiplier(map(s -> _resolve_multiplier(ocp, s), spec))
end

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

Internal callable representing the **constrained** pseudo-Hamiltonian of an OCP:
`H(t,x,p,u,v) = H̃(t,x,p,u,v) + μ(t,x,p,v)·g(t,x,u,v)`, where `H̃` is an
[`OCPPseudoHamiltonianFunction`](@ref), `g` a [`CTBase.Data.PathConstraint`](@extref)
(uniform call `g(t,x,u,v)`) and `μ` a [`CTBase.Data.Multiplier`](@extref) (uniform call
`μ(t,x,p,v)`).

Used for the `:total` differentiation mode only: the whole functor is composed with the
control law via [`CTBase.Data.ComposedHamiltonian`](@extref), so AD differentiates through
`H̃`, `μ`, `g` and the law (total derivative). The `(TD, VD)` traits drive natural-arity
dispatch exactly as for [`OCPPseudoHamiltonianFunction`](@ref).

# Type Parameters
- `TD`, `VD`: time- and variable-dependence traits (compile-time dispatch on arity).
- `H`: type of the base pseudo-Hamiltonian functor.
- `G`: type of the path-constraint carrier.
- `M`: type of the multiplier carrier.

# Fields
- `h̃::H`: base pseudo-Hamiltonian `H̃(t,x,p,u,v)`.
- `g::G`: path constraint `g(t,x,u,v)`.
- `μ::M`: multiplier `μ(t,x,p,v)`.

See also: [`OCPPseudoHamiltonianFunction`](@ref), `CTFlows.Flows._ocp_constrained_pseudo_hamiltonian`.
"""
struct ConstrainedPseudoHamiltonianFunction{
    TD<:Traits.TimeDependence,
    VD<:Traits.VariableDependence,
    H<:OCPPseudoHamiltonianFunction,
    G,
    M,
} <: Function
    h̃::H
    g::G
    μ::M
end

"""
$(TYPEDSIGNATURES)

Core computation of the constrained pseudo-Hamiltonian value
`H̃(t,x,p,u,v) + μ(t,x,p,v)·g(t,x,u,v)`. The pairing `μ·g` uses `sum(μ .* g)` so it
handles both scalar (1-D) and vector constraints (matching the `p·f` idiom in
[`CTFlows.Flows._ocp_pseudo_H`](@ref)). When `v === nothing` (Fixed problems) an empty
variable vector is forwarded to `μ`/`g`; their Fixed-trait uniform calls ignore it.

See also: [`CTFlows.Flows.ConstrainedPseudoHamiltonianFunction`](@ref).
"""
function _constrained_pseudo_H(h::ConstrainedPseudoHamiltonianFunction, t, x, p, u, v)
    base = _ocp_pseudo_H(h.h̃, t, x, p, u, v)
    vv = v === nothing ? Float64[] : v
    return base + sum(h.μ(t, x, p, vv) .* h.g(t, x, u, vv))
end

function (h::ConstrainedPseudoHamiltonianFunction{_CTM_Auton,Traits.Fixed})(x, p, u)
    return _constrained_pseudo_H(h, 0.0, x, p, u, nothing)
end
function (h::ConstrainedPseudoHamiltonianFunction{_CTM_NonAuton,Traits.Fixed})(t, x, p, u)
    return _constrained_pseudo_H(h, t, x, p, u, nothing)
end
function (h::ConstrainedPseudoHamiltonianFunction{_CTM_Auton,Traits.NonFixed})(x, p, u, v)
    return _constrained_pseudo_H(h, 0.0, x, p, u, v)
end
function (h::ConstrainedPseudoHamiltonianFunction{_CTM_NonAuton,Traits.NonFixed})(
    t, x, p, u, v
)
    return _constrained_pseudo_H(h, t, x, p, u, v)
end

"""
$(TYPEDSIGNATURES)

Build a [`CTFlows.Flows.ConstrainedPseudoHamiltonianFunction`](@ref) from an OCP, a
resolved path constraint `g` and a resolved multiplier `μ`, wrapped in a
[`CTBase.Data.PseudoHamiltonian`](@extref) so it flows into the `:total` pipeline exactly
like the unconstrained [`CTFlows.Flows._ocp_pseudo_hamiltonian`](@ref).

See also: [`CTFlows.Flows.ConstrainedPseudoHamiltonianFunction`](@ref),
[`CTFlows.Flows._resolve_constraint`](@ref), [`CTFlows.Flows._resolve_multiplier`](@ref).
"""
function _ocp_constrained_pseudo_hamiltonian(ocp, g, μ)
    n = CTModels.Models.state_dimension(ocp)
    dyn! = CTModels.Models.dynamics(ocp)
    sp0 = CTModels.Components.criterion(ocp) === :min ? -1.0 : 1.0
    lag = if CTModels.Components.has_lagrange_cost(ocp)
        CTModels.Components.lagrange(ocp)
    else
        nothing
    end
    TD = Traits.time_dependence(ocp)
    VD = Traits.variable_dependence(ocp)
    h̃_raw = OCPPseudoHamiltonianFunction{TD,VD,typeof(dyn!),typeof(lag)}(dyn!, lag, sp0, n)
    raw = ConstrainedPseudoHamiltonianFunction{TD,VD,typeof(h̃_raw),typeof(g),typeof(μ)}(
        h̃_raw, g, μ
    )
    return Data.PseudoHamiltonian(raw, TD, VD)
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
    CX<:Union{typeof(only),typeof(identity)},
    CU<:Union{typeof(only),typeof(identity)},
    CV<:Union{typeof(only),typeof(identity)},
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
_finalize_vf(r, ::Number) = only(r)
"""
$(TYPEDSIGNATURES)

Return the result buffer as-is for an n-D (vector) state.
"""
_finalize_vf(r, ::AbstractVector) = r

# Precomputed coercion from a declared dimension: `only` collapses a 1-D quantity to a
# scalar (accepting both a scalar and a length-1 vector), `identity` leaves n-D untouched.
"""
$(TYPEDSIGNATURES)

Precomputed coercion from a declared dimension: `only` collapses a 1-D quantity to a
scalar (accepting both a scalar and a length-1 vector), `identity` leaves n-D untouched.
"""
_dim_coerce(dim::Int) = dim == 1 ? only : identity

"""
$(TYPEDSIGNATURES)

Core computation of the OCP controlled dynamics `fc(t,x,u,v)`: coerce `x`/`u`/`v` with
the precomputed per-dimension coercions (scalar for 1-D), fill a length-`n_x` buffer with
the in-place dynamics, and return it (scalar for a 1-D state).

See also: [`CTFlows.Flows.OCPControlledVectorFieldFunction`](@ref).
"""
function _ocp_controlled_vf(h::OCPControlledVectorFieldFunction, t, x, u, v)
    xs = h.cx(x)
    us = h.cu(u)
    if v === nothing
        T = Base.promote_op(*, eltype(xs), eltype(us))
        vv = Vector{T}(undef, 0)
    else
        vs = h.cv(v)
        T = Base.promote_op(*, Base.promote_op(*, eltype(xs), eltype(us)), eltype(vs))
        vv = vs
    end
    r = Vector{T}(undef, h.n)
    h.dynamics!(r, t, xs, us, vv)
    return _finalize_vf(r, xs)
end

"""
Call operators for [`CTFlows.Flows.OCPControlledVectorFieldFunction`](@ref), dispatching on the
`(TD, VD)` trait pair for the correct arity:

| `TD` / `VD` | Call signature | Effective call |
|---|---|---|
| `Auton` / `Fixed` | `fc(x, u)` | `f(0, x, u)` |
| `NonAuton` / `Fixed` | `fc(t, x, u)` | `f(t, x, u)` |
| `Auton` / `NonFixed` | `fc(x, u, v)` | `f(0, x, u, v)` |
| `NonAuton` / `NonFixed` | `fc(t, x, u, v)` | `f(t, x, u, v)` |

See also: [`CTFlows.Flows.OCPControlledVectorFieldFunction`](@ref), [`CTFlows.Flows._ocp_controlled_vf`](@ref).
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

Build an [`CTFlows.Flows.OCPControlledVectorFieldFunction`](@ref) from an OCP and wrap it in a
[`CTBase.Data.ControlledVectorField`](@extref).

See also: [`CTFlows.Flows.OCPControlledVectorFieldFunction`](@ref), `CTFlows.Flows._ocp_pseudo_hamiltonian`.
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
# OptimalControlFlow — thin AbstractFlow wrapper that carries the ocp reference
#
# The inner HamiltonianFlow handles all point-eval + variable_costate logic.
# This wrapper exists solely so the trajectory call can build a CTModels.Solution.
# =============================================================================

"""
$(TYPEDEF)

Flow of the Hamiltonian system associated with a (control-free) optimal control
problem, built by [`CTFlows.Flows.Flow`](@ref) from a
[`CTModels.Models.Model`](@extref).

It is a thin [`CTFlows.Flows.AbstractFlow`](@ref) wrapper around an inner
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

# Fields
- `flow::IF`: the inner Hamiltonian flow doing the integration.
- `ocp::M`: the optimal control problem, kept so trajectory calls can build a solution.
- `law::CL`: the control law, used to reconstruct `u(t)` along the trajectory (or
  `nothing` for control-free problems).

See also: [`CTFlows.Flows.Flow`](@ref), [`CTModels.Solutions.Solution`](@extref).
"""
struct OptimalControlFlow{
    TD<:Traits.TimeDependence,VD<:Traits.VariableDependence,IF,M,CL
} <: AbstractFlow{TD,VD,Traits.HamiltonianDynamics}
    flow::IF    # inner HamiltonianFlow
    ocp::M
    law::CL
end

function OptimalControlFlow(
    flow::Flow{TD,VD,Traits.HamiltonianDynamics}, ocp, law=nothing
) where {TD<:Traits.TimeDependence,VD<:Traits.VariableDependence}
    return OptimalControlFlow{TD,VD,typeof(flow),typeof(ocp),typeof(law)}(flow, ocp, law)
end

system(F::OptimalControlFlow) = system(F.flow)
integrator(F::OptimalControlFlow) = integrator(F.flow)

# ── point eval — pure delegation ────────────────────────────────────────────

function (F::OptimalControlFlow)(
    t0::Real,
    x0,
    p0,
    tf::Real;
    variable=Core.NotProvided,
    variable_costate::Bool=false,
    unsafe::Bool=false,
)
    return F.flow(t0, x0, p0, tf; variable, variable_costate, unsafe)
end

# ── trajectory call — builds a CTModels.Solution ────────────────────────────

function (F::OptimalControlFlow)(
    tspan::Tuple{<:Real,<:Real}, x0, p0; variable=Core.NotProvided, unsafe::Bool=false
)
    sol = F.flow(tspan, x0, p0; variable, unsafe)   # HamiltonianVectorFieldTrajectory
    return _build_ocp_solution(F.ocp, sol, variable, integrator(F.flow), F.law)
end

# =============================================================================
# Solution helpers
# =============================================================================

"""
Convert a variable argument into a `Vector{Float64}`.

Returns an empty vector when the variable was not provided (`Core.NotProvided`),
a 1-element vector for scalars, and a copy for vectors.

See also: `_build_ocp_solution`, `_ocp_objective`.
"""
_variable_vector(::Core.NotProvidedType) = Float64[]
_variable_vector(v::Number) = [Float64(v)]
_variable_vector(v::AbstractVector) = Float64.(v)

"""
Reconstruct the control `u(t)` along a trajectory from a control law and the
state/costate projections. Returns `t -> Float64[]` when there is no control law
(control-free OCP), and `t -> law(t, x(t), p(t), v)` otherwise.

See also: `_ocp_objective`, `_build_ocp_solution`.
"""
_control_of(::Nothing, x, p, v) = (_ -> Float64[])
_control_of(law, x, p, v) = (t -> law(t, x(t), p(t), v))

"""
$(TYPEDSIGNATURES)

Compute the objective value (Mayer + Lagrange) of an OCP along a trajectory.

The Mayer term is evaluated at the endpoints `x(t0)` and `x(tf)`. The Lagrange term is
integrated by flowing `ℓ̇(t) = ℓ(t, x(t), u(t), v)` from `t0` to `tf`, where `u(t)` is
reconstructed from the control law (empty for a control-free OCP).

See also: `CTFlows.Flows._build_ocp_solution`, `CTFlows.Flows._control_of`, `CTFlows.Flows._variable_vector`, [`CTFlows.Flows.Flow`](@ref).
"""
function _ocp_objective(ocp, x, p, v, t0, tf, integ, law)
    obj = 0.0
    if CTModels.Components.has_mayer_cost(ocp)
        may = CTModels.Components.mayer(ocp)
        obj += may(x(t0), x(tf), v)
    end
    if CTModels.Components.has_lagrange_cost(ocp)
        lag = CTModels.Components.lagrange(ocp)
        uc = _control_of(law, x, p, v)
        # Integrate ℓ̇(t) = lag(t, x(t), u(t), v) from t0 to tf.
        # Use a 1-element Vector so SciML always has a mutable in-place buffer.
        running = Data.VectorField(
            (t, ℓ_vec) -> [lag(t, x(t), uc(t), v)]; is_autonomous=false, is_variable=false
        )
        cost_flow = build_flow(Systems.build_system(running), integ)
        ℓ_tf = cost_flow(t0, [0.0], tf)   # returns [ℓ(tf)]
        obj += ℓ_tf[1]
    end
    return obj
end

"""
$(TYPEDSIGNATURES)

Build a `CTModels.Solution` from a `HamiltonianVectorFieldTrajectory`.

Extracts the time grid, state/costate projections, and variable vector from the
trajectory, computes the objective via `CTFlows.Flows._ocp_objective`, and assembles a full
`CTModels.Solution` with empty control (control-free OCP).

See also: [`CTFlows.Flows.OptimalControlFlow`](@ref), `CTFlows.Flows._ocp_objective`, `CTFlows.Flows._variable_vector`, [`CTModels.Solutions.Solution`](@extref).
"""
function _build_ocp_solution(
    ocp, sol::Trajectories.HamiltonianVectorFieldTrajectory, variable, integ, law=nothing
)
    T = collect(Float64, Trajectories.time_grid(sol))
    x = Trajectories.state(sol)    # callable StateProjection: t -> x(t)
    p = Trajectories.costate(sol)  # callable CostateProjection: t -> p(t)
    t0, tf = first(T), last(T)
    v = _variable_vector(variable)
    u = _control_of(law, x, p, v)  # empty for control-free; law(t,x,p,v) otherwise
    obj = _ocp_objective(ocp, x, p, v, t0, tf, integ, law)
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
    )
end
