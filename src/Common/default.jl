# =============================================================================
# Default values for time-dependent object constructors
# =============================================================================

"""
$(TYPEDSIGNATURES)

Default value for autonomous flag in time-dependent object constructors.

Returns `true` by default, meaning objects do not explicitly depend on time
unless specified otherwise.
"""
__is_autonomous()::Bool = true

"""
$(TYPEDSIGNATURES)

Default value for variable flag in time-dependent object constructors.

Returns `false` by default, meaning objects have fixed parameters unless
specified otherwise.
"""
__is_variable()::Bool = false

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

See also: [`CTFlows.Traits.VariableDependence`](@ref), [`CTFlows.Traits.Fixed`](@ref), [`CTFlows.Traits.NonFixed`](@ref).
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

Default value for in-place flag in vector field constructors.

Returns `nothing` by default, meaning mutability is auto-detected from
the function signature unless specified otherwise.

# Returns
- `Nothing`: The default value for the `is_inplace` parameter.

See also: [`CTFlows.Data.VectorField`](@ref), [`CTFlows.Data.HamiltonianVectorField`](@ref).
"""
__is_inplace() = nothing

"""
$(TYPEDSIGNATURES)

Default value for variable_costate flag in Hamiltonian flow calls.

Returns `false` by default, meaning the flow does not integrate the augmented
variable costate equation `ṗᵥ = -∂H/∂v` unless explicitly requested.

# Returns
- `Bool`: The default value for the `variable_costate` parameter.

See also: [`CTFlows.Configs.AugmentedHamiltonianPointConfig`](@ref).
"""
_variable_costate()::Bool = false
