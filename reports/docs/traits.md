# Traits

## Overview

CTFlows uses a trait system for compile-time dispatch. Traits are empty marker types used as type parameters to encode configuration properties at compile time. Unlike tags (which mark extension implementations), traits encode semantic properties of the configuration itself. All concrete trait types are empty structs with no fields, making them zero-cost at runtime.

The trait pattern enables static dispatch on configuration properties without runtime type checks, providing type stability and performance benefits.

## Key Types

### Abstract Trait Hierarchy

- `AbstractTrait` - Base type for all trait markers
- `AbstractModeTrait` - Base for mode traits (Point vs Trajectory)
- `AbstractContentTrait` - Base for content traits (State vs Hamiltonian)

### Mode Traits

- `PointTrait` - Point integration mode (single endpoint evaluation)
- `TrajectoryTrait` - Trajectory integration mode (full time evolution)

### Content Traits

- `StateTrait` - State content (no costate)
- `HamiltonianTrait` - Hamiltonian content (state + costate)

### Time Dependence (from CTModels.OCP)

- `Autonomous` - Time-independent dynamics
- `NonAutonomous` - Time-dependent dynamics

### Variable Dependence (from CTModels.OCP)

- `Fixed` - Fixed parameters (non-variable)
- `NonFixed` - Variable parameters

### Configuration Types

- `AbstractConfig` - Base configuration type
- `AbstractPointConfig` - Point-mode configuration base
- `AbstractTrajectoryConfig` - Trajectory-mode configuration base
- `StatePointConfig` - State-only point configuration
- `StateTrajectoryConfig` - State-only trajectory configuration
- `HamiltonianPointConfig` - Hamiltonian point configuration
- `HamiltonianTrajectoryConfig` - Hamiltonian trajectory configuration

## Traits

Traits are used as type parameters in abstract configuration types:

- Mode traits (second type parameter): distinguish integration modes
- Content traits (third type parameter): distinguish content types
- Time dependence (in data/systems/flows): encode autonomous vs non-autonomous
- Variable dependence (in data/systems/flows): encode fixed vs non-fixed

## Usage Pattern

Traits are used throughout CTFlows to enable compile-time dispatch:

1. Configuration types use mode and content traits as type parameters to determine storage layout and behavior
2. Data types (vector fields) use time and variable dependence traits to encode dynamics properties
3. System types inherit traits from their underlying data structures
4. Flow types inherit traits from their systems
5. Trait accessors (e.g., `time_dependence`, `variable_dependence`) extract trait values from types

This enables the compiler to generate specialized code for each trait combination without runtime checks.

## Source Files

- `src/Common/abstract_trait.jl` - Abstract trait definitions and concrete trait types
- `src/Common/configs.jl` - Configuration type definitions
- `src/Common/traits.jl` - Trait-related utilities

## Test Files

- `test/suite/common/test_abstract_trait.jl` - Trait type tests
- `test/suite/common/test_configs.jl` - Configuration type tests
- `test/suite/common/test_traits.jl` - Trait accessor tests

## See Also

- [data.md](data.md) - How traits are used in vector field data structures
- [systems.md](systems.md) - How traits propagate to system types
- [flows.md](flows.md) - How traits propagate to flow types
