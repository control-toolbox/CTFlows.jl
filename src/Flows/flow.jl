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

julia> system = FakeSystem(2)
FakeSystem(n_x=2, n_p=2)

julia> integrator = FakeIntegrator()
FakeIntegrator()

julia> flow = Flow(system, integrator)
Flow{FakeSystem, FakeIntegrator, Fixed}(system=FakeSystem(n_x=2, n_p=2), integrator=FakeIntegrator)
```

See also: [`CTFlows.Flows.AbstractFlow`](@ref), [`CTFlows.Systems.AbstractSystem`](@ref), [`CTFlows.Integrators.AbstractODEIntegrator`](@ref).
"""
struct Flow{S<:Systems.AbstractSystem, I<:Integrators.AbstractODEIntegrator, VD<:Systems.VariableDependence} <: AbstractFlow
    system::S
    integrator::I
end

"""
$(TYPEDSIGNATURES)

Return the system associated with the flow.

# Returns
- `S`: The `AbstractSystem` stored in the flow.
"""
system(f::Flow) = f.system

"""
$(TYPEDSIGNATURES)

Return the integrator associated with the flow.

# Returns
- `I`: The `AbstractODEIntegrator` stored in the flow.
"""
integrator(f::Flow) = f.integrator

"""
$(TYPEDSIGNATURES)

Construct a `Flow` with automatic trait inference.

The `VariableDependence` trait is automatically extracted from the system's type
using `variable_dependence(system)`, ensuring type coherence.

# Arguments
- `system::AbstractSystem`: The system to integrate.
- `integrator::AbstractODEIntegrator`: The integrator to use.

# Returns
- `Flow{S, I, VD}`: A flow with the inferred VariableDependence trait.
"""
function Flow(system::S, integrator::I) where {S<:Systems.AbstractSystem, I<:Integrators.AbstractODEIntegrator}
    return Flow{S, I, Systems.variable_dependence(system)}(system, integrator)
end

# =============================================================================
# Flow callable — compile-time dispatch on variable trait.
#
# Fixed systems: 3 methods, NO `variable` kwarg.
# NonFixed systems: 3 methods, REQUIRED `variable` kwarg (no default).
#
# Calling a Fixed flow with `variable=v` → MethodError (unknown kwarg).
# Calling a NonFixed flow without `variable` → MethodError (required kwarg).
# =============================================================================

# --- Fixed ------------------------------------------------------------------

"""
$(TYPEDSIGNATURES)

Convenience call `flow(t0, x0, tf)` — builds a `PointConfig` internally.

# Arguments
- `f::Flow{S, I, VD}`: The flow to integrate.
- `t0`: Initial time.
- `x0`: Initial state vector.
- `tf`: Final time.

# Returns
- The integrated solution.
"""
function (f::Flow{S, I, VD})(
    t0,
    x0,
    tf,
) where {S<:Systems.AbstractSystem, I<:Integrators.AbstractODEIntegrator, VD<:Common.Fixed}
    return solve(f, Common.PointConfig(t0, x0, tf))
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
"""
function (f::Flow{S, I, VD})(
    tspan::Tuple,
    x0,
) where {S<:Systems.AbstractSystem, I<:Integrators.AbstractODEIntegrator, VD<:Common.Fixed}
    return solve(f, Common.TrajectoryConfig(tspan, x0))
end

# --- NonFixed ---------------------------------------------------------------
"""
$(TYPEDSIGNATURES)

Convenience call `flow(t0, x0, tf; variable=v)`.

# Arguments
- `f::Flow{S, I, VD}`: The flow to integrate.
- `t0`: Initial time.
- `x0`: Initial state vector.
- `tf`: Final time.
- `variable`: The variable parameter value.

# Returns
- The integrated solution.
"""
function (f::Flow{S, I, VD})(
    t0,
    x0,
    tf;
    variable,
) where {S<:Systems.AbstractSystem, I<:Integrators.AbstractODEIntegrator, VD<:Common.NonFixed}
    return solve(f, Common.PointConfig(t0, x0, tf); variable = variable)
end

"""
$(TYPEDSIGNATURES)

Convenience call `flow((t0, tf), x0; variable=v)`.

# Arguments
- `f::Flow{S, I, VD}`: The flow to integrate.
- `tspan::Tuple`: Time span as a tuple (t0, tf).
- `x0`: Initial state vector.
- `variable`: The variable parameter value.

# Returns
- The integrated solution.
"""
function (f::Flow{S, I, VD})(
    tspan::Tuple,
    x0;
    variable,
) where {S<:Systems.AbstractSystem, I<:Integrators.AbstractODEIntegrator, VD<:Common.NonFixed}
    return solve(f, Common.TrajectoryConfig(tspan, x0); variable = variable)
end
