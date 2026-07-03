"""
$(TYPEDSIGNATURES)

Default value for variable parameter in user-facing API calls.

Returns `CTBase.Core.NotProvided` by default, meaning the variable parameter
is optional unless required by the system's trait (e.g., NonFixed systems).

See also: [`CTBase.Traits.VariableDependence`](@extref), [`CTBase.Traits.Fixed`](@extref), [`CTBase.Traits.NonFixed`](@extref).
"""
__variable()::Core.NotProvidedType = Core.NotProvided

"""
$(TYPEDSIGNATURES)

Default value for unsafe flag in integration functions.

Returns `false` by default, meaning ODE solver retcodes are checked and
failures throw exceptions unless explicitly bypassed.
"""
__unsafe()::Bool = false

"""
$(TYPEDSIGNATURES)

Default value for variable_costate flag in Hamiltonian flow calls.

Returns `false` by default, meaning the flow does not integrate the augmented
variable costate equation `ṗᵥ = -∂H/∂v` unless explicitly requested.

# Returns
- `Bool`: The default value for the `variable_costate` parameter.

See also: [`CTFlows.Configs.AugmentedHamiltonianEndPointConfig`](@ref).
"""
__variable_costate()::Bool = false
