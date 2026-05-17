# CTFlowsSciMLBase Extension — Implementation Plan

## Context

CTFlows.jl currently supports flow construction from `VectorField` and
`HamiltonianVectorField` (CTFlows native types). Users working directly with the
SciML ecosystem — using `SciMLBase.AbstractODEFunction` or
`SciMLBase.AbstractODEProblem` — have no direct entry point into the CTFlows
integration pipeline.

The existing extension `CTFlowsSciML = ["DiffEqBase", "SciMLBase"]` handles the
SciML backend (ODE solving, segment merging, `real_norm`). It requires **both**
`DiffEqBase` and `SciMLBase` and must not be modified for this feature.

This plan introduces a new, lighter extension `CTFlowsSciMLBase = ["SciMLBase"]`
that depends **only on `SciMLBase`** and provides:

1. `SciMLFunctionSystem` — wraps a `SciMLBase.AbstractODEFunction` as a CTFlows system.
2. `SciMLProblemFlow` — wraps a `SciMLBase.AbstractODEProblem` as a CTFlows flow.
3. `Flow(f::AbstractODEFunction; ...)` — high-level constructor.
4. `Flow(prob::AbstractODEProblem; ...)` — high-level constructor.

## Design Decisions

### Trait assignment for SciML types

`AbstractODEFunction{iip}` encodes mutability in its type parameter:
- `iip = true` → in-place `f!(du, u, p, t)` → maps to `InPlace`
- `iip = false` → out-of-place `f(u, p, t)` → maps to `OutOfPlace`

Both `SciMLFunctionSystem` and `SciMLProblemFlow` use `NonAutonomous, NonFixed`
as their TD/VD traits — the most general case, since SciML functions always
accept `(u, p, t)` or `(du, u, p, t)` and `p` is user-controlled.

### `p` is passed as `variable` directly, without `ODEParameters`

The CTFlows-native systems use `ODEParameters(variable, cache)` to thread the
variable through the ODE. SciML-native systems bypass this: `p = variable`
directly, so users can pass arbitrary SciML parameter objects. This requires a
dedicated `build_problem` overload for `SciMLFunctionSystem`.

### `SciMLProblemFlow` does not wrap an `AbstractSystem`

A `SciMLBase.AbstractODEProblem` is already fully assembled (u0, tspan, p
baked in). There is no `AbstractSystem` to extract. `SciMLProblemFlow` inherits
directly from `AbstractFlow{NonAutonomous, NonFixed}` and exposes two call modes:
- **No-arg call** `f()` — solve the problem as-is.
- **Remake call** `f(t0, x0, tf; variable)` — call `SciMLBase.remake` first.

### Separation from `CTFlowsSciML`

`CTFlowsSciML` defines `solve_problem` for `SciMLBase.AbstractODEProblem`
generically. To avoid ambiguity when both extensions are loaded, the
`SciMLBaseIntegrationResult` type is defined here and `solve_problem` in
`CTFlowsSciMLBase` dispatches on it, while `CTFlowsSciML` dispatches on
`SciMLIntegrationResult`. The dispatch tree is disjoint.

### `system(f::SciMLProblemFlow)` contract

`AbstractFlow` requires `system` and `integrator`. For `SciMLProblemFlow`,
`system` returns `nothing` (there is no CTFlows system), and `integrator` returns
the integrator. The `Base.show` method handles this gracefully.

---

## Dependency Graph

```
Common  (NonAutonomous, NonFixed, AbstractConfig, __unsafe)
    ↓
Systems  (AbstractStateSystem)
    ↓
Integrators  (AbstractIntegrator, SciML, build_integrator,
              AbstractIntegrationResult, build_problem, solve_problem)
    ↓
Flows  (AbstractFlow, AbstractStateFlow, build_flow, StateFlow)
    ↓
ext/CTFlowsSciMLBase  (SciMLFunctionSystem, SciMLProblemFlow,
                       SciMLBaseIntegrationResult, Flow overloads)
```

---

## Phase 1 — Project Configuration

### Step 1 — `Project.toml` (modified)

Add `CTFlowsSciMLBase` as a new weak dependency extension triggered by
`SciMLBase` alone:

```toml
[extensions]
CTFlowsForwardDiff         = ["ForwardDiff"]
CTFlowsOrdinaryDiffEqTsit5 = ["OrdinaryDiffEqTsit5"]
CTFlowsPlots               = ["Plots"]
CTFlowsSciML               = ["DiffEqBase", "SciMLBase"]
CTFlowsSciMLBase           = ["SciMLBase"]               # new
CTFlowsStaticArrays        = ["StaticArrays"]
```

`SciMLBase` is already in `[weakdeps]` — no new dependency to declare.

### Step 2 — Test Checkpoint: extension loading

- `@testset "Unit: CTFlowsSciMLBase loads without DiffEqBase"` — load only
  `SciMLBase` and verify the extension activates.
- `@testset "Unit: CTFlowsSciML still loads with DiffEqBase + SciMLBase"` —
  verify no conflict with the existing extension.

---

## Phase 2 — `SciMLFunctionSystem`

### Step 3 — `ext/CTFlowsSciMLBase.jl` (new file) — skeleton

```julia
module CTFlowsSciMLBase

import DocStringExtensions: TYPEDEF, TYPEDSIGNATURES
import CTBase.Exceptions
using CTFlows: CTFlows
using CTFlows.Common: Common
using CTFlows.Systems: Systems
using CTFlows.Integrators: Integrators, SciML
using CTFlows.Flows: Flows, AbstractFlow, AbstractStateFlow, build_flow
using CTFlows.Solutions: Solutions
using SciMLBase: SciMLBase

# ... (filled in subsequent steps)

end # module CTFlowsSciMLBase
```

### Step 4 — `SciMLFunctionSystem` struct and accessors

Define the system type. TD and VD are fixed at `NonAutonomous, NonFixed` because
SciML functions always receive `(u, p, t)` and `p` is arbitrary.

```julia
"""
$(TYPEDEF)

Concrete `AbstractStateSystem` wrapping a `SciMLBase.AbstractODEFunction`.

Unlike CTFlows-native systems (`VectorFieldSystem`), this system passes `p = variable`
directly to the ODE — no `ODEParameters` wrapper — so users can pass arbitrary
SciML parameter objects.

The mutability trait is encoded in the `iip` type parameter of the wrapped function:
- `AbstractODEFunction{true}` → in-place `f!(du, u, p, t)`
- `AbstractODEFunction{false}` → out-of-place `f(u, p, t) -> du`

# Type Parameters
- `F <: SciMLBase.AbstractODEFunction`: The wrapped ODE function.

# Fields
- `f::F`: The wrapped SciML ODE function.
"""
struct SciMLFunctionSystem{
    F <: SciMLBase.AbstractODEFunction
} <: Systems.AbstractStateSystem{Common.NonAutonomous, Common.NonFixed}
    f::F
end
```

Add `rhs` and `rhs_oop` dispatching on `iip`:

```julia
# In-place: rhs returns f directly (already has (du, u, p, t) signature)
Systems.rhs(sys::SciMLFunctionSystem{<:SciMLBase.AbstractODEFunction{true}}) = sys.f

# Out-of-place: rhs_oop returns f directly (already has (u, p, t) -> du signature)
# Bool argument accepted for API uniformity, ignored
Systems.rhs_oop(
    sys::SciMLFunctionSystem{<:SciMLBase.AbstractODEFunction{false}},
    ::Bool = true,
) = sys.f
```

### Step 5 — `build_problem` overload for `SciMLFunctionSystem`

Bypasses `ODEParameters`: passes `variable` directly as `p`.

```julia
function Integrators.build_problem(
    integ::SciML,
    sys::SciMLFunctionSystem,
    config::Common.AbstractConfig;
    variable,
)
    u0   = Common.initial_condition(config)
    tspan = Common.tspan(config)
    if ismutable(u0)
        prob = SciMLBase.ODEProblem{true}(sys.f, u0, tspan, variable)
    else
        prob = SciMLBase.ODEProblem{false}(sys.f, u0, tspan, variable)
    end
    return prob
end
```

### Step 6 — `SciMLBaseIntegrationResult`

A minimal integration result type that does not depend on `DiffEqBase`, keeping
this extension independent of the heavier `CTFlowsSciML`.

