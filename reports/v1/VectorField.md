# Flow from a vector field

## Goal

Define a flow from a vector field by going through the full CTFlows pipeline
(`build_system` → `build_flow` → `f(config)` → `solve`). A vector field is a function
returning the derivative of the state, declined along two trait axes — autonomous vs.
non-autonomous (`f(x)` vs. `f(t, x)`) and fixed vs. non-fixed (with an extra variable
`v`: `f(t, x, v)`) — and along the shape of the state (scalar, vector; matrix deferred).

Two call modes are supported via the config types introduced in
[`design.md`](design.md):

- `flow(PointConfig(t0, x0[, p0], tf))` — returns the final state `xf` (and costate
  `pf` if `p0` was provided). For vector fields, no costate; `PointConfig(t0, x0, tf)`.
- `flow(TrajectoryConfig((t0, tf), x0))` — returns a solution object containing the
  full trajectory.

The high-level convenience:

```julia
solve(system, config, integrator)  # = build_flow + f(config)
```

This is delivered in phases. Phase 1 establishes the end-to-end skeleton with the
smallest viable surface; later phases progressively cover the rest.

---

## Phase 1 — In scope

The first implementation delivers an end-to-end vector-field flow with:

### Types and constructors

- **`VectorField` type** — trait matrix `{Autonomous, NonAutonomous} × {Fixed, NonFixed}`,
  scalar or vector state. Ported and trimmed from `save/src/types.jl`.

  ```julia
  # Autonomous, Fixed
  vf = VectorField(x -> -x)

  # NonAutonomous, Fixed
  vf = VectorField((t, x) -> -x)

  # NonAutonomous, NonFixed (with variable v)
  vf = VectorField((t, x, v) -> -x .* v)
  ```

- **`PointConfig` and `TrajectoryConfig`** — plain config structs (defined in `Core` or
  `Systems`) that carry call-mode data and drive dispatch in `build_solution`. For vector
  fields only the no-costate constructors are needed in Phase 1:

  ```julia
  PointConfig(t0, x0, tf)           # endpoint call
  TrajectoryConfig((t0, tf), x0)    # trajectory call
  ```

- **`VectorFieldSystem <: AbstractSystem`** — concrete system wrapping a `VectorField`.
  Implements the full `AbstractSystem` contract:

  - `rhs!(system)` — returns the ODE right-hand side closure `(du, u, p, t) -> nothing`,
    adapted to the `VectorField` trait (autonomous or not, fixed or not).
  - `dimensions(system)` — returns `(n_x = n,)` where `n` is the state dimension.
  - `build_solution(raw, flow, ::PointConfig)` — extracts and returns the final state `xf`
    from the raw `ODESolution` (i.e. `raw.u[end]`, or `raw[end]` for scalar state).
  - `build_solution(raw, flow, ::TrajectoryConfig)` — returns the raw `ODESolution` directly
    (Phase 1; a CTFlows wrapper is deferred).
  - `ode_problem(system, config)` — optional contract method used by `SciMLIntegrator` to
    assemble a standard `ODEProblem` from the system and the config's initial condition and
    time span.

### Pipeline functions (Phase 1)

- **`build_system(vf::VectorField)`** — direct dispatch; no strategy, no `ad_backend`
  required. Returns a `VectorFieldSystem`.

- **`build_flow(system, integrator)`** — wraps `(system, integrator)` into a `Flow`.

- **`(flow::Flow)(config)`** — calls `integrate` then `build_solution`.

- **`solve(system, config, integrator)`** — `build_flow` + `f(config)`.

### Integrator

- **`SciMLIntegrator <: AbstractODEIntegrator`** — defined in the package extension
  `CTFlowsSciMLExt`, loaded when `SciMLBase` and `OrdinaryDiffEqCore` are available. The
  user loads any algorithm package (`OrdinaryDiffEqTsit5`, `OrdinaryDiffEq`,
  `DifferentialEquations`) and passes `alg = Tsit5()`.

  Full CTSolvers strategy contract (`id`, `metadata`, `options`, `Base.show`, `describe`).

  Phase-1 options (sanity-checked against SciML APIs at implementation time):

  | Name | Type | Default | Description |
  | --- | --- | --- | --- |
  | `alg` | Any | `Tsit5()` | ODE algorithm |
  | `abstol` | Float64 | `1e-10` | Absolute tolerance |
  | `reltol` | Float64 | `1e-10` | Relative tolerance |
  | `maxiters` | Int | `10^5` | Maximum number of steps |
  | `dt` | Float64 | — | Fixed step size (non-adaptive) |
  | `adaptive` | Bool | `true` | Adaptive step-size control |
  | `save_everystep` | Bool | `true` | Save at every solver step |
  | `saveat` | Vector | `[]` | Save at specific times |

  Business callable: builds an `ODEProblem` from the system's `ode_problem` method, calls
  `CommonSolve.solve(prob, alg; opts...)`, and returns the `ODESolution`.

