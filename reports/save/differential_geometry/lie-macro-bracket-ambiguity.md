# `@Lie` bracket-vs-literal ambiguity: analysis and design options

**Status:** analysis / design note (no code changed by this report)
**Scope:** `src/DifferentialGeometry/lie_macro.jl`
**Trigger:** writing the user guide surfaced a real bug — `@Lie {H, G}([1.0, 2.0], [2.0, 1.0])` is wrongly rejected as "mixing Lie and Poisson brackets".

---

## 1. TL;DR

- In Julia, `[a, b]` is **simultaneously** a 2-element vector literal (`Expr(:vect, a, b)`)
  and the notation `@Lie` repurposes for the **Lie bracket** `[X, Y]`. They are
  syntactically identical. `{a, b}` (`Expr(:braces, …)`) has no common literal meaning,
  so the Poisson bracket is unambiguous.
- The macro currently decides **at expansion time** that *every* 2-element `[ , ]` is a
  Lie bracket. A 2-element numeric vector such as `[1.0, 2.0]` is therefore mistaken for a
  bracket. This is the bug.
- **Nesting and higher-order brackets already work** and are unaffected — the issue is
  specifically 2-element *data* vectors written inside a `@Lie` expression.
- The parenthesized form **`(@Lie {H, G})(x, p)` works** (verified): the macro only sees
  the bracket structure; the data point is applied to the result, outside the macro.
- The ambiguity cannot be removed in full generality at macro-expansion time (no type
  information). It **can** be resolved at **runtime** by dispatch, which is the most
  robust direction and the subject of §6.

---

## 2. The root cause: a syntactic collision

`@Lie` reuses ordinary Julia bracket syntax as mathematical notation:

| Surface syntax | Julia AST | `@Lie` meaning |
|---|---|---|
| `[X, Y]`     | `Expr(:vect, :X, :Y)`        | Lie bracket of vector fields |
| `{H, G}`     | `Expr(:braces, :H, :G)`      | Poisson bracket of Hamiltonians |
| `[1.0, 2.0]` | `Expr(:vect, 1.0, 2.0)`      | **also** a plain data vector |

The first and third rows share the **same** head (`:vect`) and arity (2). Empirically:

```julia
julia> e = :([1.0, 2.0]);  (e.head, e.args)
(:vect, Any[1.0, 2.0])

julia> using MacroTools
julia> @capture(:([1.0, 2.0]), [a_, b_])
true                      # a 2-element data vector matches the Lie-bracket pattern
```

`{a, b}` has no everyday role as a literal, so repurposing it for Poisson is safe; `[a, b]`
is one of the most common literals in numerical code, so repurposing it is not.

---

## 3. Current implementation

Three macro-time helpers in `lie_macro.jl` drive the behaviour.

`__has_mixed_brackets` — rejects expressions containing both kinds of bracket:

```julia
function __has_mixed_brackets(expr)
    has_lie = Ref(false); has_poisson = Ref(false)
    postwalk(expr) do e
        @capture(e, [_,_]) && (has_lie[]     = true)
        @capture(e, {_,_}) && (has_poisson[] = true)
        e
    end
    return has_lie[] && has_poisson[]
end
```

`__transform_brackets` — rewrites every bracket into a runtime call:

```julia
postwalk(expr) do x
    if @capture(x, [a_, b_])
        return :($pfx.DifferentialGeometry._lie_mac($a, $b, …))
    elseif @capture(x, {c_, d_})
        return :($pfx.DifferentialGeometry._poisson_mac($c, $d, …))
    else
        return x
    end
end
```

`_lie_mac` / `_poisson_mac` — the runtime workers (normalise operands, check traits,
call `ad` / `Poisson`).

Two facts matter:

1. The pattern is `[a_, b_]` — **exactly two** elements. A 3-element vector such as
   `[1.0, 1.0, 1.0]` never matches, which is why it already works as data
   (`@Lie [1.0, 1.0, 1.0] + …` is used in the test-suite and passes). **The bug is
   confined to 2-element vectors.**
2. Both `__has_mixed_brackets` (a macro-time *guard*) and `__transform_brackets` (the
   macro-time *rewrite*) use the same pattern, so any fix must touch the predicate in
   **both** places to stay consistent.

---

## 4. The bug, reproduced

```julia
H0 = Hamiltonian((x, p) -> 0.5*(2x[1]^2 + x[2]^2 + p[1]^2); is_autonomous=true)
H1 = Hamiltonian((x, p) -> 0.5*(3x[1]^2 + x[2]^2 + p[2]^2); is_autonomous=true)

@Lie {H0, H1}([1.0, 2.0], [2.0, 1.0])      # ❌ throws
```

