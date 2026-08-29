# =============================================================================
# Description vocabulary and per-type contracts
# =============================================================================

"""
$(TYPEDSIGNATURES)

Standardize a `description` tuple: map plural forms to singular and drop duplicates.
The canonical symbols are `:state`, `:costate`, `:control`.
"""
function clean(description)
    description = replace(
        description, :states => :state, :costates => :costate, :controls => :control
    )
    return tuple(Set(description)...)
end

"""
$(TYPEDSIGNATURES)

Contract: the default panels for a trajectory when the user gives no `description`.
Defined on the **abstract** trajectory types and specialized where a subtype exposes
more (a `StateFlowTrajectory` also has a control).

- `AbstractVectorFieldTrajectory` → `(:state,)`
- `StateFlowTrajectory` → `(:state, :control)`
- `AbstractHamiltonianVectorFieldTrajectory` → `(:state, :costate)`
"""
_default_description(::Trajectories.AbstractVectorFieldTrajectory) = (:state,)
_default_description(::Trajectories.StateFlowTrajectory) = (:state, :control)
function _default_description(::Trajectories.AbstractHamiltonianVectorFieldTrajectory)
    return (:state, :costate)
end
