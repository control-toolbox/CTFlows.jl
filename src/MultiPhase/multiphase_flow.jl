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
struct MultiPhaseStateFlow{
        TD<:Common.TimeDependence, 
        VD<:Common.VariableDependence, 
        S<:Systems.AbstractStateSystem{TD, VD}, 
        I<:Integrators.AbstractIntegrator,
        ST<:Vector{<:Real},
        J<:Vector{<:Any}} <: Flows.AbstractStateFlow{TD, VD, S}
    flows::Vector{Flows.StateFlow{TD, VD, S, I}}
    switching_times::ST
    jumps::J
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
struct MultiPhaseHamiltonianFlow{
        TD<:Common.TimeDependence, 
        VD<:Common.VariableDependence, 
        S<:Systems.AbstractHamiltonianSystem{TD, VD}, 
        I<:Integrators.AbstractIntegrator,
        ST<:Vector{<:Real},
        J<:Vector{<:Any}} <: Flows.AbstractHamiltonianFlow{TD, VD, S}
    flows::Vector{Flows.HamiltonianFlow{TD, VD, S, I}}
    switching_times::ST
    jumps::J
end

const AnyMultiPhaseFlow = Union{MultiPhaseStateFlow, MultiPhaseHamiltonianFlow}

"""
$(TYPEDSIGNATURES)

Return the systems associated with a multi-phase state flow.

# Arguments
- `mpsf::Union{MultiPhaseStateFlow, MultiPhaseHamiltonianFlow}`: The multi-phase state flow.

# Returns
- `Vector{S}`: Vector of systems for each phase.

# Example
\`\`\`julia
using CTFlows.MultiPhase

systems = Flows.system(mpf)  # Returns vector of systems
\`\`\`

See also: [`CTFlows.MultiPhase.MultiPhaseStateFlow`](@ref), [`CTFlows.MultiPhase.MultiPhaseHamiltonianFlow`](@ref), [`CTFlows.Flows.system`](@ref).
"""
function Flows.system(mpsf::AnyMultiPhaseFlow)
    return [Flows.system(f) for f in mpsf.flows]
end

"""
$(TYPEDSIGNATURES)

Return the integrators associated with a multi-phase state flow.

# Arguments
- `mpsf::Union{MultiPhaseStateFlow, MultiPhaseHamiltonianFlow}`: The multi-phase state flow.

# Returns
- `Vector{I}`: Vector of integrators for each phase.

# Example
\`\`\`julia
using CTFlows.MultiPhase

integrators = Flows.integrator(mpf)  # Returns vector of integrators
\`\`\`

See also: [`CTFlows.MultiPhase.MultiPhaseStateFlow`](@ref), [`CTFlows.MultiPhase.MultiPhaseHamiltonianFlow`](@ref), [`CTFlows.Flows.integrator`](@ref).
"""
function Flows.integrator(mpsf::AnyMultiPhaseFlow)
    return [Flows.integrator(f) for f in mpsf.flows]
end

# ==============================================================================
# Getter methods for encapsulation
# ==============================================================================

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
# Helper methods for concatenation (abstract flow interface)
# ==============================================================================

"""
$(TYPEDSIGNATURES)

Get the flows from a single-phase flow.

For single-phase flows (StateFlow, HamiltonianFlow), returns a single-element vector
containing the flow itself. This uniform interface enables concatenation with
multi-phase flows.

# Arguments
- `f::AbstractFlow`: The single-phase flow.

# Returns
- `Vector`: A single-element vector containing the flow.

# Example
\`\`\`julia
using CTFlows.Flows, CTFlows.MultiPhase

flow = StateFlow(system, integrator)
flows = get_flows(flow)  # Returns [flow]
\`\`\`

See also: [`CTFlows.MultiPhase.get_flows(::AnyMultiPhaseFlow)`](@ref), [`CTFlows.MultiPhase.get_switching_times`](@ref).
"""
function get_flows(f::Flows.AbstractFlow)
    return [f]
end

"""
$(TYPEDSIGNATURES)

Get the switching times from a single-phase flow.

For single-phase flows, returns an empty vector since there are no switching times.

# Arguments
- `f::AbstractFlow`: The single-phase flow.

# Returns
- `Vector{Real}`: An empty vector.

# Example
\`\`\`julia
using CTFlows.Flows, CTFlows.MultiPhase

flow = StateFlow(system, integrator)
times = get_switching_times(flow)  # Returns Real[]
\`\`\`

See also: [`CTFlows.MultiPhase.get_switching_times(::AnyMultiPhaseFlow)`](@ref), [`CTFlows.MultiPhase.get_flows`](@ref).
"""
function get_switching_times(f::Flows.AbstractFlow)
    return Real[]
end

"""
$(TYPEDSIGNATURES)

Get the jumps from a single-phase flow.

For single-phase flows, returns an empty vector since there are no jumps.

# Arguments
- `f::AbstractFlow`: The single-phase flow.

# Returns
- `Vector{Any}`: An empty vector.

# Example
\`\`\`julia
using CTFlows.Flows, CTFlows.MultiPhase

flow = StateFlow(system, integrator)
jumps = get_jumps(flow)  # Returns Any[]
\`\`\`

See also: [`CTFlows.MultiPhase.get_jumps(::AnyMultiPhaseFlow)`](@ref), [`CTFlows.MultiPhase.get_flows`](@ref).
"""
function get_jumps(f::Flows.AbstractFlow)
    return Any[]
end

"""
$(TYPEDSIGNATURES)

Get the flows from a multi-phase flow.

For multi-phase flows, returns the vector of flows for all phases.

# Arguments
- `mpf::AnyMultiPhaseFlow`: The multi-phase flow.

# Returns
- `Vector`: The vector of flows for each phase.

# Example
\`\`\`julia
using CTFlows.MultiPhase

flows = get_flows(mpf)  # Returns mpf.flows
\`\`\`

See also: [`CTFlows.MultiPhase.get_flows(::AbstractFlow)`](@ref), [`CTFlows.MultiPhase.get_switching_times`](@ref).
"""
function get_flows(mpf::AnyMultiPhaseFlow)
    return mpf.flows
end

"""
$(TYPEDSIGNATURES)

Get the switching times from a multi-phase flow.

For multi-phase flows, returns the vector of switching times between phases.

# Arguments
- `mpf::AnyMultiPhaseFlow`: The multi-phase flow.

# Returns
- `Vector{<:Real}`: The vector of switching times.

# Example
\`\`\`julia
using CTFlows.MultiPhase

times = get_switching_times(mpf)  # Returns mpf.switching_times
\`\`\`

See also: [`CTFlows.MultiPhase.get_switching_times(::AbstractFlow)`](@ref), [`CTFlows.MultiPhase.get_flows`](@ref).
"""
function get_switching_times(mpf::AnyMultiPhaseFlow)
    return mpf.switching_times
end

"""
$(TYPEDSIGNATURES)

Get the jumps from a multi-phase flow.

For multi-phase flows, returns the vector of jump functions applied at switching times.

# Arguments
- `mpf::AnyMultiPhaseFlow`: The multi-phase flow.

# Returns
- `Vector{<:Any}`: The vector of jump functions (may contain `nothing` for no jump).

# Example
\`\`\`julia
using CTFlows.MultiPhase

jumps = get_jumps(mpf)  # Returns mpf.jumps
\`\`\`

See also: [`CTFlows.MultiPhase.get_jumps(::AbstractFlow)`](@ref), [`CTFlows.MultiPhase.get_flows`](@ref).
"""
function get_jumps(mpf::AnyMultiPhaseFlow)
    return mpf.jumps
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
