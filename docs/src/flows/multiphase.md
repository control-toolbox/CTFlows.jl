# Multi-phase flows

```@meta
CurrentModule = CTFlows
```

A **multi-phase flow** concatenates several single-phase flows end-to-end, with
**switching times** between phases and optional **jump functions** applied at each
switch. Each phase is integrated on its own, and its final value (after the jump)
becomes the initial condition of the next.

```@setup flows_multiphase
using CTFlows
using CTBase: Data
using CTFlows: Flows
using CTFlows: MultiPhase
using CTFlows: Trajectories
using OrdinaryDiffEqTsit5: OrdinaryDiffEqTsit5

f_dyn(x) = -x
vf = Data.VectorField(f_dyn)
flow1 = Flows.Flow(vf; reltol=1e-8)
flow2 = Flows.Flow(vf; reltol=1e-8)
flow3 = Flows.Flow(vf; reltol=1e-8)

f_dyn2(x) = -2 .* x
flow_het = Flows.Flow(Data.VectorField(f_dyn2); reltol=1e-8)

hvf_f(x, p) = (p, -x)
hvf = Data.HamiltonianVectorField(hvf_f)
hflow1 = Flows.Flow(hvf; reltol=1e-10)
hflow2 = Flows.Flow(hvf; reltol=1e-10)
```

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

## Phases with different dynamics

Each phase may wrap a **different vector field** — the dynamics, system type, and
integrator are all free per phase. The only requirement is that all phases share the
same `TimeDependence` and `VariableDependence` traits (both autonomous or both
non-autonomous, both fixed or both variable).

```@example flows_multiphase
# flow1: f(x) = -x   |   flow_het: f(x) = -2x  — different functions, same TD/VD
mpf_het = flow1 * (1.0, flow_het)
MultiPhase.n_phases(mpf_het)
```

This enables the typical use cases of multi-phase optimal control:

- **Bang-bang trajectories**: `flow_plus * (t_switch, flow_minus)` with distinct
  controlled dynamics per arc.
- **Multi-regime systems**: phases with different physical models (e.g. free flight /
  contact phase).
- **Different solvers per phase**: stiff phases can use an implicit integrator while
  smooth phases use an explicit one.

Mixing state flows with Hamiltonian flows is not allowed — attempting it raises a
`PreconditionError`.

---

## Jumps at switching times

An additive vector `jump_x` is added to the state at the switching time
(`x ← x + jump_x`). Pass it as the second element of the switching tuple:

```@example flows_multiphase
jump_x = [0.5, 0.0]   # add 0.5 to the first component at the switch

mpf_jump = flow1 * (1.0, jump_x, flow2)
```

Pass `nothing` (or use the two-element tuple) for a continuous switch with no jump.

### Function jumps

The second element may also be a **callable** instead of an additive vector:

**State flow** — `f(x)` must return the new state:

```@example flows_multiphase
mpf_fn = flow1 * (1.0, x -> 2.0 .* x, flow2)   # x ← 2x at t = 1.0
```

**Hamiltonian flow — 3-element** — `f(x, p)` returns `(x', p')`:

```@example flows_multiphase
hmpf_fn = hflow1 * (
    1.0, (x, p) -> (2.0 .* x, p .+ 0.5), hflow2
)
```

**Hamiltonian flow — 4-element** — each component independently accepts a
vector, a callable, or `nothing` (identity). This allows state-only jumps without
passing explicit zeros for the costate:

```@example flows_multiphase
# state-only additive jump (costate unchanged)
hmpf_sx = hflow1 * (1.0, [0.1, 0.0], nothing, hflow2)

# callable on state, costate unchanged
hmpf_fx = hflow1 * (1.0, x -> 2.0 .* x, nothing, hflow2)
```

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

### The horizon of a call

The horizon `[t0, tf]` of a call can be anywhere with respect to the switching times: it may
start after the first one, end before the last one, lie inside a single phase, or be
**backward** (`t0 > tf`). The flow integrates only the phases the horizon meets, each on its
part of the horizon:

- the phase `k` holds on `[tₖ₋₁, tₖ]`; the first phase extends to `-∞` and the last one to
  `+∞`, so a horizon before the first switching time, or after the last one, uses the first,
  or the last, phase;
- a **jump** is applied only at a switching time **strictly inside** the horizon;
- at a bound of the horizon equal to a switching time `tᵢ`, the given and the returned values
  are **those on the side of the horizon**: `mpf(tᵢ, x, tf)` starts the phase `i + 1` from
  `x`, with no jump, and `mpf(t0, x, tᵢ)` returns the end of the phase `i`, before the jump;
- on a **backward** horizon, the jumps crossed are **inverted**: an additive jump (a vector or
  a number) is subtracted; a jump given as a function has no known inverse, so crossing it
  backward throws an `IncorrectArgument`;
- so `mpf(tf, mpf(t0, x0, tf), t0)` gives `x0` back, up to the integration tolerances.

With two phases that do not commute, `ẋ = 1` on `[0, 1]` then `ẋ = x`, and a jump `+10` at
`t = 1`: from `x(0) = 1`, `x(t) = 1 + t` before the switch and `x(t) = 12 e^{t-1}` after it.

```@example flows_multiphase
one_ = Flows.Flow(Data.VectorField(x -> 1.0); reltol=1e-10, abstol=1e-10)
lin = Flows.Flow(Data.VectorField(x -> x); reltol=1e-10, abstol=1e-10)
φ = one_ * (1.0, 10.0, lin)
xf = φ(0.0, 1.0, 2.0)         # 12e: the whole horizon, the jump crossed
```

```@example flows_multiphase
φ(0.0, 1.0, 0.5), φ(1.5, 12exp(0.5), 2.0)   # a horizon in one phase only
```

```@example flows_multiphase
φ(0.0, 1.0, 1.0), φ(1.0, 12.0, 2.0)         # a bound on the switching time: no jump
```

```@example flows_multiphase
φ(2.0, xf, 0.0)               # backward: the jump is subtracted, x(0) = 1 again
```

A **trajectory** is returned in increasing time, whatever the direction of integration: its
time grid increases, its switching times are those strictly inside the horizon, in increasing
order, its labels those of the phases met, and it is left-continuous at a switching time (the
value at `tᵢ` is the one before the jump, in increasing time). A backward trajectory is the
same trajectory as the forward one over the same interval:

```@example flows_multiphase
traj = φ((2.0, 0.0), xf)      # integrated backward from x(2)
Trajectories.time_grid(traj)[[1, end]], Trajectories.switching_times(traj)
```

```@example flows_multiphase
Trajectories.left_limit(traj, :state, 1), Trajectories.right_limit(traj, :state, 1)
```

The same holds for the flows of an optimal control problem: the `Solution` of a backward
trajectory has an increasing time grid, and its objective is the cost of the arc over
`[min(t0, tf), max(t0, tf)]`, Mayer term included, as for the forward call.

The point call of a Hamiltonian multi-phase flow takes `variable_costate=true`, as a single
flow does: the costate of the variable is carried from one phase to the next (the jumps do not
act on it), and the call returns `(xf, pf, pvf)`. The derivatives with respect to the
switching times (a shooting function differentiated by ForwardDiff) go through every call.

### A phase that stops early

A switching time says that the right-hand side changes at that time. If a phase does not
reach its switching time — a callback that calls `terminate!` stops it, or the integration
fails with `unsafe=true` — the flow stops there: the following phases are not integrated and
no jump is applied. A trajectory call returns the trajectory up to the stop time (its output
grid ends there, and it carries the switching times and the labels of the phases that were
integrated), and a point call returns the state at the stop time, as for a single flow.

