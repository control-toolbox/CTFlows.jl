# Multi-phase flows

```@meta
CurrentModule = CTFlows
```

A **multi-phase flow** concatenates several single-phase flows end-to-end, with
**switching times** between phases and optional **jump functions** applied at each
switch. The integration is exact: each phase is solved independently, and the output
of one phase becomes the initial condition of the next.

```@setup flows_multiphase
using CTFlows
using CTFlows.Data
using CTFlows.Flows
using CTFlows.MultiPhase
using CTFlows.Solutions
import OrdinaryDiffEqTsit5

# Named function shared across phases (required for type compatibility)
f_dyn(x) = -x
vf = Data.VectorField(f_dyn)
flow1 = Flows.Flow(vf; reltol=1e-8)
flow2 = Flows.Flow(vf; reltol=1e-8)
flow3 = Flows.Flow(vf; reltol=1e-8)
```

!!! note "Type constraint"

    All phases in a multi-phase flow must have **the same concrete system type** — that
    is, the same `VectorField` function type, same integrator type. In practice this
    means building all phase flows from the **same named function** (anonymous lambdas
    produce distinct types). Varying the dynamics per phase is done via the
    `is_variable` / `variable` parameter mechanism: build all phases from the same
    parametric function and pass a different `variable` at call time.

---

## Concatenation operator `*`

Use the `*` operator to chain two flows at a switching time:

```@example flows_multiphase
# flow1 on [t0, 1.0], then flow2 on [1.0, tf]
mpf = flow1 * (1.0, flow2)
```

The result is a `MultiPhaseStateFlow`. You can chain more phases:

```@example flows_multiphase
mpf3 = flow1 * (0.5, flow2) * (1.0, flow3)
MultiPhase.n_phases(mpf3)
```

Switching times must be **strictly increasing**. If they are not, a
`PreconditionError` is thrown.

---

## Jumps at switching times

A jump function ``g`` is applied to the state at the switching time before starting
the next phase. Pass it as the second element of the switching tuple:

```@example flows_multiphase
jump = x -> 2.0 .* x   # double the state at the switch

mpf_jump = flow1 * (1.0, jump, flow2)
```

Pass `nothing` (or use the two-element tuple) for a continuous switch with no jump.

---

## Calling a multi-phase flow

Multi-phase flows share the same call interface as single-phase flows:

```@example flows_multiphase
x0 = [1.0, 0.0]

# Point integration: final state only
xf = mpf(0.0, x0, 2.0)
```

```@example flows_multiphase
# Trajectory integration: full time history (phases merged)
sol = mpf((0.0, 2.0), x0)
```

---

## Inspecting a multi-phase flow

```@example flows_multiphase
MultiPhase.n_phases(mpf)                 # number of phases
MultiPhase.get_flow(mpf, 1)              # flow for phase 1
MultiPhase.get_switching_time(mpf, 1)    # switching time after phase 1
MultiPhase.get_jump(mpf, 1)              # jump at that switching time (nothing here)
```

```@example flows_multiphase
MultiPhase.get_flows(mpf)                # all phase flows
MultiPhase.get_switching_times(mpf)      # all switching times
MultiPhase.get_jumps(mpf)                # all jump functions
```

---

## Hamiltonian multi-phase flows

The same operators work for Hamiltonian flows:

```@example flows_multiphase
hvf_f(x, p) = (p, -x)
hvf = Data.HamiltonianVectorField(hvf_f)
hflow1 = Flows.Flow(hvf; reltol=1e-10)
hflow2 = Flows.Flow(hvf; reltol=1e-10)

hmpf = hflow1 * (1.0, hflow2)
typeof(hmpf)
```

```@example flows_multiphase
x0, p0 = [1.0, 0.0], [0.0, 1.0]
xf, pf = hmpf(0.0, x0, p0, 2.0)
(xf, pf)
```

---

## Design notes

- Concatenation is an associative binary operation on flows: `(f1 * (t, f2)) * (s, f3)`.
- All phases must have the **same concrete type parameters** `(TD, VD, S, I)`. This
  is enforced at construction time by the `flows::Vector{StateFlow{TD, VD, S, I}}`
  field type. Using different anonymous lambdas for different phases creates different
  `S` types and will fail — use a shared named function or a parametric vector field
  with the `is_variable` pattern instead.
- The trajectory integration merges phase results via `Integrators.merge`, which
  concatenates the time grids and result vectors.

---

## See also

- [`CTFlows.MultiPhase.MultiPhaseStateFlow`](@ref), [`CTFlows.MultiPhase.MultiPhaseHamiltonianFlow`](@ref), [`CTFlows.MultiPhase.AnyMultiPhaseFlow`](@ref) — multi-phase flow types.
- [`CTFlows.MultiPhase.n_phases`](@ref), [`CTFlows.MultiPhase.get_flow`](@ref), [`CTFlows.MultiPhase.get_switching_time`](@ref), [`CTFlows.MultiPhase.get_jump`](@ref) — phase accessors.
- [`CTFlows.MultiPhase.get_flows`](@ref), [`CTFlows.MultiPhase.get_switching_times`](@ref), [`CTFlows.MultiPhase.get_jumps`](@ref) — bulk accessors.
