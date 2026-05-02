"""
$(TYPEDSIGNATURES)

Build an `AbstractIntegrator` from its symbolic id.

# Arguments
- `id::Symbol`: integrator identifier. Only `:sciml` is supported.
- `kwargs...`: options forwarded to the integrator's constructor.

# Throws
- `CTBase.Exceptions.IncorrectArgument`: if `id` is not recognised.
"""
function build_integrator(id::Symbol; kwargs...)
    if id === :sciml
        return SciML(; kwargs...)
    else
        throw(
            Exceptions.IncorrectArgument(
                "Unknown integrator id";
                got = "id = :$id",
                expected = ":sciml",
                suggestion = "Use :sciml (the only integrator).",
                context = "build_integrator dispatch",
            ),
        )
    end
end
