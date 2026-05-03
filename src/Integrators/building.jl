"""
$(TYPEDSIGNATURES)

Build a `SciML` integrator with the given options.

# Arguments
- `kwargs...`: Options forwarded to the `SciML` constructor.

# Returns
- `CTFlows.Integrators.SciML`: The configured integrator.

# Example
\`\`\`julia
using CTFlows.Integrators

integrator = Integrators.build_integrator(reltol=1e-8, alg=Tsit5())
\`\`\`

See also: [`CTFlows.Integrators.SciML`](@ref), [`CTFlows.Integrators.build_sciml_integrator`](@ref).
"""
function build_integrator(; kwargs...)
    return SciML(; kwargs...)
end
