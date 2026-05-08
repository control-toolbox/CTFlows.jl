"""
$(TYPEDEF)

Tag type for SciML integrator dispatch. Used to target the implementation
provided by the `CTFlowsSciMLExt` package extension.
"""
struct SciMLTag <: Common.AbstractTag end

"""
$(TYPEDEF)

Tag type for Tsit5-specific default algorithm dispatch. Used to target
the implementation provided by the `CTFlowsOrdinaryDiffEqTsit5Ext` package extension.
"""
struct Tsit5Tag <: Common.AbstractTag end

"""
$(TYPEDEF)

Abstract supertype for SciML-based ODE integrator strategies.

This type defines the interface for all integrator strategies that use SciML solvers.
Concrete subtypes should store strategy options and implement the required contract methods.

# Interface Requirements

Subtypes must implement:
- `CTSolvers.Strategies.id(::Type{<:SubType})`: Return unique identifier
- `CTSolvers.Strategies.description(::Type{<:SubType})`: Return description
- `CTSolvers.Strategies.metadata(::Type{<:SubType})`: Return option metadata

# Example
```julia-repl
julia> using CTFlows.Integrators

julia> SciML <: AbstractSciMLIntegrator
true
```

See also: [`Integrators.SciML`](@ref), [`Integrators.SciMLTag`](@ref).
"""
abstract type AbstractSciMLIntegrator <: AbstractIntegrator end

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
- `options::CTSolvers.Strategies.StrategyOptions`: Validated option bundle.
- `options_point::Dict{Symbol, Any}`: Pre-computed options for PointConfig.
- `options_trajectory::Dict{Symbol, Any}`: Pre-computed options for TrajectoryConfig.
"""
struct SciML{O<:CTSolvers.Strategies.StrategyOptions, OP<:Dict{Symbol, Any}, OT<:Dict{Symbol, Any}} <: AbstractSciMLIntegrator
    options::O
    options_point::OP
    options_trajectory::OT
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
    "See: https://docs.sciml.ai/DiffEqDocs\n" *
    "Solver options: https://docs.sciml.ai/DiffEqDocs/stable/basics/common_solver_opts/"
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

See also: `SciML`, `CTSolvers.Strategies.StrategyMetadata`.
"""
function CTSolvers.Strategies.metadata(::Type{<:AbstractSciMLIntegrator})
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

"""
$(TYPEDSIGNATURES)

Return the default SciML ODE algorithm for the given tag type.

This stub returns `missing` for the abstract tag type. The actual implementation
for Tsit5Tag is provided by CTFlowsOrdinaryDiffEqTsit5Ext.

# Returns
- `missing`: Default stub implementation.

See also: [`Integrators.SciML`](@ref), [`Integrators.Tsit5Tag`](@ref).
"""
function __default_sciml_algorithm(::Type{<:Common.AbstractTag})
    return missing
end