# Roadmap v2

**Last updated:** May 30, 2026

## Context

The v1 refactoring is complete. CTFlows now has a modular architecture with specialized submodules, a single strategy family (`AbstractIntegrator`), and callable structs replacing most closures. This roadmap focuses on remaining tasks to complete the flow layer for optimal control problems.

---

## Architecture and Refactoring

✅ **Completed**

- Modular structure with submodules: `Common`, `Configs`, `Data`, `Systems`, `Flows`, `Integrators`, `Solutions`, `MultiPhase`, `Traits`, `Differentiation`
- Abstract types: `AbstractFlow`, `AbstractSystem`, `AbstractIntegrator`
- Single strategy family: `AbstractIntegrator <: CTSolvers.Strategies.AbstractStrategy`
- Callable structs for RHS (partial: VectorFieldSystem, HamiltonianVectorFieldSystem, SciMLFunctionSystem done)

---

## API and Accessors

⚠️ **In Progress**

- **Getter for Hamiltonian and HamiltonianVectorField** — Implement unified getter mechanism to extract Hamiltonian and Hamiltonian vector field from different contexts (Hamiltonian data structure, system definition, or flow object). See [reports/notes.md](notes.md).
- **Replace closures with callable structs** — Complete the mechanical replacement of closures with functors for better type stability and debuggability. See [#245](https://github.com/control-toolbox/CTFlows.jl/issues/245).
  - VectorFieldSystem: ✅ completed (5 closures)
  - HamiltonianVectorFieldSystem: ✅ completed (6 closures)
  - SciMLFunctionSystem: ✅ completed (5 closures)
  - HamiltonianSystem: ❌ 3 closures remaining
- **Scalar/vector consistency** — Review `scalarize` usage in solution construction to ensure proper handling of scalar vs vector cases. See [reports/notes.md](notes.md).
- Input validation at flow call — Check that user-provided functions (e.g. the control) define expected methods on intended arguments at the beginning of a flow call.

---

## Flow Construction

⚠️ **Partial**

- ✅ Multi-phase flows (module `MultiPhase/`)
- ✅ Augmented Hamiltonian support (`AugmentedHamiltonianPointConfig`, `build_rhs_augmented`)
- ❌ Complete flow construction features — Closed- and open-loop encapsulation, control-free OCP, DAE support, and generic objects. See [#247](https://github.com/control-toolbox/CTFlows.jl/issues/247).

---

## Outputs

⚠️ **Partial**

- ✅ Costate return (`HamiltonianVectorFieldSolution`)
- ❌ Dual variable return — When available, the flow should return the dual variable. See [#103](https://github.com/control-toolbox/CTFlows.jl/issues/103).
- ❌ Flow derivative handling — Correct handling of the flow derivative. See [#93](https://github.com/control-toolbox/CTFlows.jl/issues/93).

---

## Differential Geometry

❌ **Not Started**

- ❌ Refactor Differential Geometry module — Introduce `ad` operator, fix `Lift` return type, add exception handling in `@Lie`, and reorganize as a proper submodule. See [#248](https://github.com/control-toolbox/CTFlows.jl/issues/248).

---

## Integration and Extensions

⚠️ **Partial**

- ✅ Extensions: `CTFlowsOrdinaryDiffEqTsit5`, `CTFlowsForwardDiff`, `CTFlowsDifferentiationInterface`, `CTFlowsStaticArrays`, `CTFlowsPlots`
- ❌ GPU support — Add GPU support for flows with GPU-compatible integrators, strategy parameters, and comprehensive tests. See [#249](https://github.com/control-toolbox/CTFlows.jl/issues/249).

---

## Ecosystem Integration

❌ **To Do**

- **Move Traits module to CTBase** — Move all trait definitions from `CTFlows.Traits` to `CTBase.Traits` as part of ecosystem-wide trait unification. See [#246](https://github.com/control-toolbox/CTFlows.jl/issues/246).
  - Depends on [CTBase #430](https://github.com/control-toolbox/CTBase.jl/issues/430)
  - Remove `src/Traits/` directory from CTFlows
  - Update all internal references from `CTFlows.Traits.X` to `CTBase.Traits.X`
  - Update tests and documentation

---

## Tests and Documentation

⚠️ **In Progress**

- ✅ Test structure by functionality (`test/suite/`)
- ❌ Documentation following CTBase guides — Revamp documentation following [test runner guide](https://control-toolbox.org/CTBase.jl/stable/guide/test-runner.html) and [API documentation guide](https://control-toolbox.org/CTBase.jl/stable/guide/api-documentation.html).
- ❌ Test revamp — Update tests to follow CTBase guidelines.

---

## Priority Summary

**High priority:**

- [#245](https://github.com/control-toolbox/CTFlows.jl/issues/245) — Complete closure replacement (last 3 closures in HamiltonianSystem)
- [#246](https://github.com/control-toolbox/CTFlows.jl/issues/246) — Traits migration to CTBase (after CTBase #430)

**Medium priority:**

- Getter for Hamiltonian and HamiltonianVectorField
- Scalar/vector consistency
- Input validation

**Lower priority:**

- Differential geometry refactor
- GPU support
- Generic flow objects