```julia
"""
$(TYPEDEF)

Integration result wrapping a `SciMLBase.AbstractODESolution`.

Defined in `CTFlowsSciMLBase` (depends only on `SciMLBase`, not `DiffEqBase`),
parallel to `SciMLIntegrationResult` in `CTFlowsSciML`.
"""
struct SciMLBaseIntegrationResult{
    S <: SciMLBase.AbstractODESolution
} <: Integrators.AbstractIntegrationResult
    ode_sol::S
end

Integrators.final_state(r::SciMLBaseIntegrationResult)        = last(r.ode_sol.u)
Integrators.times(r::SciMLBaseIntegrationResult)              = r.ode_sol.t
Integrators.evaluate_at(r::SciMLBaseIntegrationResult, t)     = r.ode_sol(t)
```

### Step 7 — `solve_problem` for `SciMLFunctionSystem` path

Dispatches on `SciMLBaseIntegrationResult` to stay disjoint from `CTFlowsSciML`:

```julia
function Integrators.solve_problem(
    integ::SciML,
    prob::SciMLBase.AbstractODEProblem,
    options::Dict{Symbol, <:Any};
    unsafe = Common.__unsafe(),
)
    sol = SciMLBase.solve(prob; options...)
    _check_retcode(sol, unsafe)
    return SciMLBaseIntegrationResult(sol)
end
```

### Step 8 — `Base.show` for `SciMLFunctionSystem`

```julia
function Base.show(io::IO, sys::SciMLFunctionSystem{F}) where F
    iip = SciMLBase.isinplace(sys.f)
    mut = iip ? "in-place" : "out-of-place"
    println(io, "SciMLFunctionSystem")
    print(io, "  wraps: ODEFunction: non-autonomous, variable, ", mut)
end

function Base.show(io::IO, ::MIME"text/plain", sys::SciMLFunctionSystem)
    show(io, sys)
end
```

### Step 9 — Test Checkpoint: `SciMLFunctionSystem`

File: `test/suite/extensions/test_scimlbase_function_system.jl`

- `@testset "Unit: SciMLFunctionSystem from iip ODEFunction"` — struct construction,
  `Systems.rhs` returns the function directly
- `@testset "Unit: SciMLFunctionSystem from oop ODEFunction"` — struct construction,
  `Systems.rhs_oop` returns the function directly
- `@testset "Unit: ad_trait is WithoutAD"` — verify trait
- `@testset "Unit: build_problem passes variable as p directly"` — inspect `prob.p`
- `@testset "Unit: Base.show"` — smoke test on display
- `@testset "Integration: StateFlow from SciMLFunctionSystem"` — build_flow, call
  with `variable=2.0`, verify `prob.p == 2.0` during integration
- `@testset "Integration: iip vs oop give same result"` — numerical equivalence

---

## Phase 3 — `SciMLProblemFlow`

### Step 10 — `SciMLProblemFlow` struct

Inherits directly from `AbstractFlow{NonAutonomous, NonFixed}` — not from
`AbstractStateFlow` since there is no `AbstractStateSystem` to parametrize.

```julia
"""
$(TYPEDEF)

Concrete flow wrapping a `SciMLBase.AbstractODEProblem` directly.

Unlike CTFlows-native flows (`StateFlow`, `HamiltonianFlow`), this flow does not
wrap a `AbstractSystem`. The ODE problem is already fully assembled (u0, tspan, p).

Two call modes are supported:
- **No-arg** `f()`: solves the problem as-is, returns the raw `ODESolution`.
- **Remake** `f(t0, x0, tf; variable)`: calls `SciMLBase.remake` then solves,
  returns `xf` (final state only).

# Type Parameters
- `P <: SciMLBase.AbstractODEProblem`: The wrapped ODE problem.
- `I <: Integrators.AbstractIntegrator`: The integrator strategy.

# Fields
- `prob::P`: The wrapped SciML ODE problem.
- `integrator::I`: The integrator strategy.
"""
struct SciMLProblemFlow{
    P <: SciMLBase.AbstractODEProblem,
    I <: Integrators.AbstractIntegrator,
} <: AbstractFlow{Common.NonAutonomous, Common.NonFixed}
    prob::P
    integrator::I
end
```

### Step 11 — `AbstractFlow` contract methods for `SciMLProblemFlow`

```julia
# No underlying CTFlows system — return nothing
Flows.system(f::SciMLProblemFlow)     = nothing
Flows.integrator(f::SciMLProblemFlow) = f.integrator
```

### Step 12 — Call signatures for `SciMLProblemFlow`

