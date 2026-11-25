# =============================================================================
# Hamiltonian / pseudo-Hamiltonian getters and gradient getters
#
# These round out the getter API of §2 of the roadmap. They are convenience
# accessors (evaluated occasionally, e.g. in a shooting function), not the hot
# integrated RHS — so they return lightweight closures over the system's
# Hamiltonian and AD backend rather than dedicated functors.
#
# The gradient functors take the uniform signature accepted by the
# `CTBase.Differentiation` primitives:
#   - true Hamiltonian:   `(t, x, p, v)`      → `H(t, x, p, v)`
#   - pseudo-Hamiltonian: `(t, x, p, u, v)`   → `H̃(t, x, p, u, v)`
# and, like `hamiltonian(sys)` / `pseudo_hamiltonian(sys)`, the short form allowed by the
# traits (`(x, p)`, `(t, x, p)`, `(x, p, v)`; `(x, p, u)`, ...), with `x`/`p` in the shape
# the Hamiltonian expects (scalar in dimension 1).
# =============================================================================

"""
$(TYPEDSIGNATURES)

Return the pseudo-Hamiltonian underlying a `HamiltonianSystem` built in the `:total` mode
of an OCP-with-control (or pseudo-Hamiltonian + control law) flow. The control is *not*
eliminated:

- the system wraps a [`CTBase.Data.ComposedHamiltonian`](@extref): `H̃(t, x, p, u, v)`;
- the system wraps a [`CTBase.Data.ComposedConstrainedHamiltonian`](@extref) (constrained
  flow): the constrained pseudo-Hamiltonian `H(t, x, p, u, μ, v)`, with the multiplier
  explicit too — the same object as in the `:partial` mode.

# Throws
- `CTBase.Exceptions.IncorrectArgument`: if the system wraps a plain Hamiltonian with
  no associated control law (no pseudo-Hamiltonian to recover).

See also: [`CTFlows.Systems.hamiltonian`](@extref), [`CTFlows.Systems.control_law`](@extref).
"""
function Data.pseudo_hamiltonian(sys::HamiltonianSystem)
    h = sys.h
    h isa Data.ComposedHamiltonian && return h.h̃
    h isa Data.ComposedConstrainedHamiltonian && return Data.pseudo_hamiltonian(h)
    return throw(
        Exceptions.IncorrectArgument(
            "no pseudo-Hamiltonian available for this HamiltonianSystem";
            got="a HamiltonianSystem wrapping $(nameof(typeof(h)))",
            expected="a HamiltonianSystem wrapping a ComposedHamiltonian (:total mode from a control law)",
            suggestion="Build the flow from an OCP (or pseudo-Hamiltonian) and a control law, or query pseudo_hamiltonian on a PseudoHamiltonianSystem",
            context="pseudo_hamiltonian(sys::HamiltonianSystem)",
        ),
    )
end

"""
$(TYPEDSIGNATURES)

Return the control law `u(t, x, p, v)` of a `HamiltonianSystem` built in the `:total`
mode (wrapping a [`CTBase.Data.ComposedHamiltonian`](@extref) or a
[`CTBase.Data.ComposedConstrainedHamiltonian`](@extref)).

# Throws
- `CTBase.Exceptions.IncorrectArgument`: if the system wraps a plain Hamiltonian with
  no associated control law.

See also: [`CTFlows.Systems.pseudo_hamiltonian`](@extref).
"""
function Data.control_law(sys::HamiltonianSystem)
    h = sys.h
    h isa Data.ComposedHamiltonian && return h.law
    h isa Data.ComposedConstrainedHamiltonian && return Data.control_law(h)
    return throw(
        Exceptions.IncorrectArgument(
            "no control law available for this HamiltonianSystem";
            got="a HamiltonianSystem wrapping $(nameof(typeof(h)))",
            expected="a HamiltonianSystem wrapping a ComposedHamiltonian (:total mode from a control law)",
            suggestion="Build the flow from an OCP (or pseudo-Hamiltonian) and a control law",
            context="control_law(sys::HamiltonianSystem)",
        ),
    )
end

