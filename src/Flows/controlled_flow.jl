# =============================================================================
# ControlledFlow — state flow of a controlled system (OpenLoop / ClosedLoop)
#
# Wraps an inner state flow (VectorFieldSystem of the closed-loop dynamics) and the
# control law. Point evaluation returns the final state; a trajectory call returns a
# ControlledTrajectory (state + reconstructed control [+ objective when from an OCP]).
# =============================================================================

"""
$(TYPEDEF)

State flow of a controlled dynamical system with an `OpenLoop` or `ClosedLoop` control
law, built by [`CTFlows.Flows.Flow`](@ref) from `Flow(ocp, law)` or `Flow(fc, law)`.

Unlike an [`CTFlows.Flows.OptimalControlFlow`](@ref) (Hamiltonian, with a costate), this
is a **state** flow: point evaluation is `f(t0, x0, tf; variable)` (no costate) and a
trajectory call returns a [`CTFlows.Trajectories.ControlledTrajectory`](@ref).

# Type Parameters
- `TD`, `VD`: time/variable dependence, inherited from the inner flow.
- `IF`: type of the inner state flow.
- `M`: type of the OCP model, or `Nothing` (for `Flow(fc, law)`).
- `L`: type of the control law.

# Fields
- `flow::IF`: the inner state flow integrating `ẋ = g(t, x, v)`.
- `ocp::M`: the OCP model (for the objective), or `nothing`.
- `law::L`: the control law, used to reconstruct `u(t)`.

See also: [`CTFlows.Trajectories.ControlledTrajectory`](@ref), [`CTFlows.Flows.Flow`](@ref).
"""
struct ControlledFlow{TD<:Traits.TimeDependence,VD<:Traits.VariableDependence,IF,M,L} <:
       AbstractFlow{TD,VD,Traits.StateDynamics}
    flow::IF
    ocp::M
    law::L
end

"""
$(TYPEDSIGNATURES)

Construct a [`CTFlows.Flows.ControlledFlow`](@ref) from an inner state
[`CTFlows.Flows.Flow`](@ref), an optional OCP (for the objective), and a control law.
"""
function ControlledFlow(
    flow::Flow{TD,VD,Traits.StateDynamics}, ocp, law
) where {TD<:Traits.TimeDependence,VD<:Traits.VariableDependence}
    return ControlledFlow{TD,VD,typeof(flow),typeof(ocp),typeof(law)}(flow, ocp, law)
end

"""
$(TYPEDSIGNATURES)

Return the underlying [`CTFlows.Systems.AbstractSystem`](@ref) of the inner state flow.
"""
system(F::ControlledFlow) = system(F.flow)
"""
$(TYPEDSIGNATURES)

Return the underlying [`CTSolvers.Integrators.AbstractIntegrator`](@extref) of the inner
state flow.
"""
integrator(F::ControlledFlow) = integrator(F.flow)

# ── point eval — pure delegation (final state, no costate) ───────────────────

"""
$(TYPEDSIGNATURES)

Point evaluation: delegate to the inner state flow and return the final state at `tf`
(no costate — this is a state flow).
"""
function (F::ControlledFlow)(
    t0::Real, x0, tf::Real; variable=__variable(), unsafe=__unsafe()
)
    return F.flow(t0, x0, tf; variable, unsafe)
end

# ── trajectory call — builds a ControlledTrajectory ──────────────────────────

"""
$(TYPEDSIGNATURES)

Trajectory call: integrate the inner state flow over `tspan` and build a
[`CTFlows.Trajectories.ControlledTrajectory`](@ref) (state + reconstructed control,
plus objective when built from an OCP).
"""
function (F::ControlledFlow)(
    tspan::Tuple{<:Real,<:Real}, x0; variable=__variable(), unsafe=__unsafe()
)
    traj = F.flow(tspan, x0; variable, unsafe)   # VectorFieldTrajectory
    coerce = _controlled_state_coerce(F.ocp, x0)  # precomputed once (only / identity)
    obj = _controlled_objective(F.ocp, traj, F.law, variable, integrator(F.flow), coerce)
    return Trajectories.ControlledTrajectory(traj, F.law, variable, obj, coerce, F.ocp)
end

# State coercion (only for a 1-D state, identity otherwise), precomputed once — from the
# OCP's declared state dimension, or from `x0` when there is no OCP (Flow(fc, law)).
"""
$(TYPEDSIGNATURES)

Precomputed state coercion (`only` for a 1-D state, `identity` otherwise) from the
OCP's declared state dimension.
"""
_controlled_state_coerce(ocp, x0) = _dim_coerce(CTModels.Models.state_dimension(ocp))
"""
$(TYPEDSIGNATURES)

Precomputed state coercion (`only` for a 1-D state, `identity` otherwise) inferred from
`x0` when there is no OCP (`Flow(fc, law)`).
"""
_controlled_state_coerce(::Nothing, x0) = _dim_coerce(length(x0))

# =============================================================================
# Objective (only when the flow was built from an OCP)
# =============================================================================

"""
$(TYPEDSIGNATURES)

No objective when the controlled flow was not built from an OCP (e.g. `Flow(fc, law)`).
"""
_controlled_objective(::Nothing, traj, law, variable, integ, coerce) = nothing

"""
$(TYPEDSIGNATURES)

Compute the objective (Mayer + Lagrange) of an OCP along a controlled state trajectory,
reconstructing the control `u(t) = law(t, x(t), v)` for the Lagrange integrand.

See also: [`CTFlows.Trajectories.ControlledTrajectory`](@ref), `CTFlows.Flows._ocp_objective`.
"""
function _controlled_objective(ocp, traj, law, variable, integ, coerce)
    x = Trajectories.ControlledStateProjection(traj, coerce)   # callable x(t), scalar for 1-D
    T = collect(Float64, Trajectories.time_grid(traj))
    t0, tf = first(T), last(T)
    v = Trajectories._cp_variable(variable)            # raw variable (nothing if NotProvided)
    obj = 0.0
    if CTModels.Components.has_mayer_cost(ocp)
        may = CTModels.Components.mayer(ocp)
        obj += may(x(t0), x(tf), v)
    end
    if CTModels.Components.has_lagrange_cost(ocp)
        lag = CTModels.Components.lagrange(ocp)
        running = Data.VectorField(
            (t, ℓ_vec) -> [lag(t, x(t), Trajectories._controlled_u(law, t, x(t), v), v)];
            is_autonomous=false,
            is_variable=false,
        )
        cost_flow = build_flow(Systems.build_system(running), integ)
        obj += cost_flow(t0, [0.0], tf)[1]
    end
    return obj
end