**No-arg call** — solve as-is, return raw `SciMLBase.AbstractODESolution`:

```julia
"""
$(TYPEDSIGNATURES)

Solve the wrapped ODE problem as-is.

Returns the raw `SciMLBase.AbstractODESolution` — the full trajectory, accessible
via `sol(t)`, `sol.u`, `sol.t`.

# Example
```julia
prob = ODEProblem((du, u, p, t) -> du .= -u, [1.0], (0.0, 1.0))
f    = Flow(prob)
sol  = f()
```
"""
function (f::SciMLProblemFlow)(; unsafe = Common.__unsafe())
    opts = Integrators.build_options(f.integrator, nothing)
    sol  = SciMLBase.solve(f.prob; opts...)
    _check_retcode(sol, unsafe)
    return sol
end
```

**Remake call** — new `u0`, `tspan`, optional `p`; returns final state `xf`:

```julia
"""
$(TYPEDSIGNATURES)

Solve with new initial condition and time span via `SciMLBase.remake`.

The variable `p` parameter is passed directly as the ODE `p` (no `ODEParameters`
wrapper). Returns the final state `xf = u(tf)`.

# Arguments
- `t0::Real`: New initial time.
- `x0`: New initial state.
- `tf::Real`: New final time.
- `variable`: New parameter passed as `p` to the ODE (default: `nothing`).
- `unsafe`: If `true`, bypass retcode checking.

# Returns
- Final state vector `xf`.

# Example
```julia
prob = ODEProblem((du, u, p, t) -> du .= -p .* u, [1.0], (0.0, 1.0), 1.0)
f    = Flow(prob)
xf   = f(0.0, [2.0], 1.0)                  # remake u0 and tspan
xf   = f(0.0, [2.0], 1.0; variable=3.0)    # also override p
```
"""
function (f::SciMLProblemFlow)(
    t0::Real,
    x0,
    tf::Real;
    variable = nothing,
    unsafe   = Common.__unsafe(),
)
    # Build remake kwargs: always update u0 and tspan, update p only if variable given
    kw = (; u0=x0, tspan=(t0, tf))
    variable !== nothing && (kw = merge(kw, (; p=variable)))
    prob = SciMLBase.remake(f.prob; kw...)
    opts = Integrators.build_options(
        f.integrator,
        Common.StatePointConfig(t0, x0, tf),
    )
    sol = SciMLBase.solve(prob; opts...)
    _check_retcode(sol, unsafe)
    return last(sol.u)
end
```

### Step 13 — `Base.show` for `SciMLProblemFlow`

```julia
function Base.show(io::IO, ::MIME"text/plain", f::SciMLProblemFlow)
    println(io, "SciMLProblemFlow")
    println(io, "  prob:       ODEProblem (tspan=$(f.prob.tspan), u0=$(f.prob.u0))")
    print(io,   "  integrator: ", nameof(typeof(f.integrator)))
    Flows._print_user_options(io, f.integrator)
end

function Base.show(io::IO, f::SciMLProblemFlow)
    print(io, "SciMLProblemFlow(tspan=", f.prob.tspan, ")")
end
```

### Step 14 — Test Checkpoint: `SciMLProblemFlow`

File: `test/suite/extensions/test_scimlbase_problem_flow.jl`

- `@testset "Unit: SciMLProblemFlow construction"` — from iip and oop problems
- `@testset "Unit: system(f) returns nothing"`
- `@testset "Unit: integrator(f) returns integrator"`
- `@testset "Unit: Base.show"` — smoke test
- `@testset "Integration: no-arg call returns ODESolution"` — `sol.u`, `sol.t` accessible
- `@testset "Integration: remake call returns xf"` — scalar and vector states
- `@testset "Integration: remake with variable overrides p"` — verify `prob.p` in remake
- `@testset "Integration: unsafe=true skips retcode check"`
- `@testset "Error: failed solve with unsafe=false"` — `SolverFailure` thrown

---

## Phase 4 — High-Level `Flow` Constructors

### Step 15 — `Flow(f::AbstractODEFunction; ...)` constructor

