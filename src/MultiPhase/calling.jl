# ==============================================================================
# Generic Multiphase Evaluation Loop
# ==============================================================================

"""
$(TYPEDSIGNATURES)

Extract the initial state from a state configuration.

# Arguments
- `config::Configs.AbstractStateConfig`: The state configuration (StateEndPointConfig or StateTrajectoryConfig).

# Returns
- Initial state vector.

See also: [`CTFlows.Configs.initial_state`](@ref), [`CTFlows.Configs.AbstractStateConfig`](@ref).
"""
function _extract_initial_state(config::Configs.AbstractStateConfig)
    return Configs.initial_state(config)
end

"""
$(TYPEDSIGNATURES)

Extract the initial state and costate from a Hamiltonian configuration.

# Arguments
- `config::Configs.AbstractHamiltonianConfig`: The Hamiltonian configuration (HamiltonianEndPointConfig or HamiltonianTrajectoryConfig).

# Returns
- Tuple of (initial_state, initial_costate).

See also: [`CTFlows.Configs.initial_state`](@ref), [`CTFlows.Configs.initial_costate`](@ref), [`CTFlows.Configs.AbstractHamiltonianConfig`](@ref).
"""
function _extract_initial_state(config::Configs.AbstractHamiltonianConfig)
    return (Configs.initial_state(config), Configs.initial_costate(config))
end

"""
$(TYPEDSIGNATURES)

Evaluate a multi-phase flow for a point configuration, returning only the final state.

Iterates through all phases sequentially, applying jumps at switching times.

# Arguments
- `mpf`: The multi-phase flow to evaluate.
- `config::Configs.AbstractEndPointConfig`: The point configuration with time span and initial conditions.
- `variable`: The variable parameter value (for NonFixed systems).
- `unsafe`: If true, bypass ODE solver retcode checking.

# Returns
- Final state after all phases.

See also: [`CTFlows.MultiPhase._evaluate_phase`](@ref), [`CTFlows.MultiPhase._apply_jump`](@ref).
"""
function _evaluate_multiphase(mpf, config::Configs.AbstractEndPointConfig; variable, unsafe)
    t0, tf = Configs.tspan(config)
    current_state = _extract_initial_state(config)
    current_t = t0
    n_ph = n_phases(mpf)

    for i in 1:n_ph
        t_end = (i < n_ph) ? get_switching_time(mpf, i) : tf

        current_state = _evaluate_phase(
            get_flow(mpf, i),
            current_t,
            t_end,
            current_state,
            config;
            variable=variable,
            unsafe=unsafe,
        )

        current_t = t_end

        if i < n_ph
            jump = get_jump(mpf, i)
            if !isnothing(jump)
                current_state = _apply_jump(mpf, i, current_state)
            end
        end
    end

    return _format_final_output(mpf, current_state)
end

"""
$(TYPEDSIGNATURES)

Evaluate a multi-phase flow for a trajectory configuration, returning the full trajectory.

Iterates through all phases sequentially, collecting segment results and applying jumps at switching times.

# Arguments
- `mpf`: The multi-phase flow to evaluate.
- `config::Configs.AbstractTrajectoryConfig`: The trajectory configuration with time span and initial conditions.
- `variable`: The variable parameter value (for NonFixed systems).
- `unsafe`: If true, bypass ODE solver retcode checking.

# Returns
- Merged trajectory solution after all phases.

See also: [`CTSolvers.Integrators.merge`](@extref), [`CTFlows.MultiPhase._evaluate_phase`](@ref), [`CTFlows.MultiPhase._apply_jump`](@ref).
"""
function _evaluate_multiphase(
    mpf, config::Configs.AbstractTrajectoryConfig; variable, unsafe
)
    t0, tf = Configs.tspan(config)
    current_state = _extract_initial_state(config)
    current_t = t0
    n_ph = n_phases(mpf)

    results = nothing

    for i in 1:n_ph
        t_end = (i < n_ph) ? get_switching_time(mpf, i) : tf

        segment_result = _evaluate_phase(
            get_flow(mpf, i),
            current_t,
            t_end,
            current_state,
            config;
            variable=variable,
            unsafe=unsafe,
        )
        results = isnothing(results) ? [segment_result] : push!(results, segment_result)

        current_state = _extract_final_state(mpf, segment_result, current_state)
        current_t = t_end

        if i < n_ph
            jump = get_jump(mpf, i)
            if !isnothing(jump)
                current_state = _apply_jump(mpf, i, current_state)
            end
        end
    end

    return _finalize_multiphase_trajectory(mpf, Integrators.merge(results), variable)
end

