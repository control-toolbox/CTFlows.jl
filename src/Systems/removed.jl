# ==============================================================================
# Removed accessors (control-toolbox/CTFlows.jl#544)
#
# The gradient accessors lost their `get_` prefix, like the other accessors of a system
# (`hamiltonian`, `pseudo_hamiltonian`, `control_law`). The old names are kept only to say
# what replaces them.
# ==============================================================================

"""
$(TYPEDSIGNATURES)

Throw the error of a removed gradient accessor, naming its replacement.

# Throws
- [`CTBase.Exceptions.PreconditionError`](@extref): always.
"""
function _removed_gradient(old::Symbol, new::Symbol)
    return throw(
        Exceptions.PreconditionError(
            "`$old` is removed";
            reason="the accessors of a flow and of a system have no `get_` prefix",
            suggestion="use $new(f)",
            context="$old — removed accessor (control-toolbox/CTFlows.jl#544)",
        ),
    )
end

"""
$(TYPEDSIGNATURES)

Removed: use [`CTFlows.Systems.hamiltonian_gradient`](@extref). Throws a
`CTBase.Exceptions.PreconditionError`.
"""
function get_hamiltonian_gradient(args...; kwargs...)
    return _removed_gradient(:get_hamiltonian_gradient, :hamiltonian_gradient)
end

"""
$(TYPEDSIGNATURES)

Removed: use [`CTFlows.Systems.variable_gradient`](@extref). Throws a
`CTBase.Exceptions.PreconditionError`.
"""
function get_variable_gradient(args...; kwargs...)
    return _removed_gradient(:get_variable_gradient, :variable_gradient)
end

"""
$(TYPEDSIGNATURES)

Removed: use [`CTFlows.Systems.pseudo_hamiltonian_gradient`](@extref). Throws a
`CTBase.Exceptions.PreconditionError`.
"""
function get_pseudo_hamiltonian_gradient(args...; kwargs...)
    return _removed_gradient(:get_pseudo_hamiltonian_gradient, :pseudo_hamiltonian_gradient)
end

"""
$(TYPEDSIGNATURES)

Removed: use [`CTFlows.Systems.pseudo_variable_gradient`](@extref). Throws a
`CTBase.Exceptions.PreconditionError`.
"""
function get_pseudo_variable_gradient(args...; kwargs...)
    return _removed_gradient(:get_pseudo_variable_gradient, :pseudo_variable_gradient)
end
