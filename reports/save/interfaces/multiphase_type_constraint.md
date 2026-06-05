# MultiPhase — homogeneous-type constraint on phases

## Summary

The flow concatenation operator `*` fails as soon as the two flows wrap different
functions — including syntactically near-identical lambdas. This makes the multi-phase
feature unusable for its natural use case: concatenating phases with different dynamics.

---

## Minimal reproduction

```julia
using CTFlows
using CTFlows.Data, CTFlows.Flows, CTFlows.MultiPhase
import OrdinaryDiffEqTsit5

# Two different dynamics — the natural use case
flow1 = Flows.Flow(Data.VectorField(x -> -x))
flow2 = Flows.Flow(Data.VectorField(x -> -2 .* x))

flow1 * (1.0, flow2)   # ← MethodError
```

Error:

```
MethodError: no method matching MultiPhaseStateFlow(
    ::Vector{StateFlow{Autonomous, Fixed, S, SciML{...}} where S},
    ::Vector{Real},
    ::Vector{Any}
)
```

Even the associative chain fails:

```julia
flow3 = Flows.Flow(Data.VectorField(x -> -3 .* x))
flow1 * (0.5, flow2) * (1.0, flow3)   # ← MethodError
```

---

## What works

Concatenation only succeeds when both flows have **exactly the same concrete type** `S`
— i.e. when they wrap the same function reference.

```julia
# ✓  Same lambda (same function reference)
f(x) = -x
flow_a = Flows.Flow(Data.VectorField(f))
flow_b = Flows.Flow(Data.VectorField(f))   # same typeof(f)
mpf = flow_a * (1.0, flow_b)               # works

# ✓  Parametric flow (same function, different variable per phase)
dyn(x, v) = -v[1] .* x
flow_p = Flows.Flow(Data.VectorField(dyn; is_variable=true))
mpf_v  = flow_p * (1.0, flow_p)            # works

# — but the dynamics differ only via the variable, not via the function itself

# ✗  Different lambdas (distinct types even if syntactically close)
Flows.Flow(Data.VectorField(x -> -x)) * (1.0, Flows.Flow(Data.VectorField(x -> -2x)))
```

---

## Root cause

### The struct

```julia
# src/MultiPhase/multiphase_flow.jl

struct MultiPhaseStateFlow{
        TD <: TimeDependence,
        VD <: VariableDependence,
        S  <: AbstractStateSystem{TD, VD},   # ← single concrete parameter
        I  <: AbstractIntegrator,             # ← single concrete parameter
        ST <: Vector{<:Real},
        J  <: Vector{<:Any}
} <: AbstractStateFlow{TD, VD, S}
    flows :: Vector{StateFlow{TD, VD, S, I}}  # ← homogeneous vector
    switching_times :: ST
    jumps :: J
end
```

The `flows` field is a `Vector` whose type parameter `S` is fixed once for **all**
phases. This requires every flow to share the same concrete system type.

### The propagation chain

For a plain `StateFlow`, `get_flows` returns `[f]`:

```julia
# src/MultiPhase/multiphase_flow.jl
function get_flows(f::AbstractFlow)
    return [f]          # Vector{typeof(f)} — concrete type
end
```

On `flow1 * (t, flow2)`, the operator body is:

```julia
# src/MultiPhase/concatenation.jl
function Base.:*(f1::AbstractStateFlow, (t_switch, f2)::Tuple{Real, AbstractStateFlow})
    flows   = vcat(get_flows(f1), get_flows(f2))   # ← the problem
    switches = vcat(get_switching_times(f1), [t_switch], get_switching_times(f2))
    jumps   = vcat(get_jumps(f1), [nothing], get_jumps(f2))
    return MultiPhaseStateFlow(flows, switches, jumps)
end
```

If `flow1 :: StateFlow{TD, VD, S1, I}` and `flow2 :: StateFlow{TD, VD, S2, I}` with
`S1 ≠ S2`, then:

```julia
vcat([flow1], [flow2])
# → Vector{StateFlow{TD, VD, S, I} where S}   (abstract/union element type)
```

