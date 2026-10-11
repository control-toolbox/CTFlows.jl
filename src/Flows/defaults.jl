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

Default value for the `grid` keyword of a top-level trajectory call.

Returns `CTBase.Core.NotProvided` by default, meaning no output grid is imposed: the call
then generates an [`CTFlows.Configs.AutomaticGrid`](@extref) (`AdaptiveGrid(250)` when the
solver returns fewer than 250 times), unless a grid of times or the integrator's `saveat`
already shapes the output. `grid=nothing` keeps the solver steps. Internal calls (the inner
flow of a decorator, a phase of a multi-phase flow) pass `grid=nothing`.

See also: [`CTFlows.Flows._default_grid`](@extref).
"""
__grid()::Core.NotProvidedType = Core.NotProvided

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

See also: [`CTFlows.Configs.AugmentedHamiltonianEndPointConfig`](@extref).
"""
__variable_costate()::Bool = false
