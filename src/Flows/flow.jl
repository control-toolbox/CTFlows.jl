"""
$(TYPEDEF)

Concrete flow that combines an `AbstractSystem` with an `AbstractIntegrator`.

A `Flow` is the standard implementation of `AbstractFlow` that delegates
integration to the provided integrator and solution building to the system.

The `TD` and `VD` parameters encode the `TimeDependence` and `VariableDependence`
traits (Autonomous/NonAutonomous and Fixed/NonFixed) to enable compile-time dispatch.

# Fields
- `system::S`: The `AbstractSystem` to integrate.
- `integrator::I`: The `AbstractIntegrator` to use for integration.

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

See also: [`CTFlows.Flows.AbstractFlow`](@ref), [`CTFlows.Systems.AbstractSystem`](@ref), [`CTFlows.Integrators.AbstractIntegrator`](@ref).
"""
struct Flow{TD<:Common.TimeDependence, VD<:Common.VariableDependence, S<:Systems.AbstractSystem{TD, VD}, I<:Integrators.AbstractIntegrator} <: AbstractFlow{TD, VD}
    system::S
    integrator::I
end

"""
$(TYPEDSIGNATURES)

Return the system associated with the flow.

# Returns
- `S`: The `AbstractSystem` stored in the flow.
"""
function system(f::Flow{TD, VD, S, I})::S where {TD, VD, S, I}
    return f.system
end

"""
$(TYPEDSIGNATURES)

Return the integrator associated with the flow.

# Returns
- `I`: The `AbstractIntegrator` stored in the flow.
"""
function integrator(f::Flow{TD, VD, S, I})::I where {TD, VD, S, I}
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
- `variable`: The variable parameter value (required for NonFixed systems, optional for Fixed systems).
- `unsafe`: If `true`, bypass ODE solver retcode checking; if `false`, throw `SolverFailure` on integration failure.

# Returns
- The integrated solution.

See also: [`CTFlows.Common.PointConfig`](@ref), [`CTFlows.Flows.call`](@ref).
"""
function (f::Flow)(
    t0::Real,
    x0,
    tf::Real;
    variable=Common.__variable(),
    unsafe=Common.__unsafe(),
)
    return call(f, Common.PointConfig(t0, x0, tf); variable=variable, unsafe=unsafe)
end

"""
$(TYPEDSIGNATURES)

Convenience call `flow((t0, tf), x0)` — builds a `TrajectoryConfig` internally.

# Arguments
- `f::Flow{S, I, VD}`: The flow to integrate.
- `tspan::Tuple`: Time span as a tuple (t0, tf).
- `x0`: Initial state vector.
- `variable`: The variable parameter value (required for NonFixed systems, optional for Fixed systems).
- `unsafe`: If `true`, bypass ODE solver retcode checking; if `false`, throw `SolverFailure` on integration failure.

# Returns
- The integrated solution.

See also: [`CTFlows.Common.TrajectoryConfig`](@ref), [`CTFlows.Flows.call`](@ref).
"""
function (f::Flow)(
    tspan::Tuple{Real, Real},
    x0;
    variable=Common.__variable(),
    unsafe=Common.__unsafe(),
)
    return call(f, Common.TrajectoryConfig(tspan, x0); variable=variable, unsafe=unsafe)
end