```julia
using SciMLBase: ContinuousCallback, terminate!

stop = ContinuousCallback((u, t, integrator) -> u[1] - 0.8, terminate!)
f1 = Flow(Data.VectorField(x -> -x); callback=stop)   # stops at t = log(1/0.8) ≈ 0.22
f2 = Flow(Data.VectorField(x -> -x))

mpf = f1 * (0.5, f2)
traj = mpf((0.0, 1.0), [1.0])     # defined on [0, 0.22]: the phase 2 is not integrated
mpf(0.0, [1.0], 1.0)              # [0.8], the state at the stop time
```

With `unsafe=false` (the default), a phase whose integration fails raises a
`CTBase.Exceptions.SolverFailure` whose context names the phase, for instance
`phase 2 of 3, point call of the flow (SciML solve)`, and whose suggestion is to call the
flow with `unsafe=true` to get what was computed up to the failure.

---

## Inspecting a multi-phase flow

```@example flows_multiphase
MultiPhase.n_phases(mpf)             # number of phases
MultiPhase.phase_flows(mpf)[1]       # flow for phase 1
MultiPhase.switching_times(mpf)[1]   # switching time after phase 1
MultiPhase.jumps(mpf)[1]             # jump at that switching time (nothing here)
nothing # hide
```

```@example flows_multiphase
MultiPhase.phase_flows(mpf)          # tuple of all phase flows
MultiPhase.switching_times(mpf)      # all switching times
MultiPhase.jumps(mpf)                # all jump functions
MultiPhase.phase_labels(mpf)         # the labels of the phases
nothing # hide
```

---

## Phase labels

Each flow can be given a **label** at construction, naming the phase it integrates (an arc
`bang`, `singular`, `boundary`, …). Concatenation keeps the flows, so it keeps their
labels, in order:

```@example flows_multiphase
fa = Flows.Flow(vf; reltol=1e-8, label="decay")
fb = Flows.Flow(Data.VectorField(f_dyn2); reltol=1e-8, label="fast decay")
mpf_lab = fa * (1.0, fb)
MultiPhase.phase_labels(mpf_lab)
```