"""
$(TYPEDSIGNATURES)

Return the multiplier `μ(t, x, p, v)` of a `HamiltonianSystem` built in the `:total` mode
of a constrained flow (wrapping a [`CTBase.Data.ComposedConstrainedHamiltonian`](@extref))
— the same object as in the `:partial` mode.

# Throws
- `CTBase.Exceptions.IncorrectArgument`: if the system is not a constrained flow.

See also: [`CTFlows.Systems.pseudo_hamiltonian`](@extref).
"""
function Data.multiplier(sys::HamiltonianSystem)
    h = sys.h
    h isa Data.ComposedConstrainedHamiltonian && return Data.multiplier(h)
    return throw(
        Exceptions.IncorrectArgument(
            "no multiplier available for this HamiltonianSystem";
            got="a HamiltonianSystem wrapping $(nameof(typeof(h)))",
            expected="a HamiltonianSystem wrapping a ComposedConstrainedHamiltonian (constrained :total flow)",
            suggestion="Build the flow from an OCP, a control law, a constraint and a multiplier",
            context="multiplier(sys::HamiltonianSystem)",
        ),
    )
end

# -----------------------------------------------------------------------------
# Gradient getters — callable structs (functors), not closures.
#
# Each getter returns a small functor holding the Hamiltonian and the AD backend;
# calling it evaluates the corresponding `CTBase.Differentiation` primitive. This
# follows the callable-struct convention of the RHS functors (see
# `hamiltonian_rhs_functors.jl`) rather than returning anonymous closures. These
# types could later be promoted to `CTBase.Data`/`CTBase.Differentiation` next to
# `HamiltonianVectorField` — see issue #245.
# -----------------------------------------------------------------------------

"""
$(TYPEDEF)

Functor returning the gradient `(∂H/∂x, ∂H/∂p)` of a true Hamiltonian, evaluated as
`(t, x, p, v)` or, like the Hamiltonian itself, in the short form its traits allow:
`(x, p)`, `(t, x, p)` or `(x, p, v)`. For a Hamiltonian composed with a control law, the gradient is the
**total** derivative (differentiated through the law). The tuple is non-negated.

# Fields
- `h::H`: the Hamiltonian to differentiate.
- `backend::B`: the AD backend.

See also: [`CTFlows.Systems.get_hamiltonian_gradient`](@extref), [`CTFlows.Systems.HamiltonianVariableGradient`](@extref).
"""
struct HamiltonianGradient{H<:Data.AbstractHamiltonian,B<:Differentiation.AbstractADBackend}
    h::H
    backend::B
end

function (g::HamiltonianGradient)(t, x, p, v)
    return Differentiation.hamiltonian_gradient(g.backend, g.h, t, x, p, v)
end

# Short forms, as for the Hamiltonian itself: the arguments its traits do not use are
# dropped (autonomous: no `t`; fixed: no `v`).
function (g::HamiltonianGradient{
    <:Data.AbstractHamiltonian{Traits.Autonomous,Traits.Fixed}
})(
    x, p
)
    return g(0.0, x, p, nothing)
end
function (g::HamiltonianGradient{
    <:Data.AbstractHamiltonian{Traits.NonAutonomous,Traits.Fixed}
})(
    t, x, p
)
    return g(t, x, p, nothing)
end
function (g::HamiltonianGradient{
    <:Data.AbstractHamiltonian{Traits.Autonomous,Traits.NonFixed}
})(
    x, p, v
)
    return g(0.0, x, p, v)
end

"""
$(TYPEDEF)

Functor returning the variable gradient `∂H/∂v` of a true Hamiltonian, evaluated as
`(t, x, p, v)` (or `(x, p, v)` for an autonomous Hamiltonian) — the quantity (before
negation) that drives the augmented variable-costate equation `ṗv = -∂H/∂v`. Non-negated.

# Fields
- `h::H`: the Hamiltonian to differentiate.
- `backend::B`: the AD backend.

See also: [`CTFlows.Systems.get_variable_gradient`](@extref), [`CTFlows.Systems.HamiltonianGradient`](@extref).
"""
struct HamiltonianVariableGradient{
    H<:Data.AbstractHamiltonian,B<:Differentiation.AbstractADBackend
}
    h::H
    backend::B
end

function (g::HamiltonianVariableGradient)(t, x, p, v)
    return Differentiation.variable_gradient(g.backend, g.h, t, x, p, v)
end

# Short form for an autonomous Hamiltonian (the variable gradient needs `v`).
function (g::HamiltonianVariableGradient{
    <:Data.AbstractHamiltonian{Traits.Autonomous,Traits.NonFixed}
})(
    x, p, v
)
    return g(0.0, x, p, v)
end

