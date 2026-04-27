# Flow API Design Review

Refactoring `Flow(ocp, u)` to handle three control types:
- **dynamic feedback**: `u = u(x, p)` (most common)
- **state feedback**: `u = u(x)`
- **open loop**: `u = u(t)`

---

## Solution 1 — Typed wrappers

```julia
f1 = Flow(o, DynClosedLoop(u1))   # u1(x, p)
f2 = Flow(o, ClosedLoop(u2))      # u2(x)
f3 = Flow(o, OpenLoop(u3))        # u3(t)
```

**Pros:**
- Most idiomatic Julia: types carry semantic meaning, dispatch is resolved at compile time, not runtime.
- The return type of `Flow` can meaningfully differ per wrapper — `f1` has signature `(t0, x0, p0, tf)`, `f3` has `(t0, x0, tf)`, and the compiler *knows* this statically.
- No stringly-typed dispatch — a typo like `OpenLop(u)` is a `MethodError`, caught immediately.
- The wrapper types are composable and reusable across the ecosystem (e.g., `solve`, other flow constructors).
- Handles the `control(sol)` reinjection case cleanly: `Flow(o, OpenLoop(control(sol)))`.

**Cons:**
- Boilerplate for the most common case: `Flow(o, DynClosedLoop(u))` vs just `Flow(o, u)`. This will frustrate users who just want the default.
- Cognitive overhead: new users must learn wrapper types before using `Flow`.
- Could add a convenience `Flow(ocp, u::Function)` defaulting to `DynClosedLoop` to mitigate, but then the typing becomes partially advisory.

---

## Solution 2 — Positional symbol

```julia
f1 = Flow(ocp, u, :dynamic_feedback)   # default
f2 = Flow(ocp, u, :state_feedback)
f3 = Flow(ocp, u, :open_loop)
```

**Pros:**
- Self-documenting at call site: `:open_loop` reads like English.
- Default `:dynamic_feedback` makes the common case ergonomic: `Flow(ocp, u)`.

**Cons:**
- **Stringly-typed**: `:dynamcal_feedback` silently becomes a runtime error, not a compile-time one. Symbols are opaque to the type system.
- Dispatch is a runtime `if`/`elseif` chain on the symbol, not multiple dispatch — loses the central Julia strength.
- Symbol as last positional arg is semantically odd: it qualifies `u`, not the overall `Flow` call, yet appears detached at the end.
- UC1.5 (returning a tuple from `Flow`) is a design smell that does not follow from the symbol dispatch logic.

---

## Solution 3 — Kwarg variant

```julia
f1 = Flow(ocp, u)                              # default
f2 = Flow(ocp, u, control=:state_feedback)
f3 = Flow(ocp, u, control=:open_loop)
```

**Pros:**
- Named kwarg (`control=:open_loop`) is cleaner than a trailing positional symbol — intent is unambiguous at call site.
- Default is natural: `Flow(ocp, u)` just works.

**Cons:**
- Same fundamental problem as Solution 2: still stringly-typed, still runtime dispatch, still no compiler help.
- Kwargs in Julia bypass specialization in some dispatch scenarios — minor but real.
- The kwarg name has to be chosen carefully (`control_type`? `feedback`? `loop`?) and could lead to inconsistency across the codebase.

---

## Summary

| Criterion | Sol. 1 (typed) | Sol. 2 (symbol, positional) | Sol. 3 (symbol, kwarg) |
|---|---|---|---|
| Julia dispatch idiom | compile-time | runtime | runtime |
| Typo safety | `MethodError` | silent failure | silent failure |
| Ergonomics (common case) | needs default | ok | ok |
| Readability at call site | ok | ok | ok |
| Return type specialization | yes | no | no |
| Ecosystem reusability | yes | no | no |

---

## Recommendation

**Solution 1 with a convenience default.** The typed wrapper approach is the right Julian design. The ergonomics concern is real but solvable:

```julia
# Explicit, canonical
f = Flow(ocp, DynClosedLoop(u))   # u(x, p)
f = Flow(ocp, ClosedLoop(u))      # u(x)
f = Flow(ocp, OpenLoop(u))        # u(t)

# Convenience: bare function defaults to DynClosedLoop
Flow(ocp, u::Function) = Flow(ocp, DynClosedLoop(u))
```

This way `Flow(ocp, u)` still works for 90% of users, while the type system does real work for the other 10% and for library internals. The `control(sol)` reinjection pattern also becomes explicit and readable: `Flow(ocp, OpenLoop(control(sol)))`.

The symbol-based solutions (2 and 3) trade away Julia's core strength (compile-time dispatch on types) for a marginal readability gain that the wrapper names already provide.