# =============================================================================
# Final reconstruction of a multi-phase trajectory
#
# A multi-phase trajectory must return the SAME type a single-phase flow returns, with a
# PIECEWISE control reconstructed from the per-phase laws: all-OptimalControlFlow phases → a
# CTModels Solution (via _build_ocp_solution), all-ControlledFlow phases → a
# StateFlowTrajectory. Plain flows (no law) keep returning the merged raw trajectory.
# =============================================================================

"""
$(TYPEDEF)

Piecewise control law reconstructed from the per-phase laws of a multi-phase flow. It selects
the phase by time (a flat `searchsortedlast` over the switching times — no nested closures),
then delegates to that phase's law with the caller's uniform signature. It serves both
reconstruction paths: `(pl)(t, x, p, v)` for the Hamiltonian/OCP law, and
`CTFlows.Trajectories._controlled_u(pl, t, x, v)` for the state (controlled) law.

At an exact switching time the *next* phase is selected — a measure-zero choice, irrelevant to
plotting and to objective integration.

# Type Parameters
- `L`: type of the tuple of per-phase control laws.
- `S`: type of the switching-times vector.

# Fields
- `laws::L`: tuple of the per-phase control laws (each a `CTBase.Data.ControlLaw`).
- `switches::S`: the `n-1` sorted switching times.

See also: [`CTFlows.MultiPhase._reconstruct_ocp_solution`](@ref),
[`CTFlows.MultiPhase._reconstruct_controlled_trajectory`](@ref).
"""
struct _PiecewiseControlLaw{L,S}
    laws::L      # tuple of per-phase Data.ControlLaw
    switches::S  # vector of switching times
end

"""
$(TYPEDSIGNATURES)

Return the phase law active at time `t`: the law of the phase selected by `searchsortedlast`
over the switching times, clamped to the valid phase range.

# Arguments
- `pl::_PiecewiseControlLaw`: The piecewise control law.
- `t`: The time at which to select the active phase.

# Returns
- The per-phase control law active at time `t`.
"""
function _phase_law(pl::_PiecewiseControlLaw, t)
    return pl.laws[clamp(searchsortedlast(pl.switches, t) + 1, 1, length(pl.laws))]
end

"""
$(TYPEDSIGNATURES)

Hamiltonian/OCP uniform call: delegate to the phase law active at time `t`.

# Arguments
- `pl::_PiecewiseControlLaw`: The piecewise control law.
- `t`: Time.
- `x`: State.
- `p`: Costate.
- `v`: Variable (or `Core.NotProvided`).

# Returns
- The control `u = law(t, x, p, v)` of the phase active at `t`.
"""
(pl::_PiecewiseControlLaw)(t, x, p, v) = _phase_law(pl, t)(t, x, p, v)

"""
$(TYPEDSIGNATURES)

State (controlled) uniform call: delegate to the phase law active at time `t`, dispatched by
`CTFlows.Trajectories` on that law's feedback trait (`OpenLoop`/`ClosedLoop`).

# Arguments
- `pl::_PiecewiseControlLaw`: The piecewise control law.
- `t`: Time.
- `x`: State.
- `v`: Variable (or `Core.NotProvided`).

# Returns
- The control of the phase active at `t`, reconstructed by the feedback-dispatched call.
"""
function Trajectories._controlled_u(pl::_PiecewiseControlLaw, t, x, v)
    return Trajectories._controlled_u(_phase_law(pl, t), t, x, v)
end

"""
$(TYPEDSIGNATURES)

Finalize a merged multi-phase trajectory into the type a single-phase flow would return.

All-`OptimalControlFlow` phases rebuild a [`CTModels.Solutions.Solution`](@extref) (via
[`CTFlows.MultiPhase._reconstruct_ocp_solution`](@ref)); all-`ControlledFlow` phases rebuild a
[`CTFlows.Trajectories.StateFlowTrajectory`](@ref) (via
[`CTFlows.MultiPhase._reconstruct_controlled_trajectory`](@ref)); any other case (plain flows
carrying no law) returns the merged raw trajectory unchanged.

The branch is a runtime `isa` test on the phase types rather than dispatch: a parametric alias
(e.g. `MultiPhaseHamiltonianFlow`) is not more specific than the constrained base type, so it
cannot select a method here.

# Arguments
- `mpf::MultiPhaseFlow`: The multi-phase flow whose phases carry the per-phase laws.
- `merged`: The merged trajectory over all phases.
- `variable`: The variable parameter value (for NonFixed systems).

# Returns
- A `CTModels.Solution`, a `StateFlowTrajectory`, or the merged trajectory (see above).

See also: [`CTFlows.MultiPhase._evaluate_multiphase`](@ref).
"""
function _finalize_multiphase_trajectory(mpf::MultiPhaseFlow, merged, variable)
    phases = get_flows(mpf)
    isempty(phases) && return merged
    if all(p -> p isa Flows.OptimalControlFlow, phases)
        return _reconstruct_ocp_solution(mpf, merged, variable)
    end
    if all(p -> p isa Flows.ControlledFlow, phases)
        return _reconstruct_controlled_trajectory(mpf, merged, variable)
    end
    return merged
