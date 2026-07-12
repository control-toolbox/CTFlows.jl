"""
$(TYPEDEF)

Concrete multi-phase flow combining multiple flows of the same dynamics family
with switching times and optional jumps.

The dynamics axis is encoded in `D`, following the same pattern as `Flow`:
- `D = StateDynamics`       → state multi-phase flow (alias `MultiPhaseStateFlow`)
- `D = HamiltonianDynamics` → Hamiltonian multi-phase flow (alias `MultiPhaseHamiltonianFlow`)

`flows` is a **heterogeneous tuple**, lifting the previous homogeneous-`S`/`I`
constraint: phases may wrap systems and integrators of different concrete types.

# Type Parameters
- `TD <: TimeDependence`: Time dependence trait (Autonomous or NonAutonomous)
- `VD <: VariableDependence`: Variable dependence trait (Fixed or NonFixed)
- `D  <: AbstractDynamicsTrait`: Dynamics trait (`StateDynamics` or `HamiltonianDynamics`)
- `FS <: Tuple`: Tuple of `AbstractFlow{TD,VD,D}` (heterogeneous allowed)
- `ST <: Vector{<:Real}`: Type of the switching times vector
- `J  <: Vector{<:Any}`: Type of the jumps vector

# Fields
- `flows::FS`: Tuple of flows for each phase
- `switching_times::ST`: Switching times between phases
- `jumps::J`: Optional jump functions applied at switching times

See also: [`CTFlows.MultiPhase.MultiPhaseStateFlow`](@ref),
[`CTFlows.MultiPhase.MultiPhaseHamiltonianFlow`](@ref), [`CTFlows.Flows.Flow`](@ref).
"""
struct MultiPhaseFlow{
    TD<:Traits.TimeDependence,
    VD<:Traits.VariableDependence,
    D<:Traits.AbstractDynamicsTrait,
    FS<:Tuple,
    ST<:Vector{<:Real},
    J<:Vector{<:Any},
} <: Flows.AbstractFlow{TD,VD,D}
    flows::FS
    switching_times::ST
    jumps::J
end

"""
$(TYPEDEF)

Alias for state multi-phase flows: `MultiPhaseFlow{TD,VD,StateDynamics,FS,ST,J}`.

See also: [`CTFlows.MultiPhase.MultiPhaseFlow`](@ref), [`CTFlows.MultiPhase.MultiPhaseHamiltonianFlow`](@ref).
"""
const MultiPhaseStateFlow{
    TD<:Traits.TimeDependence,
    VD<:Traits.VariableDependence,
    FS<:Tuple,
    ST<:Vector{<:Real},
    J<:Vector{<:Any},
} = MultiPhaseFlow{TD,VD,Traits.StateDynamics,FS,ST,J}

"""
$(TYPEDEF)

Alias for Hamiltonian multi-phase flows: `MultiPhaseFlow{TD,VD,HamiltonianDynamics,FS,ST,J}`.

See also: [`CTFlows.MultiPhase.MultiPhaseFlow`](@ref), [`CTFlows.MultiPhase.MultiPhaseStateFlow`](@ref).
"""
const MultiPhaseHamiltonianFlow{
    TD<:Traits.TimeDependence,
    VD<:Traits.VariableDependence,
    FS<:Tuple,
    ST<:Vector{<:Real},
    J<:Vector{<:Any},
} = MultiPhaseFlow{TD,VD,Traits.HamiltonianDynamics,FS,ST,J}

function MultiPhaseStateFlow(
    flows::FS, switching_times::ST, jumps::J
) where {FS<:Tuple,ST,J}
    f1 = flows[1]
    return MultiPhaseFlow{
        Traits.time_dependence(f1),
        Traits.variable_dependence(f1),
        Traits.StateDynamics,
        FS,
        ST,
        J,
    }(
        flows, switching_times, jumps
    )
end

