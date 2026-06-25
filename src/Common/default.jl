# =============================================================================
# Default values for time-dependent object constructors
# =============================================================================

"""
$(TYPEDEF)

Sentinel type indicating that a variable parameter was not provided.

Used as the default value for the `variable` keyword argument in flow calls
to distinguish between "user did not provide a variable" and "user explicitly
passed `nothing`". This enables proper dispatch based on the system's
`VariableDependence` trait.

# Example
```julia
# Default value for variable parameter
__variable()::NotProvided = NotProvided()
```

See also: [`CTBase.Traits.VariableDependence`](@ref), [`CTBase.Traits.Fixed`](@ref), [`CTBase.Traits.NonFixed`](@ref).
"""
struct NotProvided end

"""
$(TYPEDSIGNATURES)

Default value for variable parameter in user-facing API calls.

Returns `NotProvided()` by default, meaning the variable parameter is optional
unless required by the system's trait (e.g., NonFixed systems).
"""
__variable()::NotProvided = NotProvided()

"""
$(TYPEDSIGNATURES)

Default value for unsafe flag in integration functions.

Returns `false` by default, meaning ODE solver retcodes are checked and
failures throw exceptions unless explicitly bypassed.
"""
__unsafe()::Bool = false

"""
$(TYPEDSIGNATURES)

Default value for in-place flag in hamiltonian_vector_field getter.

Returns `false` by default, meaning the getter returns out-of-place vector fields
unless specified otherwise.
"""
__hvf_inplace()::Bool = false

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