end

"""
$(TYPEDSIGNATURES)

Return the OCP shared by every phase. `Flow(fc, law)` phases carry no OCP (`nothing`), which
compare equal under `===`.

# Arguments
- `phases`: The tuple of phase flows (each carrying an `ocp` field).

# Returns
- The single OCP object (or `nothing`) common to all phases.

# Throws
- [`CTBase.Exceptions.IncorrectArgument`](@extref): if the phases carry two or more distinct
  OCP objects.
"""
function _shared_ocp(phases)
    ocp = phases[1].ocp
    all(p -> p.ocp === ocp, phases) || throw(
        Exceptions.IncorrectArgument(
            "cannot reconstruct a multi-phase solution from flows of different OCPs";
            got="phases carry ≥ 2 distinct ocp objects",
            expected="all phases built from the same ocp",
            context="MultiPhase trajectory reconstruction",
        ),
    )
    return ocp
end

"""
$(TYPEDSIGNATURES)

Rebuild a [`CTModels.Solutions.Solution`](@extref) from an all-`OptimalControlFlow` multi-phase
trajectory, reconstructing the control as a [`CTFlows.MultiPhase._PiecewiseControlLaw`](@ref)
over the per-phase laws.

# Arguments
- `mpf`: The multi-phase Hamiltonian flow.
- `merged`: The merged Hamiltonian trajectory over all phases.
- `variable`: The variable parameter value (for NonFixed systems).

# Returns
- A [`CTModels.Solutions.Solution`](@extref) with the piecewise-reconstructed control.

See also: [`CTFlows.MultiPhase._reconstruct_controlled_trajectory`](@ref), `CTFlows.Flows._build_ocp_solution`.
"""
function _reconstruct_ocp_solution(mpf, merged, variable)
    phases = get_flows(mpf)
    ocp = _shared_ocp(phases)
    plaw = _PiecewiseControlLaw(map(p -> p.law, phases), get_switching_times(mpf))
    integ = Flows.integrator(phases[1])
    return Flows._build_ocp_solution(ocp, merged, variable, integ, plaw)
end

"""
$(TYPEDSIGNATURES)

Rebuild a [`CTFlows.Trajectories.StateFlowTrajectory`](@ref) from an all-`ControlledFlow`
multi-phase trajectory, reconstructing the control as a
[`CTFlows.MultiPhase._PiecewiseControlLaw`](@ref) and recomputing the objective (Mayer +
Lagrange) over the merged trajectory when the phases carry an OCP (`nothing` objective for
`Flow(fc, law)` phases).

# Arguments
- `mpf`: The multi-phase state flow.
- `merged`: The merged state trajectory over all phases.
- `variable`: The variable parameter value (for NonFixed systems).

# Returns
- A [`CTFlows.Trajectories.StateFlowTrajectory`](@ref) with the piecewise-reconstructed control.

See also: [`CTFlows.MultiPhase._reconstruct_ocp_solution`](@ref), `CTFlows.Flows._state_flow_objective`.
"""
function _reconstruct_controlled_trajectory(mpf, merged, variable)
    phases = get_flows(mpf)
    ocp = _shared_ocp(phases)
    plaw = _PiecewiseControlLaw(map(p -> p.law, phases), get_switching_times(mpf))
    integ = Flows.integrator(phases[1])
    coerce = Flows._dim_coerce(length(Integrators.final_state(merged)))
    obj = Flows._state_flow_objective(ocp, merged, plaw, variable, integ, coerce)
    return Trajectories.StateFlowTrajectory(merged, plaw, variable, obj, coerce, ocp)
end

# ==============================================================================
# Phase Evaluation & Jump Delegation
# ==============================================================================

"""
$(TYPEDSIGNATURES)

Return the raw inner flow of a phase, unwrapping the decorator flows
([`CTFlows.Flows.OptimalControlFlow`](@ref) / [`CTFlows.Flows.ControlledFlow`](@ref)) to the
inner `HamiltonianFlow`/`StateFlow` that yields a mergeable raw segment; any other
[`CTFlows.Flows.AbstractFlow`](@ref) (a plain `HamiltonianFlow`/`StateFlow` or a nested
`MultiPhaseFlow`) is returned unchanged.

Dispatching on the abstract flow type — one method per decorator plus the fallback — covers
every phase kind with no forgotten case.

# Arguments
- `f::Flows.AbstractFlow`: The phase flow.

# Returns
- The raw inner flow to integrate for this phase.
"""
_raw_flow(f::Flows.AbstractFlow) = f
_raw_flow(f::Flows.OptimalControlFlow) = f.flow
_raw_flow(f::Flows.ControlledFlow) = f.flow

