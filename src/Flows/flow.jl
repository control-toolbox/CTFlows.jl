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
Flow(system=FakeSystem(n_x=2, n_p=2), integrator=FakeIntegrator)
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

"""
$(TYPEDSIGNATURES)

Integrate the flow from initial state `x0` at time `t0` to final time `tf`.

This method builds an ODE problem from the system's RHS, calls the integrator,
and packages the result using the system's `build_solution` method.

See also: [`AbstractFlow`](@ref), [`rhs!`](@ref), [`build_solution`](@ref).
"""
function (f::Flow)(t0, x0, tf)
    rhs = Systems.rhs!(f.system)
    # In a real implementation, this would build an ODEProblem and call the integrator
    # For now, we delegate to the integrator's callable
    ode_problem = (rhs, t0, x0)  # Placeholder: should be an actual ODEProblem
    ode_sol = f.integrator(ode_problem, (t0, tf))
    return Systems.build_solution(f.system, ode_sol)
end

"""
$(TYPEDSIGNATURES)

Integrate the flow from initial state `x0` and costate `p0` at time `t0` to final time `tf`.

See also: [`AbstractFlow`](@ref).
"""
function (f::Flow)(t0, x0, p0, tf)
    rhs = Systems.rhs!(f.system)
    # In a real implementation, this would build an ODEProblem with augmented state
    # For now, we delegate to the integrator's callable
    ode_problem = (rhs, t0, [x0; p0])  # Placeholder: should be an actual ODEProblem
    ode_sol = f.integrator(ode_problem, (t0, tf))
    return Systems.build_solution(f.system, ode_sol)
end
