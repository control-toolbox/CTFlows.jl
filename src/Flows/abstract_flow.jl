"""
$(TYPEDEF)

Abstract type for all flows in CTFlows.

An `AbstractFlow` is a callable object that combines an `AbstractSystem` with an
`AbstractIntegrator`. It carries no business logic of its own — its job is
to expose the integration protocol.

# Interface Requirements

All subtypes must implement:
- `system(flow::AbstractFlow)`: Return the associated `AbstractSystem`.
- `integrator(flow::AbstractFlow)`: Return the associated `AbstractIntegrator`.

# Traits

All `AbstractFlow` subtypes automatically support time-dependence and variable-dependence
trait queries encoded in their type parameters:
- `time_dependence(flow)`: Returns the time-dependence trait type.
- `variable_dependence(flow)`: Returns the variable-dependence trait type.
- `is_autonomous(flow)`, `is_nonautonomous(flow)`: Time-dependence predicates.
- `is_variable(flow)`, `is_nonvariable(flow)`, `has_variable(flow)`: Variable-dependence predicates.

# Example
\`\`\`julia-repl
julia> using CTFlows.Flows

julia> MyFlow <: Flows.AbstractFlow
true
\`\`\`

See also: [`CTFlows.Flows.Flow`](@ref), [`CTFlows.Systems.AbstractSystem`](@ref), [`CTSolvers.Integrators.AbstractIntegrator`](@extref).
"""
abstract type AbstractFlow{TD<:Traits.TimeDependence, VD<:Traits.VariableDependence, D<:Traits.AbstractDynamicsTrait} end

"""
$(TYPEDEF)

Alias for state flows.

Matches any `AbstractFlow` with `StateDynamics` as the dynamics parameter.

# Type Parameters
- `TD <: TimeDependence`: Time dependence trait (Autonomous or NonAutonomous)
- `VD <: VariableDependence`: Variable dependence trait (Fixed or NonFixed)

# Example
\`\`\`julia-repl
julia> using CTFlows.Flows

julia> Flow(vf) isa Flows.AbstractStateFlow
true
\`\`\`

See also: [`CTFlows.Flows.AbstractFlow`](@ref), [`CTFlows.Flows.AbstractHamiltonianFlow`](@ref).
"""
const AbstractStateFlow{TD, VD} = AbstractFlow{TD, VD, Traits.StateDynamics}

"""
$(TYPEDEF)

Alias for Hamiltonian flows.

Matches any `AbstractFlow` with `HamiltonianDynamics` as the dynamics parameter.

# Type Parameters
- `TD <: TimeDependence`: Time dependence trait (Autonomous or NonAutonomous)
- `VD <: VariableDependence`: Variable dependence trait (Fixed or NonFixed)

# Example
\`\`\`julia-repl
julia> using CTFlows.Flows

julia> Flow(hvf) isa Flows.AbstractHamiltonianFlow
true
\`\`\`

See also: [`CTFlows.Flows.AbstractFlow`](@ref), [`CTFlows.Flows.AbstractStateFlow`](@ref).
"""
const AbstractHamiltonianFlow{TD, VD} = AbstractFlow{TD, VD, Traits.HamiltonianDynamics}

"""
$(TYPEDSIGNATURES)

Indicate that `AbstractFlow` has the time-dependence trait.

# Returns
- `Bool`: Always `true` for `AbstractFlow`.

See also: `TimeDependence`, [`CTBase.Traits.time_dependence`](@ref).
"""
Traits.has_time_dependence_trait(::AbstractFlow) = true

"""
$(TYPEDSIGNATURES)

Indicate that `AbstractFlow` has the variable-dependence trait.

# Returns
- `Bool`: Always `true` for `AbstractFlow`.

See also: [`CTBase.Traits.VariableDependence`](@ref), [`CTBase.Traits.variable_dependence`](@ref).
"""
Traits.has_variable_dependence_trait(::AbstractFlow) = true

"""
$(TYPEDSIGNATURES)

Extract the time dependence trait from an `AbstractFlow`.

# Returns
- `Type{<:TimeDependence}`: The time dependence trait type (Autonomous or NonAutonomous).

# Example
\`\`\`julia
using CTFlows.Flows
using CTFlows.Common

struct MyFlow <: Flows.AbstractFlow{Traits.Autonomous, Traits.Fixed, Traits.StateDynamics}
    data::Vector{Float64}
end

Traits.time_dependence(MyFlow)  # Returns Autonomous
\`\`\`

See also: [`CTBase.Traits.has_time_dependence_trait`](@ref), `is_autonomous`, [`CTFlows.Flows.AbstractFlow`](@ref).
"""
function Traits.time_dependence(::AbstractFlow{TD, <:Traits.VariableDependence, <:Traits.AbstractDynamicsTrait}) where {TD <: Traits.TimeDependence}
    return TD
