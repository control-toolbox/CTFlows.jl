# Compatibility

```@meta
CurrentModule = CTFlows
```

This section says, for each way of building a flow, which **state types**, **element
types** and **call styles** work. Each page has a table and a minimal executable example
for every cell.

!!! note "How these pages stay true"
    - **Results are executed.** Every ✓ / ⚠ / ✗ example is an `@example` block re-run on
      each documentation build, so a result cannot drift from the code.
    - **Scope comes from a probe.** Which containers and axes are tested follows the CPU
      capability probe,
      [`probe/cpu/probe_cpu.jl`](https://github.com/control-toolbox/CTFlows.jl/blob/main/probe/cpu/probe_cpu.jl).
      A new axis appears here once it is added to the probe.
    - **GPU is the exception.** The documentation build has no device: the [GPU](gpu.md)
      page reports a run of
      [`probe/gpu`](https://github.com/control-toolbox/CTFlows.jl/tree/main/probe/gpu),
      not executed examples.

## Pages

| Constructor | Builds | Page |
|---|---|---|
| *(all constructors)* | — | [Shape contract](shape_contract.md): when a 1-D state is a scalar |
| `Flow(::VectorField)` | [`StateFlow`](@ref CTFlows.Flows.StateFlow) | [`Flow(VectorField)`](vector_field.md) |
| `Flow(::HamiltonianVectorField)` | [`HamiltonianFlow`](@ref CTFlows.Flows.HamiltonianFlow) | [`Flow(HamiltonianVectorField)`](hamiltonian_vector_field.md) |
| `Flow(::Hamiltonian)` | [`HamiltonianFlow`](@ref CTFlows.Flows.HamiltonianFlow) | [`Flow(Hamiltonian)`](hamiltonian.md) |
| `Flow(::ODEFunction)` / `Flow(::ODEProblem)` | [`StateFlow`](@ref CTFlows.Flows.StateFlow) / `SciMLProblemFlow` | [`Flow(SciML)`](sciml.md) |
| `Flow(ocp)` (control-free) | [`OptimalControlFlow`](@ref CTFlows.Flows.OptimalControlFlow) | [`Flow(ocp)`](ocp_free.md) |
| `Flow(ocp, law)` | [`OptimalControlFlow`](@ref CTFlows.Flows.OptimalControlFlow) / [`ControlledFlow`](@ref CTFlows.Flows.ControlledFlow) | [`Flow(ocp, law)`](ocp_control_laws.md) |
| `Flow(h̃, law)` | [`HamiltonianFlow`](@ref CTFlows.Flows.HamiltonianFlow) | [`Flow(h̃, law)`](pseudo_hamiltonian.md) |
| `Flow(h̃vf, law)` | [`HamiltonianFlow`](@ref CTFlows.Flows.HamiltonianFlow) | [`Flow(h̃vf, law)`](pseudo_hamiltonian_vector_field.md) |
| `Flow(fc, law)` | [`ControlledFlow`](@ref CTFlows.Flows.ControlledFlow) | [`Flow(fc, law)`](controlled_vector_field.md) |
| *(all, on device)* | — | [GPU](gpu.md) |

## At a glance

"Containers" are scalars, `Vector`, `Matrix` (one column per trajectory), `MVector` /
`SVector` and `MMatrix` / `SMatrix`. "Real" means `Float64` elements.

| Constructor | Real, every container | `Complex` | Hand-built `ForwardDiff.Dual` | Caveat |
|---|---|---|---|---|
| `Flow(VectorField)` | ✓ | ✓ | ✓ | in-place field + immutable state: works, warns |
| `Flow(HamiltonianVectorField)` | ✓ | ✓ | ✓ | same as above |
| `Flow(Hamiltonian)` | ✓ | ✗ | ✗ | AD-backed: differentiate the call, not a `Dual` state |
| `Flow(::ODEFunction)` | ✓ | ✓ | ✓ | same as `Flow(VectorField)` |
| `Flow(::ODEProblem)` | ✓ | ✓ | ✓ | no shape coercion; in-place problem + immutable state: SciML error |
| `Flow(ocp)` | ✓ | ✗ | ✗ | the state dimension is fixed by the OCP |
| `Flow(ocp, DynClosedLoop)` | ✓ | ✗ | ✗ | same with `constraint=`/`multiplier=`; `:total` = `:partial` for a stationary law |
| `Flow(ocp, OpenLoop/ClosedLoop)` | ✓ | ✓ | point call only | the trajectory call computes the objective, which is not `Dual`-transparent |
| `Flow(h̃, law)` | ✓ | ✗ | ✗ | `DynClosedLoop` only |
| `Flow(h̃vf, law)` | ✓ | ✓ | ✓ | `DynClosedLoop` only; in-place + immutable: warns |
| `Flow(fc, law)` | ✓ | ✓ | ✓ | `OpenLoop`/`ClosedLoop` only |

Why the AD-backed flows reject `Complex` and hand-built `Dual` states: the default backend,
`AutoForwardDiff`, does not handle `Complex`, and a `Dual` passed as `x0` collides with the
flow's own `Dual`s. To get sensitivities of such a flow, wrap the **call** in
`ForwardDiff.jacobian`; see [`Flow(Hamiltonian)`](hamiltonian.md).

On device, AD-free flows need no keyword: pass `CuArray`s. For AD-backed flows,
`AutoMooncake` is the backend that handles every measured call shape; see [GPU](gpu.md).
On CPU, `AutoMooncake` works on every AD-backed flow too and pays off for large states; it
refuses `Dual` states, i.e. an outer ForwardDiff through the flow.

## See also

- [Flows overview](../flows/overview.md): the data → systems → flows → trajectories pipeline.
- [Building a flow](../flows/building_a_flow.md): the shortcut constructor and the explicit pipeline.
- [Integrating](../flows/integrating.md): call styles, variable parameters, integrator options.
