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
  determines whether `variable` should be used.

# Example
\`\`\`julia
using CTFlows: Systems

# Fixed system: variable is nothing
params_fixed = Systems.ODEParameters(nothing)

# NonFixed system: variable is a value
params_nonfixed = Systems.ODEParameters(0.5)

# NonFixed system: variable is a vector
params_vector = Systems.ODEParameters([1.0, 2.0])
\`\`\`

# Notes
- This type is used exclusively by the SciML extension to wrap the variable
  before passing it to `ODEProblem`.
- The RHS functor reads `variable(p)` to access the actual variable value.

See also: [`CTBase.Traits.VariableDependence`](@extref), [`CTBase.Traits.Fixed`](@extref), [`CTBase.Traits.NonFixed`](@extref).
"""
struct ODEParameters{V}
    variable::V
end

"""
$(TYPEDSIGNATURES)

Accessor for the variable field of `ODEParameters`.

Returns the variable parameter stored in the `ODEParameters` wrapper.
For `Fixed` systems, this is `nothing`. For `NonFixed` systems, this is
the actual variable value (scalar or vector).

# Arguments
- `p::ODEParameters`: The ODEParameters instance.

# Returns
- The variable value (or `nothing` for Fixed systems).

# Example
\`\`\`julia-repl
julia> using CTFlows: Systems

julia> params_fixed = Systems.ODEParameters(nothing)
ODEParameters{Nothing}(nothing)

julia> Systems.variable(params_fixed)
nothing

julia> params_nonfixed = Systems.ODEParameters(0.5)
ODEParameters{Float64}(0.5)

julia> Systems.variable(params_nonfixed)
0.5
\`\`\`

See also: [`CTFlows.Systems.ODEParameters`](@extref), [`CTBase.Traits.VariableDependence`](@extref).
"""
function variable(p::ODEParameters)
    return p.variable
end