"""
$(TYPEDSIGNATURES)

Evaluate a single phase for a state flow with point configuration.

Dispatches on the abstract dynamics axis (`AbstractStateFlow`) and unwraps decorator flows via
[`CTFlows.MultiPhase._raw_flow`](@ref) before integrating.

# Arguments
- `flow::Flows.AbstractStateFlow`: The state (or decorated state) flow to evaluate.
- `t0`: Start time.
- `tf`: End time.
- `x`: Initial state.
- `::Configs.AbstractEndPointConfig`: Point configuration type tag.
- `variable`: The variable parameter value (for NonFixed systems).
- `unsafe`: If true, bypass ODE solver retcode checking.

# Returns
- Final state at time tf.

See also: [`CTFlows.MultiPhase._raw_flow`](@ref), [`CTFlows.Flows.StateFlow`](@ref).
"""
function _evaluate_phase(
    flow::Flows.AbstractStateFlow,
    t0,
    tf,
    x,
    ::Configs.AbstractEndPointConfig;
    variable,
    unsafe,
)
    return _raw_flow(flow)(t0, x, tf; variable=variable, unsafe=unsafe)
end

"""
$(TYPEDSIGNATURES)

Evaluate a single phase for a state flow with trajectory configuration.

Dispatches on the abstract dynamics axis (`AbstractStateFlow`) and unwraps decorator flows via
[`CTFlows.MultiPhase._raw_flow`](@ref) before integrating.

# Arguments
- `flow::Flows.AbstractStateFlow`: The state (or decorated state) flow to evaluate.
- `t0`: Start time.
- `tf`: End time.
- `x`: Initial state.
- `::Configs.AbstractTrajectoryConfig`: Trajectory configuration type tag.
- `variable`: The variable parameter value (for NonFixed systems).
- `unsafe`: If true, bypass ODE solver retcode checking.

# Returns
- Trajectory solution from t0 to tf.

See also: [`CTFlows.MultiPhase._raw_flow`](@ref), [`CTFlows.Flows.StateFlow`](@ref).
"""
function _evaluate_phase(
    flow::Flows.AbstractStateFlow,
    t0,
    tf,
    x,
    ::Configs.AbstractTrajectoryConfig;
    variable,
    unsafe,
)
    return _raw_flow(flow)((t0, tf), x; variable=variable, unsafe=unsafe)
end

"""
$(TYPEDSIGNATURES)

Evaluate a single phase for a Hamiltonian flow with point configuration.

Dispatches on the abstract dynamics axis (`AbstractHamiltonianFlow`) and unwraps decorator
flows via [`CTFlows.MultiPhase._raw_flow`](@ref) before integrating.

# Arguments
- `flow::Flows.AbstractHamiltonianFlow`: The Hamiltonian (or decorated Hamiltonian) flow to evaluate.
- `t0`: Start time.
- `tf`: End time.
- `state_tuple`: Tuple of (initial_state, initial_costate).
- `::Configs.AbstractEndPointConfig`: Point configuration type tag.
- `variable`: The variable parameter value (for NonFixed systems).
- `unsafe`: If true, bypass ODE solver retcode checking.

# Returns
- Tuple of (final_state, final_costate) at time tf.

See also: [`CTFlows.MultiPhase._raw_flow`](@ref), [`CTFlows.Flows.HamiltonianFlow`](@ref).
"""
function _evaluate_phase(
    flow::Flows.AbstractHamiltonianFlow,
    t0,
    tf,
    state_tuple,
    ::Configs.AbstractEndPointConfig;
    variable,
    unsafe,
)
    x, p = state_tuple
    return _raw_flow(flow)(t0, x, p, tf; variable=variable, unsafe=unsafe)
end

"""
$(TYPEDSIGNATURES)

Evaluate a single phase for a Hamiltonian flow with trajectory configuration.

Dispatches on the abstract dynamics axis (`AbstractHamiltonianFlow`) and unwraps decorator
flows via [`CTFlows.MultiPhase._raw_flow`](@ref) before integrating.

# Arguments
- `flow::Flows.AbstractHamiltonianFlow`: The Hamiltonian (or decorated Hamiltonian) flow to evaluate.
- `t0`: Start time.
- `tf`: End time.
- `state_tuple`: Tuple of (initial_state, initial_costate).
- `::Configs.AbstractTrajectoryConfig`: Trajectory configuration type tag.
- `variable`: The variable parameter value (for NonFixed systems).
- `unsafe`: If true, bypass ODE solver retcode checking.

# Returns
- Trajectory solution from t0 to tf.

See also: [`CTFlows.MultiPhase._raw_flow`](@ref), [`CTFlows.Flows.HamiltonianFlow`](@ref).
"""
function _evaluate_phase(
    flow::Flows.AbstractHamiltonianFlow,
    t0,
    tf,
    state_tuple,
    ::Configs.AbstractTrajectoryConfig;
    variable,
    unsafe,
)
    x, p = state_tuple
    return _raw_flow(flow)((t0, tf), x, p; variable=variable, unsafe=unsafe)