end

"""
$(TYPEDSIGNATURES)

Extract the variable dependence trait from an `AbstractFlow`.

# Returns
- `Type{<:VariableDependence}`: The variable dependence trait type (Fixed or NonFixed).

# Example
\`\`\`julia
using CTFlows.Flows
using CTFlows.Common

struct MyFlow <: Flows.AbstractFlow{Traits.Autonomous, Traits.Fixed, Traits.StateDynamics}
    data::Vector{Float64}
end

Traits.variable_dependence(MyFlow)  # Returns Fixed
\`\`\`

See also: [`CTBase.Traits.has_variable_dependence_trait`](@ref), `is_variable`, [`CTFlows.Flows.AbstractFlow`](@ref).
"""
function Traits.variable_dependence(::AbstractFlow{<:Traits.TimeDependence, VD, <:Traits.AbstractDynamicsTrait}) where {VD <: Traits.VariableDependence}
    return VD
end

"""
$(TYPEDSIGNATURES)

Extract the dynamics trait from an `AbstractFlow`.

# Returns
- `Type{<:AbstractDynamicsTrait}`: `StateDynamics` or `HamiltonianDynamics`.

See also: [`CTBase.Traits.AbstractDynamicsTrait`](@ref), [`CTFlows.Flows.AbstractStateFlow`](@ref), [`CTFlows.Flows.AbstractHamiltonianFlow`](@ref).
"""
function Traits.dynamics_trait(::AbstractFlow{<:Traits.TimeDependence, <:Traits.VariableDependence, D}) where {D <: Traits.AbstractDynamicsTrait}
    return D
end

"""
$(TYPEDSIGNATURES)

Return the automatic differentiation capability trait of a flow.

# Returns
- `Type{<:AbstractADTrait}`: The AD capability trait, either `WithAD` or `WithoutAD`.

# Notes
- Default implementation returns `WithoutAD` for all flows
- Specialized implementation on `AbstractHamiltonianFlow` delegates to the system's trait
- This trait is used for dispatch in cache preparation and augmented integration

See also: [`CTBase.Traits.AbstractADTrait`](@ref), [`CTBase.Traits.WithAD`](@ref), [`CTBase.Traits.WithoutAD`](@ref).
"""
Traits.ad_trait(::AbstractFlow) = Traits.WithoutAD

"""
$(TYPEDSIGNATURES)

Return the automatic differentiation capability trait of a Hamiltonian flow.

# Returns
- `Type{<:AbstractADTrait}`: The AD capability trait from the flow's system.

# Notes
- Delegates to the system's AD trait via `Common.ad_trait(system(flow))`
- This enables dispatch based on whether the flow was built from a scalar Hamiltonian or a vector field

See also: [`CTBase.Traits.AbstractADTrait`](@ref), [`CTBase.Traits.ad_trait`](@ref), [`CTFlows.Systems.AbstractHamiltonianSystem`](@ref).
"""
Traits.ad_trait(f::AbstractFlow{<:Traits.TimeDependence, <:Traits.VariableDependence, Traits.HamiltonianDynamics}) = Traits.ad_trait(system(f))

"""
$(TYPEDSIGNATURES)

Return the variable costate capability trait of a flow.

# Returns
- `Type{<:AbstractVariableCostateCapability}`: The capability trait, either
  `SupportsVariableCostate` or `NoVariableCostate`.

# Notes
- Default implementation returns `NoVariableCostate` for all flows
- Specialized implementation on `AbstractHamiltonianFlow` delegates to the system's trait
- This trait is used for dispatch in `_invoke_flow_variable_costate` to determine if augmented integration is possible

See also: [`CTBase.Traits.AbstractVariableCostateCapability`](@ref), [`CTBase.Traits.SupportsVariableCostate`](@ref), [`CTBase.Traits.NoVariableCostate`](@ref).
"""
Traits.variable_costate_trait(::AbstractFlow) = Traits.NoVariableCostate

"""
$(TYPEDSIGNATURES)

Return the variable costate capability trait of a Hamiltonian flow.

# Returns
- `Type{<:AbstractVariableCostateCapability}`: The capability trait from the flow's system.

# Notes
- Delegates to the system's variable costate trait via `Common.variable_costate_trait(system(flow))`
- This enables dispatch based on whether the flow's system can compute ∂H/∂v

See also: [`CTBase.Traits.AbstractVariableCostateCapability`](@ref), [`CTBase.Traits.variable_costate_trait`](@ref), [`CTFlows.Systems.AbstractHamiltonianSystem`](@ref).
"""
Traits.variable_costate_trait(f::AbstractFlow{<:Traits.TimeDependence, <:Traits.VariableDependence, Traits.HamiltonianDynamics}) = Traits.variable_costate_trait(system(f))

