# Integrators

## Overview

The Integrators module provides ODE integrator strategies for CTFlows. Integrators are responsible for the numerical solution of ODE systems, wrapping external ODE solver libraries (primarily the SciML ecosystem) and providing a strategy pattern interface consistent with the CTSolvers framework.

## Key Types

### Abstract Types

- `AbstractIntegrator` - Abstract base type for all integrators, inherits from CTSolvers.Strategies.AbstractStrategy
- `AbstractIntegrationResult` - Abstract type for raw ODE integration results

### Concrete Types

- `SciML{Tag}` - Integrator using SciML ecosystem solvers, parameterized by tag type
- `SciMLTag` - Tag marking SciML-based integrator implementations
- `Tsit5Tag` - Tag for Tsit5 (Tsitouras 5) SciML solver

### Result Types

- `SciMLIntegrationResult{S}` - Wrapper for SciML ODE solution objects

## Traits

Integrators do not have trait type parameters like data, systems, or flows. Instead, they are strategy objects that can be configured via their tag types and options. The trait information (time dependence, variable dependence) is carried by the systems and flows that use the integrators.

## Usage Pattern

The typical usage pattern for integrators:

1. Create an integrator using `build_sciml_integrator` or `build_integrator`
2. The integrator is configured with a tag (e.g., Tsit5Tag) and options
3. The integrator is combined with a system to create a flow (see [flows.md](flows.md))
4. When the flow is called, the integrator performs the numerical integration
5. The integrator returns an integration result that is wrapped in a solution type

### Building Functions

- `build_sciml_integrator(tag; options...)` - Builds a SciML integrator with specified tag and options
- `build_integrator(tag; options...)` - Generic integrator builder (dispatches based on tag)

### Integration Functions

- `build_problem(system, config)` - Builds an ODE problem from a system and configuration
- `solve_problem(problem, integrator)` - Solves an ODE problem with an integrator
- `merge(result1, result2)` - Merges integration results (used in multi-phase contexts)

### Result Accessors

- `final_state(result)` - Extracts the final state from an integration result
- `times(result)` - Extracts the time points from an integration result
- `evaluate_at(result, t)` - Evaluates the solution at a specific time

Integrators serve as the numerical method layer - they provide the actual ODE solving capability that is called by flows.

## Source Files

- `src/Integrators/abstract_integrator.jl` - Abstract integrator type definition
- `src/Integrators/integration_result.jl` - Integration result types and accessors
- `src/Integrators/sciml.jl` - SciML integrator implementation
- `src/Integrators/building.jl` - Integrator and problem building functions

## Test Files

- `test/suite/integrators/test_abstract_integrator.jl` - Abstract integrator tests
- `test/suite/integrators/test_sciml.jl` - SciML integrator tests
- `test/suite/integrators/test_building.jl` - Integrator building tests

## See Also

- [flows.md](flows.md) - How integrators are combined with systems to create flows
- [solutions.md](solutions.md) - Solution types that wrap integration results