end

"""
$(TYPEDSIGNATURES)

Extract the final state from a segment result for state flows.

# Arguments
- `::MultiPhaseStateFlow`: Multi-phase state flow type tag.
- `segment`: The segment solution.
- `current_state`: Current state (unused for state flows).

# Returns
- Final state from the segment.

See also: [`CTSolvers.Integrators.final_state`](@extref).
"""
function _extract_final_state(mpf::MultiPhaseFlow, segment, current_state)
    return _extract_final_state(Traits.dynamics_trait(mpf), segment, current_state)
end

"""
$(TYPEDSIGNATURES)

Extract the final state from a segment result for state dynamics.

# Arguments
- `::Type{Traits.StateDynamics}`: State dynamics trait tag.
- `segment`: The segment solution.
- `_`: Current state (unused for state dynamics).

# Returns
- Final state from the segment.

# Notes
This is an internal dispatch method for the `_extract_final_state` function.
"""
function _extract_final_state(::Type{Traits.StateDynamics}, segment, _)
    return Integrators.final_state(segment)
end

"""
$(TYPEDSIGNATURES)

Reshape a raw internal final state back to match `x0`'s own declared container type, for
inter-phase handoff inside a multi-phase state flow.

# Notes
This is deliberately **not** [`CTFlows.Systems._coerce_state`](@ref): that function also
collapses a length-1 `AbstractVector`/`SVector` to a scalar (the "1-D = scalar" convention,
issue #357), which is the right call for a *user-facing* accessor but wrong for this
*internal* handoff — it would silently turn a length-1-vector-sourced multi-phase state
into a scalar mid-chain, producing a phase 2 segment with a different `x0` container type
than phase 1's, which [`CTSolvers.Integrators.merge`](@extref) cannot concatenate. A bare
`Number` `x0` still collapses the raw result (needed because some flows, e.g.
`Flow(ocp, law)`, may integrate on an internally-promoted vector even when the caller
declared a scalar `x0`); any `AbstractVector`/`AbstractMatrix` `x0`, length-1 included, is
returned as-is.
"""
_reshape_to_x0(x0::Number, raw) = Systems._safe_only(raw)
_reshape_to_x0(x0, raw) = raw

"""
$(TYPEDSIGNATURES)

Extract the final state from a `VectorFieldTrajectory` segment for state dynamics,
reshaped back to the segment's own `x0` container type (see
[`CTFlows.MultiPhase._reshape_to_x0`](@ref)) rather than through its "1-D = scalar"
`Integrators.final_state` accessor (issue #357).
"""
function _extract_final_state(
    ::Type{Traits.StateDynamics}, segment::Trajectories.VectorFieldTrajectory, _
)
    return _reshape_to_x0(segment.x0, Integrators.final_state(segment.result))
end

"""
$(TYPEDSIGNATURES)

Extract the final state from a `StateFlowTrajectory` segment for state dynamics
(`Flow(fc, law)` / `Flow(ocp, law)`), reshaped back to the inner trajectory's own `x0`
container type (see [`CTFlows.MultiPhase._reshape_to_x0`](@ref)) rather than through its
"1-D = scalar" `Integrators.final_state` accessor — see the `VectorFieldTrajectory`
overload above for why.
"""
function _extract_final_state(
    ::Type{Traits.StateDynamics}, segment::Trajectories.StateFlowTrajectory, _
)
    return _reshape_to_x0(segment.traj.x0, Integrators.final_state(segment.traj.result))
end

"""
$(TYPEDSIGNATURES)

Extract the final state and costate from a segment result for Hamiltonian dynamics.

# Arguments
- `::Type{Traits.HamiltonianDynamics}`: Hamiltonian dynamics trait tag.
- `segment`: The segment solution (concatenated state and costate).
- `current_state`: Current state tuple (state, costate) used to determine dimensions.

# Returns
- Tuple of (final_state, final_costate).

# Notes
This is an internal dispatch method for the `_extract_final_state` function.
"""
function _extract_final_state(::Type{Traits.HamiltonianDynamics}, segment, current_state)
    final = Integrators.final_state(segment)
    nx = length(current_state[1])
    return (final[1:nx], final[(nx + 1):end])
