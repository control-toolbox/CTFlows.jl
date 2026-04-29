"""
$(TYPEDEF)

Concrete flow that combines an `AbstractSystem` with an `AbstractODEIntegrator`.

A `Flow` is the standard implementation of `AbstractFlow` that delegates
integration to the provided integrator and solution building to the system.

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
Flow{FakeSystem}(system=FakeSystem(n_x=2, n_p=2), integrator=FakeIntegrator)
```

See also: [`AbstractFlow`](@ref), [`AbstractSystem`](@ref), [`AbstractODEIntegrator`](@ref).
"""
struct Flow{S<:Systems.AbstractSystem, I<:Integrators.AbstractODEIntegrator} <: AbstractFlow
    system::S
    integrator::I
end

"""
$(TYPEDSIGNATURES)

Return the system associated with the flow.
"""
system(f::Flow) = f.system

"""
$(TYPEDSIGNATURES)

Return the integrator associated with the flow.
"""
integrator(f::Flow) = f.integrator

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

Integrate a `Fixed` (variable-free) `Flow` using the given `config`.
"""
function (f::Flow{S})(
    config,
) where {S <: Systems.VectorFieldSystem{<:Any, <:Any, Systems.Fixed}}
    prob = Systems.ode_problem(f.system, config)
    raw = f.integrator(prob)
    return Systems.build_solution(f.system, raw, f, config)
end

"""
$(TYPEDSIGNATURES)

Convenience call `flow(t0, x0, tf)` — builds a `PointConfig` internally.
"""
function (f::Flow{S})(
    t0,
    x0,
    tf,
) where {S <: Systems.VectorFieldSystem{<:Any, <:Any, Systems.Fixed}}
    return f(Common.PointConfig(t0, x0, tf))
end

"""
$(TYPEDSIGNATURES)

Convenience call `flow((t0, tf), x0)` — builds a `TrajectoryConfig` internally.
"""
function (f::Flow{S})(
    tspan::Tuple,
    x0,
) where {S <: Systems.VectorFieldSystem{<:Any, <:Any, Systems.Fixed}}
    return f(Common.TrajectoryConfig(tspan, x0))
end

# --- NonFixed ---------------------------------------------------------------

"""
$(TYPEDSIGNATURES)

Integrate a `NonFixed` `Flow` with the required `variable` kwarg.
"""
function (f::Flow{S})(
    config;
    variable,
) where {S <: Systems.VectorFieldSystem{<:Any, <:Any, Systems.NonFixed}}
    prob = Systems.ode_problem(f.system, config; variable = variable)
    raw = f.integrator(prob)
    return Systems.build_solution(f.system, raw, f, config)
end

"""
$(TYPEDSIGNATURES)

Convenience call `flow(t0, x0, tf; variable=v)`.
"""
function (f::Flow{S})(
    t0,
    x0,
    tf;
    variable,
) where {S <: Systems.VectorFieldSystem{<:Any, <:Any, Systems.NonFixed}}
    return f(Common.PointConfig(t0, x0, tf); variable = variable)
end

"""
$(TYPEDSIGNATURES)

Convenience call `flow((t0, tf), x0; variable=v)`.
"""
function (f::Flow{S})(
    tspan::Tuple,
    x0;
    variable,
) where {S <: Systems.VectorFieldSystem{<:Any, <:Any, Systems.NonFixed}}
    return f(Common.TrajectoryConfig(tspan, x0); variable = variable)
end

# =============================================================================
# Specialized show for Flow with VectorFieldSystem
# =============================================================================

function Base.show(io::IO, ::MIME"text/plain", flow::Flow{S}) where {S <: Systems.VectorFieldSystem}
    print(io, "Flow{", nameof(S), "}")
    sys = Flows.system(flow)
    integ = Flows.integrator(flow)
    
    print(io, "\n  system: VectorFieldSystem")
    print(io, "\n    time_dependence: ", Systems.time_dependence(sys))
    print(io, "\n    variable_dependence: ", Systems.variable_dependence(sys))
    print(io, "\n    vector_field: ", typeof(sys.vf))
    print(io, "\n  integrator: ", nameof(typeof(integ)))
end

function Base.show(io::IO, flow::Flow{S}) where {S <: Systems.VectorFieldSystem}
    sys = Flows.system(flow)
    integ = Flows.integrator(flow)
    print(io, "Flow(")
    print(io, "VectorFieldSystem(")
    print(io, Systems.time_dependence(sys), ", ")
    print(io, Systems.variable_dependence(sys))
    print(io, "), ")
    print(io, typeof(integ))
    print(io, ")")
end