Julia infers the most general element type covering both, giving an abstract-element
vector (`where S`). The `MultiPhaseStateFlow` constructor cannot deduce a concrete `S`
from it, hence the `MethodError`.

### Why do two lambdas have different types?

In Julia, each lambda (anonymous function) creates a new singleton type at definition:

```julia
f1 = x -> -x
f2 = x -> -2 .* x

typeof(f1)   # var"#1#2"  — unique type
typeof(f2)   # var"#3#4"  — distinct type

# Same syntax, different types because two distinct objects:
g1 = x -> -x
g2 = x -> -x
typeof(g1) == typeof(g2)   # false
```

So `VectorField{typeof(f1), ...}` ≠ `VectorField{typeof(f2), ...}`, and therefore the
systems `VectorFieldSystem{VectorField{typeof(f1),...}}` and
`VectorFieldSystem{VectorField{typeof(f2),...}}` are distinct types — even if both
functions compute `x -> -x`.

---

## What this prevents

### Case 1 — Phases with different dynamics (the most common)

Example: a mechanical system with two regimes, or a bang-bang arc problem.

```julia
# Phase 1: free dynamics
drift1(x) = [x[2], -x[1]]
# Phase 2: dynamics with friction
drift2(x) = [x[2], -x[1] - 0.5 * x[2]]

flow1 = Flows.Flow(Data.VectorField(drift1))
flow2 = Flows.Flow(Data.VectorField(drift2))

flow1 * (1.0, flow2)   # ← MethodError  —  does not work
```

### Case 2 — Optimal switching problem (bang-bang)

```julia
# Control u ∈ {-1, +1}, switching at t = 1.0
f_plus(x)  = [x[2],  1.0 - x[1]]   # u = +1
f_minus(x) = [x[2], -1.0 - x[1]]   # u = -1

flow_plus  = Flows.Flow(Data.VectorField(f_plus))
flow_minus = Flows.Flow(Data.VectorField(f_minus))

flow_plus * (1.0, flow_minus)   # ← MethodError
```

### Case 3 — Different Hamiltonians per phase

```julia
using LinearAlgebra

h1 = Data.Hamiltonian((x, p) -> 0.5 * (dot(x, x) + dot(p, p)))     # phase 1
h2 = Data.Hamiltonian((x, p) -> 0.5 * dot(p, p) + cos(x[1]))         # phase 2

import DifferentiationInterface, ForwardDiff
hflow1 = Flows.Flow(h1)
hflow2 = Flows.Flow(h2)

hflow1 * (1.0, hflow2)   # ← MethodError
```

### Case 4 — Chaining multiple arcs

```julia
# Three-arc trajectory: free / controlled / free
arc_free    = Flows.Flow(Data.VectorField(x -> [x[2], -x[1]]))
arc_control = Flows.Flow(Data.VectorField(x -> [x[2], -x[1] + 1.0]))

mpf = arc_free * (0.5, arc_control) * (1.5, arc_free)   # ← MethodError
# (even reusing arc_free, the intermediate vcat produces an abstract type)
```

---

## Fix directions

The problem stems from storing the phases in a homogeneous `Vector` with a single type
parameter `S`. Two approaches lift it:

### Option A — Abstract vector (simple, light dispatch cost)

```julia
struct MultiPhaseStateFlow{TD, VD, ST<:Vector{<:Real}, J<:Vector{<:Any}}
        <: AbstractFlow{TD, VD}
    flows           :: Vector{<:AbstractStateFlow{TD, VD}}   # ← abstract
    switching_times :: ST
    jumps           :: J
end
```

- ✓ Fixes the problem immediately
- ✓ No user-facing change
- ✗ Loses type stability on `flows[i]` (dynamic dispatch in the loop)

### Option B — Typed tuple (type-stable, zero dynamic dispatch)

```julia
struct MultiPhaseStateFlow{TD, VD, F<:Tuple, ST<:Vector{<:Real}, J<:Vector{<:Any}}
        <: AbstractFlow{TD, VD}
    flows           :: F   # NTuple or heterogeneous Tuple
    switching_times :: ST
    jumps           :: J
end
```

The integration loop uses `@generated` or `ntuple`/`Base.Cartesian` to stay
type-stable:

