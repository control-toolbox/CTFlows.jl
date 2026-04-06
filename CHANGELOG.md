# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