```julia
"""
$(TYPEDSIGNATURES)

Build a `StateFlow` from a `SciMLBase.AbstractODEFunction`.

Wraps the function in a `SciMLFunctionSystem` and builds a standard CTFlows
`StateFlow`. The `variable` keyword at call time is passed directly as `p`
to the ODE — no `ODEParameters` wrapper.

The mutability trait (in-place vs out-of-place) is inferred from the `iip`
type parameter of the function.

# Arguments
- `f::SciMLBase.AbstractODEFunction`: The ODE function to wrap.
- `opts...`: Keyword options forwarded to `build_integrator` (e.g., `reltol`, `abstol`, `alg`).

# Returns
- `StateFlow{NonAutonomous, NonFixed, SciMLFunctionSystem, SciML}`.

# Example
```julia
using SciMLBase, CTFlows

# In-place
fip = ODEFunction((du, u, p, t) -> du .= -p .* u)
flow = Flow(fip; reltol=1e-10)
xf   = flow(0.0, [1.0], 1.0; variable=2.0)

# Out-of-place
foop = ODEFunction{false}((u, p, t) -> -p .* u)
flow = Flow(foop)
xf   = flow(0.0, [1.0], 1.0; variable=2.0)
```
"""
function CTFlows.Flows.Flow(f::SciMLBase.AbstractODEFunction; opts...)
    sys   = SciMLFunctionSystem(f)
    integ = Integrators.build_integrator(; opts...)
    return build_flow(sys, integ)
end
```

### Step 16 — `Flow(prob::AbstractODEProblem; ...)` constructor

```julia
"""
$(TYPEDSIGNATURES)

Build a `SciMLProblemFlow` from a `SciMLBase.AbstractODEProblem`.

The problem is stored as-is. Two call modes are available:
- `f()` — solve as-is, returns the raw `ODESolution`.
- `f(t0, x0, tf; variable)` — remake then solve, returns `xf`.

# Arguments
- `prob::SciMLBase.AbstractODEProblem`: The ODE problem to wrap.
- `opts...`: Keyword options forwarded to `build_integrator`.

# Returns
- `SciMLProblemFlow`.

# Example
```julia
using SciMLBase, CTFlows, OrdinaryDiffEqTsit5

prob = ODEProblem((du, u, p, t) -> du .= -u, [1.0], (0.0, 1.0))
f    = Flow(prob)

sol  = f()                       # solve as-is
xf   = f(0.0, [2.0], 2.0)       # remake and solve
```
"""
function CTFlows.Flows.Flow(prob::SciMLBase.AbstractODEProblem; opts...)
    integ = Integrators.build_integrator(; opts...)
    return SciMLProblemFlow(prob, integ)
end
```

### Step 17 — Test Checkpoint: High-level constructors

File: `test/suite/extensions/test_scimlbase_flow_constructors.jl`

- `@testset "Unit: Flow(ODEFunction) builds StateFlow"` — type check
- `@testset "Unit: Flow(ODEFunction) iip"` — rhs inferred correctly
- `@testset "Unit: Flow(ODEFunction) oop"` — rhs_oop inferred correctly
- `@testset "Unit: Flow(ODEProblem) builds SciMLProblemFlow"` — type check
- `@testset "Integration: Flow(ODEFunction) end-to-end"` — numerical result
- `@testset "Integration: Flow(ODEProblem) no-arg call"` — sol accessible
- `@testset "Integration: Flow(ODEProblem) remake call"` — xf correct
- `@testset "Integration: Flow(ODEFunction) with opts"` — reltol, abstol respected
- `@testset "Integration: Flow(ODEProblem) with opts"` — same

---

## Phase 5 — Conflict Prevention with `CTFlowsSciML`

### Step 18 — Verify dispatch disjointness

When both `CTFlowsSciML` and `CTFlowsSciMLBase` are loaded simultaneously
(i.e., `DiffEqBase`, `SciMLBase` both present), two `solve_problem` methods
exist for `SciMLBase.AbstractODEProblem`. They must be disjoint:

- `CTFlowsSciML.solve_problem` → returns `SciMLIntegrationResult`
- `CTFlowsSciMLBase.solve_problem` → returns `SciMLBaseIntegrationResult`

Since Julia dispatches on argument types, both methods have the same signature
`(SciML, AbstractODEProblem, Dict; unsafe)` — **this is ambiguous**.

