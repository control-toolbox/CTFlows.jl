# CTFlows Documentation Plan

A plan for extending the user-facing documentation beyond the existing
`DifferentialGeometry` guide. The guiding principle: **document the user journey,
not the source-module layout**. `DifferentialGeometry` is a *horizontal* toolkit
(a family of sibling operators) and rightly gets one page per operator. The
remaining modules form a *vertical pipeline* traversed once per use:

```text
Data → Systems → Integrators → Flows → Solutions
        (Traits / Configs / Common / Differentiation = cross-cutting infrastructure)
```

Documenting each module in isolation would create redundancy and miss the point —
how the pieces chain together. So the new guides follow the pipeline as a narrative.

---

## Decision: which modules get a guide

Not all modules deserve a `DifferentialGeometry`-level treatment. Three tiers:

| Module | Treatment | Rationale |
|---|---|---|
| **Flows** | 🟢 Detailed narrative guide (the core) | Central abstraction (`Flow`, `build_flow`, calling a flow). The main CTFlows tutorial. |
| **Data** | 🟢 Guide | Building blocks (`VectorField`, `Hamiltonian`, `HamiltonianVectorField`) + traits. Partly introduced already in DG. |
| **Systems** | 🟢 Guide (may fold into Flows) | `AbstractSystem` / RHS contract. Often explained *en route* inside the Flows guide. |
| **Solutions** | 🟢 Short guide | `state`, `costate`, `time_grid`, `plot` — user-oriented output layer. |
| **MultiPhase** | 🟢 Dedicated guide | Distinct, advanced feature (concatenation, switching times, jumps). |
| **Traits** | 🟡 Cross-cutting *conceptual* guide | Determines call signatures everywhere. Explain **once**, not per module. The DG traits/signatures table is an embryo of this. |
| **Integrators** | 🟡 Configuration page | Mainly `SciML` + options. For advanced users switching backends. |
| **Differentiation** | 🟡 Short page (or section in DG Limitations) | AD backend selection. Partly covered by `differential_geometry/limitations.md`. |
| **Configs** | 🔴 API reference only | Pipeline plumbing (`StatePointConfig`, …). No narrative guide. |
| **Common** | 🔴 API reference only | Almost entirely internal (`__is_autonomous`, `__variable`, …). |

🟢 = written guide · 🟡 = brief/config page · 🔴 = docstrings + generated API reference only

---

## Target structure

Mirror the existing `differential_geometry/` directory with a `flows/` directory
following the user-journey pipeline:

```text
docs/src/
  index.md                  # existing introduction (light revision)
  flows/
    index.md                # pipeline overview: Data → Systems → Integrators → Flows → Solutions
    data.md                 # VectorField / Hamiltonian / HVF + traits
    building_a_flow.md      # build_system / build_flow / Flow
    integrating.md          # configs, calling the flow, choosing an integrator
    solutions.md            # state / costate / plot
    multiphase.md           # multi-phase flows
    traits.md               # cross-cutting conceptual guide (call signatures)
  differential_geometry/    # existing — unchanged
  api/                      # generated reference — unchanged
```

`Configs`, `Common`, `Differentiation` stay in the auto-generated API reference.

---

## Page-by-page outline

### `flows/index.md` — pivot page (write first)

Modelled on `differential_geometry/index.md`. Contents:

- One-paragraph statement of what CTFlows integrates and why.
- The pipeline diagram (`Data → Systems → Integrators → Flows → Solutions`).
- A **reading-order table** linking each sub-page to the pipeline stage and the
  key type it introduces (same shape as the DG reading-order table).
- The **qualified-access** boilerplate (`using CTFlows.Flows`, etc.) — reuse the
  DG `@example` setup block so cross-page state is consistent.
- A short "minimal end-to-end" runnable example (build a `VectorField` → `Flow` →
  call → inspect solution), each step linked to its detailed page.

### `flows/data.md`

- `VectorField`, `Hamiltonian`, `HamiltonianVectorField`: math object + typed
  constructors.
- Trait combinations and the resulting call signatures (link back to `traits.md`).
- In-place vs out-of-place forms.
- Runnable `@example` blocks per trait combination.

### `flows/building_a_flow.md`

- The `AbstractSystem` contract (`rhs!`, trait delegation) — pulled from the
  current `index.md` "Contracts at a glance".
- `build_system`, `build_flow`, the concrete `Flow` wrapper.
- How a `Flow` combines a system with an integrator (`system(flow)`,
  `integrator(flow)`).

### `flows/integrating.md`

- Configuration objects (`StatePointConfig`, `StateTrajectoryConfig`,
  Hamiltonian variants) — what each drives.
- Calling a flow; point-to-point vs full-trajectory.
- Selecting / configuring an integrator (`SciML`, `Tsit5`, tolerances) — overlaps
  with the Integrators tier note.

### `flows/solutions.md`

- `VectorFieldSolution` / `HamiltonianVectorFieldSolution`.
- Accessors: `state`, `costate`, `time_grid`, `evaluate_at`, `final_state`.
- `plot` (note the Plots extension trigger).

### `flows/multiphase.md`

- `MultiPhaseStateFlow`, `MultiPhaseHamiltonianFlow`.
- Concatenation, `n_phases`, `get_flow`, `get_switching_time`, `get_jump`.
- Constraint: concatenation restricted to flows from the same OCP (see roadmap).

### `flows/traits.md` — cross-cutting

- The three trait axes (time / variable / mutability) and their values.
- The call-signature tables (lift the vector-field and Hamiltonian tables from
  `differential_geometry/index.md` so both guides share one canonical reference).
- `Autonomous`/`NonAutonomous`, `Fixed`/`NonFixed`, `InPlace`/`OutOfPlace`.

---

## `docs/make.jl` changes

Add a "Flows" section to `pages` (between "Introduction" and "Differential
Geometry"), mirroring the DG block:

```julia
"Flows" => [
    "Overview"           => "flows/index.md",
    "Data structures"    => "flows/data.md",
    "Building a flow"    => "flows/building_a_flow.md",
    "Integrating"        => "flows/integrating.md",
    "Solutions"          => "flows/solutions.md",
    "Multi-phase flows"  => "flows/multiphase.md",
    "Traits"             => "flows/traits.md",
],
```

Extension triggers already loaded in `make.jl` (`OrdinaryDiffEqTsit5`, `Plots`,
`DifferentiationInterface`, `SciMLBase`) cover the runnable examples — no new
`using` needed.

---

## Conventions (match the DG guide)

- `@meta CurrentModule = CTFlows` at the top of every page.
- Math first, runnable `@example` second.
- Cross-references via `@ref CTFlows.Submodule.Symbol` (qualified paths only —
  the package exports nothing).
- One shared `@example` setup block per page (`using CTFlows.Flows`, etc.).
- Reading-order and notation-summary tables on the overview page.

---

## Suggested sequencing

1. `flows/index.md` (pivot) — establishes the narrative and shared setup block.
2. `flows/data.md` + `flows/traits.md` — the foundation other pages link to.
3. `flows/building_a_flow.md` → `flows/integrating.md` → `flows/solutions.md`.
4. `flows/multiphase.md`.
5. Wire `make.jl`; build locally (`julia --project=. docs/make.jl`) and fix
   broken `@ref` / `@example` blocks.
6. Light revision of `index.md` to point at the new Flows guide and drop content
   now covered there.

Tiers 🟡 (Integrators / Differentiation) can be brief sections inside
`integrating.md` and the DG `limitations.md` rather than standalone pages, unless
they grow enough to warrant their own.
