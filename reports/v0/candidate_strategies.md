# Candidate Strategies for CTFlows

This report is a **brainstorm** — no decisions are made here. Every dimension of choice in
CTFlows that *could* become a strategy or strategy family is listed and discussed. Decisions on
which candidates to promote to actual families, and the drafting of their business contracts,
are deferred to a follow-up step.

For background on the strategy contract and the infrastructure it unlocks, see
[`strategies.md`](strategies.md).

## 1. Conceptual hierarchy and the CTSolvers analogy

CTFlows maps onto the same three-layer architecture as CTSolvers:

```text
CTSolvers                              CTFlows (proposed)
─────────────────────────────────────────────────────────────────
AbstractOptimizationProblem            AbstractSystem
   OCP, NLP, …                            VectorField, Hamiltonian,
                                          OCP, Function, ODEProblem, …

AbstractNLPModeler                     AbstractFlowModeler
   OCP → NLP model                        input → AbstractSystem
   (ADNLP, Exa)                           (OpenLoop, ClosedLoop,
                                           HamiltonianModeler, …)

AbstractNLPSolver                      AbstractODEIntegrator
   NLP → execution stats                  ODEProblem → trajectory
   (Ipopt, MadNLP, …)                     (Tsit5, DP8, Rodas4, …)
─────────────────────────────────────────────────────────────────
```

- **Layer 1 — the object** (`AbstractSystem`): the thing being acted upon. Types vary by
  problem structure; selection is handled by Julia's type dispatch, not by strategies.
- **Layer 2 — the construction strategy** (`AbstractFlowModeler`): takes any integrable input
  (a `VectorField`, a `Hamiltonian`, an OCP with control law, …) and produces a fully assembled
  `AbstractSystem` with an embedded `rhs!`. Direct analog of `AbstractNLPModeler`.
- **Layer 3 — the execution strategy** (`AbstractODEIntegrator`): solves the Cauchy problem and
  returns a trajectory. Direct analog of `AbstractNLPSolver`.

A multi-phase composition level (several systems + switching times) sits above as a
higher-order object built from flows, with no direct CTSolvers counterpart.

The precise mapping of **actions**, **objects**, and **strategies** onto this hierarchy —
including canonical names (`build`, `solve`, …) and user-friendly aliases (`Flow(...)`,
`f(t0, x0, p0, tf)`) — is developed in §2.

## 2. Actions, objects, and strategies in CTFlows

Applying the action-object-strategies pattern from [`strategies.md` §2](strategies.md) to
CTFlows gives the following mapping. Each action has a **canonical name** consistent with
CTSolvers (`build`, `solve`, …) and, where appropriate, a **user-friendly alias** that matches
the CTFlows idiom (`Flow(...)`, `f(t0, x0, p0, tf)`).

### 2.1 Action inventory

| Action (canonical) | User-friendly alias | Level | Object | Strategies | Result |
| --- | --- | --- | --- | --- | --- |
| `build_system` | `System(ocp, u, modeler)` | atomic | `(ocp, control_law)` | `flow_modeler` | `AbstractSystem` |
| `build_flow` | `Flow(system, integrator)` | atomic | `system` | `ode_integrator` | `Flow` |
| `build_system` + `build_flow` | `Flow(ocp, u, modeler, integrator)` | pipeline | `(ocp, control_law)` | `(flow_modeler, ode_integrator)` | `Flow` |
| `integrate` | `f(t0, x0[, p0], tf)` | atomic | `flow` | `ode_integrator` (embedded) | trajectory |
| `solve` | `f((t0, tf), x0[, p0])` | pipeline | `flow` | — (all embedded) | `CTModels.Solution` |
| `build_solution` | — | atomic | `(system, ode_sol)` | — (embedded in system) | `CTModels.Solution` |

The key insight: a `Flow` is simply `(system, integrator)`. The system is a **fully assembled
object** — it already embeds its `rhs!`, its metadata, and its solution-building logic. The
modeler does its work once, at `build_system` time, and disappears from subsequent calls.

`build_system` applies to all input types. For raw types (`VectorField`, `Hamiltonian`,
`Function`, …) a default or trivial modeler assembles the system; for OCP inputs a
non-trivial modeler is required to handle the loop type and augmentation choices.

### 2.2 The `build_system` atomic action