```julia
function _evaluate_multiphase(mpf, config; variable, unsafe)
    _loop(mpf.flows, ...)   # specialized by the compiler on the tuple type
end
```

- ✓ Fixes the problem
- ✓ Type-stable — the compiler specializes the loop per phase combination
- ✗ Longer compile time for long tuples (> 5-6 phases)
- ✗ `*` must build the tuple (trivial with `(flows..., new_flow)`)

### Option C — Immediate user workaround (no code change)

Wrap the differing dynamics in a **single parametric function**:

```julia
function dyn_switched(x, v)
    phase = round(Int, v[1])
    if phase == 1
        return [x[2], -x[1]]
    else
        return [x[2], -x[1] - 0.5 * x[2]]
    end
end

flow_param = Flows.Flow(Data.VectorField(dyn_switched; is_variable=true))

# Same S and I types, different variable at integration time:
mpf = flow_param * (1.0, flow_param)

# Calling with a different variable per phase — not directly supported today
# (would need a `variables=[v1, v2]` kwarg at call time)
```

This approach is limited: it requires knowing the phases at function-definition time and
does not pass per-phase variables at call time.

---

## Recommendation

**Option B** (tuple of flows) is the cleanest architecturally: type-stable, extensible,
and matching the multi-phase semantics (a fixed number of phases, known at
construction). It aligns CTFlows with the pattern used e.g. in `DiffEqCallbacks.jl` for
heterogeneous callbacks.

The impact on user syntax is nil — `*` and the accessors stay identical. Only `*` must
be changed to build a tuple instead of a vector, and the integration loop in
`calling.jl` must be adapted.

Moving to a tuple raises a design question: **what should be allowed or forbidden as a
concatenation?** That is the subject of the next section.

---

## Compatibility model for concatenation

### Inventory of flow types

```text
AbstractFlow{TD, VD}
├── AbstractStateFlow{TD, VD, S<:AbstractStateSystem{TD,VD}}
│   ├── StateFlow{TD, VD, S, I}                    # carried: x ∈ ℝⁿ
│   └── MultiPhaseStateFlow{…}                     # (to rework)
└── AbstractHamiltonianFlow{TD, VD, S<:AbstractHamiltonianSystem{TD,VD,AT}}
    ├── HamiltonianFlow{TD, VD, S, I}              # carried: (x, p) ∈ ℝⁿ × ℝⁿ
    └── MultiPhaseHamiltonianFlow{…}              # (to rework)
```

Underlying systems:

| System | Family | Built from |
|---|---|---|
| `VectorFieldSystem` | `AbstractStateSystem` | `VectorField` |
| `HamiltonianVectorFieldSystem` | `AbstractHamiltonianSystem` | `HamiltonianVectorField` (derivatives provided) |
| `HamiltonianSystem` | `AbstractHamiltonianSystem` | `Hamiltonian` (derivatives by AD) |

### The guiding principle

Concatenation is **sequential integration**: the output of phase *i* becomes the input
of phase *i+1*. The only thing that must be compatible at the boundary is therefore the
**nature of the carried object** — not the dynamics that evolve it.

> **Rule.** Two flows are concatenable iff they carry the same kind of object
> (state-only `x`, or state+costate `(x, p)`) and expose the same variable contract.
> The dynamics, the integrator, the solver options and the AD backend may differ freely
> per phase. *Dimensional* consistency at the boundary is the user's responsibility,
> mediated by the optional jump, and is checked at integration time, not at construction.

### What must / must not match

| Aspect | Match | Rationale |
|---|---|---|
| **Carried nature** (state `x` vs Hamiltonian `(x,p)`) | **REQUIRED** | A state flow carries `x`, a Hamiltonian flow carries `(x,p)`: the handoff is undefined between them. |
| **Variable dependence** (`Fixed`/`NonFixed`) | **REQUIRED** (v1) | Determines the call signature `(… ; variable)` and the variable is threaded to all phases. |
| **Time dependence** (`Autonomous`/`NonAutonomous`) | uniform in v1, relaxable | Each phase receives `(t_start, t_end)`; an autonomous phase ignores `t`. Relaxable by promoting to `NonAutonomous`. |
| **Dynamics / system `S`** | **FREE** | This is the whole point of multi-phase. |
| **Integrator `I` + options** | **FREE** | Each phase may have its own solver / tolerances. |
| **AD backend** (Hamiltonian) | **FREE** | Per-phase derivative computation is independent. |
| **State dimension `n`** | not encodable | Vector fields are opaque functions; a jump may even remap dimensions. → runtime check. |