function MultiPhaseHamiltonianFlow(
    flows::FS, switching_times::ST, jumps::J
) where {FS<:Tuple,ST,J}
    f1 = flows[1]
    return MultiPhaseFlow{
        Traits.time_dependence(f1),
        Traits.variable_dependence(f1),
        Traits.HamiltonianDynamics,
        FS,
        ST,
        J,
    }(
        flows, switching_times, jumps
    )
end

"""
$(TYPEDEF)

Type alias for any multi-phase flow.

See also: [`CTFlows.MultiPhase.MultiPhaseStateFlow`](@ref), [`CTFlows.MultiPhase.MultiPhaseHamiltonianFlow`](@ref).
"""
const AnyMultiPhaseFlow = MultiPhaseFlow

"""
$(TYPEDSIGNATURES)

Return the systems associated with a multi-phase flow as a tuple.

See also: [`CTFlows.Flows.system`](@ref).
"""
function Flows.system(mpsf::MultiPhaseFlow)
    return map(Flows.system, mpsf.flows)
end

"""
$(TYPEDSIGNATURES)

Return the integrators associated with a multi-phase flow as a tuple.

See also: [`CTFlows.Flows.integrator`](@ref).
"""
function Flows.integrator(mpsf::MultiPhaseFlow)
    return map(Flows.integrator, mpsf.flows)
end

# ==============================================================================
# Getter methods for encapsulation
# ==============================================================================

"""
$(TYPEDSIGNATURES)

Return the number of phases in a multi-phase flow.

# Arguments
- `mpf::MultiPhaseFlow`: The multi-phase flow.

# Returns
- `Int`: Number of phases.

See also: [`CTFlows.MultiPhase.get_flow`](@ref), [`CTFlows.MultiPhase.get_switching_time`](@ref).
"""
function n_phases(mpf::MultiPhaseFlow)
    return length(mpf.flows)
end

"""
$(TYPEDSIGNATURES)

Return the flow for a specific phase.

# Arguments
- `mpf::MultiPhaseFlow`: The multi-phase flow.
- `i::Int`: Phase index (1-based).

# Returns
- `AbstractFlow`: The flow for phase `i`.

See also: [`CTFlows.MultiPhase.n_phases`](@ref), [`CTFlows.MultiPhase.get_switching_time`](@ref).
"""
function get_flow(mpf::MultiPhaseFlow, i::Int)
    return mpf.flows[i]
end

"""
$(TYPEDSIGNATURES)

Return the switching time at a specific phase boundary.

# Arguments
- `mpf::MultiPhaseFlow`: The multi-phase flow.
- `i::Int`: Phase index (1-based). Returns the switching time between phase `i` and `i+1`.

# Returns
- `Real`: The switching time.

See also: [`CTFlows.MultiPhase.n_phases`](@ref), [`CTFlows.MultiPhase.get_flow`](@ref).
"""
function get_switching_time(mpf::MultiPhaseFlow, i::Int)
    return mpf.switching_times[i]
end

"""
$(TYPEDSIGNATURES)

Return the jump function at a specific phase boundary.

# Arguments
- `mpf::MultiPhaseFlow`: The multi-phase flow.
- `i::Int`: Phase index (1-based). Returns the jump applied after phase `i`.

# Returns
- `Union{Nothing, Function, Tuple}`: The jump function, or `nothing` if no jump is defined.

See also: [`CTFlows.MultiPhase.n_phases`](@ref), [`CTFlows.MultiPhase.get_flow`](@ref).
"""
function get_jump(mpf::MultiPhaseFlow, i::Int)
    return mpf.jumps[i]
end

# ==============================================================================
# Helper methods for concatenation (abstract flow interface)
# ==============================================================================

"""
$(TYPEDSIGNATURES)

Get the flows from a single-phase flow as a 1-tuple.
"""
function get_flows(f::Flows.AbstractFlow)
    return (f,)
end

"""
$(TYPEDSIGNATURES)

Get the switching times from a single-phase flow (empty vector).
"""
function get_switching_times(::Flows.AbstractFlow)
    return Real[]
