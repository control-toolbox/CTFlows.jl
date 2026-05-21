# ==============================================================================
# DifferentiationInterface — Concrete AD Backend Strategy
# ==============================================================================

"""
$(TYPEDEF)

Concrete AD backend strategy wrapping DifferentiationInterface.jl backends.

`DifferentiationInterface` stores a `:ad_backend` option (e.g., `AutoForwardDiff()`,
`AutoZygote()`) and uses it to compute gradients via the DifferentiationInterface.jl
ecosystem.

# Arguments
- `backend=AutoForwardDiff()`: The DifferentiationInterface.jl backend to use. Defaults
  to `AutoForwardDiff()` from `ADTypes.jl` (a hard dependency).
- `kwargs...`: Additional options passed to `StrategyOptions`.

# Notes
 - `ADTypes.jl` is a hard dependency, so `AutoForwardDiff()` is always available in core.
 - Gradient computation requires the `CTFlowsDifferentiationInterface` extension (Phase 5).
 - Without the extension, the gradient methods throw `NotImplemented` with a helpful message.

See also: [`CTFlows.Differentiation.AbstractADBackend`](@ref),
[`CTFlows.Differentiation.hamiltonian_gradient`](@ref),
[`CTFlows.Differentiation.variable_gradient`](@ref),
[`CTFlows.Differentiation.prepare_cache`](@ref).
"""
struct DifferentiationInterface{O<:CTSolvers.Strategies.StrategyOptions} <:
       AbstractADBackend
    options::O
end

"""
$(TYPEDSIGNATURES)

Constructor for `DifferentiationInterface` with a specific backend.

# Arguments
- `backend=AutoForwardDiff()`: The DifferentiationInterface.jl backend.
- `kwargs...`: Additional options passed to `StrategyOptions`.

# Returns
- `DifferentiationInterface`: A new backend strategy instance.
"""
function DifferentiationInterface(; mode::Symbol=:strict, kwargs...)
    opts = CTSolvers.Strategies.build_strategy_options(DifferentiationInterface; mode=mode, kwargs...)
    return DifferentiationInterface{typeof(opts)}(opts)
end

# ==============================================================================
# CTSolvers.Strategies Contract
# ==============================================================================

"""
$(TYPEDSIGNATURES)

Return the strategy identifier for `DifferentiationInterface`.
"""
CTSolvers.Strategies.id(::Type{<:DifferentiationInterface}) = :differentiation_interface

"""
$(TYPEDSIGNATURES)

Return a human-readable description of the `DifferentiationInterface` strategy.
"""
CTSolvers.Strategies.description(::Type{<:DifferentiationInterface}) =
    "AD backend wrapping DifferentiationInterface.jl backends (e.g., AutoForwardDiff)."

"""
$(TYPEDSIGNATURES)

Return metadata defining `DifferentiationInterface` options and their specifications.
"""
function CTSolvers.Strategies.metadata(::Type{<:DifferentiationInterface})
    return CTSolvers.Strategies.StrategyMetadata(
        CTSolvers.Strategies.OptionDefinition(;
            name = :ad_backend,
            type = ADTypes.AbstractADType,
            default = ADTypes.AutoForwardDiff(),  # ADTypes.jl — always available (hard dep)
            description = "DifferentiationInterface.jl backend (e.g. AutoForwardDiff()).",
            aliases=(:backend, :ad),
        ),
        CTSolvers.Strategies.OptionDefinition(;
            name = :prepare_cache,
            type = Bool,
            default = false,
            description = "If true, call DI.prepare_gradient once at cache-preparation time and reuse the plan. If false, call plain DI.gradient at every integration step (no preallocation).",
        ),
    )
end