The key observation: **the required distinction (state vs Hamiltonian) is already
expressed by dispatch on `AbstractStateFlow` / `AbstractHamiltonianFlow`.** No `*`
method mixes the two families — so it is already forbidden, but with an opaque
`MethodError`. The fix is to **(a)** relax the *storage* (tuple) and **(b)** make the
prohibition explicit with a good message.

!!! note "Exception choice (see [traits_vs_abstract_types.md](traits_vs_abstract_types.md))"

    All errors in this report are **relational**: each flow is valid individually; it is
    their *combination* (incompatible families, divergent TD/VD traits, time ordering,
    boundary dimension) that is forbidden. Per CTBase semantics, that is exactly the role
    of **`PreconditionError`** ("arguments may be valid, but the call is forbidden by its
    composition"). `IncorrectArgument` is reserved for the case where *one* argument is
    out of domain (negative tolerance, empty phase tuple). The examples below therefore
    use `PreconditionError` — not `IncorrectArgument`, which moreover has no `reason`
    field (only `got`/`expected`).

### Implementation: the constraint in the field type

The elegance of the tuple solution: the rule "same nature, same TD, same VD, the rest
free" is written **directly** in the field type via a partially-bound `Vararg`.

```julia
# src/MultiPhase/multiphase_flow.jl

struct MultiPhaseStateFlow{
        TD <: Traits.TimeDependence,
        VD <: Traits.VariableDependence,
        FS <: Tuple{Vararg{Flows.AbstractStateFlow{TD, VD}}},   # ← the core
        ST <: AbstractVector{<:Real},
        J  <: AbstractVector,
} <: Flows.AbstractStateFlow{TD, VD, Systems.AbstractStateSystem{TD, VD}}
    flows           :: FS
    switching_times :: ST
    jumps           :: J
end
```

`Tuple{Vararg{AbstractStateFlow{TD, VD}}}` requires **every** phase to be a state flow
sharing those precise `TD`/`VD` — while leaving the 3rd parameter `S` (the system)
**free** per phase. That is exactly the desired constraint, for free, at the type level.

- The supertype `AbstractStateFlow{TD, VD, AbstractStateSystem{TD,VD}}` uses the
  *abstract* system type as a tag (valid since `AbstractStateSystem{TD,VD} <:
  AbstractStateSystem{TD,VD}`). This keeps `MultiPhaseStateFlow <: AbstractStateFlow`, so
  chaining `mpf * (t, flow3)` keeps dispatching correctly.

Outer constructor inferring `TD`/`VD` from the tuple:

```julia
function MultiPhaseStateFlow(
    flows::Tuple{Vararg{Flows.AbstractStateFlow{TD, VD}}},
    switching_times::AbstractVector{<:Real},
    jumps::AbstractVector,
) where {TD, VD}
    return MultiPhaseStateFlow{TD, VD, typeof(flows), typeof(switching_times), typeof(jumps)}(
        flows, switching_times, jumps,
    )
end

# Fallback: clear message if TD/VD differ between phases
function MultiPhaseStateFlow(flows::Tuple{Vararg{Flows.AbstractStateFlow}}, switching_times, jumps)
    throw(Exceptions.PreconditionError(
        "Cannot concatenate state flows with different time/variable dependence";
        reason = "all phases must share the same (TimeDependence, VariableDependence) traits",
        suggestion = "ensure every phase is built with matching `is_autonomous` / `is_variable`",
        context = "multi-phase flow construction",
    ))
end
```

### The `*` operator: tuple instead of `vcat`

```julia
# get_flows now returns a tuple (1-tuple for a single flow)
get_flows(f::Flows.AbstractFlow)   = (f,)
get_flows(mpf::AnyMultiPhaseFlow)  = mpf.flows

function Base.:*(f1::Flows.AbstractStateFlow, (t, f2)::Tuple{Real, Flows.AbstractStateFlow})
    flows    = (get_flows(f1)..., get_flows(f2)...)        # splat → heterogeneous tuple OK
    switches = vcat(get_switching_times(f1), [t], get_switching_times(f2))
    _check_switching_times_order(switches)
    jumps    = vcat(get_jumps(f1), Any[nothing], get_jumps(f2))
    return MultiPhaseStateFlow(flows, switches, jumps)
end
```

### Explicitly forbid mixing state × Hamiltonian

```julia
const _CROSS_MSG = "Cannot concatenate a state flow with a Hamiltonian flow"

function Base.:*(::Flows.AbstractStateFlow, ::Tuple{Real, Flows.AbstractHamiltonianFlow})
    throw(Exceptions.PreconditionError(
        _CROSS_MSG;
        reason = "a state flow carries x; a Hamiltonian flow carries (x, p): the handoff is undefined",
        suggestion = "concatenate flows of the same kind (state↔state, Hamiltonian↔Hamiltonian)",
        context = "multi-phase flow concatenation",
    ))
end

function Base.:*(::Flows.AbstractHamiltonianFlow, ::Tuple{Real, Flows.AbstractStateFlow})
    throw(Exceptions.PreconditionError(_CROSS_MSG; context = "multi-phase flow concatenation"))
end
# (+ 3-tuple and 4-tuple jump variants, delegating to the same message)
```

### State dimension: a runtime contract, not a type

We **cannot** encode `n` in the type (vector fields are opaque `Function`s). Boundary
dimension consistency is therefore a runtime contract, already surfaced naturally: if
phase *i+1* receives a wrong-size vector, its RHS errors. We can make the diagnostic
clearer:

```julia
# src/MultiPhase/calling.jl — handoff between phases
function _handoff(state_in, state_out, phase_from::Int)
    if state_out isa AbstractVector && state_in isa AbstractVector &&
       length(state_out) != length(state_in)
        throw(Exceptions.PreconditionError(
            "State dimension mismatch at phase boundary $phase_from → $(phase_from + 1)";
            reason = "phase $phase_from produced a state of length $(length(state_out)), " *
                     "but phase $(phase_from + 1) expects $(length(state_in))",
            suggestion = "insert a jump g: ℝⁿ → ℝᵐ at this switching time to remap the state",
            context = "multi-phase integration",
        ))
    end
    return state_out
end
```

The **jump** is precisely the escape hatch for a change of dimension or representation:
`g : ℝⁿ → ℝᵐ`. Without a jump (`nothing` = identity), dimensions must line up.

### Edge case: augmented Hamiltonian / variable costate

Augmented integration (transporting `p_v`, the costate associated with the variable
`v`) is selected **at call time** (`variable_costate=true`), not baked into the flow
type. It is therefore orthogonal to concatenation: as long as all phases are compatible
`AbstractHamiltonianFlow`s, the augmentation applies uniformly at the call. If the
augmented carried object `(x, p, p_v)` ever became a distinct *type*, the **dynamics
trait** (`AbstractDynamicsTrait`: `StateDynamics` / `HamiltonianDynamics` /
`AugmentedHamiltonianDynamics` — see the proposed rename in
[traits_vs_abstract_types.md](traits_vs_abstract_types.md)) would be the right tool to
extend the compatibility rule — that is already the mechanism used for `Config`s.

### Synthesis

| Decision | Mechanism |
|---|---|
| State ↔ state, Hamiltonian ↔ Hamiltonian | dispatch on the flow family (already in place) |
| Same TD / VD between phases | `Tuple{Vararg{AbstractStateFlow{TD,VD}}}` (field type) |
| Free dynamics / integrator / AD | 3rd parameter `S` left free in the `Vararg` |
| Forbid state × Hamiltonian | explicit `*` methods raising a readable error |
| State dimension | runtime contract + jump as the escape hatch |

The "just enough" constraint thus emerges from a single idea: **bind `TD`, `VD` and the
family in the `Vararg` field type, and leave everything else free.**