"""
$(TYPEDSIGNATURES)

Return the associated `AbstractSystem` for the flow.

# Throws
- `CTBase.Exceptions.NotImplemented`: If not implemented by the concrete type.

See also: [`CTFlows.Flows.AbstractFlow`](@ref), [`CTFlows.Systems.AbstractSystem`](@ref).
"""
function system(flow::AbstractFlow)
    throw(Exceptions.NotImplemented(
        "AbstractFlow system method not implemented";
        required_method = "system(flow::$(typeof(flow)))",
        suggestion = "Return the AbstractSystem associated with this flow.",
        context = "AbstractFlow.system - required method implementation",
    ))
end

"""
$(TYPEDSIGNATURES)

Return the associated `AbstractIntegrator` for the flow.

# Throws
- `CTBase.Exceptions.NotImplemented`: If not implemented by the concrete type.

See also: [`CTFlows.Flows.AbstractFlow`](@ref), [`CTSolvers.Integrators.AbstractIntegrator`](@extref).
"""
function integrator(flow::AbstractFlow)
    throw(Exceptions.NotImplemented(
        "AbstractFlow integrator method not implemented";
        required_method = "integrator(flow::$(typeof(flow)))",
        suggestion = "Return the AbstractIntegrator associated with this flow.",
        context = "AbstractFlow.integrator - required method implementation",
    ))
end

"""
$(TYPEDSIGNATURES)

Display the flow in tree-style format with proper indentation for multi-line system displays.

# Example
```julia-repl
julia> using CTFlows.Flows

julia> flow = Flow(system, integrator)
StateFlow
  system:     VectorFieldSystem
                wraps: VectorField: autonomous, fixed (no variable), out-of-place
  integrator: SciML (abstol = 1e-8, reltol = 1e-6)
```
"""
function Base.show(io::IO, ::MIME"text/plain", flow::AbstractFlow)
    sys   = system(flow)
    integ = integrator(flow)

    # "system:" and "integrator:" padded to the same width for column alignment
    lbl_sys  = "  system:     "
    lbl_int  = "  integrator: "

    # Capture system display; indent continuation lines to sit under the first
    sys_str = sprint(show, sys)
    sys_display = _indent_continuation(sys_str, length(lbl_sys))

    println(io, nameof(typeof(flow)))
    println(io, lbl_sys, sys_display)
    print(io,   lbl_int, nameof(typeof(integ)))
    _print_user_options(io, integ)
end

"""
$(TYPEDSIGNATURES)

Compact display of the flow.

# Example
```julia-repl
julia> using CTFlows.Flows

julia> flow = Flow(system, integrator)
Flow(system=FakeSystem(n_x=2, n_p=2), integrator=FakeIntegrator)
```
"""
function Base.show(io::IO, flow::AbstractFlow)
    sys = system(flow)
    integ = integrator(flow)
    print(io, nameof(typeof(flow)), "(")
    parts = String[]
    push!(parts, "system=$(sys)")
    push!(parts, "integrator=$(nameof(typeof(integ)))")
    print(io, join(parts, ", "))
    print(io, ")")
end

# =============================================================================
# Internal helpers for show
# =============================================================================

"""
    _indent_continuation(s::String, n::Int) -> String

Indent every line of a multiline string by `n` spaces, except the first line.

# Arguments
- `s::String`: The multiline string to indent.
- `n::Int`: Number of spaces to indent continuation lines.

# Returns
- `String`: The indented string.

# Example
\`\`\`julia
_indent_continuation("line1\\nline2\\nline3", 4)  # Returns "line1\\n    line2\\n    line3"
\`\`\`
"""
function _indent_continuation(s::String, n::Int)
    pad   = " " ^ n
    lines = split(s, "\n")
    return join((i == 1 ? l : pad * l for (i, l) in enumerate(lines)), "\n")
end

"""
    _print_user_options(io::IO, integ::Integrators.AbstractIntegrator)

Print user-supplied integrator options inline: `(key = val, …)`.
Silently does nothing when no user options are set.

# Arguments
- `io::IO`: The IO stream to write to.
- `integ::Integrators.AbstractIntegrator`: The integrator to inspect for user options.

# Example
\`\`\`julia
# If user options are set: prints " (abstol = 1e-8, reltol = 1e-6)"
# If no user options: prints nothing
\`\`\`
"""
function _print_user_options(io::IO, integ::Integrators.AbstractIntegrator)
    opts      = Strategies.options(integ)
    user_opts = sort!(
        [(k, Options.value(v)) for (k, v) in pairs(opts.options)
         if Options.is_user(opts, k)];
        by = x -> string(x[1]),
    )
    isempty(user_opts) && return
    print(io, " (")
    for (i, (k, v)) in enumerate(user_opts)
        i > 1 && print(io, ", ")
        print(io, k, " = ", v)
    end
    print(io, ")")
end
