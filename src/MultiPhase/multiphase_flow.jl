"""
$(TYPEDEF)

Multi-phase flow for state systems.

Concatenates multiple state flows with switching times and optional jumps for
sequential integration. Each phase uses its own flow (system + integrator).

# Type Parameters
- `TD <: TimeDependence`: Time dependence trait (Autonomous or NonAutonomous)
- `VD <: VariableDependence`: Variable dependence trait (Fixed or NonFixed)
- `S <: AbstractStateSystem{TD, VD}`: The state system type
- `I <: AbstractIntegrator`: The integrator type

# Fields
- `flows::Vector{StateFlow{TD, VD, S, I}}`: Vector of state flows for each phase
- `switching_times::Vector{<:Real}`: Switching times between phases
- `jumps::Vector{<:Any}`: Optional jump functions applied at switching times

# Example
\`\`\`julia
using CTFlows.MultiPhase, CTFlows.Flows

flow1 = StateFlow(system1, integrator1)
flow2 = StateFlow(system2, integrator2)
mpf = MultiPhaseStateFlow([flow1, flow2], [1.0], [nothing])
\`\`\`

See also: [`CTFlows.MultiPhase.MultiPhaseHamiltonianFlow`](@ref), [`CTFlows.Flows.StateFlow`](@ref).
"""
struct MultiPhaseStateFlow{TD<:Common.TimeDependence, VD<:Common.VariableDependence, S<:Systems.AbstractStateSystem{TD, VD}, I<:Integrators.AbstractIntegrator} <: Flows.AbstractStateFlow{TD, VD, S}
    flows::Vector{Flows.StateFlow{TD, VD, S, I}}
    switching_times::Vector{<:Real}
    jumps::Vector{<:Any}
end

"""
$(TYPEDEF)

Multi-phase flow for Hamiltonian systems.

Concatenates multiple Hamiltonian flows with switching times and optional jumps for
sequential integration. Each phase uses its own flow (system + integrator).

# Type Parameters
- `TD <: TimeDependence`: Time dependence trait (Autonomous or NonAutonomous)
- `VD <: VariableDependence`: Variable dependence trait (Fixed or NonFixed)
- `S <: AbstractHamiltonianSystem{TD, VD}`: The Hamiltonian system type
- `I <: AbstractIntegrator`: The integrator type

# Fields
- `flows::Vector{HamiltonianFlow{TD, VD, S, I}}`: Vector of Hamiltonian flows for each phase
- `switching_times::Vector{<:Real}`: Switching times between phases
- `jumps::Vector{<:Any}`: Optional jump functions applied at switching times

# Example
\`\`\`julia
using CTFlows.MultiPhase, CTFlows.Flows

flow1 = HamiltonianFlow(system1, integrator1)
flow2 = HamiltonianFlow(system2, integrator2)
mpf = MultiPhaseHamiltonianFlow([flow1, flow2], [1.0], [nothing])
\`\`\`

See also: [`CTFlows.MultiPhase.MultiPhaseStateFlow`](@ref), [`CTFlows.Flows.HamiltonianFlow`](@ref).
"""
struct MultiPhaseHamiltonianFlow{TD<:Common.TimeDependence, VD<:Common.VariableDependence, S<:Systems.AbstractHamiltonianSystem{TD, VD}, I<:Integrators.AbstractIntegrator} <: Flows.AbstractHamiltonianFlow{TD, VD, S}
    flows::Vector{Flows.HamiltonianFlow{TD, VD, S, I}}
    switching_times::Vector{<:Real}
    jumps::Vector{<:Any}
end

"""
$(TYPEDSIGNATURES)

Return the systems associated with a multi-phase state flow.

# Arguments
- `mpsf::MultiPhaseStateFlow`: The multi-phase state flow.

# Returns
- `Vector{S}`: Vector of systems for each phase.

# Example
\`\`\`julia
using CTFlows.MultiPhase

systems = Flows.system(mpf)  # Returns vector of systems
\`\`\`

See also: [`CTFlows.MultiPhase.MultiPhaseStateFlow`](@ref), [`CTFlows.Flows.system`](@ref).
"""
function Flows.system(mpsf::MultiPhaseStateFlow)
    return [Flows.system(f) for f in mpsf.flows]
end

"""
$(TYPEDSIGNATURES)

Return the systems associated with a multi-phase Hamiltonian flow.

# Arguments
- `mphf::MultiPhaseHamiltonianFlow`: The multi-phase Hamiltonian flow.

# Returns
- `Vector{S}`: Vector of systems for each phase.

# Example
\`\`\`julia
using CTFlows.MultiPhase

systems = Flows.system(mpf)  # Returns vector of systems
\`\`\`

See also: [`CTFlows.MultiPhase.MultiPhaseHamiltonianFlow`](@ref), [`CTFlows.Flows.system`](@ref).
"""
function Flows.system(mphf::MultiPhaseHamiltonianFlow)
    return [Flows.system(f) for f in mphf.flows]