### Tests

Following `.windsurf/rules/testing.md`:

- **Unit tests** for `VectorField` (all four trait combinations, scalar and vector state).
- **Unit tests** for `VectorFieldSystem` (`rhs!`, `dimensions`, `build_solution` for both
  config types).
- **Unit tests** for `PointConfig` and `TrajectoryConfig` (construction, field access).
- **Contract tests** for `SciMLIntegrator` (`id`, `metadata`, `options`, `NotImplemented`
  path for unimplemented callables).
- **End-to-end pipeline test** (guarded by the SciML extension, using
  `OrdinaryDiffEqTsit5` in test extras): integrate `f(t, x) = -x` from `t0 = 0` to
  `tf = 1` with `x0 = [1.0]`; check `xf ≈ [exp(-1)]` and `sol(0.5) ≈ [exp(-0.5)]`.

### End-to-end user example (Phase 1)

```julia
using CTFlows
using OrdinaryDiffEqTsit5

# Build system directly from vector field — no strategy, no AD
vf  = VectorField((t, x) -> -x)    # NonAutonomous, Fixed
sys = build_system(vf)              # VectorFieldSystem

# Build integrator (strategy with options)
integ = SciMLIntegrator(abstol = 1e-12, reltol = 1e-12)

# Build flow (system + integrator)
flow = build_flow(sys, integ)

# Endpoint call — returns final state only
xf = flow(PointConfig(0.0, [1.0], 1.0))         # ≈ [exp(-1)]

# Trajectory call — returns raw ODESolution (Phase 1)
sol = flow(TrajectoryConfig((0.0, 1.0), [1.0]))  # ODESolution
sol(0.5)                                          # ≈ [exp(-0.5)]

# High-level convenience
xf2 = solve(sys, PointConfig(0.0, [1.0], 1.0), integ)
```

---

## Deferred to later phases

The following items are intentionally **not** in Phase 1:

- **Matrix-valued vector fields** — Phase 1 supports scalar/vector states only. The
  third trait axis (or parametric state shape) needs a design pass.
- **Solution wrapper with getters** — Phase 1 returns the raw SciML `ODESolution`.
  Later, `build_solution` for `TrajectoryConfig` will produce a CTFlows-specific
  `AbstractSolution` subtype exposing `state(sol)`, `time_grid(sol)`, `sol(t)`.
- **Plot recipe** — mirroring `CTModelsPlots`; deferred to a sibling extension
  (`CTFlowsPlots`) or a `RecipesBase` extension.