**Resolution**: restrict `CTFlowsSciMLBase.solve_problem` to only be called via
`SciMLFunctionSystem`'s `build_problem` path by making it internal (not exported,
only reachable through the `StateFlow` call pipeline via `build_problem` dispatch
on `SciMLFunctionSystem`). The `build_problem` overload for `SciMLFunctionSystem`
constructs an `ODEProblem` tagged via a wrapper:

```julia
# Thin wrapper to disambiguate dispatch at solve time
struct SciMLBaseODEProblem{P <: SciMLBase.AbstractODEProblem}
    prob::P
end

function Integrators.build_problem(integ::SciML, sys::SciMLFunctionSystem, config; variable)
    u0   = Common.initial_condition(config)
    prob = SciMLBase.ODEProblem(sys.f, u0, Common.tspan(config), variable)
    return SciMLBaseODEProblem(prob)   # wrapped → unambiguous dispatch
end

function Integrators.solve_problem(
    integ::SciML,
    prob::SciMLBaseODEProblem,
    options::Dict{Symbol, <:Any};
    unsafe = Common.__unsafe(),
)
    sol = SciMLBase.solve(prob.prob; options...)
    _check_retcode(sol, unsafe)
    return SciMLBaseIntegrationResult(sol)
end
```

`CTFlowsSciML.solve_problem` dispatches on the raw `SciMLBase.AbstractODEProblem`
— the two methods are now on disjoint types.

### Step 19 — Test Checkpoint: coexistence

File: `test/suite/extensions/test_scimlbase_coexistence.jl`

- `@testset "Integration: CTFlowsSciML and CTFlowsSciMLBase coexist"` — load both
  DiffEqBase and SciMLBase, verify both paths work without method ambiguity
- `@testset "Integration: VectorField flow still works with both extensions"` —
  regression
- `@testset "Integration: ODEFunction flow correct when DiffEqBase loaded"` —
  `SciMLBaseIntegrationResult` used, not `SciMLIntegrationResult`

---

## Phase 6 — Documentation

### Step 20 — Docstrings

Write docstrings for:
- `SciMLFunctionSystem` struct, `rhs`, `rhs_oop`, `build_problem`, `Base.show`
- `SciMLBaseIntegrationResult` struct, `final_state`, `times`, `evaluate_at`
- `SciMLProblemFlow` struct, both call signatures, `Base.show`
- `Flow(::AbstractODEFunction; ...)`, `Flow(::AbstractODEProblem; ...)`
- `SciMLBaseODEProblem` (internal wrapper, brief note)

### Step 21 — Final Test Run

```bash
julia --project -e 'using Pkg; Pkg.test()' 2>&1 | tee /tmp/scimlbase.log
grep -E "Error|Fail|Test Summary" /tmp/scimlbase.log
```

Expected: all suites pass, zero failures, zero errors.

---

## Files Summary

### New
- `ext/CTFlowsSciMLBase.jl`
- `test/suite/extensions/test_scimlbase_function_system.jl`
- `test/suite/extensions/test_scimlbase_problem_flow.jl`
- `test/suite/extensions/test_scimlbase_flow_constructors.jl`
- `test/suite/extensions/test_scimlbase_coexistence.jl`

### Modified
- `Project.toml` — add `CTFlowsSciMLBase = ["SciMLBase"]` to `[extensions]`

### Deleted
None.

---

## User-Facing API Summary

```julia
using CTFlows, SciMLBase, OrdinaryDiffEqTsit5

# ── From AbstractODEFunction ──────────────────────────────────────────────────

# In-place
fip  = ODEFunction((du, u, p, t) -> du .= -p .* u)
flow = Flow(fip; reltol=1e-10)
xf   = flow(0.0, [1.0], 1.0)                    # p = nothing
xf   = flow(0.0, [1.0], 1.0; variable=2.0)      # p = 2.0

# Out-of-place
foop = ODEFunction{false}((u, p, t) -> -p .* u)
flow = Flow(foop)
xf   = flow(0.0, [1.0], 1.0; variable=2.0)

# ── From AbstractODEProblem ───────────────────────────────────────────────────

prob = ODEProblem((du, u, p, t) -> du .= -u, [1.0], (0.0, 1.0))
flow = Flow(prob; abstol=1e-10)

sol  = flow()                                    # solve as-is → ODESolution
xf   = flow(0.0, [2.0], 1.0)                    # remake u0, tspan → xf
xf   = flow(0.0, [2.0], 1.0; variable=3.0)      # also override p → xf
```
