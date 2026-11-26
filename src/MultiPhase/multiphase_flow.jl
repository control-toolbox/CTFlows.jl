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

See also: [`CTFlows.MultiPhase.MultiPhaseStateFlow`](@extref),
[`CTFlows.MultiPhase.MultiPhaseHamiltonianFlow`](@extref), [`CTFlows.Flows.Flow`](@extref).
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

See also: [`CTFlows.MultiPhase.MultiPhaseFlow`](@extref), [`CTFlows.MultiPhase.MultiPhaseHamiltonianFlow`](@extref).
"""
const MultiPhaseStateFlow{TD<:Traits.TimeDependence,VD<:Traits.VariableDependence,FS<:Tuple,ST<:Vector{<:Real},J<:Vector{<:Any}} = MultiPhaseFlow{
    TD,VD,Traits.StateDynamics,FS,ST,J
}

"""
$(TYPEDEF)

Alias for Hamiltonian multi-phase flows: `MultiPhaseFlow{TD,VD,HamiltonianDynamics,FS,ST,J}`.

See also: [`CTFlows.MultiPhase.MultiPhaseFlow`](@extref), [`CTFlows.MultiPhase.MultiPhaseStateFlow`](@extref).
"""
const MultiPhaseHamiltonianFlow{TD<:Traits.TimeDependence,VD<:Traits.VariableDependence,FS<:Tuple,ST<:Vector{<:Real},J<:Vector{<:Any}} = MultiPhaseFlow{
    TD,VD,Traits.HamiltonianDynamics,FS,ST,J
}

"""
$(TYPEDSIGNATURES)

Construct a `MultiPhaseStateFlow` from a tuple of flows, switching times, and jumps.

The time and variable dependence traits are inferred from the first flow.

# Arguments
- `flows::Tuple`: Tuple of phase flows (each `<: Flows.AbstractStateFlow`).
- `switching_times::Vector{<:Real}`: Switching times between phases.
- `jumps::Vector{<:Any}`: Jump conditions at each switching time.

# Returns
- A `MultiPhaseFlow` with `StateDynamics` trait.

See also: [`CTFlows.MultiPhase.MultiPhaseFlow`](@extref), [`CTFlows.MultiPhase.MultiPhaseHamiltonianFlow`](@extref).
"""
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

"""
$(TYPEDSIGNATURES)

Construct a `MultiPhaseHamiltonianFlow` from a tuple of flows, switching times, and jumps.

The time and variable dependence traits are inferred from the first flow.

# Arguments
- `flows::Tuple`: Tuple of phase flows (each `<: Flows.AbstractHamiltonianFlow`).
- `switching_times::Vector{<:Real}`: Switching times between phases.
- `jumps::Vector{<:Any}`: Jump conditions at each switching time.

# Returns
- A `MultiPhaseFlow` with `HamiltonianDynamics` trait.

See also: [`CTFlows.MultiPhase.MultiPhaseFlow`](@extref), [`CTFlows.MultiPhase.MultiPhaseStateFlow`](@extref).
"""
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

See also: [`CTFlows.MultiPhase.MultiPhaseStateFlow`](@extref), [`CTFlows.MultiPhase.MultiPhaseHamiltonianFlow`](@extref).
"""
const AnyMultiPhaseFlow = MultiPhaseFlow

"""
$(TYPEDSIGNATURES)

Return the systems associated with a multi-phase flow as a tuple.

See also: [`CTFlows.Flows.system`](@extref).
"""
function Flows.system(mpsf::MultiPhaseFlow)
    return map(Flows.system, mpsf.flows)
end

"""
$(TYPEDSIGNATURES)

Return the integrators associated with a multi-phase flow as a tuple.

See also: [`CTFlows.Flows.integrator`](@extref).
"""
function Flows.integrator(mpsf::MultiPhaseFlow)
    return map(Flows.integrator, mpsf.flows)
end

# ==============================================================================
# Getter methods for encapsulation
# ==============================================================================

"""
$(TYPEDSIGNATURES)

Return the number of phases of a flow: `1` for a single flow, the number of concatenated
flows for a multi-phase flow.

# Arguments
- `f`: a flow, single-phase or multi-phase.

# Returns
- `Int`: the number of phases.

See also: [`CTFlows.MultiPhase.phase_flows`](@extref), [`CTFlows.MultiPhase.switching_times`](@extref).
"""
n_phases(mpf::MultiPhaseFlow)::Int = length(mpf.flows)
n_phases(::Flows.AbstractFlow)::Int = 1