`build_system` is the CTFlows analog of `build_model` in CTSolvers. The modeler's callable
produces a fully assembled `AbstractSystem`:

```julia
# For raw inputs (VectorField, Hamiltonian, Function, …)
function build_system(input, modeler)
    return modeler(input)        # modeler(input) → AbstractSystem
end

# For OCP inputs (control law embedded in the system)
function build_system(ocp, u, modeler)
    return modeler(ocp, u)       # modeler(ocp, u) → AbstractSystem
end
```

The resulting system embeds:

- `rhs!(du, u, p, t)` — the ODE right-hand side (built by the modeler),
- dimensional metadata (state, costate, control sizes),
- `build_solution(system, ode_sol)` — how to package a trajectory into a result.

### 2.3 The `build_flow` and `solve` actions

With the system fully assembled, `build_flow` is just a wrapper:

```julia
function build_flow(system::AbstractSystem, integrator::AbstractODEIntegrator)
    return Flow(system, integrator)
end
```

The user-facing `Flow(ocp, u, modeler, integrator)` sequences both steps:

```julia
# Canonical two-step form
flow = build_flow(build_system(ocp, u, modeler), integrator)

# User-friendly pipeline alias (build_system + build_flow in one call)
flow = Flow(ocp, u, modeler, integrator)

# Descriptive form (OptimalControl registry)
flow = Flow(ocp, u, :tsit5; abstol = 1e-10)
```

Calling the flow is `integrate`; for OCP flows `solve` adds `build_solution`:

```julia
xf, pf = f(t0, x0, p0, tf)              # integrate — returns final state/costate

function solve(flow::Flow, tspan, x0, p0)
    ode_sol = flow(tspan, x0, p0)        # integrate
    return build_solution(flow.system, ode_sol)  # system handles its own solution
end
```

### 2.4 Key consequences

- **The modeler acts once, at construction.** `modeler(ocp, u)` → `AbstractSystem` is the
  atomic call — directly analogous to `modeler(ocp, x0)` → `NLP` in CTSolvers. After that,
  the modeler is gone from the call chain.
- **The system is the stable intermediate object.** It has a contract — `rhs!`, dimensions,
  `build_solution` — that `build`, `integrate`, and `solve` rely on. The loop type
  (open/closed/dyn-closed) is encoded in the type of `u` and thus in the type of the system
  produced; it does not appear in the modeler's contract.
