# CTFlows Internal Documentation

This directory contains internal documentation notes for CTFlows, providing a conceptual overview of the package's capabilities. These notes serve as a foundation for future official documentation.

## What is CTFlows?

CTFlows is a Julia package for flow-based integration and optimal control. It provides a modular architecture for building and integrating dynamical systems using flow-based approaches. The package is organized into specialized submodules, with all public symbols accessed via qualified paths (e.g., `CTFlows.Systems.AbstractSystem`).

## Module Architecture

CTFlows is organized into the following submodules (in dependency order):

```
Common
  ├── Data
  ├── Systems
  ├── Integrators
  ├── Solutions
  ├── Flows
  └── MultiPhase
```

### Common
Shared utilities and types, including the trait system (mode traits, content traits, time dependence, variable dependence) and configuration types.

### Data
Data structures for vector fields and Hamiltonian vector fields with trait-based encoding of properties.

### Systems
System types and contracts for dynamical systems, including state systems and Hamiltonian systems.

### Integrators
ODE integrator strategies, integrating with the CTSolvers strategy pattern and SciML ecosystem.

### Solutions
Solution types and solution building functions for integration results.

### Flows
Flow types that combine systems with integrators, providing callable interfaces for integration.

### MultiPhase
Multi-phase flow concatenation and sequential integration with switching times and jumps.

## Concept Documentation

The following documents provide detailed conceptual overviews of each major theme:

- [traits.md](traits.md) - Trait system for compile-time dispatch
- [data.md](data.md) - Vector field data structures
- [systems.md](systems.md) - System types and contracts
- [flows.md](flows.md) - Flow types (system + integrator)
- [integrators.md](integrators.md) - ODE integrator strategies
- [solutions.md](solutions.md) - Solution types and accessors
- [multiphase.md](multiphase.md) - Multi-phase concatenation

## Key Concepts

### Traits
CTFlows uses a trait system for compile-time dispatch. Traits are empty marker types used as type parameters to encode configuration properties:
- **Mode traits**: EndPointMode (point-to-point integration) vs TrajectoryMode (full trajectory)
- **Content traits**: StateTrait (state only) vs HamiltonianTrait (state + costate)
- **Time dependence**: Autonomous vs NonAutonomous
- **Variable dependence**: Fixed vs NonFixed

### Data Flow
The typical workflow in CTFlows follows this pattern:

1. Define a vector field (Data module) with appropriate traits
2. Build a system from the vector field (Systems module)
3. Create an integrator (Integrators module)
4. Build a flow combining system and integrator (Flows module)
5. Call the flow to integrate and obtain a solution (Solutions module)
6. Optionally concatenate multiple flows for multi-phase problems (MultiPhase module)

### Trait Inheritance
Traits propagate through the type hierarchy:
- Vector fields have time and variable dependence traits
- Systems inherit traits from their underlying vector fields
- Flows inherit traits from their systems
- This enables compile-time dispatch throughout the stack

## Source Files

- Main module: `src/CTFlows.jl`
- Common: `src/Common/`
- Data: `src/Data/`
- Systems: `src/Systems/`
- Integrators: `src/Integrators/`
- Solutions: `src/Solutions/`
- Flows: `src/Flows/`
- MultiPhase: `src/MultiPhase/`

## Test Files

Test examples demonstrating usage can be found in:
- `test/suite/common/`
- `test/suite/data/`
- `test/suite/systems/`
- `test/suite/integrators/`
- `test/suite/solutions/`
- `test/suite/flows/`
- `test/suite/multiphase/`
