# Mooncake on CPU probe

A **diagnostic** (not a test suite) behind
[#448](https://github.com/control-toolbox/CTFlows.jl/issues/448): why
`Flow(h; ad_backend=AutoMooncake())` failed on host arrays, which fix to apply and where,
what it costs, and what stays unsupported. The plan and the decisions are in the issue.

Measured on 2026-10-21 with Mooncake 0.5.65, DifferentiationInterface 0.7.21, ForwardDiff
1.4.6, Julia 1.12, against **CTBase 0.30.12**, i.e. **before** the `CTBaseMooncake`
extension. The scripts simulate the candidate fixes by redefining methods
([`patches.jl`](patches.jl)), so with CTBase ≥ 0.30.13 the `raw` mode no longer fails, and
P4/P5 hit the `PreconditionError` that `Flows._check_call` now raises for `Dual` values.

## How it is run

```bash
julia --project=probe/mooncake_cpu -e 'using Pkg; Pkg.develop(path="."); Pkg.instantiate()'
julia --project=probe/mooncake_cpu probe/mooncake_cpu/p1_di_level.jl
julia --project=probe/mooncake_cpu probe/mooncake_cpu/p2_rhs_paths.jl raw   # or fixA, fixB
julia --project=probe/mooncake_cpu probe/mooncake_cpu/p3_cost.jl fixB2      # or fixA, fixB
julia --project=probe/mooncake_cpu probe/mooncake_cpu/p4_nested.jl
julia --project=probe/mooncake_cpu probe/mooncake_cpu/p5_eltypes.jl
```

Each mode runs in its own process: the patches redefine methods globally. Every mode
bypasses the #436 guard on host arrays.

| Mode | What it simulates |
| --- | --- |
| `raw` | nothing (the guard only) |
| `fixA` | `_ham_split` / `_aug_split` return copies (a CTFlows-side fix) |
| `fixB` | CTBase copies a host view before `DI.gradient`, for `AutoMooncake` only |
| `fixB2` | as `fixB`, and every array captured by the gradient closures is copied too |

## Results

- **P1, root cause** (`p1_di_level.jl`, no CTFlows): `DI.gradient(f, AutoMooncake(), x)`
  returns a `Mooncake.Tangent{(parent, indices, offset1, stride1)}` for any `SubArray` `x`
  (vector view, column view, row-block view of a matrix), with or without
  `friendly_tangents=true`. Upstream does not convert it on purpose
  ([chalk-lab/Mooncake.jl#1294](https://github.com/chalk-lab/Mooncake.jl/issues/1294)).
- **P2, every AD-backed right-hand side** (`p2_rhs_paths.jl`): in `raw` mode, 13 of 15
  paths fail with `MethodError: -(::Mooncake.Tangent)`; only the 1-D (scalar) case and the
  AD-free state-only `Flow(ocp)` call pass. With `fixA` or `fixB`, every path matches
  `AutoForwardDiff` to within 1.3e-15.
- **P3, cost of a full flow call** (`p3_cost.jl`, ms):

  | n | ForwardDiff | fixA | fixB | fixB2 |
  | --- | --- | --- | --- | --- |
  | 2 | 0.14 | 1.52 | 1.70 | 1.50 |
  | 30 | 0.45 | 2.50 | 2.88 | 2.23 |
  | 100 | 2.99 | 3.27 | 4.33 | 3.27 |
  | 400 | 38.9 | 7.50 | 10.4 | 7.44 |
  | 1000 | 231 | 16.2 | 22.4 | 15.3 |

  The crossover is around a hundred dimensions. `fixB` is 30–40 % slower than `fixA`
  because the closure still captures the other block as a view of the whole state; `fixB2`
  matches `fixA`. `fixB2` is what CTBase implements (`CTBaseMooncake`).
- **P4, nested AD** (`p4_nested.jl`): an outer `ForwardDiff` around a Mooncake flow fails
  (Mooncake refuses a `Dual` primal); an outer `FiniteDiff` works (2e-8); an outer
  `Mooncake` needs SciMLSensitivity.
- **P5, element types** (`p5_eltypes.jl`): `Float32` and an integer time pass; a `Dual`
  state, 1-D state, final time or variable fails, and so does `BigFloat`. This scopes the
  `PreconditionError` of `Flows._check_call`.

Not usable as a CTFlows-side fix: `_ham_split(du, N)` also returns the blocks the in-place
vector-field right-hand sides **write** `dx`, `dp` through, so it must keep returning views.