"""
$(TYPEDSIGNATURES)

Return the flows of the phases of a flow, in order: a 1-tuple for a single flow, the
concatenated flows for a multi-phase flow. The flow of phase `i` is `phase_flows(f)[i]`.

# Arguments
- `f`: a flow, single-phase or multi-phase.

# Returns
- `Tuple`: the flows of the phases.

See also: [`CTFlows.MultiPhase.n_phases`](@extref), [`CTFlows.MultiPhase.switching_times`](@extref),
[`CTFlows.MultiPhase.jumps`](@extref).
"""
phase_flows(f::Flows.AbstractFlow) = (f,)
phase_flows(mpf::MultiPhaseFlow) = mpf.flows

"""
$(TYPEDSIGNATURES)

Return the switching times of a flow: empty for a single flow; for a multi-phase flow, the
time between phase `i` and phase `i + 1` is `switching_times(f)[i]`.

This is a method of [`CTModels.Solutions.switching_times`](@extref), the function that reads
the switching times of a solution: the same name for a flow and for what it returns. The
times keep their type (a `ForwardDiff.Dual` while a shooting function is differentiated).

# Arguments
- `f`: a flow, single-phase or multi-phase.

# Returns
- `AbstractVector{<:Real}`: the switching times.

See also: [`CTFlows.MultiPhase.n_phases`](@extref), [`CTFlows.MultiPhase.jumps`](@extref).
"""
switching_times(::Flows.AbstractFlow) = Real[]
switching_times(mpf::MultiPhaseFlow) = mpf.switching_times

"""
$(TYPEDSIGNATURES)

Return the jumps of a flow: empty for a single flow; for a multi-phase flow, the jump applied
at the switching time after phase `i` is `jumps(f)[i]` (`nothing` for no jump).

# Arguments
- `f`: a flow, single-phase or multi-phase.

# Returns
- `AbstractVector`: the jumps.

See also: [`CTFlows.MultiPhase.switching_times`](@extref), [`CTFlows.MultiPhase.phase_flows`](@extref).
"""
jumps(::Flows.AbstractFlow) = Any[]
jumps(mpf::MultiPhaseFlow) = mpf.jumps

"""
$(TYPEDSIGNATURES)

Return the labels of the phases of a flow, one per phase (`""` for a phase with no label),
given with `Flow(...; label="bang")`. Concatenation keeps the phases' flows, so their labels
are kept in order.

This is a method of [`CTModels.Solutions.phase_labels`](@extref), the function that reads the
labels of the phases of a solution.

# Example
\`\`\`julia
using CTFlows: Flows, MultiPhase

f1 = Flows.Flow(ocp, u_max; label="bang+")
f2 = Flows.Flow(ocp, u_min; label="bang-")
MultiPhase.phase_labels(f1 * (0.5, f2))   # ["bang+", "bang-"]
\`\`\`

See also: [`CTFlows.Flows.label`](@extref), [`CTFlows.MultiPhase.phase_flows`](@extref).
"""
phase_labels(f::Flows.AbstractFlow)::Vector{String} = String[Flows.label(f)]
phase_labels(mpf::MultiPhaseFlow)::Vector{String} = String[Flows.label(f) for f in mpf.flows]

# ==============================================================================
# Base.show
# ==============================================================================

"""
Return a human-readable display name for a `MultiPhaseFlow`, dispatching on the dynamics trait.

- `StateDynamics` → `"MultiPhaseStateFlow"`
- `HamiltonianDynamics` → `"MultiPhaseHamiltonianFlow"`
- Fallback → `string(nameof(typeof(mpf)))`

See also: [`CTFlows.MultiPhase.MultiPhaseFlow`](@extref).
"""
function _multiphase_display_name(
    ::MultiPhaseFlow{
        <:Traits.TimeDependence,<:Traits.VariableDependence,Traits.StateDynamics
    },
)
    return "MultiPhaseStateFlow"
end

"""
$(TYPEDSIGNATURES)

Return `"MultiPhaseHamiltonianFlow"` for a `MultiPhaseFlow` with `HamiltonianDynamics`.
"""
function _multiphase_display_name(
    ::MultiPhaseFlow{
        <:Traits.TimeDependence,<:Traits.VariableDependence,Traits.HamiltonianDynamics
    },
)
    return "MultiPhaseHamiltonianFlow"
end

"""
$(TYPEDSIGNATURES)

Fallback: return the concrete type name as a string.
"""
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
- Shows the flow type, number of phases, systems, integrators, switching times, phase labels
  (when at least one phase is labelled; an unlabelled phase shows as `·`), and jumps.
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
    labels = phase_labels(mpf)
    if any(!isempty, labels)
        Display.print_field(io, "labels", Trajectories._phase_sequence(labels); fmt=fmt)
    end
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
