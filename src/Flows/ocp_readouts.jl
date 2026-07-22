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
  [`CTFlows.Trajectories._controlled_u`](@ref) (the `OpenLoop` / `ClosedLoop` state
  path, no costate).

`x` and `p` are callables `t -> x(t)` / `t -> p(t)`; `v` is the variable.

See also: `CTFlows.Flows._flow_objective`, [`CTFlows.Trajectories._controlled_u`](@ref).
"""
_control_of(::Nothing, x, v) = (_ -> Float64[])
_control_of(::Nothing, x, p, v) = (_ -> Float64[])
_control_of(law, x, p, v) = (t -> law(t, x(t), p(t), v))
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