What happens: `__has_mixed_brackets` walks the expression, sees the **array literals**
`[1.0, 2.0]` / `[2.0, 1.0]` (→ `has_lie = true`) and the genuine `{H0, H1}`
(→ `has_poisson = true`), concludes the expression "mixes" Lie and Poisson brackets, and
emits a `throw(CTBase.Exceptions.IncorrectArgument(...))`. In a context where `CTBase` is
not in scope (e.g. a docs `@example` module), the symptom is even an
`UndefVarError: CTBase`.

The tests never hit this because they bind the evaluation point to a **variable**
(`_x2 = [1.0, 2.0]`) and write `@Lie {H0, H1}(_x2, _p2)`, which contains no `[ , ]` literal.

---

## 5. Two things that are **not** broken

**Nesting / higher order.** `postwalk` is bottom-up and each Lie bracket is *binary*, so
`[[X, Y], Y]` rewrites inner-first: `[X,Y] → _lie_mac(X,Y,…)`, then
`[_lie_mac(…), Y] → _lie_mac(_lie_mac(…), Y, …)`. Arbitrary depth works, and the
"exactly-2" matching is precisely what makes this clean.

**The parenthesized form.** Verified:

```julia
(@Lie {H0, H1})([1.0, 2.0], [2.0, 1.0])    # ✅ = 4.0
```

Here the parentheses scope the macro to `{H0, H1}` alone; the data point is applied to the
**result** (a `Hamiltonian`), *outside* the macro. The macro never sees the literals, so
no false "mixed" detection. This is the idiom every guide example already uses
(`(@Lie [F0, F1])(x)`, `(@Lie {F, G})(x, p)`).

The only form that breaks is the **bare** one, where arguments live *inside* the macro
expression: `@Lie {H, G}([1.,2.], [2.,1.])`. That form exists to support arithmetic that
combines evaluated brackets, e.g. `@Lie [F0,F1](x) + 4*[F1,F2](x)` — and there the point
`x` is (and must be) a variable, not a literal.

---

## 6. Design space

There are four levels, in increasing robustness and cost.

### Level 0 — current

Every 2-element `[ , ]` is a Lie bracket, decided at macro time. Bug as in §4.

### Level 1 — macro-time numeric guard (cheap, safe)

A number is **never** a valid Lie-bracket operand (you cannot bracket two scalars). So a
2-element vector with a numeric-literal element is unambiguously data. Refine the predicate
used by *both* helpers:

```julia
_literal_scalar(x) = x isa Number || x isa AbstractString
_is_lie_bracket(x) = @capture(x, [a_, b_]) && !_literal_scalar(a) && !_literal_scalar(b)
```

- Fixes the reported case: `[1.0, 2.0]` is no longer seen as a bracket, so
  `@Lie {H, G}([1.0, 2.0], [2.0, 1.0])` works.
- **Type-stable** (literals are left untouched; no extra runtime call).
- All current tests stay green; the friendly "mixed brackets" error is preserved for
  genuine field brackets (`@Lie [f, g] + {f, g}` still throws `IncorrectArgument`).
- **Limit:** only *literal* numbers are caught. A numeric **variable** or an indexing
  expression (`[c, d]` with `c, d` numbers, `[x[1], x[2]]`) is not a literal at macro time
  and is still treated as a bracket.

### Level 2 — runtime dispatch on `_lie_mac` (the question raised: "handle it at runtime")

Move the bracket-vs-data decision to **runtime**, where the actual types are known. The
macro keeps rewriting every `[a, b]` to `_lie_mac(a, b, …)`, but `_lie_mac` dispatches:

```julia
const _Bracketable = Union{Function, Data.AbstractVectorField}

# both operands are field-like ⇒ genuine Lie bracket
function _lie_mac(a::_Bracketable, b::_Bracketable,
                  ::Type{TD}, ::Type{VD}, has_aut::Val, has_var::Val, backend) where {TD, VD}
    _check_td(a, TD, has_aut); _check_td(b, TD, has_aut)
    _check_vd(a, VD, has_var); _check_vd(b, VD, has_var)
    return ad(_as_vf(a, TD, VD), _as_vf(b, TD, VD); ad_backend=backend)
end

# anything else (numbers, …) ⇒ it was a 2-element data vector, rebuild it
_lie_mac(a, b, ::Type, ::Type, ::Val, ::Val, _) = [a, b]
```

What this buys, beyond Level 1:

- `@Lie [F0, F1]([c, d])` with `c, d` **numeric variables** → `_lie_mac(c, d, …)` falls
  back to `[c, d]`; the bracket is evaluated at that point. **Works.**
- `@Lie [F0, F1]([x[1], x[2]])` (indexing, non-literal) → same. **Works.**
- Genuine brackets and nesting are unchanged (operands are field-like → typed method).

