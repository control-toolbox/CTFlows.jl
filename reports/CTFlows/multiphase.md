# MultiPhase

## Overview

The MultiPhase module provides multi-phase flow concatenation and sequential integration. It enables combining multiple flows with switching times and optional jumps to solve problems where the dynamics change at discrete time points (e.g., control switches, phase transitions). The module implements exact sequential integration, ensuring continuity or specified jumps at phase boundaries.

## Key Types

### Concrete Types

- `MultiPhaseStateFlow{TD, VD, N}` - Multi-phase flow for state systems, parameterized by time dependence (TD), variable dependence (VD), and number of phases (N)
- `MultiPhaseHamiltonianFlow{TD, VD, N}` - Multi-phase flow for Hamiltonian systems (state + costate), parameterized by time dependence (TD), variable dependence (VD), and number of phases (N)

## Traits

Multi-phase flows inherit traits from their constituent flows:

- **Time Dependence (TD)**: `Autonomous` or `NonAutonomous` - inherited from the flows
- **Variable Dependence (VD)**: `Fixed` or `NonFixed` - inherited from the flows

All flows in a multi-phase sequence must have compatible traits (same time and variable dependence).

## Usage Pattern

The typical usage pattern for multi-phase flows:

1. Create individual flows for each phase (see [flows.md](flows.md))
2. Specify switching times between phases
3. Optionally specify jump functions at phase boundaries
4. Concatenate flows using the `*` operator
5. Call the multi-phase flow to perform sequential integration
6. Access individual phases, switching times, and jumps using accessor functions

### Concatenation Operators

- `flow1 * flow2` - Concatenates two flows (infix operator)

Note: only the `*` operator is implemented for concatenation in CTFlows. The `∘` operator is not defined.

### Accessors

- `n_phases(multi_flow)` - Returns the number of phases
- `get_flow(multi_flow, i)` - Returns the i-th flow in the sequence
- `get_switching_time(multi_flow, i)` - Returns the switching time before phase i
- `get_jump(multi_flow, i)` - Returns the jump function at phase boundary i (if any)
- `get_flows(multi_flow)` - Returns all flows as a tuple
- `get_switching_times(multi_flow)` - Returns all switching times as a tuple
- `get_jumps(multi_flow)` - Returns all jump functions as a tuple

## Algebraic Structure and Associativity

### Left Action (partial) of Phase Insertions on Flows

Let F be the set of flows (including already concatenated multi-phase flows). Let E be the set of phase insertions of the form e = (t, g), (t, j, g) for state flows, or (t, jx, jp, g) for Hamiltonian flows, where t ∈ ℝ is a switching time, g is a flow, and j, jx, jp are jump functions.

Define a partial left action

- f ⋆ e := f * e, with domain restricted by strictly increasing switching times.

If f already contains switching times (t₁ < ⋯ < t_k), then f ⋆ (t, …) is defined only when t > t_k. This is enforced in code by `_check_switching_times_order`; violations raise a `PreconditionError`.

Under this precondition, successive insertions are associative on the left: for e₁ = (t₁, g) and e₂ = (t₂, h) with t₁ < t₂ and both defined for f,

- (f ⋆ e₁) ⋆ e₂ = f ⋆ e₁ ⋆ e₂,

and both sides yield the same multi-phase flow with phases of f, then g at t₁, then h at t₂. Internally, concatenation constructs new flows by concatenating (vcat) the lists of flows, switching-times, and jumps; this operation is associative.

Note that an expression like f ⋆ (e₁ ⋆ e₂) is not meaningful here: E elements are not flows, and there is no binary operation defined on E in this design. Composition is achieved by repeated application of the left action.

### Not a Group Action

This structure is not a group action: E has no inverses and the action is partial due to the time-order precondition. One can view CTFlows as implementing a partial left action of the free monoid of well-formed insertion sequences (monotone times) on flows.

### Why not a Right Action or Non-Associative Variant?

One could imagine a right action semantics where adding (t₂, h) after F = f * (t₁, g) would allow t₂ < t₁ and defer routing to evaluation time (e.g., running f up to t₂, then h, etc.). CTFlows deliberately does not implement this:

- Strictly increasing switching times establish a canonical, evaluation-independent partition of the time axis.
- This simplifies evaluation/merging and error handling, and avoids time-query–dependent routing.
- The left-insertion operation remains associative under the monotonicity precondition.

Hence, in CTFlows it is valid to build G = (f * (t₁, g)) * (t₂, h) only when t₂ > t₁. Allowing t₂ < t₁ would require different semantics (non-associative right action or time-dependent dispatch) that CTFlows rejects by design.

### Calling Interface

Multi-phase flows are callable with the same signatures as single-phase flows:

- For state flows: `(multi_flow)(t0, x0, tf)` - Sequentially integrates through all phases
- For Hamiltonian flows: `(multi_flow)(t0, x0, p0, tf)` - Sequentially integrates through all phases

### Sequential Integration

When a multi-phase flow is called:

1. Integration starts at t0 with initial condition
2. Each phase is integrated up to its switching time
3. At each switching time, the jump function (if provided) is applied to the state
4. The result becomes the initial condition for the next phase
5. Process continues until final time tf
6. Results from all phases are merged into a single solution

Multi-phase flows serve as the composition layer - they enable complex multi-stage problems to be expressed as sequences of simpler flows with exact handling of phase transitions.

## Source Files

- `src/MultiPhase/multiphase_flow.jl` - Multi-phase flow type definitions
- `src/MultiPhase/concatenation.jl` - Concatenation operators and building functions
- `src/MultiPhase/calling.jl` - Multi-phase flow callable interface

## Test Files

- `test/suite/multiphase/test_multiphase_flow.jl` - Multi-phase flow tests
- `test/suite/multiphase/test_concatenation.jl` - Concatenation tests
- `test/suite/multiphase/test_calling.jl` - Multi-phase calling tests

## See Also

- [flows.md](flows.md) - Single-phase flow types
- [systems.md](systems.md) - System types used in flows
- [solutions.md](solutions.md) - Solution types returned by multi-phase flows
