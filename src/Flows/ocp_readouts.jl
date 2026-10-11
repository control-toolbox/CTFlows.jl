# =============================================================================
# OCP readouts — objective value and reconstructed control along a trajectory,
# shared by the Hamiltonian (OptimalControlFlow) and state (ControlledFlow) paths.
# =============================================================================

"""
$(TYPEDSIGNATURES)

Reconstruct the control along a trajectory as a callable `t -> u(t)`.

Dispatched on the control law and the available data:
- `nothing` → `t -> Float64[]` (control-free OCP), for both the state `(x, v)` and the
  Hamiltonian `(x, p, v)` call shapes.
- a law with the state and costate projections `(x, p, v)` → `t -> law(t, x(t), p(t), v)`
  (the `DynClosedLoop` / Hamiltonian path, which uses the costate).
- a law with only the state projection `(x, v)` → `t -> u(t)` via
  [`CTFlows.Trajectories._controlled_u`](@extref) (the `OpenLoop` / `ClosedLoop` state
  path, no costate).

`x` and `p` are callables `t -> x(t)` / `t -> p(t)`; `v` is the variable.

See also: `CTFlows.Flows._flow_objective`, [`CTFlows.Trajectories._controlled_u`](@extref).
"""
_control_of(::Nothing, x, v) = (_ -> Float64[])

"""
$(TYPEDSIGNATURES)

Control-free OCP with costate projection: returns `t -> Float64[]` (no control to reconstruct).

See also: [`CTFlows.Flows._control_of`](@extref).
"""
_control_of(::Nothing, x, p, v) = (_ -> Float64[])

"""
$(TYPEDSIGNATURES)

DynClosedLoop law with costate: returns `t -> law(t, x(t), p(t), v)` (Hamiltonian path).

See also: [`CTFlows.Flows._control_of`](@extref).
"""
_control_of(law, x, p, v) = (t -> law(t, x(t), p(t), v))

"""
$(TYPEDSIGNATURES)

OpenLoop/ClosedLoop law with state only: returns `t -> u(t)` via
[`CTFlows.Trajectories._controlled_u`](@extref) (state path, no costate).

See also: [`CTFlows.Flows._control_of`](@extref), [`CTFlows.Trajectories._controlled_u`](@extref).
"""
_control_of(law, x, v) = (t -> Trajectories._controlled_u(law, t, x(t), v))

"""
$(TYPEDSIGNATURES)

Compute the objective value (Mayer + Lagrange) of an OCP along a trajectory, given
callable state `x(t)` and control `u(t)` and the variable `v`.

The Mayer term is evaluated at the endpoints `x(t0)` and `x(tf)`. The Lagrange term is
integrated by flowing `ℓ̇(t) = ℓ(t, x(t), u(t), v)` from `t0` to `tf` on a **scalar** cost
state: under the "1-D = scalar" convention the out-of-place right-hand side is wrapped in
an `IPVFOoPRHS`, and that wrapper — not the state — supplies SciML's mutable in-place
buffer. Shared core of both the Hamiltonian
(`OptimalControlFlow`) and state (`ControlledFlow`) objective paths; each caller builds
its own `x`, `u`, `v` and delegates here.

See also: `CTFlows.Flows._control_of`, `CTFlows.Flows._build_ocp_solution`,
`CTFlows.Flows._state_flow_objective`.
"""
function _flow_objective(ocp, x, u, v, t0, tf, integ)
    obj = 0.0
    if CTModels.Components.has_mayer_cost(ocp)
        may = CTModels.Components.mayer(ocp)
        obj += may(x(t0), x(tf), v)
    end
    if CTModels.Components.has_lagrange_cost(ocp)
        lag = CTModels.Components.lagrange(ocp)
        running = Data.VectorField(
            (t, ℓ) -> lag(t, x(t), u(t), v); is_autonomous=false, is_variable=false
        )
        cost_flow = build_flow(Systems.build_system(running), integ)
        obj += cost_flow(t0, 0.0, tf)
    end
    return obj
end

"""
$(TYPEDSIGNATURES)

Warn (once) when an OCP objective is about to be recomputed from a trajectory that has no
dense interpolant (e.g. integrated with `dense=false`): the state is then only linearly
interpolated between the saved points, so the objective — and the reconstructed control —
are accurate to the grid spacing, not to the solver tolerances.

See also: `CTFlows.Flows._flow_objective`, [`CTSolvers.Integrators.is_dense`](@extref).
"""
function _warn_not_dense(traj)
    Integrators.is_dense(traj) && return nothing
    @warn "The objective is recomputed from a trajectory without dense output " *
        "(`dense=false`): the state is linearly interpolated between the saved points, " *
        "so the objective and the control are only accurate to the time-grid spacing. " *
        "Remove `dense=false` for solver accuracy (`saveat` alone keeps it)." maxlog = 1
    return nothing