end

function _extract_final_state(
    ::Type{Traits.HamiltonianDynamics},
    segment::Trajectories.HamiltonianVectorFieldTrajectory,
    _,
)
    return Integrators.final_state(segment)
end

"""
$(TYPEDSIGNATURES)

Apply an additive jump to a single component.

# Arguments
- `v`: Component value (state or costate).
- `j`: Additive offset (vector or scalar); added element-wise.

# Returns
- `v .+ j`.

See also: [`CTFlows.MultiPhase._apply_jump`](@ref).
"""
_apply_component_jump(v, j) = v .+ j

"""
$(TYPEDSIGNATURES)

Apply a callable jump to a single component.

# Arguments
- `v`: Component value (state or costate).
- `j::Function`: Callable; called as `j(v)`.

# Returns
- `j(v)`.

See also: [`CTFlows.MultiPhase._apply_jump`](@ref).
"""
_apply_component_jump(v, j::Function) = j(v)

"""
$(TYPEDSIGNATURES)

Identity jump — leave the component unchanged.

# Arguments
- `v`: Component value (state or costate).
- `::Nothing`: Sentinel for "no jump on this component".

# Returns
- `v` unchanged.

See also: [`CTFlows.MultiPhase._apply_jump`](@ref).
"""
_apply_component_jump(v, ::Nothing) = v

"""
$(TYPEDSIGNATURES)

Apply a jump to the state for state flows.

# Arguments
- `mpf::MultiPhaseStateFlow`: The multi-phase state flow.
- `i`: Phase index.
- `state`: Current state.

# Returns
- State after applying the jump.

See also: [`CTFlows.MultiPhase.get_jump`](@ref).
"""
function _apply_jump(mpf::MultiPhaseFlow, i, state)
    return _apply_jump(Traits.dynamics_trait(mpf), mpf, i, state)
end

"""
$(TYPEDSIGNATURES)

Apply a jump to the state for state dynamics.

# Arguments
- `::Type{Traits.StateDynamics}`: State dynamics trait tag.
- `mpf::MultiPhaseFlow`: The multi-phase flow.
- `i::Int`: Phase index.
- `state`: Current state.

# Returns
- State after applying the jump.

# Notes
This is an internal dispatch method for the `_apply_jump` function.
Delegates to [`CTFlows.MultiPhase._apply_component_jump`](@ref), which supports
additive offsets (`j` a vector/scalar), callables (`j(state)`), and `nothing`
(identity).
"""
function _apply_jump(::Type{Traits.StateDynamics}, mpf, i, state)
    return _apply_component_jump(state, get_jump(mpf, i))
end

"""
$(TYPEDSIGNATURES)

Apply a jump to the state and costate for Hamiltonian dynamics.

# Arguments
- `::Type{Traits.HamiltonianDynamics}`: Hamiltonian dynamics trait tag.
- `mpf::MultiPhaseFlow`: The multi-phase flow.
- `i::Int`: Phase index.
- `state_tuple`: Tuple of (state, costate).

# Returns
- Tuple of (state, costate) after applying the jump.

# Notes
This is an internal dispatch method for the `_apply_jump` function.
"""
function _apply_jump(::Type{Traits.HamiltonianDynamics}, mpf, i, state_tuple)
    return _apply_hamiltonian_jump(state_tuple, get_jump(mpf, i))
end

"""
$(TYPEDSIGNATURES)

Apply per-component jumps to a Hamiltonian state tuple.

Each component (`jump[1]` for state, `jump[2]` for costate) is handled
independently by [`CTFlows.MultiPhase._apply_component_jump`](@ref): a
vector/scalar is added, a callable is applied, and `nothing` leaves the
component unchanged.

# Arguments
- `state_tuple::Tuple`: Tuple of (state, costate).
- `jump::Tuple`: Tuple of (state_jump, costate_jump); each element may be a
  vector/scalar, a callable, or `nothing`.

# Returns
- Tuple of updated (state, costate).

See also: [`CTFlows.MultiPhase._apply_jump`](@ref),
  [`CTFlows.MultiPhase._apply_component_jump`](@ref).
"""
function _apply_hamiltonian_jump(state_tuple::Tuple, jump::Tuple)
    x, p = state_tuple
    return (_apply_component_jump(x, jump[1]), _apply_component_jump(p, jump[2]))
end

