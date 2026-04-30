"""
$(TYPEDEF)

Concrete flow that combines an `AbstractSystem` with an `AbstractODEIntegrator`.

A `Flow` is the standard implementation of `AbstractFlow` that delegates
integration to the provided integrator and solution building to the system.

The `VD` parameter encodes the `VariableDependence` trait (Fixed or NonFixed)
to enable compile-time dispatch on whether the `variable` kwarg is required.

# Fields
- `system::S`: The `AbstractSystem` to integrate.
- `integrator::I`: The `AbstractODEIntegrator` to use for integration.

# Example
```julia-repl
julia> using CTFlows.Flows, CTFlows.Systems

julia> system = FakeSystem()
FakeSystem()

julia> integrator = FakeIntegrator()
FakeIntegrator()

julia> flow = Flow(system, integrator)
Flow{FakeSystem, FakeIntegrator, Fixed}(system=FakeSystem(), integrator=FakeIntegrator)
```

See also: [`CTFlows.Flows.AbstractFlow`](@ref), [`CTFlows.Systems.AbstractSystem`](@ref), [`CTFlows.Integrators.AbstractODEIntegrator`](@ref).
"""
struct Flow{VD<:Common.VariableDependence, S<:Systems.AbstractSystem{VD}, I<:Integrators.AbstractODEIntegrator} <: AbstractFlow{VD}
    system::S
    integrator::I
end

"""
$(TYPEDSIGNATURES)

Return the system associated with the flow.

# Returns
- `S`: The `AbstractSystem` stored in the flow.
"""
function system(f::Flow{S, I})::S where {S, I}
    return f.system
end

"""
$(TYPEDSIGNATURES)

Return the integrator associated with the flow.

# Returns
- `I`: The `AbstractODEIntegrator` stored in the flow.
"""
function integrator(f::Flow{S, I})::I where {S, I}
    return f.integrator
end

# =============================================================================
# Flow callable — compile-time dispatch on variable trait.
#
# Calling a Fixed flow with `variable=v` → Error.
# Calling a NonFixed flow without `variable` → Error.
#
# The error is thrown by the inner `solve` method.
#
# =============================================================================

"""
$(TYPEDSIGNATURES)

Convenience call `flow(t0, x0, tf)` — builds a `PointConfig` internally.

# Arguments
- `f::Flow`: The flow to integrate.
- `t0`: Initial time.
- `x0`: Initial state vector.
- `tf`: Final time.

# Returns
- The integrated solution.

See also: [`CTFlows.Common.PointConfig`](@ref), [`CTFlows.Flows.solve`](@ref).
"""
function (f::Flow)(
    t0::Real,
    x0,
    tf::Real;
    variable=nothing,
)
    return solve(f, Common.PointConfig(t0, x0, tf); variable=variable)
end

"""
$(TYPEDSIGNATURES)

Convenience call `flow((t0, tf), x0)` — builds a `TrajectoryConfig` internally.

# Arguments
- `f::Flow{S, I, VD}`: The flow to integrate.
- `tspan::Tuple`: Time span as a tuple (t0, tf).
- `x0`: Initial state vector.

# Returns
- The integrated solution.

See also: [`CTFlows.Common.TrajectoryConfig`](@ref), [`CTFlows.Flows.solve`](@ref).
"""
function (f::Flow)(
    tspan::Tuple{Real, Real},
    x0; 
    variable=nothing,
)
    return solve(f, Common.TrajectoryConfig(tspan, x0); variable=variable)
end
