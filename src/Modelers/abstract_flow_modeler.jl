"""
$(TYPEDEF)

Abstract strategy for building an `AbstractSystem` from an input.

An `AbstractFlowModeler` is a strategy that assembles an `AbstractSystem` from
various inputs (e.g., OCP + control law, Hamiltonian, ODEProblem, etc.).

This type inherits the full CTSolvers strategy contract:
- `id(::Type{<:S}) → Symbol`
- `metadata(::Type{<:S}) → StrategyMetadata`
- `options(s::S) → StrategyOptions`
- `Base.show` (tree + compact, automatic)
- `describe(::Type{<:S})`

# Contract

All subtypes must implement:
- `(modeler)(input, ad_backend)`: Build and return an `AbstractSystem` from the input
  using the provided automatic differentiation backend.

# Throws
- `CTBase.Exceptions.NotImplemented`: If the callable is not implemented by the concrete type.

See also: [`AbstractSystem`](@ref), [`AbstractADBackend`](@ref).
"""
abstract type AbstractFlowModeler <: CTSolvers.Strategies.AbstractStrategy end

"""
$(TYPEDSIGNATURES)

Build an `AbstractSystem` from the input using the provided AD backend.

The input type is intentionally unqualified to allow concrete modelers to dispatch
freely on different input types (e.g., `Tuple{<:OCP, <:Function}`, `<:Hamiltonian`, etc.).

# Arguments
- `modeler::AbstractFlowModeler`: The modeler strategy.
- `input`: The input to build a system from (type varies by concrete modeler).
- `ad_backend::AbstractADBackend`: The automatic differentiation backend to use.

# Returns
- `AbstractSystem`: The assembled system.

# Throws
- `CTBase.Exceptions.NotImplemented`: If not implemented by the concrete type.

See also: [`AbstractFlowModeler`](@ref), [`AbstractADBackend`](@ref).
"""
function (modeler::AbstractFlowModeler)(input, ad_backend)
    throw(Exceptions.NotImplemented(
        "AbstractFlowModeler callable not implemented";
        required_method = "(modeler::$(typeof(modeler)))(input, ad_backend)",
        suggestion = "Implement (m::YourModeler)(input, ad_backend) returning an AbstractSystem. " *
                     "For OCP modelers, accept input as a tuple (ocp, u).",
        context = "AbstractFlowModeler call - required method implementation",
    ))
end