"""
$(TYPEDSIGNATURES)

Apply a callable jump to a Hamiltonian state tuple.

The callable receives both components and must return an updated
`(state, costate)` tuple: `(x, p) ← jump(x, p)`.

# Arguments
- `state_tuple::Tuple`: Tuple of (state, costate).
- `jump::Function`: Callable with signature `(x, p) -> (x', p')`.

# Returns
- Tuple `(x', p')` returned by `jump`.

See also: [`CTFlows.MultiPhase._apply_jump`](@ref),
  [`CTFlows.MultiPhase._apply_component_jump`](@ref).
"""
function _apply_hamiltonian_jump(state_tuple::Tuple, jump::Function)
    x, p = state_tuple
    return jump(x, p)
end

"""
$(TYPEDSIGNATURES)

Apply an additive costate jump to a Hamiltonian state tuple.

Adds `jump` to the costate only; the state is left unchanged.
Follows the "1-D is a scalar" convention: pass a scalar for a 1-D costate,
a vector for an n-D costate.

# Arguments
- `state_tuple::Tuple`: Tuple of (state, costate).
- `jump`: Additive costate offset (scalar or vector).

# Returns
- Tuple of `(state, costate .+ jump)`.

See also: [`CTFlows.MultiPhase._apply_jump`](@ref),
  [`CTFlows.MultiPhase._apply_component_jump`](@ref).
"""
function _apply_hamiltonian_jump(state_tuple::Tuple, jump)
    x, p = state_tuple
    return (x, p .+ jump)
end

"""
$(TYPEDSIGNATURES)

Format the final output for state flows.

# Arguments
- `::MultiPhaseStateFlow`: Multi-phase state flow type tag.
- `x`: Final state.

# Returns
- The final state (no formatting needed).

See also: [`CTFlows.MultiPhase._evaluate_multiphase`](@ref).
"""
function _format_final_output(mpf::MultiPhaseFlow, state)
    return _format_final_output(Traits.dynamics_trait(mpf), state)
end

"""
$(TYPEDSIGNATURES)

Format the final output for state dynamics.

# Arguments
- `::Type{Traits.StateDynamics}`: State dynamics trait tag.
- `x`: Final state.

# Returns
- The final state (no formatting needed).

# Notes
This is an internal dispatch method for the `_format_final_output` function.
"""
function _format_final_output(::Type{Traits.StateDynamics}, x)
    return x
end

"""
$(TYPEDSIGNATURES)

Format the final output for Hamiltonian dynamics.

# Arguments
- `::Type{Traits.HamiltonianDynamics}`: Hamiltonian dynamics trait tag.
- `state_tuple`: Tuple of (state, costate).

# Returns
- Concatenated vector [state; costate].

# Notes
This is an internal dispatch method for the `_format_final_output` function.
"""
function _format_final_output(::Type{Traits.HamiltonianDynamics}, state_tuple)
    x, p = state_tuple
    return vcat(x, p)
end

# ==============================================================================
# Public Callable Interfaces
# ==============================================================================

"""
$(TYPEDSIGNATURES)

Convenience call for `MultiPhaseStateFlow` with point configuration.

Builds a `StateEndPointConfig` internally and evaluates the multi-phase flow.

# Arguments
- `mpf::MultiPhaseStateFlow`: The multi-phase state flow to evaluate.
- `t0::Real`: Initial time.
- `x0`: Initial state vector.
- `tf::Real`: Final time.
- `variable`: The variable parameter value (required for NonFixed systems, optional for Fixed systems).
- `unsafe`: If `true`, bypass ODE solver retcode checking; if `false`, throw `SolverFailure` on integration failure.

# Returns
- The final state after sequential integration through all phases.

# Example
\`\`\`julia
using CTFlows.MultiPhase

mpf = flow1 * (1.0, flow2) * (2.0, flow3)
sol = mpf(0.0, [1.0, 0.0], 3.0)
\`\`\`

See also: [`CTFlows.MultiPhase.MultiPhaseStateFlow`](@ref), [`CTFlows.Configs.StateEndPointConfig`](@ref).
"""
function (mpf::MultiPhaseFlow{TD,VD,Traits.StateDynamics})(
    t0::Real, x0, tf::Real; variable=Flows.__variable(), unsafe=Flows.__unsafe()
) where {TD<:Traits.TimeDependence,VD<:Traits.VariableDependence}
    config = Configs.StateEndPointConfig(t0, x0, tf)
    xf = _evaluate_multiphase(mpf, config; variable=variable, unsafe=unsafe)
    return Systems._coerce_state(xf)(xf)   # 1-D = scalar
end

