# =============================================================================
# ControlledFlow — state flow of a controlled system (OpenLoop / ClosedLoop)
#
# Wraps an inner state flow (VectorFieldSystem of the closed-loop dynamics) and the
# control law. Point evaluation returns the final state; a trajectory call returns a
# StateFlowTrajectory (state + reconstructed control [+ objective when from an OCP]).
# =============================================================================

"""
$(TYPEDEF)

State flow of a controlled dynamical system with an `OpenLoop` or `ClosedLoop` control
law, built by [`CTFlows.Flows.Flow`](@ref) from `Flow(ocp, law)` or `Flow(fc, law)`.

Unlike an [`CTFlows.Flows.OptimalControlFlow`](@ref) (Hamiltonian, with a costate), this
is a **state** flow: point evaluation is `f(t0, x0, tf; variable)` (no costate) and a
trajectory call returns a [`CTFlows.Trajectories.StateFlowTrajectory`](@ref).

# Type Parameters
- `TD`, `VD`: time/variable dependence, inherited from the inner flow.
- `IF`: type of the inner state flow.
- `M`: type of the OCP model, or `Nothing` (for `Flow(fc, law)`).
- `L`: type of the control law.

# Fields
- `flow::IF`: the inner state flow integrating `ẋ = g(t, x, v)`.
- `ocp::M`: the OCP model (for the objective), or `nothing`.
- `law::L`: the control law, used to reconstruct `u(t)`.

See also: [`CTFlows.Trajectories.StateFlowTrajectory`](@ref), [`CTFlows.Flows.Flow`](@ref).
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
    xf = F.flow(t0, x0, tf; variable, unsafe)
    return _flow_state_coerce(F.ocp, x0)(xf)   # 1-D = scalar
end

# ── trajectory call — builds a StateFlowTrajectory ──────────────────────────

"""
$(TYPEDSIGNATURES)

Trajectory call: integrate the inner state flow over `tspan` and build a
[`CTFlows.Trajectories.StateFlowTrajectory`](@ref) (state + reconstructed control,
plus objective when built from an OCP).
"""
function (F::ControlledFlow)(
    tspan::Tuple{<:Real,<:Real}, x0; variable=__variable(), unsafe=__unsafe()
)
    traj = F.flow(tspan, x0; variable, unsafe)   # VectorFieldTrajectory
    coerce = _flow_state_coerce(F.ocp, x0)  # precomputed once (only / identity)
    obj = _state_flow_objective(F.ocp, traj, F.law, variable, integrator(F.flow), coerce)
    return Trajectories.StateFlowTrajectory(traj, F.law, variable, obj, coerce, F.ocp)
end

# State coercion (only for a 1-D state, identity otherwise), precomputed once — from the
# OCP's declared state dimension, or from `x0` when there is no OCP (Flow(fc, law)).
"""
$(TYPEDSIGNATURES)

Precomputed state coercion (`only` for a 1-D state, `identity` otherwise) from the
OCP's declared state dimension. Unlike [`CTFlows.Flows._dim_coerce`](@ref) alone, this
also special-cases a batched `Matrix` `x0` to always return `identity`, regardless of the
declared dimension — `_dim_coerce` is baked in from the OCP's *declared* dimension and
cannot see `x0`'s runtime shape by itself. Fixing it here (the single source of `coerce`)
covers every later application of the returned function, including inside
[`CTFlows.Trajectories.StateFlowTrajectory`](@ref).
"""
_flow_state_coerce(ocp, ::AbstractMatrix) = identity

"""
$(TYPEDSIGNATURES)

State coercion from the OCP's declared state dimension for a non-batched `x0`:
`only` for a 1-D state, `identity` otherwise.

See also: [`CTFlows.Flows._flow_state_coerce`](@ref), [`CTFlows.Flows._dim_coerce`](@ref).
"""
_flow_state_coerce(ocp, x0) = _dim_coerce(CTModels.Models.state_dimension(ocp))

"""
$(TYPEDSIGNATURES)

Precomputed state coercion (`only` for a 1-D state, `identity` otherwise) inferred from
`x0` when there is no OCP (`Flow(fc, law)`); a batched `Matrix` `x0` always yields
`identity` — see [`CTFlows.Flows._flow_state_coerce`](@ref).
"""
_flow_state_coerce(::Nothing, ::AbstractMatrix) = identity
"""
$(TYPEDSIGNATURES)

Precomputed state coercion (`only` for a 1-D state, `identity` otherwise) inferred from
`x0` when there is no OCP (`Flow(fc, law)`): a `Matrix` `x0` always yields `identity`
(see [`CTFlows.Flows._flow_state_coerce`](@ref)).

See also: [`CTFlows.Flows._flow_state_coerce`](@ref), [`CTFlows.Flows._dim_coerce`](@ref).
"""
_flow_state_coerce(::Nothing, x0) = _dim_coerce(length(x0))

# =============================================================================
# Objective (only when the flow was built from an OCP)
# =============================================================================

"""
$(TYPEDSIGNATURES)

No objective when the state flow was not built from an OCP (e.g. `Flow(fc, law)`).
"""
_state_flow_objective(::Nothing, traj, law, variable, integ, coerce) = nothing

"""
$(TYPEDSIGNATURES)

Compute the objective (Mayer + Lagrange) of an OCP along a state-flow trajectory.

Builds the (1-D = scalar coerced) state projection `x(t)` and the reconstructed control
`u(t)` from the law (empty when `law === nothing`), then delegates to the shared
[`CTFlows.Flows._flow_objective`](@ref) core.

See also: [`CTFlows.Trajectories.StateFlowTrajectory`](@ref), `CTFlows.Flows._flow_objective`, `CTFlows.Flows._control_of`.
"""
function _state_flow_objective(ocp, traj, law, variable, integ, coerce)
    x = Trajectories.ControlledStateProjection(traj, coerce)  # callable x(t), scalar for 1-D
    T = collect(Float64, Trajectories.time_grid(traj))
    t0, tf = first(T), last(T)
    v = Trajectories._cp_variable(variable)  # raw variable (nothing if NotProvided)
    u = _control_of(law, x, v)               # OpenLoop/ClosedLoop, or empty when law===nothing
    return _flow_objective(ocp, x, u, v, t0, tf, integ)
end