end

# =============================================================================
# Generated output grids (issue #435): the plotted curves include the control
# =============================================================================

"""
$(TYPEDSIGNATURES)

No generated grid: the Hamiltonian trajectory is returned unchanged.
"""
_regrid_hamiltonian(sol, ::Union{Nothing,AbstractVector}, law, variable, bounds) = sol

"""
$(TYPEDSIGNATURES)

Regrid a Hamiltonian trajectory on the generated grid `spec`, whose plotted curves are the
state, the costate and, when there is a law, the reconstructed control.

See also: [`CTFlows.Trajectories.apply_generated_grid`](@extref).
"""
function _regrid_hamiltonian(sol, spec::Configs.AbstractGrid, law, variable, bounds)
    x, p = Trajectories.state(sol), Trajectories.costate(sol)
    u = law === nothing ? nothing : _control_of(law, x, p, _variable_vector(variable))
    return Trajectories.apply_generated_grid(
        sol, spec, Trajectories._plotted_curve(x, p, u), bounds
    )
end

"""
$(TYPEDSIGNATURES)

No generated grid: the state trajectory is returned unchanged.
"""
_regrid_state(traj, ::Union{Nothing,AbstractVector}, law, variable, coerce, bounds) = traj

"""
$(TYPEDSIGNATURES)

Regrid a state trajectory on the generated grid `spec`, whose plotted curves are the state
and, when there is a law, the reconstructed control.

See also: [`CTFlows.Trajectories.apply_generated_grid`](@extref).
"""
function _regrid_state(traj, spec::Configs.AbstractGrid, law, variable, coerce, bounds)
    x = Trajectories.ControlledStateProjection(traj, coerce)
    u = law === nothing ? nothing : _control_of(law, x, Trajectories._cp_variable(variable))
    return Trajectories.apply_generated_grid(
        traj, spec, Trajectories._plotted_curve(x, u), bounds
    )
end

"""
$(TYPEDSIGNATURES)

Resolve the `grid` keyword of a top-level trajectory call. An explicit `grid` (`nothing`, an
integer, a generated grid) is returned as given. `Core.NotProvided` becomes
[`CTFlows.Configs.AutomaticGrid`](@extref) when the call sets a time span and none of the
`flows` (every phase of a multi-phase flow) has an integrator with `saveat`, and `nothing`
otherwise: a grid of times or a `saveat` already shapes the output.

See also: [`CTFlows.Flows.__grid`](@extref).
"""
_default_grid(grid, tspan, flows...) = grid
function _default_grid(::Core.NotProvidedType, tspan, flows...)
    tspan isa Tuple{Real,Real} || return nothing
    any(f -> Integrators.has_saveat(integrator(f)), flows) && return nothing
    return Configs.AutomaticGrid()
end

"""
$(TYPEDSIGNATURES)

Validate the `grid` keyword of a decorated trajectory call and return the generated grid
spec (or `nothing`). A grid of times given in place of the span is left to the inner flow.

# Throws
- `CTBase.Exceptions.IncorrectArgument`: If a grid of times and `grid=` are both given, or
  if the integrator sets `saveat` while `grid=` is given.
"""
function _call_grid_spec(tspan, grid, flow)
    grid isa Core.NotProvidedType && return _default_grid(grid, tspan, flow)
    spec = Configs._grid_spec(grid)
    spec === nothing && return nothing
    Configs._time_spec(tspan, spec)
    _reject_saveat(integrator(flow))
    return spec
end

"""
$(TYPEDSIGNATURES)

Reject an output grid imposed at the call when the integrator already sets `saveat`.

# Throws
- `CTBase.Exceptions.IncorrectArgument`: If `Integrators.has_saveat(integ)`.
"""
function _reject_saveat(integ)
    Integrators.has_saveat(integ) && throw(
        Exceptions.IncorrectArgument(
            "Two output grids given: `saveat` on the flow and a grid at the call";
            got="saveat set on the integrator, and a grid of times or `grid=` at the call",
            expected="a single output grid",
            suggestion="Remove `saveat` from the flow, or call it with the time span (t0, tf) only.",
            context="trajectory call",
        ),
    )
    return nothing
end

"""
$(TYPEDSIGNATURES)

Reject an output grid given at the call (grid of times or generated) when the flow's
integrator sets `saveat` (the integrator is only queried when a grid is given).
"""
function _check_output_grid(flow, config)
    Configs.output_grid(config) === nothing || _reject_saveat(integrator(flow))
    return nothing
end
