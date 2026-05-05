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
# Getter methods for encapsulation
# ==============================================================================

"""
$(TYPEDSIGNATURES)

Get the number of phases in a multi-phase flow.

# Arguments
- `mpf::MultiPhaseStateFlow`: The multi-phase state flow.

# Returns
- `Int`: Number of phases.
"""
function n_phases(mpf::MultiPhaseStateFlow)
    return length(mpf.flows)
end

"""
$(TYPEDSIGNATURES)

Get the number of phases in a multi-phase flow.

# Arguments
- `mpf::MultiPhaseHamiltonianFlow`: The multi-phase Hamiltonian flow.

# Returns
- `Int`: Number of phases.
"""
function n_phases(mpf::MultiPhaseHamiltonianFlow)
    return length(mpf.flows)
end

"""
$(TYPEDSIGNATURES)

Get the flow at phase index i.

# Arguments
- `mpf::MultiPhaseStateFlow`: The multi-phase state flow.
- `i::Int`: Phase index (1-based).

# Returns
- `StateFlow`: The flow at phase i.
"""
function get_flow(mpf::MultiPhaseStateFlow, i::Int)
    return mpf.flows[i]
end

"""
$(TYPEDSIGNATURES)

Get the flow at phase index i.

# Arguments
- `mpf::MultiPhaseHamiltonianFlow`: The multi-phase Hamiltonian flow.
- `i::Int`: Phase index (1-based).

# Returns
- `HamiltonianFlow`: The flow at phase i.
"""
function get_flow(mpf::MultiPhaseHamiltonianFlow, i::Int)
    return mpf.flows[i]
end

"""
$(TYPEDSIGNATURES)

Get the switching time at index i.

# Arguments
- `mpf::MultiPhaseStateFlow`: The multi-phase state flow.
- `i::Int`: Switching time index (1-based).

# Returns
- `Real`: The switching time.
"""
function get_switching_time(mpf::MultiPhaseStateFlow, i::Int)
    return mpf.switching_times[i]
end

"""
$(TYPEDSIGNATURES)

Get the switching time at index i.

# Arguments
- `mpf::MultiPhaseHamiltonianFlow`: The multi-phase Hamiltonian flow.
- `i::Int`: Switching time index (1-based).

# Returns
- `Real`: The switching time.
"""
function get_switching_time(mpf::MultiPhaseHamiltonianFlow, i::Int)
    return mpf.switching_times[i]
end

"""
$(TYPEDSIGNATURES)

Get the jump at index i.

# Arguments
- `mpf::MultiPhaseStateFlow`: The multi-phase state flow.
- `i::Int`: Jump index (1-based).

# Returns
- The jump value (may be `nothing` if no jump).
"""
function get_jump(mpf::MultiPhaseStateFlow, i::Int)
    return mpf.jumps[i]
end

"""
$(TYPEDSIGNATURES)

Get the jump at index i.

# Arguments
- `mpf::MultiPhaseHamiltonianFlow`: The multi-phase Hamiltonian flow.
- `i::Int`: Jump index (1-based).

# Returns
- The jump value (may be `nothing` if no jump).
"""
function get_jump(mpf::MultiPhaseHamiltonianFlow, i::Int)
    return mpf.jumps[i]
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