end

"""
$(TYPEDSIGNATURES)

Return the integrators associated with a multi-phase state flow.

# Arguments
- `mpsf::MultiPhaseStateFlow`: The multi-phase state flow.

# Returns
- `Vector{I}`: Vector of integrators for each phase.

# Example
\`\`\`julia
using CTFlows.MultiPhase

integrators = Flows.integrator(mpf)  # Returns vector of integrators
\`\`\`

See also: [`CTFlows.MultiPhase.MultiPhaseStateFlow`](@ref), [`CTFlows.Flows.integrator`](@ref).
"""
function Flows.integrator(mpsf::MultiPhaseStateFlow)
    return [Flows.integrator(f) for f in mpsf.flows]
end

"""
$(TYPEDSIGNATURES)

Return the integrators associated with a multi-phase Hamiltonian flow.

# Arguments
- `mphf::MultiPhaseHamiltonianFlow`: The multi-phase Hamiltonian flow.

# Returns
- `Vector{I}`: Vector of integrators for each phase.

# Example
\`\`\`julia
using CTFlows.MultiPhase

integrators = Flows.integrator(mpf)  # Returns vector of integrators
\`\`\`

See also: [`CTFlows.MultiPhase.MultiPhaseHamiltonianFlow`](@ref), [`CTFlows.Flows.integrator`](@ref).
"""
function Flows.integrator(mphf::MultiPhaseHamiltonianFlow)
    return [Flows.integrator(f) for f in mphf.flows]
end

# ==============================================================================
# Getter methods for encapsulation
# ==============================================================================

const AnyMultiPhaseFlow = Union{MultiPhaseStateFlow, MultiPhaseHamiltonianFlow}

"""
$(TYPEDSIGNATURES)

Get the number of phases in a multi-phase flow.

# Arguments
- `mpf::AnyMultiPhaseFlow`: The multi-phase flow.

# Returns
- `Int`: Number of phases.
"""
function n_phases(mpf::AnyMultiPhaseFlow)
    return length(mpf.flows)
end

"""
$(TYPEDSIGNATURES)

Get the flow at phase index i.

# Arguments
- `mpf::AnyMultiPhaseFlow`: The multi-phase flow.
- `i::Int`: Phase index (1-based).

# Returns
- The flow at phase i (StateFlow or HamiltonianFlow).
"""
function get_flow(mpf::AnyMultiPhaseFlow, i::Int)
    return mpf.flows[i]
end

"""
$(TYPEDSIGNATURES)

Get the switching time at index i.

# Arguments
- `mpf::AnyMultiPhaseFlow`: The multi-phase flow.
- `i::Int`: Switching time index (1-based).

# Returns
- `Real`: The switching time.
"""
function get_switching_time(mpf::AnyMultiPhaseFlow, i::Int)
    return mpf.switching_times[i]
end

"""
$(TYPEDSIGNATURES)

Get the jump at index i.

# Arguments
- `mpf::AnyMultiPhaseFlow`: The multi-phase flow.
- `i::Int`: Jump index (1-based).

# Returns
- The jump value (may be `nothing` if no jump).
"""
function get_jump(mpf::AnyMultiPhaseFlow, i::Int)
    return mpf.jumps[i]
end

# ==============================================================================
# Base.show
# ==============================================================================

"""
$(TYPEDSIGNATURES)

Display a multi-phase flow in REPL format.

Shows the type name, number of phases, systems, integrators, switching times, and jumps.

# Arguments
- `io::IO`: The IO stream to write to.
- `::MIME"text/plain"`: The MIME type for REPL display.
- `mpf::AnyMultiPhaseFlow`: The multi-phase flow to display.
"""
function Base.show(io::IO, ::MIME"text/plain", mpf::AnyMultiPhaseFlow)
    print(io, nameof(typeof(mpf)))
    print(io, "\n  phases: ", length(mpf.flows))
    print(io, "\n  systems: ", typeof(Flows.system(mpf)))
    print(io, "\n  integrators: ", typeof(Flows.integrator(mpf)))
    print(io, "\n  switching_times: ", mpf.switching_times)
    print(io, "\n  jumps: ", mpf.jumps)
end

"""
$(TYPEDSIGNATURES)

Compact display of a multi-phase flow.

Shows the type name, number of phases, and switching times.

# Arguments
- `io::IO`: The IO stream to write to.
- `mpf::AnyMultiPhaseFlow`: The multi-phase flow to display.
"""
function Base.show(io::IO, mpf::AnyMultiPhaseFlow)
    print(io, nameof(typeof(mpf)), "(")
    parts = String[]
    push!(parts, "phases=$(length(mpf.flows))")
    push!(parts, "switching_times=$(mpf.switching_times)")
    print(io, join(parts, ", "))
    print(io, ")")
end