Important caveat — **the macro-time `__has_mixed_brackets` cannot be rescued by runtime
dispatch.** It runs before any value exists, so for an expression that *also* contains
`{ }`, e.g. `@Lie {H, G}([c, d], …)` with `c, d` variables, the guard still sees `[c, d]`
as a Lie bracket and throws *at expansion*, before `_lie_mac` ever runs. Therefore Level 2
must be combined with the **Level 1 numeric guard on `__has_mixed_brackets`** (which fixes
the *literal* mixed case) — but the *variable-point mixed* case remains blocked until
Level 3.

Also note the trade-offs of the fallback:

- **Type instability:** `_lie_mac` now returns either a `VectorField` or a `Vector`,
  depending on runtime types. Acceptable for a setup/REPL-level convenience macro; a
  consideration if used in hot inner loops.
- **Silent masking:** `@Lie [a, b]` where `a`/`b` accidentally resolve to non-fields
  returns `[a, b]` instead of raising — a typo that yields a number could pass silently.
- **`Function` is broad:** a 2-vector deliberately holding two functions *as data* would
  still be read as a bracket (irreducible, and nonsensical in practice).

### Level 3 — fully runtime (remove the macro-time mixed guard)

To make even `@Lie {H, G}([c, d], …)` (variable point) work, the "mixed brackets"
detection must also move to runtime. Concretely: drop `__has_mixed_brackets`, let the
expression evaluate, and add overloads so that combining incompatible results raises the
friendly error — e.g.

```julia
Base.:+(::Data.AbstractVectorField, ::Data.AbstractHamiltonian) =
    throw(Exceptions.IncorrectArgument("@Lie: cannot mix Lie and Poisson brackets …"))
# and -, *, … symmetrically
```

- Fully general: no surviving false positive for numeric data of any form.
- Heaviest change: must reproduce the current friendly error to keep
  `@test_throws IncorrectArgument @Lie [f, g] + {f, g}` green, and adds operator overloads
  on library types (possible piracy concerns; needs care).

---

## 7. Comparison

| | Fixes `[1.,2.]` literal | Fixes numeric **variable** point | Fixes mixed `{…}([c,d],…)` var. point | Type-stable | API change | Test impact |
|---|---|---|---|---|---|---|
| L0 current | ✗ | ✗ | ✗ | ✓ | — | — |
| L1 numeric guard | ✓ | ✗ | ✓ (literals only) | ✓ | none | none |
| L2 runtime `_lie_mac` (+L1 guard) | ✓ | ✓ (non-mixed expr) | literals only | ✗ | none | none expected |
| L3 fully runtime | ✓ | ✓ | ✓ | ✗ | semantics | needs new guards to stay green |

---

## 8. Recommendation

- **Adopt L1 now.** It is safe (a number is never a bracket operand), type-stable, fixes
  the reported bug, keeps every test green, and preserves the friendly mixed-bracket error.
- **Add L2 if** we want bracket evaluation at numeric-variable / indexed points
  (`@Lie [F0,F1]([x[1],x[2]])`). It composes with L1 and needs no API change; accept the
  type-instability and silent-fallback trade-offs for a convenience macro.
- **Defer L3** unless the bare mixed form with variable points
  (`@Lie {H, G}([c, d], …)`) is genuinely required. It is the only level that removes the
  ambiguity entirely, at the cost of operator overloads and reworking the mixed-bracket
  error path.

Regardless of level, keep the documented idiom: **apply arguments outside the macro** —
`(@Lie [F0, F1])(x)`, `(@Lie {H, G})(x, p)` — so the macro only ever sees bracket
structure, never data. Inside-the-macro arguments are needed only for the arithmetic form
`@Lie [F0,F1](x) + [F1,F2](x)`, where `x` is a variable.

---

## 9. Regression checklist (for whichever level is implemented)

Must remain true:

- `@Lie [F0, F1]` → `VectorField`; `@Lie {H0, H1}` → `Hamiltonian`.
- Nesting: `@Lie [[F0, F1], F1]`, `@Lie {{H0, H1}, H1}`.
- Arithmetic with variable points: `@Lie [F0,F1](x) + 4*[F1,F2](x)`,
  `@Lie {H0,H1}(x,p) - {H1,H2}(x,p)`.
- Friendly errors: `@Lie [f, g] + {f, g}` → `IncorrectArgument`; unknown keyword →
  `IncorrectArgument`; trait mismatch → `IncorrectArgument`.
- `@Lie [1.0, 1.0, 1.0] + …` (3-element data vector) unchanged.

New cases that should pass after the fix:

- L1+: `@Lie {H, G}([1.0, 2.0], [2.0, 1.0])` (literal point inside the macro).
- L2+: `@Lie [F0, F1]([c, d])` and `@Lie [F0, F1]([x[1], x[2]])` (numeric variable / indexed point).

---

## 10. Documentation note

`docs/src/differential_geometry/lie_macro.md` currently carries a warning advising users to
bind evaluation points to variables (the L0/L1 reality). If L2/L3 is implemented, that
warning can be relaxed accordingly; until then it should stay.
