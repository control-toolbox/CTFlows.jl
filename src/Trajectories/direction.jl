# =============================================================================
# Direction of time of a trajectory (issue #547)
#
# A flow may be integrated backward (t0 > tf). Its trajectory is always returned in
# increasing time: the integration result is read in the other direction with
# `reverse` (CTSolvers), without integrating again. So a backward trajectory gives the same
# objects as the forward one over the same interval: increasing time grid, switching times
# in increasing order, left-continuous at a switching time, objective over [min, max].
# =============================================================================

"""
$(TYPEDSIGNATURES)

Whether the time grid of an integration result decreases: the result of a backward
integration, still in integration order.
"""
function _is_backward(result::Integrators.AbstractIntegrationResult)
    return _is_backward(Integrators.times(result))
end
_is_backward(ts::AbstractVector) = length(ts) >= 2 && first(ts) > last(ts)

"""
$(TYPEDSIGNATURES)

Return the trajectory in increasing time. A trajectory integrated backward (`t0 > tf`) is read
in the other direction of time, with the same interpolant (`reverse` of
[`CTSolvers.Integrators.AbstractIntegrationResult`](@extref)); a forward one is returned
unchanged.

This is the convention of every trajectory call of a flow: **the time grid is increasing,
whatever the direction of integration**. For a multi-phase flow, the switching times are then
increasing too, and the trajectory is left-continuous at each of them (the value at `tᵢ` is
the one before the jump, in increasing time).

# Arguments
- `traj`: a [`CTFlows.Trajectories.VectorFieldTrajectory`](@extref) or a
  [`CTFlows.Trajectories.HamiltonianVectorFieldTrajectory`](@extref), in integration order.

# Returns
- The same type, in increasing time. Any other value (a trajectory type this function does
  not know) is returned unchanged.
"""
in_increasing_time(traj) = traj
function in_increasing_time(traj::VectorFieldTrajectory)
    _is_backward(traj.result) || return traj
    return VectorFieldTrajectory(reverse(traj.result), traj.variable, traj.x0, traj.labels)
end
function in_increasing_time(traj::HamiltonianVectorFieldTrajectory)
    _is_backward(traj.result) || return traj
    return HamiltonianVectorFieldTrajectory(
        traj.x0, reverse(traj.result), traj.variable, traj.labels
    )
end
