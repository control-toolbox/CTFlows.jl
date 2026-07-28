# =============================================================================
# Hamiltonian / pseudo-Hamiltonian getters and gradient getters
#
# These round out the getter API of §2 of the roadmap. They are convenience
# accessors (evaluated occasionally, e.g. in a shooting function), not the hot
# integrated RHS — so they return lightweight closures over the system's
# Hamiltonian and AD backend rather than dedicated functors.
#
# The gradient closures use the uniform signature accepted by the
# `CTBase.Differentiation` primitives:
#   - true Hamiltonian:   `(t, x, p, v)`      → `H(t, x, p, v)`
#   - pseudo-Hamiltonian: `(t, x, p, u, v)`   → `H̃(t, x, p, u, v)`
# with `x`/`p` in the shape the Hamiltonian expects (scalar in dimension 1),
# exactly as the user would call `hamiltonian(sys)` / `pseudo_hamiltonian(sys)`.
# =============================================================================

"""
$(TYPEDSIGNATURES)

Return the pseudo-Hamiltonian `H̃` underlying a `HamiltonianSystem`, when the system
wraps a [`CTBase.Data.ComposedHamiltonian`](@extref) — i.e. it was built in the
`:total` mode of an OCP-with-control (or pseudo-Hamiltonian + control law) flow. The
control is *not* eliminated: `H̃(t, x, p, u, v)` keeps `u` as an independent argument.

# Throws
- `CTBase.Exceptions.IncorrectArgument`: if the system wraps a plain Hamiltonian with
  no associated control law (no pseudo-Hamiltonian to recover).

See also: [`CTFlows.Systems.hamiltonian`](@ref), [`CTFlows.Systems.control_law`](@ref).
"""
function pseudo_hamiltonian(sys::HamiltonianSystem)
    h = sys.h
    h isa Data.ComposedHamiltonian && return h.h̃
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
mode (wrapping a [`CTBase.Data.ComposedHamiltonian`](@extref)).

# Throws
- `CTBase.Exceptions.IncorrectArgument`: if the system wraps a plain Hamiltonian with
  no associated control law.

See also: [`CTFlows.Systems.pseudo_hamiltonian`](@ref).
"""
function control_law(sys::HamiltonianSystem)
    h = sys.h
    h isa Data.ComposedHamiltonian && return h.law
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
`(t, x, p, v)`. For a Hamiltonian composed with a control law, the gradient is the
**total** derivative (differentiated through the law). The tuple is non-negated.

# Fields
- `h::H`: the Hamiltonian to differentiate.
- `backend::B`: the AD backend.

See also: [`CTFlows.Systems.get_hamiltonian_gradient`](@ref), [`CTFlows.Systems.HamiltonianVariableGradient`](@ref).
"""
struct HamiltonianGradient{H<:Data.AbstractHamiltonian,B<:Differentiation.AbstractADBackend}
    h::H
    backend::B
end

function (g::HamiltonianGradient)(t, x, p, v)
    return Differentiation.hamiltonian_gradient(g.backend, g.h, t, x, p, v)
end

"""
$(TYPEDEF)

Functor returning the variable gradient `∂H/∂v` of a true Hamiltonian, evaluated as
`(t, x, p, v)` — the quantity (before negation) that drives the augmented
variable-costate equation `ṗv = -∂H/∂v`. Non-negated.

# Fields
- `h::H`: the Hamiltonian to differentiate.
- `backend::B`: the AD backend.

See also: [`CTFlows.Systems.get_variable_gradient`](@ref), [`CTFlows.Systems.HamiltonianGradient`](@ref).
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

"""
$(TYPEDEF)

Functor returning the gradient `(∂H̃/∂x, ∂H̃/∂p)` of a pseudo-Hamiltonian, evaluated as
`(t, x, p, u, v)` at **fixed control** `u`. Non-negated.

# Fields
- `h̃::H`: the pseudo-Hamiltonian to differentiate.
- `backend::B`: the AD backend.

See also: [`CTFlows.Systems.get_pseudo_hamiltonian_gradient`](@ref), [`CTFlows.Systems.PseudoHamiltonianVariableGradient`](@ref).
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