- **`build_flow` is trivial.** It only binds a system to an integrator. The `Flow` carries no
  extra logic — complexity lives in the system (modeler's output) and the integrator.
- **`build_solution` needs no strategy argument.** The system already embeds its
  solution-building logic; `build_solution(system, ode_sol)` is self-contained.
- **Canonical names** (`build_system`, `build_flow`, `integrate`, `solve`, `build_solution`)
  follow the CTSolvers convention. **User-friendly names** (`Flow(...)`,
  `f(t0, x0, p0, tf)`) are idiomatic CTFlows aliases on top.

The following sections (§3–§9) develop each candidate family in detail.

## 3. System (not a strategy — the problem type)

`AbstractSystem` (or the existing type hierarchy) groups everything that can be integrated:

- `VectorField` — `f(t, x, v)` or `f(x)` → `ẋ`
- `Hamiltonian` — `H(t, x, p, v)` → scalar
- `HamiltonianVectorField` — `(Ẋ, Ṗ)` already in phase space
- OCP with control (`WithControlModel`) — dynamics + cost + control law
- `ControlFreeModel` — OCP without control (parameter estimation, optimal design)
- Raw `Function` — `(t, x, v) → ẋ` with no additional structure
- `ODEProblem` / `ODEFunction` — SciML standard form (already integrable)

**This is not a strategy**: the types are not interchangeable implementations of the same role.
The right mechanism for varying the input type is Julia's type dispatch. What varies, for a
given input type, is *how* the system is assembled from it — and that is the role of the flow
modeler in `build_system`.

**`MultiPhaseSystem <: AbstractSystem`**: an ordered list of systems + switching conditions
assembled into a single composite system. Belongs at this level — assembled by a flow modeler
and handed to `build_flow` like any other system. Compatibility (same OCP type, or matching
dimensions encoded in parametric types) is enforced at construction time. Uses one integrator
for a single ODE solve with `tstops` and callbacks handling the switching.

## 4. Candidate family: Flow Modeler (`AbstractFlowModeler`)

**Role**: takes any integrable input and produces a fully assembled `AbstractSystem` that
embeds its own `rhs!`, dimensional metadata, and solution-building logic. Called via
`build_system`. This is the direct analog of `AbstractNLPModeler`.

**Current code**: this logic is currently hardcoded and spread across `hamiltonian.jl`,
`optimal_control_problem.jl`, `vector_field.jl`, and `function.jl`. There is no user-visible
choice here — the construction is determined entirely by the system type.

**Why a strategy**: for several input types, there are genuinely different ways to assemble
the system:

- **For OCP with control** — this is where the *loop type* lives:
  - `OpenLoopModeler` — control `u(t, v)` is a pre-computed open-loop law.
  - `ClosedLoopModeler` — control `u(t, x, v)` is a state-feedback law.
  - `DynClosedLoopModeler` — control `u(t, x, p, v)` is a state-costate feedback law
    (Hamiltonian gradient feedback). This is the natural form in indirect optimal control.
  - Each modeler wraps the user-provided function differently and assembles a different system.
  - Common option: `augmented::Bool` — whether to extend the system with
    $dp_v/dt = -\partial H/\partial v$ (needed to return the dual variable when it exists;
    roadmap item [issue #103](https://github.com/control-toolbox/CTFlows.jl/issues/103)).

- **For `Hamiltonian`** (without OCP structure):
  - `HamiltonianModeler` — standard Hamilton's equations `(ẋ, ṗ) = (∂H/∂p, -∂H/∂x)`.
  - `AugmentedHamiltonianModeler` — same, extended with the $p_v$ costate equation.
  - This maps directly to `rhs_augmented` in the current `ext/hamiltonian.jl`.

- **For `ControlFreeModel`**:
  - `ControlFreeModeler` — Pontryagin Hamiltonian with empty control; augmentation optional.

- **For `VectorField` / `Function`**:
  - A trivial modeler (`VectorFieldModeler`) that assembles the function as an
    `AbstractSystem`. Conceptually an identity, but preserves the uniform `build_system`
    interface across all input types.

- **For `ODEProblem` / `ODEFunction`**:
  - A passthrough modeler — the system is already in ODE form, just forward it.

**Canonical callable**: `(modeler)(input[, control_law]) → AbstractSystem` — the modeler
takes whatever input is relevant and produces a fully assembled system with embedded `rhs!`
and solution-building logic.

**Candidate options**: `augmented::Bool`, `internalnorm`, `tstops`, `jumps`.

**Open questions**:

- Single `AbstractFlowModeler` with dispatch on system type, or per-system-type
  sub-families (`AbstractOCPFlowModeler`, `AbstractHamiltonianFlowModeler`, …)?
  The per-system split is more ISP-compliant but requires more families.
- Should `internalnorm`, `tstops`, `jumps` live on the modeler (they describe the ODE
  structure) or on the integrator (they configure the solver)? Currently they are passed
  to the solver.
- Is `ControlFreeModeler` a sub-case of `OpenLoopModeler` (with `u = []`) or a separate
  strategy?

**Classification**: 🟢 **Strong candidate.** This is the most important gap in the current
architecture. Without it, all construction choices are hardcoded and non-extensible.

## 5. Candidate family: ODE Integrator Backend (`AbstractODEIntegrator`)

**Role**: solves a Cauchy problem (an `ODEProblem` or equivalent `rhs!` + initial condition +
time span) and returns a trajectory. Direct analog of `AbstractNLPSolver`.

**Current code**: `__alg() = Tsit5()`, `__abstol() = 1e-10`, `__reltol() = 1e-10`,
`__saveat() = []`, `__internalnorm()` in `ext_default.jl`; threaded through all `Flow(...)`
constructors as flat kwargs. The entire extension `CTFlowsODE` loads `OrdinaryDiffEq`.

**Why a strategy**: different algorithms live in different packages
(`OrdinaryDiffEqTsit5.jl`, `OrdinaryDiffEqRosenbrock.jl`, …). The roadmap explicitly calls
for `using`-based backend switching with `Tsit5` as default. Each algorithm has its own
relevant options (step size control, stiffness detection, dense output, …). GPU integrators
(`DiffEqGPU`) require different defaults and a different loading path.

**Candidate strategies**: `Tsit5`, `BS3`, `DP8`, `Rodas4`, `AutoTsit5`, `KenCarp4`, and one
strategy per relevant algorithm in the OrdinaryDiffEq ecosystem.

**Candidate options**: `abstol`, `reltol`, `saveat`, `internalnorm`, `dense`, `maxiters`.

**Parameters**: `CPU`, `GPU` (GPU integrators expose different defaults, e.g. larger
`maxiters`; dispatch at compile time).

**Canonical callable**: `(integrator)(ode_problem; display) → trajectory` (mirrors
`solver(nlp; display) → stats` in CTSolvers).

**Tag dispatch pattern**: as in CTSolvers solvers, the type can be declared in the main
package while the implementation lives in a package extension, loaded only when the
corresponding `OrdinaryDiffEqXxx.jl` is brought in.

**Open questions**: is one strategy per ODE algorithm the right granularity, or should
stiffness class (non-stiff, stiff, DAE) be the primary axis with algorithm as a sub-option?
Should tolerances be options on the integrator or passed separately at call time?

**Classification**: 🟢 **Strong candidate.** The most natural extension point in CTFlows.

## 6. Candidate family: AD Backend (`AbstractADBackend`)

**Role**: provides automatic differentiation for `ctgradient`, `ctderivative`, `ctjacobian`
used throughout differential geometry operations and flow construction.

**Current code**: `utils.jl` calls `ForwardDiff.derivative`, `ForwardDiff.gradient`,
`ForwardDiff.jacobian` directly — hardcoded, not configurable.

**Why a strategy**: GPU support (roadmap item) requires a GPU-compatible AD backend (Zygote,
Enzyme). Reverse-mode AD is more efficient for large-state systems. This is a cross-cutting
concern: it affects both differential geometry operators (`Lift`, `ad`, `@Lie`) and the
construction of the Hamiltonian gradient in `rhs_augmented`.

**Candidate strategies**: `ForwardDiffAD`, `ZygoteAD`, `EnzymeAD`, `ReverseDiffAD`.

**Parameters**: `CPU`, `GPU`.

**Canonical callable**: `ctgradient(backend, f, x)`, `ctjacobian(backend, f, x)`, etc.

**Open questions**: is this one family (uniform AD interface) or two (one for scalar
derivatives, one for jacobians/gradients)? Should the AD backend be tied to the integrator
(so `Tsit5(GPU)` implies `EnzymeAD(GPU)`) or kept independent? Is this a CTFlows family or
a CTBase concern?

**Classification**: 🟢 **Strong candidate** for GPU support; may be cross-package.

## 7. Candidate family: Solution Builder (`AbstractFlowSolutionBuilder`)

**Role**: packages the raw ODE trajectory of an OCP flow into a `CTModels.Solution`
(cost evaluation, trajectory extraction, control reconstruction).

**Current code**: `CTModels.Solution(ocfs::OptimalControlFlowSolution; kwargs...)` in
`ext_types.jl` — integrates the Lagrange cost with a second nested ODE solve, extracts
`x(t)`, `u(t)`, `p(t)`, builds a full `CTModels.Solution`.

**Why a strategy**: one may want a lightweight solution (no cost integration, no Lagrange
term evaluation) for performance-critical applications; a GPU variant may need a different
packaging path. The analogy is the "solution builder callable" in `AbstractNLPModeler`
(`(modeler)(prob, nlp_stats) → Solution`).

**Candidate strategies**: `FullOCPSolutionBuilder` (current behavior),
`LightweightOCPSolutionBuilder` (skip Lagrange integration).

**Candidate options**: `compute_objective::Bool`, `control_interpolation::Symbol`.

**Open questions**: should this be a separate family or an option on the flow modeler (similar
to how the NLP modeler bundles both model building and solution building)? Keeping them
together makes the analogy with CTSolvers cleaner.

**Classification**: 🟡 **Arguable.** Strong if bundled with the flow modeler (as in CTSolvers);
weaker if separated.

## 8. Multi-phase composition: two levels

Multi-phase composition exists at two distinct levels with different semantics.

### 8.1 System level — `MultiPhaseSystem`

**What it is**: an ordered list of systems + switching conditions assembled via the `∘`
operator (or `MultiPhaseSystem([sys1, sys2], [t_switch])`). The result is an
`AbstractSystem` and is handled by the rest of the pipeline unchanged:

```julia
multi_sys = sys1 ∘ sys2                           # MultiPhaseSystem
flow      = build_flow(multi_sys, integrator)     # single ODE solve
xf, pf    = flow(t0, x0, p0, tf)                  # one call
```

**Semantics**: ONE integration over `[t0, tf]`; the integrator uses `tstops` and a callback
to handle state discontinuities at switching times.

**Compatibility**: enforced at `∘` construction time — same OCP type (for OCP systems), or
matching state dimension encoded in the parametric type `HamiltonianSystem{n}`.

**Classification**: ❌ **Not a strategy.** `MultiPhaseSystem` is an `AbstractSystem` object;
its construction is handled by the flow modeler (same as any other system type).

### 8.2 Flow level — `MultiPhaseFlow`

**What it is**: concatenation of already-built flows via the `*` operator:

```julia
flow1 = build_flow(sys1, tsit5_integrator)
flow2 = build_flow(sys2, rodas4_integrator)
multi = flow1 * flow2                             # MultiPhaseFlow
xf    = multi(t0, x0, p0, tf)                    # sequential calls
```

**Semantics**: SEQUENTIAL integration — `flow1` is called from `t0` to `t_switch`, its
output is passed as initial condition to `flow2` from `t_switch` to `tf`. Each phase uses
its own integrator with its own tolerances.

**Compatibility**: state dimensions must match between consecutive phases; checked at `*`
construction. No integrator compatibility required — each phase integrates independently.

**Current code**: `concatenation.jl` already implements this `*` operator for two flows.

**Classification**: ❌ **Not a strategy.** `MultiPhaseFlow` is a composite callable object,
not an interchangeable implementation of a role. The `*` operator is a builder utility.

## 9. What is probably not a strategy

- **Flow problem type** (`VectorField`, `Hamiltonian`, OCP, `Function`, `ODEProblem`): distinct
  types with different interfaces, not interchangeable implementations of the same role. The
  right mechanism is Julia's multiple dispatch, not strategy lookup.
- **Event and jump handling** (`tstops`, `jumps`, callbacks): these configure *when* the
  integrator pauses or applies discrete effects. Best modeled as options on the integrator
  strategy or passed at call time, not as a separate family.
- **`autonomous` / `variable` flags**: derived from the OCP type at construction time, not a
  user strategy choice.
- **Control law function** (the Julia function `u(t, x, p, v)` provided by the user): this is
  user data, not a strategy. The *type* of law (open/closed/dyn-closed) is what becomes a
  strategy (via the flow modeler).

## 10. Summary

| Candidate | Tier | Action(s) | CTSolvers analog | Note |
| --- | --- | --- | --- | --- |
| **Flow Modeler** | 🟢 Strong | `build_system` | `AbstractNLPModeler` | Central gap; loop type + augmentation |
| **ODE Integrator Backend** | 🟢 Strong | `build_flow`, `integrate` | `AbstractNLPSolver` | Roadmap priority, extension-based |
| **AD Backend** | 🟢 Strong | `ctgradient`, `ctjacobian` | — (cross-cutting) | Required for GPU |
| **Solution Builder** | 🟡 Arguable | `build_solution` | Modeler solution callable | Natural if bundled with modeler |
| **MultiPhaseSystem** | ❌ Not a strategy | `build_system` (via `∘`) | — | `AbstractSystem` object; compatibility at type level |
| **MultiPhaseFlow** | ❌ Not a strategy | `*` operator | — | Composite callable; sequential integration, per-phase integrators |
| **Flow Problem Type** | ❌ Not a strategy | — | The "problem" itself | Type dispatch is correct |
| **Event/jump handling** | ❌ Not a strategy | — | Solver kwargs | Options on integrator |

## 11. Next step

Decisions on which candidates to retain as actual families, and the drafting of their
**business contracts** (required methods, callable signatures, options), are the subject of
the next report.

Items to decide:

- Whether `AbstractFlowModeler` is one family or several (per-system sub-families).
- Whether the solution builder is bundled with the flow modeler or separate.
- Whether the AD backend is a CTFlows family or delegated to a lower-level package.
- The granularity of the ODE integrator family (per algorithm vs. per stiffness class).