A flow with no label has the label `""`. The labels are stored in the trajectory
([`Trajectories.phase_labels`](@ref CTFlows.Trajectories.phase_labels)) and, for an
optimal control flow, in the `CTModels.Solution`; the plots write them on the curves (see
[Plotting](#Plotting) below).

Every `Flow` constructor accepts `label`, the SciML ones (`Flow(::ODEFunction)`,
`Flow(::ODEProblem)`) included, and a flow displays its label. Like `hamiltonian_type`,
`label` is an **action option** of the constructor: it is routed apart from the strategy
options (`reltol`, `alg`, `ad_backend`, …) and never passed to the integrator or to the AD
backend. A value that is not a string is rejected with an `IncorrectArgument`.

---

## Left and right limits at a switching time

A multi-phase trajectory is **left-continuous**: at a switching time `tᵢ`, `sol(tᵢ)` and
the accessors return the value at the end of the phase that finishes there, before the
jump. The value after the jump is read with
[`Trajectories.right_limit`](@ref CTFlows.Trajectories.right_limit):

```@example flows_multiphase
sol_lab = (fa * (1.0, [0.5, 0.0], fb))((0.0, 2.0), x0)
Trajectories.switching_times(sol_lab)
```

```@example flows_multiphase
Trajectories.left_limit(sol_lab, :state, 1), Trajectories.right_limit(sol_lab, :state, 1)
```

The components are `:state` for a state trajectory, `:state` and `:costate` for a
Hamiltonian one, and `:state` and `:control` for the trajectory of a controlled flow: at
`tᵢ`, the control is computed with the law of the phase that ends there; its right limit,
with the law of the next phase. The time grid holds each switching time **once**.

For an optimal control flow, the `CTModels.Solution` keeps the same structure — switching
times, phase labels, left and right limits of the state, costate and control — read with
`CTModels.switching_times`, `CTModels.phase_labels`, `CTModels.left_limit` and
`CTModels.right_limit` (see [Optimal control flows](optimal_control.md)).

---

## Hamiltonian multi-phase flows

The same operators work for Hamiltonian flows:

```@example flows_multiphase
hmpf = hflow1 * (1.0, hflow2)
```

```@example flows_multiphase
x0, p0 = [1.0, 0.0], [0.0, 1.0]
xf, pf = hmpf(0.0, x0, p0, 2.0)
(xf, pf)
```

---

## Plotting

The merged trajectory of a multi-phase flow is a plain `VectorFieldTrajectory` (or
`HamiltonianVectorFieldTrajectory`) — the same types produced by a single-phase flow
— so `plot` (see [Trajectories](trajectories.md#Plotting)) applies directly. At each
switching time, a vertical line marks the switch, and a jump of the state, costate or
control is drawn as a **vertical segment** from the left to the right limit:

```@setup flows_multiphase
using Plots
```

```@example flows_multiphase
plot(sol)   # state trajectory across both phases, switch at t = 1.0
```

```@example flows_multiphase
hsol = hmpf((0.0, 2.0), x0, p0)
plot(hsol)  # state and costate, across both phases
```

### Switching lines and phase labels

The phase labels are written on the control panel, or on the first panel when there is no
control. Four keywords control the switching structure on the plot:

| Keyword | Values (default first) | Effect |
| --- | --- | --- |
| `switching_style` | `NamedTuple()` / a `NamedTuple` / `:none` | style of the vertical lines at the switching times (dashed black lines by default); `:none` hides them |
| `phase_labels` | `:control` / `:all` / `:none` | write the labels on the control panel (or the first panel), on every panel, or nowhere |
| `phase_labels_style` | `NamedTuple()` | `color`, `fontsize`, `halign`, `valign` of the labels |
| `jumps` | `:segment` / `:none` | draw a jump as a vertical segment, or break the curve between the two limits |

```@example flows_multiphase
plot(sol_lab)   # labels "decay" and "fast decay", state jump at t = 1.0
```

```@example flows_multiphase
plot(sol_lab; switching_style=(color=:red,), phase_labels_style=(fontsize=12,))
```

The vertical segment makes a jump easy to see, and to compare with a solution whose jump
is smoothed (e.g. from a direct method); it does not mean that the trajectory takes the
values in between. With `jumps=:none`, the curve stops at the left limit and starts again
at the right limit:

```@example flows_multiphase
plot(sol_lab; jumps=:none)
```

The limits are exact: the left limit is the end of the phase that finishes at the
switching time, the right limit the start of the next phase, after the jump (`x + Δx`,
`p + Δp`); the control on each side is given by the law of its phase at these values. They
are not read from the next point of the time grid. The whole trajectory keeps one color:
the phases are parts of the same curve, not separate series.

### Different dynamics — kink at the switching time

When the two phases use different vector fields, the slope changes abruptly at the
switching time. The trajectory is continuous but not differentiable:

```@example flows_multiphase
# phase 1: f(x) = -x   |   phase 2: f(x) = -2x
sol_het = mpf_het((0.0, 2.0), x0)
plot(sol_het)   # kink visible at t = 1.0
```

### State jump — discontinuity in state

A non-zero additive jump `x ← x + jump_x` produces a visible discontinuity in the
state trajectory:

```@example flows_multiphase
# jump_x = [0.5, 0.0] defined above
sol_jump = mpf_jump((0.0, 2.0), x0)
plot(sol_jump)   # state jumps by [0.5, 0.0] at t = 1.0
```

### Hamiltonian flow — costate jump

For Hamiltonian flows, `hflow1 * (t, jump_p, hflow2)` adds an additive vector to
the costate (`p ← p + jump_p`). The state remains continuous:

```@example flows_multiphase
jump_p = [0.0, 0.5]
hmpf_jp = hflow1 * (1.0, jump_p, hflow2)
hsol_jp = hmpf_jp((0.0, 2.0), x0, p0)
plot(hsol_jp)   # costate jumps by [0.0, 0.5] at t = 1.0, state unchanged
```

### Hamiltonian flow — simultaneous state and costate jump

`hflow1 * (t, jump_x, jump_p, hflow2)` jumps both components at once
(`x ← x + jump_x`, `p ← p + jump_p`):

```@example flows_multiphase
jump_xx, jump_pp = [0.1, 0.0], [0.0, 0.5]
hmpf_jxp = hflow1 * (1.0, jump_xx, jump_pp, hflow2)
hsol_jxp = hmpf_jxp((0.0, 2.0), x0, p0)
plot(hsol_jxp)   # both state and costate jump at t = 1.0
```

### State function jump

A callable `f(x)` transforms the state at the switching time:

```@example flows_multiphase
mpf_fn = flow1 * (1.0, x -> 2.0 .* x, flow2)
sol_fn = mpf_fn((0.0, 2.0), x0)
plot(sol_fn)   # state doubled at t = 1.0
```

### Hamiltonian function jump — full transformation

A callable `f(x, p)` transforms both components simultaneously:

```@example flows_multiphase
hmpf_fn = hflow1 * (
    1.0, (x, p) -> (2.0 .* x, p .+ 0.5), hflow2
)
hsol_fn = hmpf_fn((0.0, 2.0), x0, p0)
plot(hsol_fn)   # state doubled, costate shifted at t = 1.0
```

### Hamiltonian state-only jump

Using `nothing` for the costate component leaves it unchanged:

```@example flows_multiphase
hmpf_sx = hflow1 * (1.0, [0.1, 0.0], nothing, hflow2)
hsol_sx = hmpf_sx((0.0, 2.0), x0, p0)
plot(hsol_sx)   # state jumps, costate continuous
```

---

## Design notes

- Concatenation is an associative binary operation on flows: `(f1 * (t, f2)) * (s, f3)`.
- Phases may have **different system and integrator types** (`S`, `I`): each phase can
  wrap a distinct function and use its own solver. The `flows` field is a heterogeneous
  tuple, so the compiler specializes the integration loop per phase combination.
  The required uniformity across phases is `TD`, `VD`, and the dynamics family
  (state vs Hamiltonian), enforced at construction time.
- The trajectory integration merges phase results via `Integrators.merge`, which keeps
  each phase's result and dense interpolant (a piecewise result): the merged trajectory
  is as accurate as a single-phase one. With `grid=nothing`, its time grid concatenates the
  phase grids, each switching time once; by default (no output grid at the call),
  an adaptive grid of 250 times is generated over the merged trajectory and every
  switching time appears once (the phases themselves are integrated without it).
  Evaluating at a switching time returns the end value of the phase that finishes there
  (before the jump); `Trajectories.right_limit` returns the value after it. A grid of
  times given at the call is
  returned exactly (switching times are not added); a generated grid (`grid=n`,
  `UniformGrid`, `AdaptiveGrid`) has exactly `n` distinct times, every switching time
  included once, the intervals being shared between the phases.

---

## See also

- [`CTFlows.MultiPhase.MultiPhaseStateFlow`](@ref), [`CTFlows.MultiPhase.MultiPhaseHamiltonianFlow`](@ref), [`CTFlows.MultiPhase.AnyMultiPhaseFlow`](@ref) — multi-phase flow types.
- [`CTFlows.MultiPhase.n_phases`](@ref), [`CTFlows.MultiPhase.phase_flows`](@ref), [`CTFlows.MultiPhase.switching_times`](@ref), [`CTFlows.MultiPhase.jumps`](@ref), [`CTFlows.MultiPhase.phase_labels`](@ref) — phase accessors.
- [`CTFlows.MultiPhase.phase_flows`](@ref), [`CTFlows.MultiPhase.switching_times`](@ref), [`CTFlows.MultiPhase.jumps`](@ref), [`CTFlows.MultiPhase.phase_labels`](@ref) — bulk accessors.
- [`CTFlows.Flows.label`](@ref) — the label of a flow.
- [`CTFlows.Trajectories.switching_times`](@ref), [`CTFlows.Trajectories.phase_labels`](@ref), [`CTFlows.Trajectories.left_limit`](@ref), [`CTFlows.Trajectories.right_limit`](@ref) — the switching structure of a trajectory.