"""
$(TYPEDEF)

Functor returning the gradient `(∂H̃/∂x, ∂H̃/∂p)` of a pseudo-Hamiltonian, evaluated as
`(t, x, p, u, v)` at **fixed control** `u`, or in the short form the pseudo-Hamiltonian's
traits allow: `(x, p, u)`, `(t, x, p, u)` or `(x, p, u, v)`. Non-negated.

# Fields
- `h̃::H`: the pseudo-Hamiltonian to differentiate.
- `backend::B`: the AD backend.

See also: [`CTFlows.Systems.get_pseudo_hamiltonian_gradient`](@extref), [`CTFlows.Systems.PseudoHamiltonianVariableGradient`](@extref).
"""
struct PseudoHamiltonianGradient{
    H<:Data.AbstractPseudoHamiltonian,B<:Differentiation.AbstractADBackend
}
    h̃::H
    backend::B
end

function (g::PseudoHamiltonianGradient)(t, x, p, u, v)
    return Differentiation.pseudo_hamiltonian_gradient(g.backend, g.h̃, t, x, p, u, v)
end

# Short forms, as for the pseudo-Hamiltonian itself (autonomous: no `t`; fixed: no `v`).
function (g::PseudoHamiltonianGradient{
    <:Data.AbstractPseudoHamiltonian{Traits.Autonomous,Traits.Fixed}
})(
    x, p, u
)
    return g(0.0, x, p, u, nothing)
end
function (g::PseudoHamiltonianGradient{
    <:Data.AbstractPseudoHamiltonian{Traits.NonAutonomous,Traits.Fixed}
})(
    t, x, p, u
)
    return g(t, x, p, u, nothing)
end
function (g::PseudoHamiltonianGradient{
    <:Data.AbstractPseudoHamiltonian{Traits.Autonomous,Traits.NonFixed}
})(
    x, p, u, v
)
    return g(0.0, x, p, u, v)
end

"""
$(TYPEDEF)

Functor returning the variable gradient `∂H̃/∂v` of a pseudo-Hamiltonian, evaluated as
`(t, x, p, u, v)` (or `(x, p, u, v)` for an autonomous pseudo-Hamiltonian) at **fixed
control** `u`. Non-negated.

# Fields
- `h̃::H`: the pseudo-Hamiltonian to differentiate.
- `backend::B`: the AD backend.

See also: [`CTFlows.Systems.get_pseudo_variable_gradient`](@extref), [`CTFlows.Systems.PseudoHamiltonianGradient`](@extref).
"""
struct PseudoHamiltonianVariableGradient{
    H<:Data.AbstractPseudoHamiltonian,B<:Differentiation.AbstractADBackend
}
    h̃::H
    backend::B
end

function (g::PseudoHamiltonianVariableGradient)(t, x, p, u, v)
    return Differentiation.pseudo_variable_gradient(g.backend, g.h̃, t, x, p, u, v)
end

# Short form for an autonomous pseudo-Hamiltonian (the variable gradient needs `v`).
function (g::PseudoHamiltonianVariableGradient{
    <:Data.AbstractPseudoHamiltonian{Traits.Autonomous,Traits.NonFixed}
})(
    x, p, u, v
)
    return g(0.0, x, p, u, v)
end

"""
$(TYPEDEF)

Functor returning the gradient `(∂H/∂x, ∂H/∂p)` of a constrained pseudo-Hamiltonian
`H(t, x, p, u, μ, v)`, evaluated as `(t, x, p, u, μ, v)` at **fixed control** `u` **and
fixed multiplier** `μ` — the partial derivatives of the PMP, those integrated by the
`:partial` mode — or in the short form the traits allow: `(x, p, u, μ)`,
`(t, x, p, u, μ)` or `(x, p, u, μ, v)`. Non-negated. It differentiates
[`CTBase.Data.freeze_multiplier`](@extref)`(H, μ)`.

# Fields
- `h::H`: the constrained pseudo-Hamiltonian to differentiate.
- `backend::B`: the AD backend.

See also: [`CTFlows.Systems.get_pseudo_hamiltonian_gradient`](@extref), [`CTFlows.Systems.PseudoHamiltonianGradient`](@extref).
"""
struct ConstrainedPseudoHamiltonianGradient{
    H<:Data.ConstrainedPseudoHamiltonian,B<:Differentiation.AbstractADBackend
}
    h::H
    backend::B
end

