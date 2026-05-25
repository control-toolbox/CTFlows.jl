const _FLOW_REGISTRY = CTSolvers.Strategies.create_registry(
    Differentiation.AbstractADBackend => (Differentiation.DifferentiationInterface,),
    Integrators.AbstractIntegrator => (Integrators.SciML,),
)

"""
$(TYPEDSIGNATURES)

Return the strategy registry for flow construction.

The registry maps abstract strategy families to their concrete implementations
for automatic differentiation backends and ODE integrators.

# Returns
- `CTSolvers.Strategies.StrategyRegistry`: Registry with `:di` (DifferentiationInterface)
  and `:sciml` (SciML) strategies registered.

# Notes
- This registry is used by [`_route_flow_options`](@ref) to resolve and build
  concrete strategy instances from keyword arguments.
- The registry is precomputed and cached in `_FLOW_REGISTRY` for performance.

See also: [`_route_flow_options`](@ref), [`_build_flow_components`](@ref),
[`CTSolvers.Strategies.create_registry`](@extref)
"""
function flow_registry()
    return _FLOW_REGISTRY
end
