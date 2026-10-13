# =============================================================================
# Accessors that do not apply to a system — uniform IncorrectArgument
#
# Every accessor (`hamiltonian`, `hamiltonian_vector_field`, `pseudo_hamiltonian`,
# `control_law` and the gradient getters) has a fallback on `AbstractSystem` that says
# what the flow holds and which accessor to use instead, rather than a `MethodError`
# printing the full system type. Included last: the specific methods of each system
# take precedence.
# =============================================================================

"""
$(TYPEDSIGNATURES)

Describe what a system holds and which accessors apply to it, as a `(got, suggestion)`
pair of strings for [`CTFlows.Systems._unavailable`](@extref).
"""
function _accessor_hint(sys::AbstractSystem)
    return (
        "a flow whose system is a $(nameof(typeof(sys)))",
        "Check which accessors the system $(nameof(typeof(sys))) implements",
    )
end

function _accessor_hint(::AbstractStateSystem)
    return (
        "a state flow: it integrates ẋ = f(t, x, v), with no costate and no Hamiltonian",
        "Use vector_field(flow) to get its vector field",
    )
end

function _accessor_hint(::HamiltonianVectorFieldSystem)
    return (
        "a flow built from a Hamiltonian vector field: it stores X_H, with no scalar Hamiltonian and no control law",
        "Use hamiltonian_vector_field(flow) to get X_H, or build the flow from a scalar Hamiltonian",
    )
end

function _accessor_hint(::PseudoHamiltonianVectorFieldSystem)
    return (
        "a flow built from a pseudo-Hamiltonian vector field and a control law: it stores X_H̃, with no scalar (pseudo-)Hamiltonian",
        "Use control_law(flow) to get the control law, or build the flow from a scalar pseudo-Hamiltonian",
    )
end

function _accessor_hint(::ConstrainedPseudoHamiltonianSystem)
    return (
        "a flow built from a pseudo-Hamiltonian, a control law and a path constraint",
        "Use hamiltonian, pseudo_hamiltonian or control_law, and differentiate them with the backend of your choice",
    )
end

"""
$(TYPEDSIGNATURES)

Throw the `IncorrectArgument` raised by an accessor that does not apply to `sys`.

# Arguments
- `accessor::Symbol`: the name of the accessor, e.g. `:hamiltonian`.
- `what::String`: what the accessor returns, e.g. `"Hamiltonian"`.
- `sys::AbstractSystem`: the system of the flow.

# Throws
- `CTBase.Exceptions.IncorrectArgument`: always.
"""
function _unavailable(accessor::Symbol, what::String, sys::AbstractSystem)
    got, suggestion = _accessor_hint(sys)
    return throw(
        Exceptions.IncorrectArgument(
            "no $what available for this flow";
            got=got,
            expected="a flow that carries a $what",
            suggestion=suggestion,
            context="$accessor(flow)",
        ),
    )
end

# -----------------------------------------------------------------------------
# Fallbacks
# -----------------------------------------------------------------------------

"""
$(TYPEDSIGNATURES)

Fallback: the system carries no scalar Hamiltonian.

# Throws
- `CTBase.Exceptions.IncorrectArgument`: always, naming the accessor to use instead.

See also: [`CTFlows.Systems.hamiltonian_vector_field`](@extref), [`CTFlows.Systems.vector_field`](@extref).
"""
hamiltonian(sys::AbstractSystem) = _unavailable(:hamiltonian, "Hamiltonian", sys)

"""
$(TYPEDSIGNATURES)

Fallback: the system carries no scalar pseudo-Hamiltonian.

# Throws
- `CTBase.Exceptions.IncorrectArgument`: always, naming the accessor to use instead.

See also: [`CTFlows.Systems.hamiltonian`](@extref), [`CTFlows.Systems.control_law`](@extref).
"""
function pseudo_hamiltonian(sys::AbstractSystem)
    return _unavailable(:pseudo_hamiltonian, "pseudo-Hamiltonian", sys)
end

"""
$(TYPEDSIGNATURES)

Fallback: the system carries no control law.

# Throws
- `CTBase.Exceptions.IncorrectArgument`: always, naming the accessor to use instead.

See also: [`CTFlows.Systems.pseudo_hamiltonian`](@extref).
"""
control_law(sys::AbstractSystem) = _unavailable(:control_law, "control law", sys)

"""
$(TYPEDSIGNATURES)

Return the control law `u(t, x, p, v)` of a `PseudoHamiltonianVectorFieldSystem`.

See also: [`CTFlows.Systems.PseudoHamiltonianVectorFieldSystem`](@extref).
"""
control_law(sys::PseudoHamiltonianVectorFieldSystem) = sys.law

"""
$(TYPEDSIGNATURES)

A state system has no costate, hence no Hamiltonian vector field.

# Throws
- `CTBase.Exceptions.IncorrectArgument`: always, suggesting [`CTFlows.Systems.vector_field`](@extref).
"""
function hamiltonian_vector_field(sys::AbstractStateSystem; kwargs...)
    return _unavailable(:hamiltonian_vector_field, "Hamiltonian vector field", sys)
end

"""
$(TYPEDSIGNATURES)

A `PseudoHamiltonianVectorFieldSystem` stores the pseudo-Hamiltonian vector field `X_H̃`,
which depends on the control: it exposes no Hamiltonian vector field.

# Throws
- `CTBase.Exceptions.IncorrectArgument`: always.
"""
function hamiltonian_vector_field(sys::PseudoHamiltonianVectorFieldSystem; kwargs...)
    return _unavailable(:hamiltonian_vector_field, "Hamiltonian vector field", sys)
end

"""
$(TYPEDSIGNATURES)

Fallback: no AD-backed Hamiltonian to differentiate.

# Throws
- `CTBase.Exceptions.IncorrectArgument`: always, naming the accessor to use instead.

See also: [`CTFlows.Systems.get_hamiltonian_gradient`](@extref).
"""
function get_hamiltonian_gradient(sys::AbstractSystem; kwargs...)
    return _unavailable(:get_hamiltonian_gradient, "Hamiltonian gradient", sys)
end

"""
$(TYPEDSIGNATURES)

Fallback: no AD-backed Hamiltonian to differentiate.

# Throws
- `CTBase.Exceptions.IncorrectArgument`: always, naming the accessor to use instead.

See also: [`CTFlows.Systems.get_variable_gradient`](@extref).
"""
function get_variable_gradient(sys::AbstractSystem; kwargs...)
    return _unavailable(:get_variable_gradient, "Hamiltonian variable gradient", sys)
end

"""
$(TYPEDSIGNATURES)

Fallback: no AD-backed pseudo-Hamiltonian to differentiate.

# Throws
- `CTBase.Exceptions.IncorrectArgument`: always, naming the accessor to use instead.

See also: [`CTFlows.Systems.get_pseudo_hamiltonian_gradient`](@extref).
"""
function get_pseudo_hamiltonian_gradient(sys::AbstractSystem; kwargs...)
    return _unavailable(
        :get_pseudo_hamiltonian_gradient, "pseudo-Hamiltonian gradient", sys
    )
end

"""
$(TYPEDSIGNATURES)

Fallback: no AD-backed pseudo-Hamiltonian to differentiate.

# Throws
- `CTBase.Exceptions.IncorrectArgument`: always, naming the accessor to use instead.

See also: [`CTFlows.Systems.get_pseudo_variable_gradient`](@extref).
"""
function get_pseudo_variable_gradient(sys::AbstractSystem; kwargs...)
    return _unavailable(
        :get_pseudo_variable_gradient, "pseudo-Hamiltonian variable gradient", sys
    )
end
