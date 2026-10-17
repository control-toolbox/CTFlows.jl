# Extending CTFlows

```@meta
CurrentModule = CTFlows
```

The layers of CTFlows meet at small contracts: implement one and the rest of the pipeline
(calls, configurations, trajectories, concatenation, plotting) works with it. This page
lists the contracts, from the most common extension to the least.

| To add | Subtype | Implement | Then |
|---|---|---|---|
| a system | `Systems.AbstractSystem{TD,VD,D}` | `get_ip_rhs`, `get_oop_rhs` (and `get_ip_rhs_augmented` for a variable costate) | `Flows.build_flow(sys, integ)` |
| a flow | `Flows.AbstractFlow{TD,VD,D}` | `Flows.system`, `Flows.integrator` | call it like any flow |
| an integrator | `CTSolvers.Integrators.AbstractIntegrator` | the strategy contract, `CommonSolve.solve`, `merge`, and the CTFlows glue `build_problem` / `build_options` | pass it to `build_flow` |

`TD` is the time dependence (`Traits.Autonomous` / `Traits.NonAutonomous`), `VD` the
variable dependence (`Traits.Fixed` / `Traits.NonFixed`), and `D` the dynamics
(`Traits.StateDynamics` / `Traits.HamiltonianDynamics`). They select the call signatures
and the trajectory type, so they must be right.

```@setup extending
using CTFlows
using CTBase: Traits
using CTFlows: Systems
using CTFlows: Flows
using CTFlows: Integrators
using CTFlows: Trajectories
using OrdinaryDiffEqTsit5: OrdinaryDiffEqTsit5
```

---

## A new system

A system turns data into an ODE right-hand side. Two methods are required; both receive
the configuration of the call (`Configs.StateEndPointConfig`, …), so that a system can
build closures typed on the initial condition:

- `Systems.get_ip_rhs(sys, config)` returns `(du, u, p, t) -> nothing`, filling `du`;
- `Systems.get_oop_rhs(sys, config)` returns `(u, p, t) -> du`.

The integration picks one from the mutability of the initial condition. `p` is a
`Systems.ODEParameters`, which carries the `variable`. A Hamiltonian system
(`D = Traits.HamiltonianDynamics`) works on the stacked state `[x; p]`, and implements
`Systems.get_ip_rhs_augmented(sys, config)` too if it supports `variable_costate=true`
(it then declares `Traits.variable_costate_trait(sys) = Traits.SupportsVariableCostate`).

A linear system ``\dot x = a x``:

```@example extending
struct LinearSystem <: Systems.AbstractSystem{
    Traits.Autonomous,Traits.Fixed,Traits.StateDynamics,
}
    a::Float64
end

function Systems.get_ip_rhs(sys::LinearSystem, config)
    return (du, u, p, t) -> (du .= sys.a .* u; nothing)
end

Systems.get_oop_rhs(sys::LinearSystem, config) = (u, p, t) -> sys.a .* u
nothing # hide
```

[`Flows.build_flow`](@ref CTFlows.Flows.build_flow) combines it with an integrator into a
flow, which has every call style of a built-in one:

```@example extending
integ = Integrators.SciML(; reltol=1e-10)
flow = Flows.build_flow(LinearSystem(-1.0), integ)
flow(0.0, [1.0, 2.0], 1.0)                  # point call
```

```@example extending
sol = flow((0.0, 1.0), [1.0, 2.0])         # trajectory call
Trajectories.state(sol)(0.5)
```

```@example extending
(flow * (0.5, flow))(0.0, [1.0, 2.0], 1.0)  # concatenation
```

```@example extending
@assert flow(0.0, [1.0, 2.0], 1.0) ≈ [1, 2] .* exp(-1)                    # hide
@assert Trajectories.state(sol)(0.5) ≈ [1, 2] .* exp(-0.5)                # hide
@assert flow(0.0, 1.0, 1.0) ≈ exp(-1)                                     # hide
nothing                                                                   # hide
```

A one-dimensional state is a scalar (`flow(0.0, 1.0, 1.0)` returns a `Float64`): the
coercion lives in the shared call path, not in the system (see the
[Shape contract](../compatibility/shape_contract.md)).