end

"""
$(TYPEDSIGNATURES)

Get the jumps from a single-phase flow (empty vector).
"""
function get_jumps(::Flows.AbstractFlow)
    return Any[]
end

"""
$(TYPEDSIGNATURES)

Get the flows tuple from a multi-phase flow.
"""
function get_flows(mpf::MultiPhaseFlow)
    return mpf.flows
end

"""
$(TYPEDSIGNATURES)

Get the switching times from a multi-phase flow.
"""
function get_switching_times(mpf::MultiPhaseFlow)
    return mpf.switching_times
end

"""
$(TYPEDSIGNATURES)

Get the jumps from a multi-phase flow.
"""
function get_jumps(mpf::MultiPhaseFlow)
    return mpf.jumps
end

# ==============================================================================
# Base.show
# ==============================================================================

"""
Return a human-readable display name for a `MultiPhaseFlow`, dispatching on the dynamics trait.

- `StateDynamics` → `"MultiPhaseStateFlow"`
- `HamiltonianDynamics` → `"MultiPhaseHamiltonianFlow"`
- Fallback → `string(nameof(typeof(mpf)))`

See also: [`CTFlows.MultiPhase.MultiPhaseFlow`](@ref).
"""
function _multiphase_display_name(
    ::MultiPhaseFlow{
        <:Traits.TimeDependence,<:Traits.VariableDependence,Traits.StateDynamics
    },
)
    return "MultiPhaseStateFlow"
end
function _multiphase_display_name(
    ::MultiPhaseFlow{
        <:Traits.TimeDependence,<:Traits.VariableDependence,Traits.HamiltonianDynamics
    },
)
    return "MultiPhaseHamiltonianFlow"
end
function _multiphase_display_name(mpf::MultiPhaseFlow)
    return string(nameof(typeof(mpf)))
end

"""
$(TYPEDSIGNATURES)

Display a multi-phase flow in a human-readable format.

# Arguments
- `io::IO`: IO stream.
- `::MIME"text/plain"`: MIME type for pretty printing.
- `mpf::MultiPhaseFlow`: The multi-phase flow to display.

# Notes
- Shows the flow type, number of phases, systems, integrators, switching times, and jumps.
- Used by the REPL for interactive display.
"""
function Base.show(io::IO, ::MIME"text/plain", mpf::MultiPhaseFlow)
    fmt = Display.format_codes(io)
    Display.print_header(io, _multiphase_display_name(mpf); fmt=fmt)
    Display.print_field(io, "phases", length(mpf.flows); fmt=fmt, value_style=fmt.count)
    sys = Flows.system(mpf)
    if !isempty(sys)
        Display.print_field(
            io, "systems", join(map(s -> string(nameof(typeof(s))), sys), ", "); fmt=fmt
        )
    end
    integ = Flows.integrator(mpf)
    if !isempty(integ)
        Display.print_field(
            io,
            "integrators",
            join(map(i -> string(nameof(typeof(i))), integ), ", ");
            fmt=fmt,
        )
    end
    Display.print_field(io, "switching_times", mpf.switching_times; fmt=fmt)
    return Display.print_field(io, "jumps", mpf.jumps; last=true, fmt=fmt)
end

"""
$(TYPEDSIGNATURES)

Display a multi-phase flow in a compact single-line format.

# Arguments
- `io::IO`: IO stream.
- `mpf::MultiPhaseFlow`: The multi-phase flow to display.

# Notes
- Shows the flow type, number of phases, and switching times in a compact form.
- Used when the flow is embedded in other output.
"""
function Base.show(io::IO, mpf::MultiPhaseFlow)
    fmt = Display.format_codes(io)
    print(io, fmt.name, _multiphase_display_name(mpf), fmt.reset, "(")
    parts = String[]
    push!(parts, "phases=$(length(mpf.flows))")
    push!(parts, "switching_times=$(mpf.switching_times)")
    print(io, join(parts, ", "))
    return print(io, ")")
end
