# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- **`method=:gpu` device selection on every `Flow(...)` constructor** (GPU roadmap-v4 §5,
  phase 2): registers the now-parameterized `SciML{P}` (CTSolvers `v0.4.30-beta`) and
  `DifferentiationInterface{P}` (CTBase `v0.28.1-beta`) strategies with `[CPU, GPU]`. A single
  `method=:gpu` token resolves `GPU` for both the `:di` and `:sciml` families at once. Default
  (no `method`) behaviour is byte-identical to before.

### Changed

- **Unified flow construction** onto one resolution mechanism keyed by `Traits.ad_trait`
  (`WithAD` vs `WithoutAD`), retiring direct `build_integrator` use in favour of a shared
  `_build_integrator` helper.
- **BREAKING** — `Flow(vf; ad_backend=…)` on an **AD-free** flow is now rejected as an unknown
  option instead of being silently ignored (the AD-free plan has no `:di` family).

## [0.14.0-beta] - 2026-07-17

### Added

- **Basic (non-Hamiltonian) `Flow(ocp)` call without a costate** (§6, [#230]):
  `xf = f(t0, x0, tf; variable=v)` for a control-free OCP — the direct-shooting use case.
  Same `Flow(ocp)` object, dispatched on arity via a new inner `state_flow`; a trajectory
  call returns a `StateFlowTrajectory` with `law = nothing` (objective kept, no control,
  no costate). `Flow(ocp, law)` with a `DynClosedLoop` law has no such call (its dynamics
  need the costate) and raises a `PreconditionError` suggesting `f(t0, x0, p0, tf)`.
- **`Systems.vector_field` getter** (§7, [#185]): returns the vector field of a state flow.
  `Systems.hamiltonian_vector_field` extended to accept `AbstractHamiltonian`, covering
  `ComposedHamiltonian` from OCP + law.
- **Function-based jumps and per-component `nothing` for multi-phase flows**:
  `_apply_component_jump` with 3 dispatches — additive (`v .+ j`), callable (`j(v)`), and
  identity (`nothing`). Applies to both state-only and Hamiltonian multi-phase flows,
  enabling state-dependent costate jumps and partial jumps.
- **Cached trajectory projections** (§9): accessors return stored functors instead of
  rebuilding one per call.
- **Variable-costate free-time tests** (§8, [#231]): `v = t0` and `v = (t0, tf)` cases,
  plus the transversality note in the guide.
- **Dimension/shape test coverage**: 20 new tests across 8 files enforcing the "1-D =
  scalar" convention (vector `x0` → scalar output for OCP-backed flows), n-D vector
  preservation, and matrix 1×1 / 2×2 conventions for `StateFlow`, `HamiltonianFlow`, and
  `MultiPhaseStateFlow`.
- **New documentation pages**: `trajectories.md` (solution types and accessors),
  `control_laws.md` (control law types and flow paths), with executed examples and plot
  recipes.

### Changed

- **BREAKING — `ControlledTrajectory` renamed to `StateFlowTrajectory`** (no compat alias).
  The type is produced by three state flows (`Flow(fc, law)`, `Flow(ocp, law)`, and the
  new basic `Flow(ocp)`), so its invariant is "trajectory of a state flow", not "there is
  a control".
- **BREAKING — `Data` module moved to `CTBase.Data`.** `src/Data/` deleted; `CTFlows.Data`
  is now an alias via `using CTBase.Data` (re-exports `VectorField`/`Hamiltonian`/… for
  back-compat).
- **BREAKING — 1-D scalar coercion on OCP-backed flow point calls.** `OptimalControlFlow`
  basic call, `ControlledFlow` point call, and `MultiPhaseStateFlow` point call now coerce
  length-1 vector outputs to scalars via `_flow_state_coerce` / `Systems._coerce_state`,
  matching the existing Hamiltonian call behavior. Raw `StateFlow` (from `VectorField` /
  `ODEProblem`) intentionally preserves the input type.
- **Targeted helper renames**: `_controlled_state_coerce` → `_flow_state_coerce`,
  `_controlled_objective` → `_state_flow_objective`.
- **Consolidated objective core** `_flow_objective` and single feedback-dispatched
  `_control_of`, removing duplication between Hamiltonian and state paths.
- **New fields** on `StateFlowTrajectory`, `HamiltonianVectorFieldTrajectory`, and
  `OptimalControlFlow` (constructor signatures preserved).
- **New export** `Systems.vector_field`.

## [0.13.1-beta] - 2026-07-16

### Added

- **Real `status`/`successful` on flow-built `CTModels.Solution`s**: `_build_ocp_solution`
  previously hard-coded `successful=true` and left `status` unset, discarding the actual ODE
  termination info. It now delegates to `Integrators.status`/`Integrators.successful`
  (requires CTSolvers v0.4.29-beta, which added these accessors to
  `AbstractIntegrationResult`), so a degraded or forced-`unsafe=true` integration is reported
  truthfully on the resulting `CTModels.Solution` — single-phase, control-free, and merged
  multi-phase alike.
- **`status`/`successful` delegation on all trajectory wrappers**: added to
  `HamiltonianVectorFieldTrajectory`, `VectorFieldTrajectory`, and `ControlledTrajectory`
  (via its inner state trajectory), matching the existing
  `final_state`/`times`/`evaluate_at`/`merge` delegation already present on all three.

### Changed

- **`CTBase` compat bumped to `0.28`** (pulled in transitively by CTSolvers v0.4.29-beta).

## [0.13.0-beta] - 2026-07-11

### Added

- **Multiple simultaneous path constraints**: `constraint`/`multiplier` accept **tuples**
  of matched length to combine several separately-defined constraints —
  `Flow(ocp, law; constraint=(g1, g2), multiplier=(μ1, μ2))` — resolved by concatenation
  (`Σᵢ μᵢ·gᵢ`), in both `:total` and `:partial`. A single constraint carrier that is itself
  vector-valued (a `:path` label or function returning a vector, paired with a vector
  multiplier) already worked with no code changes — the tuple form is for combining
  *distinct* carriers.
- **MultiPhase reconstruction for OCP-built flows**: a multi-phase `*` concatenation of
  `OptimalControlFlow`s (built via `Flow(ocp, law)`) now evaluates — previously it errored
  with `MethodError: no method matching _evaluate_phase(::OptimalControlFlow, …)`. A
  trajectory call returns a `CTModels.Solution` with a **piecewise** control reconstructed
  from the per-phase laws and switching times, matching the return type of a single-phase
  OCP flow. Requires all phases to share the same OCP.
- **MultiPhase reconstruction for `ControlledFlow` concatenation**: the symmetric state-flow
  case — a multi-phase `*` of `ControlledFlow`s (`Flow(ocp, law)` with an `OpenLoop` /
  `ClosedLoop` law, or `Flow(fc, law)`) now returns a `ControlledTrajectory` with piecewise
  reconstructed control, previously erroring the same way.
- **Arity-checking for OCP convenience constructors**: `Flow(ocp, u::Function)` and raw
  `Function` `constraint`/`multiplier` specs wrap the user's function with the OCP's own
  time/variable dependence; when the function has a single method (arity detection is
  skipped if ambiguous — multiple dispatch or default arguments), a mismatched arity is now
  caught up front and raised as one `CTBase.Exceptions.IncorrectArgument` naming the real
  expected syntax for every mismatched control law / constraint / multiplier, instead of
  surfacing as an opaque `MethodError` deep inside AD or integration. The error also points
  to the explicit constructors (`DynClosedLoop`/`OpenLoop`/`ClosedLoop`,
  `MixedConstraint`/`StateConstraint`/`ControlConstraint`, `Multiplier`) as an escape hatch.
- **[Constrained flows](https://control-toolbox.org/CTFlows.jl/dev/flows/constrained.html)
  guide chapter**: the `constraint`/`multiplier` API, the `g ≥ 0` sign convention (vs.
  Maurer's `c ≤ 0`), multiple constraints, the `:total`/`:partial` semantics with the PMP
  symplectic-gradient decomposition explaining *why* the two modes agree on a constrained
  arc, and two worked examples (Goddard, order 1; double integrator, order 2).

## [0.12.0-beta] - 2026-07-10

### Added

- **Constrained pseudo-Hamiltonian flows (`:partial` mode)**: `Flow(ocp, law; constraint,
  multiplier, hamiltonian_type=:partial)` now integrates the constrained Hamiltonian
  `H = H̃ + μ·g` with **both** the control `u` **and** the multiplier value `μ` frozen at
  their feedback values during differentiation — `g` is differentiated in `(x, p, v)`, `μ`
  is not. This is the constrained counterpart of the unconstrained `:partial` mode and is
  sound on a boundary arc (where `g ≡ 0`, the neglected `(∂μ/∂z)ᵀg` term vanishes). See
  `.reports/constraints-and-duals/math.md`.
  - New `CTFlows.Systems.ConstrainedPseudoHamiltonianSystem` (carrying the base `H̃`, the
    law, `g` and `μ` separately) with dedicated RHS functors that evaluate `μ` before the
    gradient call and freeze it; and `FrozenConstrainedPseudoHamiltonian`, a
    frozen-multiplier `CTBase.Data.AbstractPseudoHamiltonian` used by those functors.
  - The variable-costate path picks up `ṗᵥ ∋ −μᵀ ∂g/∂v` at frozen `μ`.
  - Lifts the PR-3 guard that rejected constrained flows with `hamiltonian_type=:partial`.

### Changed

- **BREAKING — constrained flows are only defined with a control law.** `Flow(ocp;
  constraint=…, multiplier=…)` on a **control-free** OCP now throws an explicit
  `CTBase.Exceptions.PreconditionError` (previously an `IncorrectArgument` about an unknown
  option): a state constraint has no well-defined place in a control-free OCP Hamiltonian
  flow. Use `Flow(ocp, law; constraint=…, multiplier=…)`. This reverses the design note's
  earlier "control-free constrained flows stay supported" position.
- **BREAKING — constrained `Flow(ocp, law; constraint, multiplier, hamiltonian_type=:partial)`
  no longer errors.** It previously threw `IncorrectArgument` ("not yet supported"); it now
  integrates the frozen-multiplier constrained flow. Code relying on that error is affected.

## [0.11.0-beta] - 2026-07-10

### Added

- **Constrained pseudo-Hamiltonian flows (`:total` mode)**: `Flow(ocp, law; constraint, multiplier)`
  builds the flow of the constrained Hamiltonian `H = H̃ + μ·g`, where `g` is a path
  constraint and `μ` a user-supplied Lagrange multiplier.
  - `constraint` accepts a `:path` constraint **label** (`Symbol`), a
    `CTBase.Data.PathConstraint`, or a plain function with the OCP's natural arity.
  - `multiplier` accepts a `CTBase.Data.Multiplier` or a plain function `μ(x,p)` /
    `μ(t,x,p)` / `μ(x,p,v)` / `μ(t,x,p,v)`.
  - The constraint term is differentiated *through* in the `:total` mode (total derivative,
    chain-rule through the law and `μ`); a dedicated guide chapter on the `:total` vs
    `:partial` semantics is planned.
  - `constraint`/`multiplier` are paired (both-or-neither); a single one throws
    `IncorrectArgument`. Constrained flows with `hamiltonian_type=:partial` are not yet
    supported (planned for a later release) and are rejected at construction.
  - The unconstrained flow paths are untouched (dispatch selects the constrained
    pseudo-Hamiltonian only when a constraint is supplied).

### Requires

- CTBase ≥ 0.27.4-beta and CTModels ≥ 0.15.2-beta (AD-friendly constraint-by-label
  functors, needed to differentiate a labelled path constraint through the `:total` flow).

## [0.10.0-beta] - 2026-06-28

### Fixed

- **`Flow(ocp::CTModels.Models.Model)` now dispatches on control dependence.** Previously the
  constructor matched *any* model and silently built a Hamiltonian flow even for problems with a
  control input (ignoring the control — a latent correctness bug). It now re-dispatches on the
  `CTBase.Traits.ControlDependence` trait: a control-free OCP builds the flow as before, while a
  with-control OCP throws a descriptive `CTBase.Exceptions.PreconditionError` (the control-law /
  PMP path is not built here).

### Changed

- **Hardened the closed dispatch tables in `Flows/calling.jl`.** Added catch-all fallbacks for
  unforeseen `VariableDependence` and variable-costate capability trait values, so an unexpected
  tag yields a clean `PreconditionError` instead of a raw `MethodError`.

### Tests

- Added with-control and catch-all fallback tests.
- **Made the AD extension trigger explicit:** added `import ForwardDiff` to the test files that use
  an `AutoForwardDiff` backend (so `DifferentiationInterfaceForwardDiff`, which provides the fast
  pushforward path, loads when a file is run in isolation rather than relying on test-run order).

### Dependencies

- Bump CTBase compat to `0.26` (adds the `ControlDependence` trait family) and CTModels compat to
  `0.14` (implements the trait on `Model`). Requires CTLie ≥ `0.1.1` (widened CTBase compat).

## [0.9.4-beta] - 2026-06-26

### Changed

- **Breaking (internal sentinel):** `CTFlows.Common.NotProvided` / `CTFlows.Common.NotProvidedType` are removed.
  The local `struct NotProvided end` is deleted and there is **no re-export** — all code uses
  `CTBase.Core.NotProvided` (singleton instance of `CTBase.Core.NotProvidedType`) directly.
- `__variable()` default now returns `CTBase.Core.NotProvided`.
- `Flows/calling.jl` dispatch updated: `::Type{Common.NotProvided}` → `::Type{Core.NotProvidedType}`.
- DifferentialGeometry AD-backend sentinel and the SciML extensions consume `CTBase.Core.NotProvided` directly.

### Dependencies

- Bump CTBase compat to `0.25` (CTBase 0.25 moves `NotProvided`/`NotProvidedType` to `CTBase.Core`).

## [0.8.24-beta] - 2026-04-20

### Changed

- Version bump to 0.8.24-beta
- Added `<:CTModels.OCP.AbstractDefinition` parameter to `ControlFreeModel` and `WithControlModel` type aliases

## [0.8.23] - 2026-04-06

### Added

- `augment=true` keyword for `OptimalControlFlow` point evaluation
- Computes costate `pv(tf)` associated with variable `v` with initial condition `pv(t0) = 0`
- Implementation uses `Flow(Hamiltonian(H_aug))` to avoid `::ctVector` type constraints
- Returns triple `(xf, pf, pvf)` when `augment=true`, standard `(xf, pf)` when `augment=false`
- Support for scalar and vector states and variables with automatic type handling
- Comprehensive test suite with 55 tests covering all combinations and edge cases

### Changed

- Modified `OptimalControlFlow` to store Hamiltonian for augmented system construction
- Updated `__ocp_Flow` to pass Hamiltonian to constructor
- Updated `concatenate` functions to preserve Hamiltonian parameter
- Fixed scalar/vector assignment issues in `rhs_augmented` using explicit loops

### Fixed

- Resolved `ForwardDiff.Dual` type conversion errors with `::ctVector` constraint in `Dynamics`
- Fixed `copyto!` broadcast errors when variable dimension is 1 (scalar)
- Proper error handling for `augment=true` on Fixed models and trajectory calls

### Test

- Added 55 comprehensive tests in `test_augmented_flow.jl`
- Tests include unit tests for `rhs_augmented`, reference implementations, error cases, and mathematical correctness
- All tests pass with both scalar and vector variables
- Zero regression in existing functionality

## [0.8.21-beta] - 2026-04-06

### Added

- Support for control-free optimal control problems (parameter estimation, optimal design)
- New type aliases: `ControlFreeModel` and `WithControlModel` for dispatch
- New `Flow(ocp)` constructor for control-free problems without control variables
- New `Flow(ocp, g, μ)` constructor for control-free problems with state constraints and multipliers
- New `makeH` variants passing `Float64[]` as control for control-free Hamiltonians
- New `__create_hamiltonian` overloads for control-free OCPs with/without constraints
- Dummy `ControlLaw` returning `Float64[]` for compatibility with control-free problems
- Comprehensive test suite with 17 new tests covering all control-free functionality
- PreconditionError guards with clear error messages for invalid usage

### Changed

- Enhanced `Flow(ocp, u)` methods to reject control-free problems with descriptive errors
- Updated documentation with examples for control-free problem usage
- Maintained full backward compatibility with existing control-based flows

### Fixed

- Fixed type dispatch for control-free vs control-based optimal control problems
- Fixed Hamiltonian construction for problems with zero control dimension
- Fixed solution conversion to handle empty control trajectories correctly

### Test

- Added 17 comprehensive tests for control-free functionality
- Tests cover construction, integration, guards, constraints, variable parameters, and type stability
- All 45 tests now pass (28 existing + 17 new)
- Zero regression in existing functionality

## [0.8.20] - 2026-04-02

### Changed

- Bumped version from 0.8.19-beta to 0.8.20
- Added automatic Julia formatter pull requests via GitHub Actions

## [0.8.19-beta] - 2026-04-02

### Added

- Runtime consistency checks for @Lie macro to prevent silent argument ignoring
- Automatic detection of TimeDependence (TD) and VariableDependence (VD) mismatches between typed operands
- Clear error messages when user-provided autonomous/variable arguments conflict with operand types
- Support for mixed Function + VectorField/Hamiltonian combinations with proper validation

### Changed

- Modified __parse_lie_args() to track which arguments user explicitly provided
- Added _get_TD() and _get_VD() accessor functions for runtime type parameter extraction
- Created __check_bracket_consistency() function for centralized validation logic
- Updated __transform_lie_poisson_expression() to call consistency checks before bracket computation
- Enhanced @Lie macro to pass has_autonomous and has_variable flags to validation logic

### Fixed

- Fixed issue where autonomous/variable keyword arguments were silently ignored when used with already typed VectorField/Hamiltonian operands
- Fixed test syntax errors with parentheses for macro + isa expressions
- Improved error handling with clear IncorrectArgument messages instead of cryptic MethodErrors

### Test

- Added 47 comprehensive test scenarios covering all TD/VD combinations
- Tests include TD mismatches, VD mismatches, user argument conflicts, mixed types, and nested brackets
- All error cases provide clear, descriptive error messages

## [0.8.18] - 2026-04-01

### Changed

- Updated version from 0.8.17-beta to 0.8.18

## [0.8.17-beta] - 2026-03-26

### Changed

- Refactored @Lie macro for improved maintainability and testability
- Extracted helper functions: __is_mixed_usage(), __parse_lie_args(), __transform_lie_poisson_expression()
- Added comprehensive documentation with examples for all helper functions
- Added 40+ new tests covering macro functionality and error cases
- Replaced ArgumentError with CTBase.Exceptions.IncorrectArgument for better error handling
- Qualified function calls with CTFlows. to avoid namespace conflicts
- Improved code structure with separation of concerns

## [0.8.16-beta] - 2026-03-17

### Changed

- Updated version to 0.8.16-beta
- Added linear interpolation for control in OptimalControlFlowSolution

## [0.8.15] - 2026-03-08

### Changed

- Updated version from 0.8.14-beta to 0.8.15

## [0.8.14-beta] - 2025-02-13

### Changed

- Updated version to 0.8.14-beta
- Updated CTModels compatibility from 0.8 to 0.9

## [0.8.13-beta] - 2025-02-10

### Changed

- Updated version to 0.8.13-beta
- Updated docs/Project.toml version to match

## [0.8.12-beta] - 2025-02-10

### Changed

- Updated version to 0.8.12-beta
- Updated .gitignore: changed `reports/` to `.reports/`
- Updated GitHub workflows (CI.yml, Coverage.yml, Documentation.yml) to trigger on main branch and tags

## [0.8.11-beta.1] - 2025-02-10

### Changed

- Version bump to 0.8.11-beta.1

## [0.8.11-beta] - 2025-02-10

### Changed

- Widened CTModels compatibility to support versions 0.6 and 0.7

## [0.8.10-beta] - 2025-02-10

### Changed

- Updated version to 0.8.10-beta
- Added CTBase v0.17 compatibility

## [0.8.9] and earlier

### Changed

- Updated README with latest ABOUT.md, INSTALL.md, CONTRIBUTING.md and badges
- Added spell check workflow
- Updated CI configuration
- Added automatic Julia formatter pull requests
- Updated Breakage.yml to handle more pull request types