The other accessors (`Systems.hamiltonian`, `Systems.control_law`, …) are optional. A
system that does not implement one gets an `IncorrectArgument` naming the system type;
add a method of `Systems._accessor_hint` to say what the system holds and which accessor
to use instead.

---

## A new flow

A flow pairs a system with an integrator. The call methods are defined on the abstract
types `Flows.AbstractStateFlow` and `Flows.AbstractHamiltonianFlow`, so a subtype of
`Flows.AbstractFlow{TD,VD,D}` only implements:

- `Flows.system(flow)`, the `Systems.AbstractSystem`;
- `Flows.integrator(flow)`, the integrator.

A flow that tags another one, for instance:

```@example extending
struct TaggedFlow{TD,VD,F} <: Flows.AbstractFlow{TD,VD,Traits.StateDynamics}
    inner::F
    tag::String
end

function TaggedFlow(f::Flows.AbstractFlow{TD,VD}, tag) where {TD,VD}
    return TaggedFlow{TD,VD,typeof(f)}(f, tag)
end

Flows.system(f::TaggedFlow) = Flows.system(f.inner)
Flows.integrator(f::TaggedFlow) = Flows.integrator(f.inner)

tagged = TaggedFlow(flow, "decay")
tagged(0.0, [1.0, 2.0], 1.0)
```

```@example extending
@assert tagged(0.0, [1.0, 2.0], 1.0) == flow(0.0, [1.0, 2.0], 1.0)   # hide
nothing                                                              # hide
```

This is how `Flows.ControlledFlow` and `Flows.OptimalControlFlow` are built: they wrap an
inner flow, delegate `system` and `integrator` to it, and add their own trajectory call
(a `StateFlowTrajectory`, a `CTModels.Solution`).

---

## A new integrator

The integrator strategy lives in CTSolvers; CTFlows only owns the glue typed on its own
`Systems` and `Configs`. A new integrator therefore implements, in CTSolvers terms:

- the `CTBase.Strategies` contract of
  [`CTSolvers.Integrators.AbstractIntegrator`](@extref): `Strategies.id`,
  `Strategies.metadata`, `Strategies.options`;
- `CommonSolve.solve(prob, integ; options, unsafe)`, returning a
  [`CTSolvers.Integrators.AbstractIntegrationResult`](@extref) (with `times`,
  `evaluate_at`, `final_state`, `status`, `successful`), and throwing a
  `CTBase.Exceptions.SolverFailure` on failure unless `unsafe=true`;
- `CTSolvers.Integrators.merge` of results, for multi-phase trajectories;

and, on the CTFlows side:

- [`Integrators.build_problem`](@ref CTFlows.Integrators.build_problem)`(sys, config, integ; variable)`,
  which builds the problem `solve` integrates, from `Systems.get_ip_rhs` /
  `Systems.get_oop_rhs`;
- [`Integrators.build_options`](@ref CTFlows.Integrators.build_options)`(integ, config)`,
  which returns the solver options for a point call or a trajectory call;
- `Integrators.has_saveat(integ)`, when the integrator can impose its own output grid.

The SciML integrator is the reference: `CTSolversSciMLIntegrator` in CTSolvers for the
solve, `CTFlowsSciMLIntegrator` in this repository for the glue (`ext/`).

---

## Where the generic code lives

| Step of a call | Function | File |
|---|---|---|
| check the call against the device and the AD backend | `Flows._check_call` | `src/Flows/device_checks.jl` |
| build the configuration | `Configs.*Config` constructors | `src/Configs/` |
| dispatch on the variable dependence | `Flows._invoke_flow` | `src/Flows/calling.jl` |
| build the problem, choose the options, solve | `Flows._core_invoke_flow` | `src/Flows/calling.jl` |
| wrap the result | `Trajectories.build_trajectory` | `src/Trajectories/building.jl` |
| generate the output grid | `Integrators.regrid` | CTSolvers |

`Trajectories.build_trajectory` dispatches on the configuration's mode (point or
trajectory) and dynamics, so a new system or flow gets the existing trajectory types
without code.

## See also

- [Building a flow](../flows/building_a_flow.md): the shortcut constructor and the
  explicit pipeline.
- [GPU internals](gpu-internals.md): how a device token reaches the strategies.
- The API reference of [`CTFlows.Systems`](@ref CTFlows.Systems) and
  [`CTFlows.Flows`](@ref CTFlows.Flows), and the internals page.
