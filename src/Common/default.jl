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
$(TYPEDSIGNATURES)

Default value for variable parameter in user-facing API calls.

Returns `nothing` by default, meaning the variable parameter is optional
unless required by the system's trait (e.g., NonFixed systems).
"""
__variable() = nothing

"""
$(TYPEDSIGNATURES)

Default value for unsafe flag in integration functions.

Returns `false` by default, meaning ODE solver retcodes are checked and
failures throw exceptions unless explicitly bypassed.
"""
__unsafe()::Bool = false
