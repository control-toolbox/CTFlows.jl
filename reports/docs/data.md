# Data

## Overview

The Data module provides data structures for vector fields and Hamiltonian vector fields with trait-based encoding of properties. These structures encapsulate vector-field functions together with their time-dependence and variable-dependence traits, enabling compile-time dispatch throughout the CTFlows stack.

## Key Types

### Abstract Types

- `AbstractVectorField{TD, VD}` - Abstract base type for all vector fields with type parameters for time dependence (TD) and variable dependence (VD)

### Concrete Types

- `VectorField{F, TD, VD}` - Standard vector field wrapping a function `f(u, p, t)` or `f(u, p)` depending on time dependence
- `HamiltonianVectorField{F, TD, VD}` - Hamiltonian vector field wrapping a function that returns state and costate derivatives

## Traits

Vector fields use two trait type parameters:

- **Time Dependence (TD)**: `Autonomous` or `NonAutonomous`
  - Encodes whether the vector field depends explicitly on time
  - Affects function signature (time parameter presence)

- **Variable Dependence (VD)**: `Fixed` or `NonFixed`
  - Encodes whether parameters are fixed or variable
  - Used for optimization and sensitivity analysis contexts

Trait accessors are implemented at the abstract level:
- `time_dependence(vf::AbstractVectorField)` - Returns the time dependence trait type
- `variable_dependence(vf::AbstractVectorField)` - Returns the variable dependence trait type
- `has_time_dependence_trait(vf::AbstractVectorField)` - Always returns true
- `has_variable_dependence_trait(vf::AbstractVectorField)` - Always returns true

## Usage Pattern

The typical usage pattern for data structures:

1. Define a vector field function with appropriate signature
2. Create a `VectorField` or `HamiltonianVectorField` wrapping the function
3. Specify time and variable dependence via keyword arguments or constructor parameters
4. The traits are encoded in the type parameters for compile-time dispatch
5. Vector fields are then used to build systems (see [systems.md](systems.md))

Vector fields serve as the foundational data layer - they encode the dynamics with trait information that propagates through systems, flows, and solutions.

## Source Files

- `src/Data/abstract_vector_field.jl` - Abstract type definition and trait accessors
- `src/Data/vector_field.jl` - Concrete VectorField implementation
- `src/Data/hamiltonian_vector_field.jl` - Concrete HamiltonianVectorField implementation

## Test Files

- `test/suite/data/test_abstract_vector_field.jl` - Abstract vector field tests
- `test/suite/data/test_vector_field.jl` - VectorField tests
- `test/suite/data/test_hamiltonian_vector_field.jl` - HamiltonianVectorField tests

## See Also

- [traits.md](traits.md) - Trait system overview
- [systems.md](systems.md) - How vector fields are used to build systems
