# Flow from a vector field

## Goal

Define a flow from a vector field by going through the full CTFlows pipeline (`build_system` → `build_flow` → `integrate` → `solve`). A vector field is a function returning the derivative of the state, declined along two trait axes — autonomous vs. non-autonomous (`f(x)` vs. `f(t, x)`) and fixed vs. non-fixed (with an extra variable `v`: `f(t, x, v)`) — and along the shape of the state (scalar, vector, matrix). On top of this we want a configurable integrator (default `Tsit5`, switchable, with CPU/GPU paths), a sensible option set, a solution wrapper with getters and plotting, support for system/flow concatenation, and a correct treatment of dual numbers in the integrator's internal norm (issue [#93](https://github.com/control-toolbox/CTFlows.jl/issues/93)).

This is delivered in several phases. Phase 1 establishes the end-to-end skeleton with the smallest viable surface; later phases progressively cover the rest.

## Phase 1 — In scope

The first PR (branch `feature/vector-field-flow`) delivers an end-to-end vector-field flow with:

- **`VectorField` type** with the full `{Autonomous, NonAutonomous} × {Fixed, NonFixed}` trait matrix, ported and trimmed from `save/src/types.jl#L626-L692`. State is scalar or vector (matrix-valued fields deferred).
- **`VectorFieldSystem <: Systems.AbstractSystem`** — concrete system wrapping a `VectorField`. Implements `rhs!`, `dimensions`, `build_solution` (identity passthrough for now) and a new optional `Systems.ode_problem` contract method used by SciML-based integrators.
- **`VectorFieldModeler <: Modelers.AbstractFlowModeler`** — trivial modeler whose business callable returns a `VectorFieldSystem`. Full CTSolvers strategy contract (`id`, `metadata`, `options`).
- **`NoOpADBackend <: ADBackends.AbstractADBackend`** — placeholder AD backend satisfying the strategy contract; not exercised by `VectorField` (no differentiation needed for a raw RHS). Real AD backends arrive with the Hamiltonian/OCP modelers.
- **`AbstractSciMLIntegrator <: Integrators.AbstractODEIntegrator`** in core; concrete **`SciMLIntegrator`** in a new package extension `CTFlowsSciMLExt` built on `SciMLBase` + `OrdinaryDiffEqCore`. The user loads any algorithm package (`OrdinaryDiffEqTsit5`, `OrdinaryDiffEq`, `DifferentialEquations`) and passes `alg = Tsit5()`.
- **Pipeline conveniences**: `build_system(vf)` and `Flow(vf; alg, kwargs...)` so the user-facing idiom from `save/ext/vector_field.jl` is preserved.
- **Phase-1 integrator options** (subset of the original list, sanity-checked against SciML at implementation time): `alg`, `abstol`, `reltol`, `maxiters`, `dt`, `adaptive`, `save_everystep`, `saveat`.
- **Tests** following `.windsurf/rules/testing.md`: unit tests for each new type, contract tests for each strategy, an end-to-end pipeline test guarded by the SciML extension (using `OrdinaryDiffEqTsit5` in the test extras) integrating `f(t, x) = -x` and checking against the analytical solution.

The detailed implementation plan lives in `vector-field-flow-019537.md`.

## Deferred to later phases

The following items from the original brief are intentionally **not** in Phase 1 and will be addressed in dedicated follow-ups:

- **Matrix-valued vector fields**. Phase 1 supports scalar/vector states only.
- **Solution wrapper with getters**. Phase 1 returns the raw SciML `ODESolution`. Later, `build_solution` will produce a CTFlows-specific struct with `state(sol)`, `time_grid(sol)`, `sol(t)`, and friends.
- **Plot recipe**. Mirroring `CTModelsPlots` (see references below) — deferred.
- **`internalnorm` option and ForwardDiff.Dual fix** (issue [#93](https://github.com/control-toolbox/CTFlows.jl/issues/93)). The reference snippet is preserved in the appendix as the design template.
- **Event/jump handling**: `tstops`, `callback`, `jumps` options.
- **GPU support and CPU/GPU strategy parameters** (à la `CTSolvers` `Modelers/exa.jl`). The Exa metadata snippet is preserved in the appendix as the design template.
- **Concatenation**: `MultiPhaseSystem`, `MultiPhaseFlow`, the `∘` and `*` operators. See `reports/design.md` §2.3–§2.4.
- **Real AD backends** (ForwardDiff, Zygote, Enzyme). Only `NoOpADBackend` in Phase 1.
- **Per-algorithm integrator strategies** (e.g. dedicated `Tsit5Integrator`, GPU integrators). Phase 1 ships a single generic `SciMLIntegrator`.

## Open questions / to clarify before Phase ≥ 2

These points are not yet decided and need a design pass before the corresponding feature is implemented:

- **Matrix-field shape in the trait matrix**: add a third trait axis, parameterise by `T <: AbstractArray`, or handle it purely through method dispatch on `f`'s signature?
- **Option ownership** between modeler and integrator. The Phase-1 plan puts all SciML options on the integrator. Some options (e.g. `tstops`, `jumps`, `internalnorm`) arguably describe the *problem*, not the *solver* — see `reports/design.md` §3.1. Revisit when adding event handling.
- **Integrator granularity**: keep one generic `SciMLIntegrator` long-term, or introduce one strategy per algorithm (`Tsit5Integrator`, `Rodas4Integrator`, …) sharing a common metadata base?
- **GPU pathway**: do we mirror `exa.jl` exactly with `CPU`/`GPU` parameters on `AbstractSciMLIntegrator{P}` and computed defaults, or carry the parameter on the AD backend instead, or both? See the Exa snippet in the appendix.
- **Where the dual-number `internalnorm` fix lives**: as a default in the integrator metadata (auto-on when state `eltype` is `ForwardDiff.Dual`), or as an explicit opt-in option the user activates?
- **Solution wrapper API**: introduce a CTFlows-specific type with `state(sol)`/`time_grid(sol)`, or just return the SciML `ODESolution` and document that `x(t) = sol(t)` is the canonical accessor?
- **Plot recipe location**: a CTFlows package extension on `RecipesBase`/`Plots`, or a sibling package mirroring `CTModelsPlots`?
- **SciML option-name verification**: every option name in the Phase-1 list must be checked against the actual `SciMLBase`/`OrdinaryDiffEq` APIs at implementation time (the original brief already flagged this).

## Appendix — reference snippets

### Exa modeler with CPU/GPU parameter

Kept verbatim from [`CTSolvers Modelers/exa.jl`](https://github.com/control-toolbox/CTSolvers.jl/blob/main/src/Modelers/exa.jl) as the reference template for parameterising a CTFlows strategy by `CPU`/`GPU` (see [CTSolvers parameters](https://github.com/control-toolbox/CTSolvers.jl/blob/main/src/Strategies/contract/parameters.jl)).

```julia
__exa_model_backend() = nothing
__exa_model_backend(::Type{CPU}) = nothing
function __exa_model_backend(P::Type{GPU})
    return __get_cuda_backend(P)
end
function __get_cuda_backend(::Type{<:GPU})
    throw(
        Exceptions.ExtensionError(
            :CUDA;
            message="to use GPU backend with Exa modeler",
            feature="GPU computation with ExaModels",
            context="Load CUDA extension first: using CUDA",
        ),
    )
end

function Strategies.metadata(::Type{<:Modelers.Exa{P}}) where {P<:Union{CPU,GPU}}
    return Strategies.StrategyMetadata(
        # === Existing Options (enhanced) ===
        Strategies.OptionDefinition(;
            name=:base_type,
            type=DataType,
            default=__exa_model_base_type(),
            description="Base floating-point type used by ExaModels",
            validator=validate_exa_base_type,
        ),
        Strategies.OptionDefinition(;
            name=:backend,
            type=Union{Nothing,KernelAbstractions.Backend},  # More permissive for various backend types
            default=__exa_model_backend(P),
            description="Execution backend for ExaModels (CPU, GPU, etc.)",
            computed=true,  # Default is computed from parameter P
            aliases=(:exa_backend,),
            validator=function (backend)
                if !__consistent_backend(P, backend)
                    param_str = P == CPU ? "CPU" : "GPU"
                    backend_str =
                        backend === nothing ? "no backend" : string(typeof(backend))
                    @warn "Inconsistent backend ($backend_str) for $param_str parameter" maxlog=1
                end
                return backend
            end,
        ),
    )
end
```

### Dual-number internal norm

Reference snippet for the future `internalnorm` fix (issue [#93](https://github.com/control-toolbox/CTFlows.jl/issues/93)) — only the real part of `ForwardDiff.Dual` numbers should contribute to the adaptive-step norm.

```julia
df_sol = DataFrame(adaptive=Bool[], VAR_IND=String[], internalnorm=String[], norm_∞_error=Real[], norm_∞_diff=Real[], time_steps=Vector[])


# with my_norm the diagram switches 
sse(x::Number) = x^2
sse(x::ForwardDiff.Dual) = sse(ForwardDiff.value(x)) #+ sum(sse, ForwardDiff.partials(x))
totallength(x::Number) = 1
function totallength(x::ForwardDiff.Dual)
  totallength(ForwardDiff.value(x)) #+ sum(totallength, ForwardDiff.partials(x))
end
totallength(x::AbstractArray) = sum(totallength, x)
function my_norm(u, t)
  return sqrt(sum(x -> sse(x), u) / totallength(u))
end

test_FD!(df_sol,fun_lin, tspan, x0, λ, sol_∂xO_flow,true,internalnorm=my_norm)
println(df_sol)
```

### Candidate option list (original brief)

Full list of options envisioned across all phases (Phase 1 implements only the subset listed in the in-scope section above; the rest must still be checked against the actual SciML/OrdinaryDiffEq APIs):

- `alg`: the integrator algorithm
- `abstol`: the absolute tolerance
- `reltol`: the relative tolerance
- `maxiters`: the maximum number of iterations
- `internalnorm`: the internal norm function
- `save_everystep`: whether to save every step
- `dt`: the time step
- `adaptive`: whether to use adaptive time stepping
- `tstops`
- `callback`
- `saveat`

### References

- [CTModels — `Autonomous`/`NonAutonomous` types](https://github.com/control-toolbox/CTModels.jl/blob/34fe34d6f5e76d8b8d750475c96e5ef1e8fb8d3e/src/OCP/Types/components.jl#L28-L40)
- `save/src/types.jl#L38-L54` — time dependence traits
- `save/src/types.jl#L62-L79` — variable dependence traits
- `save/src/types.jl#L626-L692` — original `VectorField` implementation
- `save/ext/vector_field.jl` — original `Flow(::VectorField; ...)` extension
- [`Tsit5` documentation](https://docs.sciml.ai/OrdinaryDiffEq/stable/explicit/Tsit5/#OrdinaryDiffEqTsit5)
- [CTSolvers — strategy parameters](https://github.com/control-toolbox/CTSolvers.jl/blob/main/src/Strategies/contract/parameters.jl)
- [CTSolvers — Exa modeler with CPU/GPU](https://github.com/control-toolbox/CTSolvers.jl/blob/main/src/Modelers/exa.jl)
- [CTFlows issue #93 — dual-number internal norm](https://github.com/control-toolbox/CTFlows.jl/issues/93)
- CTModelsPlots extension (template for the future plot recipe):
  - <https://github.com/control-toolbox/CTModels.jl/blob/main/ext/CTModelsPlots.jl>
  - <https://github.com/control-toolbox/CTModels.jl/blob/main/ext/plot.jl>
  - <https://github.com/control-toolbox/CTModels.jl/blob/main/ext/plot_default.jl>
  - <https://github.com/control-toolbox/CTModels.jl/blob/main/ext/plot_utils.jl>
- `reports/design.md` — overall CTFlows architecture (objects, strategies, pipelines)
- `reports/candidate_strategies.md` — strategy candidate analysis
- `vector-field-flow-019537.md` — Phase 1 implementation plan