"""
$(TYPEDEF)

Functor returning the variable gradient `∂H̃/∂v` of a pseudo-Hamiltonian, evaluated as
`(t, x, p, u, v)` at **fixed control** `u`. Non-negated.

# Fields
- `h̃::H`: the pseudo-Hamiltonian to differentiate.
- `backend::B`: the AD backend.

See also: [`CTFlows.Systems.get_pseudo_variable_gradient`](@ref), [`CTFlows.Systems.PseudoHamiltonianGradient`](@ref).
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

"""
$(TYPEDSIGNATURES)

Return a [`CTFlows.Systems.HamiltonianGradient`](@ref) functor `(t, x, p, v) ->
(∂H/∂x, ∂H/∂p)` for the true Hamiltonian of an AD-backed Hamiltonian system. For a
`PseudoHamiltonianSystem` (or a `:total` `HamiltonianSystem`), the gradient is the
**total** derivative — it differentiates through the control law.

The `ad_backend` keyword selects the AD backend used to differentiate; it defaults to
the system's own backend but can be overridden (e.g. to use reverse mode for the
gradient).

See also: [`CTFlows.Systems.hamiltonian`](@ref), [`CTFlows.Systems.get_variable_gradient`](@ref).
"""
function get_hamiltonian_gradient(
    sys::Union{HamiltonianSystem,PseudoHamiltonianSystem};
    ad_backend::Differentiation.AbstractADBackend=backend(sys),
)
    return HamiltonianGradient(hamiltonian(sys), ad_backend)
end

"""
$(TYPEDSIGNATURES)

Return a [`CTFlows.Systems.HamiltonianVariableGradient`](@ref) functor `(t, x, p, v) ->
∂H/∂v` for the true Hamiltonian of an AD-backed Hamiltonian system — the same quantity
(before negation) that drives the augmented variable-costate equation `ṗv = -∂H/∂v`.

The `ad_backend` keyword selects the AD backend (default: the system's own backend).

See also: [`CTFlows.Systems.get_hamiltonian_gradient`](@ref).
"""
function get_variable_gradient(
    sys::Union{HamiltonianSystem,PseudoHamiltonianSystem};
    ad_backend::Differentiation.AbstractADBackend=backend(sys),
)
    return HamiltonianVariableGradient(hamiltonian(sys), ad_backend)
end

"""
$(TYPEDSIGNATURES)

Return a [`CTFlows.Systems.PseudoHamiltonianGradient`](@ref) functor `(t, x, p, u, v) ->
(∂H̃/∂x, ∂H̃/∂p)` for the pseudo-Hamiltonian, differentiated at **fixed control** `u`.
Available for a `PseudoHamiltonianSystem` and for a `:total` `HamiltonianSystem`
wrapping a `ComposedHamiltonian`.

The `ad_backend` keyword selects the AD backend (default: the system's own backend).

See also: [`CTFlows.Systems.pseudo_hamiltonian`](@ref), [`CTFlows.Systems.get_pseudo_variable_gradient`](@ref).
"""
function get_pseudo_hamiltonian_gradient(
    sys::Union{HamiltonianSystem,PseudoHamiltonianSystem};
    ad_backend::Differentiation.AbstractADBackend=backend(sys),
)
    return PseudoHamiltonianGradient(pseudo_hamiltonian(sys), ad_backend)
end

"""
$(TYPEDSIGNATURES)

Return a [`CTFlows.Systems.PseudoHamiltonianVariableGradient`](@ref) functor
`(t, x, p, u, v) -> ∂H̃/∂v` for the pseudo-Hamiltonian, differentiated at **fixed
control** `u`.

The `ad_backend` keyword selects the AD backend (default: the system's own backend).

See also: [`CTFlows.Systems.get_pseudo_hamiltonian_gradient`](@ref).
"""
function get_pseudo_variable_gradient(
    sys::Union{HamiltonianSystem,PseudoHamiltonianSystem};
    ad_backend::Differentiation.AbstractADBackend=backend(sys),
)
    return PseudoHamiltonianVariableGradient(pseudo_hamiltonian(sys), ad_backend)
end