function (g::ConstrainedPseudoHamiltonianGradient)(t, x, p, u, μ, v)
    h̃ = Data.freeze_multiplier(g.h, μ)
    return Differentiation.pseudo_hamiltonian_gradient(g.backend, h̃, t, x, p, u, v)
end

# Short forms, as for the constrained pseudo-Hamiltonian itself.
function (g::ConstrainedPseudoHamiltonianGradient{
    <:Data.ConstrainedPseudoHamiltonian{<:Function,Traits.Autonomous,Traits.Fixed}
})(
    x, p, u, μ
)
    return g(0.0, x, p, u, μ, nothing)
end
function (g::ConstrainedPseudoHamiltonianGradient{
    <:Data.ConstrainedPseudoHamiltonian{<:Function,Traits.NonAutonomous,Traits.Fixed}
})(
    t, x, p, u, μ
)
    return g(t, x, p, u, μ, nothing)
end
function (g::ConstrainedPseudoHamiltonianGradient{
    <:Data.ConstrainedPseudoHamiltonian{<:Function,Traits.Autonomous,Traits.NonFixed}
})(
    x, p, u, μ, v
)
    return g(0.0, x, p, u, μ, v)
end

"""
$(TYPEDEF)

Functor returning the variable gradient `∂H/∂v` of a constrained pseudo-Hamiltonian
`H(t, x, p, u, μ, v)`, evaluated as `(t, x, p, u, μ, v)` (or `(x, p, u, μ, v)` when
autonomous) at **fixed control** `u` **and fixed multiplier** `μ`. Non-negated.

# Fields
- `h::H`: the constrained pseudo-Hamiltonian to differentiate.
- `backend::B`: the AD backend.

See also: [`CTFlows.Systems.get_pseudo_variable_gradient`](@extref), [`CTFlows.Systems.ConstrainedPseudoHamiltonianGradient`](@extref).
"""
struct ConstrainedPseudoHamiltonianVariableGradient{
    H<:Data.ConstrainedPseudoHamiltonian,B<:Differentiation.AbstractADBackend
}
    h::H
    backend::B
end

function (g::ConstrainedPseudoHamiltonianVariableGradient)(t, x, p, u, μ, v)
    h̃ = Data.freeze_multiplier(g.h, μ)
    return Differentiation.pseudo_variable_gradient(g.backend, h̃, t, x, p, u, v)
end

# Short form for an autonomous constrained pseudo-Hamiltonian (the variable gradient needs `v`).
function (g::ConstrainedPseudoHamiltonianVariableGradient{
    <:Data.ConstrainedPseudoHamiltonian{<:Function,Traits.Autonomous,Traits.NonFixed}
})(
    x, p, u, μ, v
)
    return g(0.0, x, p, u, μ, v)
end

"""
$(TYPEDSIGNATURES)

Return a [`CTFlows.Systems.HamiltonianGradient`](@extref) functor `(t, x, p, v) ->
(∂H/∂x, ∂H/∂p)` for the true Hamiltonian of an AD-backed Hamiltonian system. For a
`PseudoHamiltonianSystem` (or a `:total` `HamiltonianSystem`), the gradient is the
**total** derivative — it differentiates through the control law.

The `ad_backend` keyword selects the AD backend used to differentiate; it defaults to
the system's own backend but can be overridden (e.g. to use reverse mode for the
gradient).

See also: [`CTFlows.Systems.hamiltonian`](@extref), [`CTFlows.Systems.get_variable_gradient`](@extref).
"""
function get_hamiltonian_gradient(
    sys::Union{HamiltonianSystem,PseudoHamiltonianSystem};
    ad_backend::Differentiation.AbstractADBackend=backend(sys),
)
    return HamiltonianGradient(hamiltonian(sys), ad_backend)
end

"""
$(TYPEDSIGNATURES)

Return a [`CTFlows.Systems.HamiltonianVariableGradient`](@extref) functor `(t, x, p, v) ->
∂H/∂v` for the true Hamiltonian of an AD-backed Hamiltonian system — the same quantity
(before negation) that drives the augmented variable-costate equation `ṗv = -∂H/∂v`.

The `ad_backend` keyword selects the AD backend (default: the system's own backend).

See also: [`CTFlows.Systems.get_hamiltonian_gradient`](@extref).
"""
function get_variable_gradient(
    sys::Union{HamiltonianSystem,PseudoHamiltonianSystem};
    ad_backend::Differentiation.AbstractADBackend=backend(sys),
)
    return HamiltonianVariableGradient(hamiltonian(sys), ad_backend)
