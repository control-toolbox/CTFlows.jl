# Solutions

## Overview

The Solutions module provides solution types and solution building functions for CTFlows. Solutions wrap raw ODE integration results and provide semantic accessors for state, costate, and time data. They also support plotting functionality through the RecipesBase interface.

## Key Types

### Abstract Types

- `AbstractIntegrationResult` - Abstract type for raw ODE integration results (defined in Integrators module)

### Concrete Types

- `VectorFieldSolution{R, C}` - Solution type for state-only systems, wrapping an integration result R with configuration C
- `HamiltonianVectorFieldSolution{R, C}` - Solution type for Hamiltonian systems (state + costate), wrapping an integration result R with configuration C

## Traits

Solution types inherit their trait information from the configuration parameter C. The configuration encodes mode (EndPointMode vs TrajectoryMode) and content (StateTrait vs HamiltonianTrait) traits, which determine what data is stored and how it can be accessed.

## Usage Pattern

The typical usage pattern for solutions:

1. A flow is called to perform integration (see [flows.md](flows.md))
2. The flow returns an integration result (from the Integrators module)
3. The integration result is wrapped in a solution type using `build_solution`
4. Solution accessors provide semantic access to the data:
   - `state(solution)` - Returns the state trajectory or final state
   - `costate(solution)` - Returns the costate trajectory or final costate (Hamiltonian only)
   - `time_grid(solution)` - Returns the time points
5. Solutions can be plotted using the `plot` function (RecipesBase integration)

### Building Functions

- `build_solution(result, config)` - Constructs a solution from an integration result and configuration

### Accessors

For VectorFieldSolution (state-only):
- `state(solution)` - Returns state data (trajectory or point depending on mode)
- `time_grid(solution)` - Returns time grid

For HamiltonianVectorFieldSolution (state + costate):
- `state(solution)` - Returns state data
- `costate(solution)` - Returns costate data
- `time_grid(solution)` - Returns time grid

### Plotting

- `plot(solution)` - Plots the solution using RecipesBase, with automatic handling of state vs Hamiltonian and point vs trajectory modes

Solutions serve as the result layer - they wrap raw integration results in a type-safe, semantically meaningful interface that aligns with the configuration used for integration.

## Source Files

- `src/Solutions/vector_field_solution.jl` - VectorFieldSolution implementation
- `src/Solutions/hamiltonian_vector_field_solution.jl` - HamiltonianVectorFieldSolution implementation
- `src/Solutions/building.jl` - Solution building functions

## Test Files

- `test/suite/solutions/test_vector_field_solution.jl` - VectorFieldSolution tests
- `test/suite/solutions/test_hamiltonian_vector_field_solution.jl` - HamiltonianVectorFieldSolution tests
- `test/suite/solutions/test_building.jl` - Solution building tests

## See Also

- [flows.md](flows.md) - How flows return integration results
- [integrators.md](integrators.md) - Integration result types
- [traits.md](traits.md) - Configuration traits that determine solution structure
