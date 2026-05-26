# Systems

## Overview

The Systems module provides system types and contracts for dynamical systems in CTFlows. Systems represent fully assembled objects that can be integrated, embedding their own right-hand side (rhs) functions, dimensional metadata, and solution-building logic. Systems inherit traits from their underlying data structures (vector fields), enabling compile-time dispatch throughout the integration stack.

## Key Types

### Abstract Types

- `AbstractSystem{TD, VD}` - Abstract base type for all systems with time dependence (TD) and variable dependence (VD) traits
- `AbstractStateSystem{TD, VD}` - Abstract type for state systems (non-Hamiltonian)
- `AbstractHamiltonianSystem{TD, VD}` - Abstract type for Hamiltonian systems (state + costate)

### Concrete Types

- `VectorFieldSystem{VF, TD, VD}` - Concrete system wrapping a VectorField
- `HamiltonianVectorFieldSystem{VF, TD, VD}` - Concrete system wrapping a HamiltonianVectorField

## Traits

Systems inherit their traits from the underlying vector field data structures:

- **Time Dependence (TD)**: `Autonomous` or `NonAutonomous` - inherited from vector field
- **Variable Dependence (VD)**: `Fixed` or `NonFixed` - inherited from vector field

Trait accessors are implemented at the abstract level:
- `time_dependence(sys::AbstractSystem)` - Returns the time dependence trait type
- `variable_dependence(sys::AbstractSystem)` - Returns the variable dependence trait type
- `has_time_dependence_trait(sys::AbstractSystem)` - Always returns true
- `has_variable_dependence_trait(sys::AbstractSystem)` - Always returns true

## Usage Pattern

The typical usage pattern for systems:

1. Create a vector field (see [data.md](data.md))
2. Build a system from the vector field using `build_system`
3. The system inherits traits from the vector field
4. The system provides an `rhs` function for ODE integration
5. Systems are then combined with integrators to create flows (see [flows.md](flows.md))

### Contract Methods

All concrete systems must implement:

- `rhs(system::AbstractSystem)` - Returns a function `(du, u, p, t) -> nothing` that fills `du` in place with the derivative
- `rhs_oop(system::AbstractSystem)` - Returns a function `(u, p, t) -> du` for out-of-place operations (used with immutable arrays like StaticArrays)

### Building Functions

- `build_system(vector_field)` - Constructs a system from a vector field, automatically handling trait inheritance

Systems serve as the integration-ready layer - they encapsulate the dynamics in a form suitable for ODE solvers.

## Source Files

- `src/Systems/abstract_system.jl` - Abstract type definitions and contract methods
- `src/Systems/vector_field_system.jl` - VectorFieldSystem implementation
- `src/Systems/hamiltonian_vector_field_system.jl` - HamiltonianVectorFieldSystem implementation
- `src/Systems/building.jl` - System building functions

## Test Files

- `test/suite/systems/test_abstract_system.jl` - Abstract system tests
- `test/suite/systems/test_vector_field_system.jl` - VectorFieldSystem tests
- `test/suite/systems/test_hamiltonian_vector_field_system.jl` - HamiltonianVectorFieldSystem tests
- `test/suite/systems/test_building.jl` - System building tests

## See Also

- [data.md](data.md) - Vector field data structures used to build systems
- [flows.md](flows.md) - How systems are combined with integrators to create flows
- [traits.md](traits.md) - Trait system overview
