"""
$(TYPEDEF)

Wrapper type for parameters passed through SciML's `p` slot.

This type formalizes the contract for what transits in the ODE problem's
parameter slot. For CTFlows, the primary content is the variable parameter
for `NonFixed` systems (or `nothing` for `Fixed` systems).

The wrapper makes the contract explicit and extensible — additional fields
can be added later (callbacks, extra data) without breaking existing code.

# Fields
- `variable::V`: The variable parameter (or `nothing` for `Fixed` systems).

# Constructor Validation

- `V` can be `Nothing` (for `Fixed` systems) or any concrete type (for `NonFixed`).
- No validation is performed at construction — the system's `VariableDependence`
  trait determines whether `variable` should be used.

# Example
\`\`\`julia
using CTFlows.Common

# Fixed system: variable is nothing
params_fixed = ODEParameters(nothing)

# NonFixed system: variable is a value
params_nonfixed = ODEParameters(0.5)
\`\`\`

# Notes
- This type is used exclusively by the SciML extension to wrap the variable
  before passing it to `ODEProblem`.
- The RHS closure reads `p.variable` to access the actual variable value.

See also: [`CTFlows.Common.VariableDependence`](@ref), [`CTFlows.Common.Fixed`](@ref), [`CTFlows.Common.NonFixed`](@ref).
"""
struct ODEParameters{V}
    variable::V
end
