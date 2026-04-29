"""
$(TYPEDSIGNATURES)

Build an `AbstractODEIntegrator` from its symbolic id.

# Arguments
- `id::Symbol`: integrator identifier. Phase 1 supports `:sciml`.
- `kwargs...`: options forwarded to the integrator's constructor.

# Throws
- `CTBase.Exceptions.IncorrectArgument`: if `id` is not recognised.
"""
function build_integrator(id::Symbol; kwargs...)
    if id === :sciml
        return SciMLIntegrator(; kwargs...)
    else
        throw(
            Exceptions.IncorrectArgument(
                "Unknown integrator id";
                got = "id = :$id",
                expected = "one of: :sciml",
                suggestion = "Use :sciml (the only Phase-1 integrator).",
                context = "build_integrator dispatch",
            ),
        )
    end
end
