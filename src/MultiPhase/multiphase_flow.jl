# TODO: docstring
struct MultiPhaseStateFlow{TD<:Common.TimeDependence, VD<:Common.VariableDependence, S<:Systems.AbstractStateSystem{TD, VD}, I<:Integrators.AbstractIntegrator} <: Flows.AbstractStateFlow{TD, VD, S}
    flows::Vector{Flows.StateFlow{TD, VD, S, I}}
    switching_times::Vector{<:Real}
    jumps::Vector{<:Any}
end

# TODO: docstring
struct MultiPhaseHamiltonianFlow{TD<:Common.TimeDependence, VD<:Common.VariableDependence, S<:Systems.AbstractHamiltonianSystem{TD, VD}, I<:Integrators.AbstractIntegrator} <: Flows.AbstractHamiltonianFlow{TD, VD, S}
    flows::Vector{Flows.HamiltonianFlow{TD, VD, S, I}}
    switching_times::Vector{<:Real}
    jumps::Vector{<:Any}
end

# TODO: docstring
function Flows.system(mpsf::MultiPhaseStateFlow)
    return [Flows.system(f) for f in mpsf.flows]
end

# TODO: docstring
function Flows.system(mphf::MultiPhaseHamiltonianFlow)
    return [Flows.system(f) for f in mphf.flows]
end

# TODO: docstring
function Flows.integrator(mpsf::MultiPhaseStateFlow)
    return [Flows.integrator(f) for f in mpsf.flows]
end

# TODO: docstring
function Flows.integrator(mphf::MultiPhaseHamiltonianFlow)
    return [Flows.integrator(f) for f in mphf.flows]
end

# ==============================================================================
# Base.show
# ==============================================================================

const AnyMultiPhaseFlow = Union{MultiPhaseStateFlow, MultiPhaseHamiltonianFlow}

# TODO: docstring
function Base.show(io::IO, ::MIME"text/plain", mpf::AnyMultiPhaseFlow)
    print(io, nameof(typeof(mpf)))
    print(io, "\n  phases: ", length(mpf.flows))
    print(io, "\n  systems: ", typeof(Flows.system(mpf)))
    print(io, "\n  integrators: ", typeof(Flows.integrator(mpf)))
    print(io, "\n  switching_times: ", mpf.switching_times)
    print(io, "\n  jumps: ", mpf.jumps)
end

# TODO: docstring
function Base.show(io::IO, mpf::AnyMultiPhaseFlow)
    print(io, nameof(typeof(mpf)), "(")
    parts = String[]
    push!(parts, "phases=$(length(mpf.flows))")
    push!(parts, "switching_times=$(mpf.switching_times)")
    print(io, join(parts, ", "))
    print(io, ")")
end
