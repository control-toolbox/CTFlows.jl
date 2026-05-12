# Flows

## Overview

The Flows module provides flow types that combine systems with integrators. A flow is a callable object that exposes the integration protocol - it carries no business logic of its own, but serves as the interface for performing ODE integration. Flows inherit traits from their systems, enabling compile-time dispatch throughout the integration process.

## Key Types

### Abstract Types

- `AbstractFlow{TD, VD}` - Abstract base type for all flows with time dependence (TD) and variable dependence (VD) traits
- `AbstractStateFlow{TD, VD, S}` - Abstract type for state flows (non-Hamiltonian), parameterized by system type S
- `AbstractHamiltonianFlow{TD, VD, S}` - Abstract type for Hamiltonian flows (state + costate), parameterized by system type S

### Concrete Types

- `Flow{S, I}` - Concrete flow combining a system S with an integrator I
- `StateFlow{S, I}` - Concrete state flow (alias for Flow with state system)
- `HamiltonianFlow{S, I}` - Concrete Hamiltonian flow (alias for Flow with Hamiltonian system)

## Traits

Flows inherit their traits from the underlying system:

- **Time Dependence (TD)**: `Autonomous` or `NonAutonomous` - inherited from system
- **Variable Dependence (VD)**: `Fixed` or `NonFixed` - inherited from system

Trait accessors are implemented at the abstract level:
- `time_dependence(flow::AbstractFlow)` - Returns the time dependence trait type
- `variable_dependence(flow::AbstractFlow)` - Returns the variable dependence trait type
- `has_time_dependence_trait(flow::AbstractFlow)` - Always returns true
- `has_variable_dependence_trait(flow::AbstractFlow)` - Always returns true

## Usage Pattern

The typical usage pattern for flows:

1. Create a system (see [systems.md](systems.md))
2. Create an integrator (see [integrators.md](integrators.md))
3. Build a flow from the system and integrator using `build_flow`
4. Call the flow to perform integration: `flow(t0, x0, tf)` for state or `flow(t0, x0, p0, tf)` for Hamiltonian
5. The flow returns a solution (see [solutions.md](solutions.md))

### Contract Methods

All concrete flows must implement:

- `system(flow::AbstractFlow)` - Returns the associated AbstractSystem
- `integrator(flow::AbstractFlow)` - Returns the associated AbstractIntegrator

### Callable Interface

Flows are callable objects with the following signatures:

- For state flows: `(flow)(t0, x0, tf)` - Integrates from initial state x0 at time t0 to final time tf
- For Hamiltonian flows: `(flow)(t0, x0, p0, tf)` - Integrates from initial state x0 and costate p0 at time t0 to final time tf

### Building Functions

- `build_flow(system, integrator)` - Constructs a flow from a system and integrator

Flows serve as the integration interface layer - they combine the dynamics (system) with the numerical method (integrator) to provide a callable integration operation.

## Source Files

- `src/Flows/abstract_flow.jl` - Abstract type definitions and contract methods
- `src/Flows/flow.jl` - Concrete Flow implementation
- `src/Flows/building.jl` - Flow building functions
- `src/Flows/calling.jl` - Flow callable interface implementation

## Test Files

- `test/suite/flows/test_abstract_flow.jl` - Abstract flow tests
- `test/suite/flows/test_flow.jl` - Flow tests
- `test/suite/flows/test_building.jl` - Flow building tests
- `test/suite/flows/test_calling.jl` - Flow callable interface tests

## See Also

- [systems.md](systems.md) - System types used in flows
- [integrators.md](integrators.md) - Integrator types used in flows
- [solutions.md](solutions.md) - Solution types returned by flows
- [multiphase.md](multiphase.md) - Multi-phase flow concatenation
