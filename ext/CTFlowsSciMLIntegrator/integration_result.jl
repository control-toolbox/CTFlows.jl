# =============================================================================
# SciMLIntegrationResult
# =============================================================================

"""
$(TYPEDEF)

Integration result from a SciML solver.

Wraps a `SciMLBase.AbstractODESolution` and implements the `AbstractIntegrationResult`
interface required by the Trajectories layer.

# Fields
- `ode_sol::S`: The raw SciML ODE solution.
"""
struct SciMLIntegrationResult{S<:SciMLBase.AbstractODESolution} <:
       Integrators.AbstractIntegrationResult
    ode_sol::S
end

"""
$(TYPEDSIGNATURES)

Return the final state vector from the SciML ODE solution.

# Arguments
- `r::SciMLIntegrationResult`: The integration result.

# Returns
- The final state vector.

See also: [`CTFlowsSciMLIntegrator.SciMLIntegrationResult`](@ref), [`CTFlows.Integrators.times`](@ref).
"""
Integrators.final_state(r::SciMLIntegrationResult) = last(r.ode_sol.u)

"""
$(TYPEDSIGNATURES)

Return the vector of time points from the SciML ODE solution.

# Arguments
- `r::SciMLIntegrationResult`: The integration result.

# Returns
- Vector of time points.

See also: [`CTFlowsSciMLIntegrator.SciMLIntegrationResult`](@ref), [`CTFlows.Integrators.final_state`](@ref).
"""
Integrators.times(r::SciMLIntegrationResult) = r.ode_sol.t

"""
$(TYPEDSIGNATURES)

Evaluate the SciML ODE solution at a specific time `t` using its interpolation.

# Arguments
- `r::SciMLIntegrationResult`: The integration result.
- `t::Real`: The time at which to evaluate the solution.

# Returns
- The state vector at time `t`.

See also: [`CTFlowsSciMLIntegrator.SciMLIntegrationResult`](@ref), [`CTFlows.Integrators.times`](@ref).
"""
Integrators.evaluate_at(r::SciMLIntegrationResult, t::Real) = r.ode_sol(t)

# =============================================================================
# SciML Segment Merging
# =============================================================================

"""
$(TYPEDSIGNATURES)

Merge a sequence of SciML ODE solutions into a single solution.
This allows concatenation of trajectories from multiple phases.
"""
function Integrators.merge(segments::AbstractVector{<:SciMLIntegrationResult})
    # Extract the raw ODESolution objects
    ode_sols = [r.ode_sol for r in segments]

    if isempty(ode_sols)
        throw(
            Exceptions.IncorrectArgument(
                "Cannot merge empty sequence of segments";
                got="0 segments",
                expected="at least 1 segment",
                context="SciML merge",
            ),
        )
    end

    if length(ode_sols) == 1
        return segments[1]
    end

    # Merge using DiffEqBase.EnsembleSolution (or custom concatenation if we want a single ODESolution)
    # The simplest robust way in SciML to represent concatenated trajectories over time
    # is often to reconstruct an ODESolution, but since times are strictly monotonic 
    # (except at jumps where they might be equal), we can concatenate `t`, `u` and `k`.
    # Let's concatenate them to form a continuous trajectory.

    t_merged = copy(ode_sols[1].t)
    u_merged = copy(ode_sols[1].u)

    for i in eachindex(ode_sols)[2:end]
        sol = ode_sols[i]
        # Append all points except the first one (which is the same time as previous last, but after jump)
        # Actually, keep it so we can have discontinuities properly represented.
        append!(t_merged, sol.t)
        append!(u_merged, sol.u)
    end

    # Create a new ODESolution (using the first one as template)
    # This is a bit of a hack, but SciML doesn't provide a clean `vcat` for ODESolutions yet.
    # Note: Interpolation might not work properly across the whole merged solution this way.
    sol1 = ode_sols[1]

    merged_sol = DiffEqBase.build_solution(
        sol1.prob,
        sol1.alg,
        t_merged,
        u_merged;
        retcode=SciMLBase.ReturnCode.Success,
        dense=false, # Disable dense interpolation for merged as it requires k-arrays which are tricky to merge
    )

    return SciMLIntegrationResult(merged_sol)
end
