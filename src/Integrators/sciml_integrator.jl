"""
$(TYPEDEF)

Tag type for SciML integrator dispatch. Used to target the implementation
provided by the `CTFlowsSciMLExt` package extension.
"""
struct SciMLTag <: Common.AbstractTag end

"""
$(TYPEDEF)

Generic SciML ODE integrator strategy.

Wraps any SciML algorithm (e.g. `Tsit5`, `Rodas4`) through a unified
`CTSolvers`-backed option system. The full implementation (metadata, builder
and callable) is provided by the `CTFlowsSciMLExt` package extension; this
file declares the type and **stubs** that throw `ExtensionError` until the
extension is loaded.

To activate the extension, load any of:
- `using OrdinaryDiffEqTsit5` (minimal)
- `using OrdinaryDiffEq`
- `using DifferentialEquations`

# Fields
- `options::CTSolvers.Strategies.StrategyOptions`: validated option bundle.
"""
struct SciMLIntegrator <: AbstractODEIntegrator
    options::CTSolvers.Strategies.StrategyOptions
end

"""
$(TYPEDSIGNATURES)

Return the unique identifier for SciMLIntegrator.
"""
CTSolvers.Strategies.id(::Type{<:SciMLIntegrator}) = :sciml

"""
$(TYPEDSIGNATURES)

Construct a `SciMLIntegrator`. Delegates to `build_sciml_integrator`, which
is overridden by the `CTFlowsSciMLExt` package extension.
"""
function SciMLIntegrator(; mode::Symbol = :strict, kwargs...)
    return build_sciml_integrator(SciMLTag; mode = mode, kwargs...)
end

"""
$(TYPEDSIGNATURES)

Stub builder for `SciMLIntegrator`. The real implementation is provided by
`CTFlowsSciMLExt`; this stub throws `ExtensionError` until the extension
is loaded.
"""
function build_sciml_integrator(::Type{<:Common.AbstractTag}; mode::Symbol = :strict, kwargs...)
    throw(
        Exceptions.ExtensionError(
            :OrdinaryDiffEqTsit5;
            message = "to construct a SciMLIntegrator",
            feature = "ODE integration via SciML",
            context = "Load OrdinaryDiffEqTsit5, OrdinaryDiffEq, or DifferentialEquations to activate the CTFlowsSciMLExt extension.",
        ),
    )
end

# Note: the callable `(integ::SciMLIntegrator)(prob)` is provided by the
# CTFlowsSciMLExt extension. Without the extension, `SciMLIntegrator` cannot
# be constructed (the builder above throws `ExtensionError`), so no explicit
# stub callable is needed at the package level.