end

"""
$(TYPEDSIGNATURES)

Return the gradient functor of the pseudo-Hamiltonian returned by
[`CTFlows.Systems.pseudo_hamiltonian`](@extref)`(sys)`, differentiated at **fixed control**:

- unconstrained flow: a [`CTFlows.Systems.PseudoHamiltonianGradient`](@extref)
  `(t, x, p, u, v) -> (∂H̃/∂x, ∂H̃/∂p)`;
- constrained flow (`:total` or `:partial`): a
  [`CTFlows.Systems.ConstrainedPseudoHamiltonianGradient`](@extref)
  `(t, x, p, u, μ, v) -> (∂H/∂x, ∂H/∂p)`, at fixed `u` **and** `μ` — the partial
  derivatives of the PMP, the same in both modes.

Available for a `PseudoHamiltonianSystem`, a `ConstrainedPseudoHamiltonianSystem`, and a
`:total` `HamiltonianSystem` built from a control law.

The `ad_backend` keyword selects the AD backend (default: the system's own backend).

See also: [`CTFlows.Systems.pseudo_hamiltonian`](@extref), [`CTFlows.Systems.get_pseudo_variable_gradient`](@extref).
"""
function get_pseudo_hamiltonian_gradient(
    sys::Union{
        HamiltonianSystem,PseudoHamiltonianSystem,ConstrainedPseudoHamiltonianSystem
    };
    ad_backend::Differentiation.AbstractADBackend=backend(sys),
)
    return _pseudo_gradient(pseudo_hamiltonian(sys), ad_backend)
end

"""
$(TYPEDSIGNATURES)

Return the variable-gradient functor of the pseudo-Hamiltonian returned by
[`CTFlows.Systems.pseudo_hamiltonian`](@extref)`(sys)`, at **fixed control**: a
[`CTFlows.Systems.PseudoHamiltonianVariableGradient`](@extref) `(t, x, p, u, v) -> ∂H̃/∂v`,
or, on a constrained flow, a
[`CTFlows.Systems.ConstrainedPseudoHamiltonianVariableGradient`](@extref)
`(t, x, p, u, μ, v) -> ∂H/∂v` at fixed `u` and `μ`.

The `ad_backend` keyword selects the AD backend (default: the system's own backend).

See also: [`CTFlows.Systems.get_pseudo_hamiltonian_gradient`](@extref).
"""
function get_pseudo_variable_gradient(
    sys::Union{
        HamiltonianSystem,PseudoHamiltonianSystem,ConstrainedPseudoHamiltonianSystem
    };
    ad_backend::Differentiation.AbstractADBackend=backend(sys),
)
    return _pseudo_variable_gradient(pseudo_hamiltonian(sys), ad_backend)
end

"""
$(TYPEDSIGNATURES)

The gradient functor of the pseudo-Hamiltonian `h`: a
[`CTFlows.Systems.PseudoHamiltonianGradient`](@extref) for `H̃(t, x, p, u, v)`, a
[`CTFlows.Systems.ConstrainedPseudoHamiltonianGradient`](@extref) for a constrained
`H(t, x, p, u, μ, v)` (multiplier explicit, as returned by `pseudo_hamiltonian(sys)` on a
constrained flow).

See also: [`CTFlows.Systems.get_pseudo_hamiltonian_gradient`](@extref).
"""
_pseudo_gradient(h̃::Data.AbstractPseudoHamiltonian, b) = PseudoHamiltonianGradient(h̃, b)
function _pseudo_gradient(h::Data.ConstrainedPseudoHamiltonian, b)
    return ConstrainedPseudoHamiltonianGradient(h, b)
end

"""
$(TYPEDSIGNATURES)

The variable-gradient functor of the pseudo-Hamiltonian `h`, unconstrained or constrained;
see [`CTFlows.Systems._pseudo_gradient`](@extref).

See also: [`CTFlows.Systems.get_pseudo_variable_gradient`](@extref).
"""
function _pseudo_variable_gradient(h̃::Data.AbstractPseudoHamiltonian, b)
    return PseudoHamiltonianVariableGradient(h̃, b)
end
function _pseudo_variable_gradient(h::Data.ConstrainedPseudoHamiltonian, b)
    return ConstrainedPseudoHamiltonianVariableGradient(h, b)
end