"""
$(TYPEDSIGNATURES)

Convenience call for `MultiPhaseStateFlow` with trajectory configuration.

Builds a `StateTrajectoryConfig` internally and evaluates the multi-phase flow,
returning a merged trajectory from all phases.

# Arguments
- `mpf::MultiPhaseStateFlow`: The multi-phase state flow to evaluate.
- `tspan::Tuple{Real, Real}`: Time span as a tuple (t0, tf).
- `x0`: Initial state vector.
- `variable`: The variable parameter value (required for NonFixed systems, optional for Fixed systems).
- `unsafe`: If `true`, bypass ODE solver retcode checking; if `false`, throw `SolverFailure` on integration failure.

# Returns
- The merged trajectory solution after sequential integration through all phases.

# Example
\`\`\`julia
using CTFlows.MultiPhase

mpf = flow1 * (1.0, flow2) * (2.0, flow3)
sol = mpf((0.0, 3.0), [1.0, 0.0])
\`\`\`

See also: [`CTFlows.MultiPhase.MultiPhaseStateFlow`](@ref), [`CTFlows.Configs.StateTrajectoryConfig`](@ref).
"""
function (mpf::MultiPhaseFlow{TD,VD,Traits.StateDynamics})(
    tspan::Tuple{Real,Real}, x0; variable=Flows.__variable(), unsafe=Flows.__unsafe()
) where {TD<:Traits.TimeDependence,VD<:Traits.VariableDependence}
    config = Configs.StateTrajectoryConfig(tspan, x0)
    return _evaluate_multiphase(mpf, config; variable=variable, unsafe=unsafe)
end

"""
$(TYPEDSIGNATURES)

Convenience call for `MultiPhaseHamiltonianFlow` with point configuration.

Builds a `HamiltonianEndPointConfig` internally and evaluates the multi-phase flow.

# Arguments
- `mpf::MultiPhaseHamiltonianFlow`: The multi-phase Hamiltonian flow to evaluate.
- `t0::Real`: Initial time.
- `x0`: Initial state vector.
- `p0`: Initial costate vector.
- `tf::Real`: Final time.
- `variable`: The variable parameter value (required for NonFixed systems, optional for Fixed systems).
- `unsafe`: If `true`, bypass ODE solver retcode checking; if `false`, throw `SolverFailure` on integration failure.

# Returns
- The final state and costate after sequential integration through all phases.

# Example
\`\`\`julia
using CTFlows.MultiPhase

mpf = flow1 * (1.0, flow2) * (2.0, flow3)
sol = mpf(0.0, [1.0, 0.0], [0.5, 0.3], 3.0)
\`\`\`

See also: [`CTFlows.MultiPhase.MultiPhaseHamiltonianFlow`](@ref), [`CTFlows.Configs.HamiltonianEndPointConfig`](@ref).
"""
function (mpf::MultiPhaseFlow{TD,VD,Traits.HamiltonianDynamics})(
    t0::Real, x0, p0, tf::Real; variable=Flows.__variable(), unsafe=Flows.__unsafe()
) where {TD<:Traits.TimeDependence,VD<:Traits.VariableDependence}
    config = Configs.HamiltonianEndPointConfig(t0, x0, p0, tf)
    return _evaluate_multiphase(mpf, config; variable=variable, unsafe=unsafe)
end

"""
$(TYPEDSIGNATURES)

Convenience call for `MultiPhaseHamiltonianFlow` with trajectory configuration.

Builds a `HamiltonianTrajectoryConfig` internally and evaluates the multi-phase flow,
returning a merged trajectory from all phases.

# Arguments
- `mpf::MultiPhaseHamiltonianFlow`: The multi-phase Hamiltonian flow to evaluate.
- `tspan::Tuple{Real, Real}`: Time span as a tuple (t0, tf).
- `x0`: Initial state vector.
- `p0`: Initial costate vector.
- `variable`: The variable parameter value (required for NonFixed systems, optional for Fixed systems).
- `unsafe`: If `true`, bypass ODE solver retcode checking; if `false`, throw `SolverFailure` on integration failure.

# Returns
- The merged trajectory solution after sequential integration through all phases.

# Example
\`\`\`julia
using CTFlows.MultiPhase

mpf = flow1 * (1.0, flow2) * (2.0, flow3)
sol = mpf((0.0, 3.0), [1.0, 0.0], [0.5, 0.3])
\`\`\`

See also: [`CTFlows.MultiPhase.MultiPhaseHamiltonianFlow`](@ref), [`CTFlows.Configs.HamiltonianTrajectoryConfig`](@ref).
"""
function (mpf::MultiPhaseFlow{TD,VD,Traits.HamiltonianDynamics})(
    tspan::Tuple{Real,Real}, x0, p0; variable=Flows.__variable(), unsafe=Flows.__unsafe()
) where {TD<:Traits.TimeDependence,VD<:Traits.VariableDependence}
    config = Configs.HamiltonianTrajectoryConfig(tspan, x0, p0)
    return _evaluate_multiphase(mpf, config; variable=variable, unsafe=unsafe)
end
