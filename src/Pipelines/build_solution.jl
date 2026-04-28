"""
$(TYPEDSIGNATURES)

Package the raw ODE solution into the appropriate result type.

This function delegates to the system's own `build_solution` method, which was
embedded by the modeler when the system was assembled. The packaging logic is
system-specific (e.g., raw trajectory for vector fields, `CTModels.Solution` for OCPs).

# Arguments
- `system::Systems.AbstractSystem`: The system that produced the solution.
- `ode_sol`: The raw ODE solution from the integrator.

# Returns
- The packaged solution (type varies by system implementation).

See also: [`Systems.build_solution`](@ref), [`solve`](@ref).
"""
function build_solution(system::Systems.AbstractSystem, ode_sol)
    return Systems.build_solution(system, ode_sol)
end
