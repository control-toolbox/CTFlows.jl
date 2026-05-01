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
struct SciML <: AbstractIntegrator
    options::CTSolvers.Strategies.StrategyOptions
end

# ============================================================================
# AbstractStrategy Contract Implementation
# ============================================================================

"""
$(TYPEDSIGNATURES)

Return the unique identifier for SciML integrator.
"""
CTSolvers.Strategies.id(::Type{<:SciML}) = :sciml

"""
$(TYPEDSIGNATURES)

Return the description for the SciML integrator.
"""
function CTSolvers.Strategies.description(::Type{<:SciML})
    "SciML ODE integrator.\n" *
    "See: https://docs.sciml.ai/DiffEqDocs"
end

# ============================================================================
# Constructor with Tag Dispatch
# ============================================================================

"""
$(TYPEDSIGNATURES)

Construct a `SciML` integrator. Delegates to `build_sciml_integrator`, which
is overridden by the `CTFlowsSciMLExt` package extension.

# Arguments
- `kwargs...`: Options forwarded to the integrator builder (see extension documentation).

# Throws
- `CTBase.Exceptions.ExtensionError`: If the CTFlowsSciMLExt extension is not loaded.

See also: `SciML`, `build_sciml_integrator`.
"""
function SciML(; mode::Symbol = :strict, kwargs...)
    return build_sciml_integrator(SciMLTag; mode = mode, kwargs...)
end

"""
$(TYPEDSIGNATURES)

Stub builder for `SciML`. The real implementation is provided by
`CTFlowsSciMLExt`; this stub throws `ExtensionError` until the extension
is loaded.
"""
function build_sciml_integrator(::Type{<:Common.AbstractTag}; kwargs...)
    throw(
        Exceptions.ExtensionError(
            :OrdinaryDiffEqTsit5;
            message = "to construct a SciML",
            feature = "ODE integration via SciML",
            context = "Load OrdinaryDiffEqTsit5, OrdinaryDiffEq, or DifferentialEquations to activate the CTFlowsSciMLExt extension.",
        ),
    )
end

"""
$(TYPEDSIGNATURES)

Stub function that throws ExtensionError if CTFlowsSciMLExt extension is not loaded.
Real metadata implementation provided by the extension.

# Throws
- `CTBase.Exceptions.ExtensionError`: Always thrown by this stub implementation

See also: `SciML`, `Strategies.StrategyMetadata`.
"""
function Strategies.metadata(::Type{<:SciML})
    # Extension is missing
    throw(
        Exceptions.ExtensionError(
            :OrdinaryDiffEqTsit5;
            message="to access SciML options metadata",
            feature="SciML metadata",
            context="Load OrdinaryDiffEqTsit5, OrdinaryDiffEq, or DifferentialEquations extension first: using OrdinaryDiffEqTsit5",
        ),
    )
end