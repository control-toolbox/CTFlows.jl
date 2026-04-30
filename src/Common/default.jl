# =============================================================================
# Default values for time-dependent object constructors
# =============================================================================

"""
$(TYPEDSIGNATURES)

Default value for autonomous flag in time-dependent object constructors.

Returns `true` by default, meaning objects do not explicitly depend on time
unless specified otherwise.
"""
__autonomous()::Bool = true

"""
$(TYPEDSIGNATURES)

Default value for variable flag in time-dependent object constructors.

Returns `false` by default, meaning objects have fixed parameters unless
specified otherwise.
"""
__variable()::Bool = false
