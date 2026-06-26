"""
$(TYPEDEF)

Strategy registry for flow construction.

This constant holds the precomputed strategy registry that maps abstract strategy
types to their concrete implementations for flow construction:
- `Differentiation.AbstractADBackend` → `Differentiation.DifferentiationInterface`
- `Integrators.AbstractIntegrator` → `Integrators.SciML`

# Type
- `CTBase.Strategies.StrategyRegistry`: Registry mapping abstract types to concrete implementations.

# Notes
- Created at module load time via [`CTBase.Strategies.create_registry`](@extref).
- Used by [`CTFlows.Flows.flow_registry`](@ref) to provide the registry to routing functions.
- The registry is cached for performance.

See also: [`CTFlows.Flows.flow_registry`](@ref), [`CTFlows.Flows._route_flow_options`](@ref), [`CTBase.Strategies.create_registry`](@extref).
"""
const _FLOW_REGISTRY = Strategies.create_registry(
    Differentiation.AbstractADBackend => (Differentiation.DifferentiationInterface,),
    Integrators.AbstractIntegrator => (Integrators.SciML,),
)

"""
$(TYPEDSIGNATURES)

Return the strategy registry for flow construction.

The registry maps abstract strategy families to their concrete implementations
for automatic differentiation backends and ODE integrators.

# Returns
- `CTBase.Strategies.StrategyRegistry`: Registry with `:di` (DifferentiationInterface)
  and `:sciml` (SciML) strategies registered.

# Notes
- This registry is used by [`_route_flow_options`](@ref) to resolve and build
  concrete strategy instances from keyword arguments.
- The registry is precomputed and cached in `_FLOW_REGISTRY` for performance.

See also: [`_route_flow_options`](@ref), [`_build_flow_components`](@ref),
[`CTBase.Strategies.create_registry`](@extref)
"""
function flow_registry()
    return _FLOW_REGISTRY
end