- **`internalnorm` option and ForwardDiff.Dual fix** (issue
  [#93](https://github.com/control-toolbox/CTFlows.jl/issues/93)) — only the real part
  of `ForwardDiff.Dual` numbers should contribute to the adaptive-step norm. Reference
  snippet preserved in the Appendix.
- **Event / jump handling** — `tstops`, `callback`, `jumps` options on `SciMLIntegrator`.
- **GPU support** — `CPU`/`GPU` strategy parameters on `SciMLIntegrator`, mirroring the
  Exa modeler pattern in CTSolvers (see Appendix).
- **Concatenation** — `MultiPhaseSystem`, `MultiPhaseFlow`, the `∘` and `*` operators.
- **Per-algorithm integrator strategies** — dedicated `Tsit5Integrator`,
  `Rodas4Integrator`, etc.; Phase 1 ships one generic `SciMLIntegrator`.
- **Costate integration** — `PointConfig(t0, x0, p0, tf)` and
  `TrajectoryConfig((t0, tf), x0, p0)` for Hamiltonian and OCP flows; not relevant for
  plain vector fields.

---

## Open questions (Phase ≥ 2)

- **Matrix-field shape**: third trait axis, parametric `T <: AbstractArray`, or pure
  method dispatch on the function signature?
- **Option ownership**: `tstops` / `jumps` / `internalnorm` on the integrator (they
  configure the solver) or on the system (they describe the ODE structure)?
- **Integrator granularity**: keep one generic `SciMLIntegrator` long-term, or introduce
  one strategy per algorithm (`Tsit5Integrator`, `Rodas4Integrator`, …) sharing a common
  metadata base?
- **GPU pathway**: mirror `exa.jl` exactly with `CPU`/`GPU` parameters on
  `SciMLIntegrator{P}` and computed defaults, or carry the parameter on the AD backend,
  or both?
- **Solution wrapper API**: CTFlows-specific type with `state(sol)` / `time_grid(sol)`,
  or just return the SciML `ODESolution` and document `sol(t)` as the canonical accessor?
- **Plot recipe location**: extension on `RecipesBase`/`Plots`, or a sibling package
  `CTFlowsPlots` mirroring `CTModelsPlots`?
- **SciML option-name verification**: every option name in the Phase-1 list must be
  checked against the actual `SciMLBase` / `OrdinaryDiffEqCore` APIs at implementation
  time.

---

## Appendix — reference snippets

### Dual-number internal norm (issue #93)

Reference snippet for the future `internalnorm` fix — only the real part of
`ForwardDiff.Dual` numbers should contribute to the adaptive-step norm:

```julia
sse(x::Number) = x^2
sse(x::ForwardDiff.Dual) = sse(ForwardDiff.value(x))

totallength(x::Number) = 1
totallength(x::ForwardDiff.Dual) = totallength(ForwardDiff.value(x))
totallength(x::AbstractArray) = sum(totallength, x)

my_norm(u, t) = sqrt(sum(sse, u) / totallength(u))

# Usage: SciMLIntegrator(internalnorm = my_norm)
```

### CPU/GPU parameter template (from CTSolvers `exa.jl`)

Reference pattern for parameterising a CTFlows strategy by `CPU`/`GPU`:

```julia
# Parameter types (singletons, subtype AbstractStrategyParameter)
struct CPU <: Strategies.AbstractStrategyParameter end
struct GPU <: Strategies.AbstractStrategyParameter end

# Parameterised strategy type
struct SciMLIntegrator{P <: Union{CPU, GPU}} <: AbstractODEIntegrator
    options::Strategies.StrategyOptions
end

# Default constructor: CPU
SciMLIntegrator(; kwargs...) = SciMLIntegrator{CPU}(; kwargs...)
SciMLIntegrator(::Type{P}; kwargs...) where {P} = SciMLIntegrator{P}(
    Strategies.build_strategy_options(SciMLIntegrator{P}; kwargs...)
)

# Parameter-specific metadata (different defaults per backend)
function Strategies.metadata(::Type{<:SciMLIntegrator{CPU}})
    return Strategies.StrategyMetadata(
        Strategies.OptionDefinition(name=:alg, type=Any, default=Tsit5(),
                                    description="ODE algorithm (CPU default: Tsit5)"),
        # … other options …
    )
end

function Strategies.metadata(::Type{<:SciMLIntegrator{GPU}})
    return Strategies.StrategyMetadata(
        Strategies.OptionDefinition(name=:alg, type=Any, default=GPUTsit5(),
                                    description="ODE algorithm (GPU default: GPUTsit5)"),
        # … other options …
    )
end
```

### References

- `save/src/types.jl` — original `VectorField` implementation (`L38-L54` traits,
  `L626-L692` type)
- `save/ext/vector_field.jl` — original `Flow(::VectorField; ...)` extension
- [`Tsit5` documentation](https://docs.sciml.ai/OrdinaryDiffEq/stable/explicit/Tsit5/)
- [`DifferentiationInterface.jl` backends](https://juliadiff.org/DifferentiationInterface.jl/DifferentiationInterface/stable/explanation/backends/)
- [CTSolvers — strategy parameters](https://github.com/control-toolbox/CTSolvers.jl/blob/main/src/Strategies/contract/parameters.jl)
- [CTSolvers — Exa modeler with CPU/GPU](https://github.com/control-toolbox/CTSolvers.jl/blob/main/src/Modelers/exa.jl)
- [CTFlows issue #93 — dual-number internal norm](https://github.com/control-toolbox/CTFlows.jl/issues/93)
- [`reports/v1/design.md`](design.md) — overall CTFlows v1 architecture
