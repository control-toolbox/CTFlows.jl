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
# TODO: docstring
struct StateFlow{TD, VD, S<:Systems.AbstractStateSystem{TD, VD}, I<:Integrators.AbstractIntegrator} <: AbstractStateFlow{TD, VD, S}
    system::S
    integrator::I
end

# TODO: docstring
struct HamiltonianFlow{TD, VD, S<:Systems.AbstractHamiltonianSystem{TD, VD}, I<:Integrators.AbstractIntegrator} <: AbstractHamiltonianFlow{TD, VD, S}
    system::S
    integrator::I
end

"""
$(TYPEDSIGNATURES)

Build a `Flow` from an `AbstractSystem` and an `AbstractIntegrator`.

Constructs a concrete flow that combines the system and integrator for integration.
The resulting flow is callable and can be used with both point and trajectory configurations.

# Arguments
- `system::S`: The `AbstractSystem` to integrate.
- `integrator::I`: The `AbstractIntegrator` to use for integration.

# Returns
- `Flow`: A concrete flow combining the system and integrator.

# Example
\`\`\`julia-repl
julia> using CTFlows.Flows, CTFlows.Systems, CTFlows.Integrators

julia> system = VectorFieldSystem(VectorField(x -> -x))
VectorFieldSystem

julia> integrator = FakeIntegrator()
FakeIntegrator()

julia> flow = build_flow(system, integrator)
Flow{...}
\`\`\`

See also: [`CTFlows.Flows.Flow`](@ref), [`CTFlows.Systems.AbstractSystem`](@ref), [`CTFlows.Integrators.AbstractIntegrator`](@ref).
"""
# TODO: docstring
function build_flow(system::S, integrator::I) where {S<:Systems.AbstractStateSystem, I<:Integrators.AbstractIntegrator}
    return StateFlow(system, integrator)
end

# TODO: docstring
function build_flow(system::S, integrator::I) where {S<:Systems.AbstractHamiltonianSystem, I<:Integrators.AbstractIntegrator}
    return HamiltonianFlow(system, integrator)
end

"""
$(TYPEDSIGNATURES)

Return the system associated with the flow.

# Returns
- `S`: The `AbstractSystem` stored in the flow.
"""
# TODO: docstring
function system(f::StateFlow{TD, VD, S, I})::S where {TD, VD, S, I}
    return f.system
end

# TODO: docstring
function system(f::HamiltonianFlow{TD, VD, S, I})::S where {TD, VD, S, I}
    return f.system
end

"""
$(TYPEDSIGNATURES)

Return the integrator associated with the flow.

# Returns
- `I`: The `AbstractIntegrator` stored in the flow.
"""
# TODO: docstring
function integrator(f::StateFlow{TD, VD, S, I})::I where {TD, VD, S, I}
    return f.integrator
end

# TODO: docstring
function integrator(f::HamiltonianFlow{TD, VD, S, I})::I where {TD, VD, S, I}
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
# TODO: docstring
function (f::StateFlow)(
    t0::Real,
    x0,
    tf::Real;
    variable=Common.__variable(),
    unsafe=Common.__unsafe(),
)
    return call(f, Common.PointConfig(t0, x0, tf); variable=variable, unsafe=unsafe)
end

# TODO: docstring
function (f::HamiltonianFlow)(
    t0::Real,
    x0,
    p0,
    tf::Real;
    variable=Common.__variable(),
    unsafe=Common.__unsafe(),
)
    return call(f, Common.HamiltonianPointConfig(t0, x0, p0, tf); variable=variable, unsafe=unsafe)
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
# TODO: docstring
function (f::StateFlow)(
    tspan::Tuple{Real, Real},
    x0;
    variable=Common.__variable(),
    unsafe=Common.__unsafe(),
)
    return call(f, Common.TrajectoryConfig(tspan, x0); variable=variable, unsafe=unsafe)
end

# TODO: docstring
function (f::HamiltonianFlow)(
    tspan::Tuple{Real, Real},
    x0,
    p0;
    variable=Common.__variable(),
    unsafe=Common.__unsafe(),
)
    return call(f, Common.HamiltonianTrajectoryConfig(tspan, x0, p0); variable=variable, unsafe=unsafe)
end
