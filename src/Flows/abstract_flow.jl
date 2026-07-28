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
abstract type AbstractFlow{
    TD<:Traits.TimeDependence,VD<:Traits.VariableDependence,D<:Traits.AbstractDynamicsTrait
} end

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
const AbstractStateFlow{TD<:Traits.TimeDependence,VD<:Traits.VariableDependence} = AbstractFlow{
    TD,VD,Traits.StateDynamics
}

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
const AbstractHamiltonianFlow{TD<:Traits.TimeDependence,VD<:Traits.VariableDependence} = AbstractFlow{
    TD,VD,Traits.HamiltonianDynamics
}

"""
$(TYPEDSIGNATURES)

Indicate that `AbstractFlow` has the time-dependence trait.

# Returns
- `Bool`: Always `true` for `AbstractFlow`.

See also: `TimeDependence`, [`CTBase.Traits.time_dependence`](@extref).
"""
Traits.has_time_dependence_trait(::AbstractFlow) = true

"""
$(TYPEDSIGNATURES)

Indicate that `AbstractFlow` has the variable-dependence trait.

# Returns
- `Bool`: Always `true` for `AbstractFlow`.

See also: [`CTBase.Traits.VariableDependence`](@extref), [`CTBase.Traits.variable_dependence`](@extref).
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

struct MyFlow <: Flows.AbstractFlow{Traits.Autonomous, Traits.Fixed, Traits.StateDynamics}
    data::Vector{Float64}
end

Traits.time_dependence(MyFlow)  # Returns Autonomous
\`\`\`

See also: [`CTBase.Traits.has_time_dependence_trait`](@extref), `is_autonomous`, [`CTFlows.Flows.AbstractFlow`](@ref).
"""
function Traits.time_dependence(
    ::AbstractFlow{TD,<:Traits.VariableDependence,<:Traits.AbstractDynamicsTrait}
) where {TD<:Traits.TimeDependence}
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

struct MyFlow <: Flows.AbstractFlow{Traits.Autonomous, Traits.Fixed, Traits.StateDynamics}
    data::Vector{Float64}
end

Traits.variable_dependence(MyFlow)  # Returns Fixed
\`\`\`

See also: [`CTBase.Traits.has_variable_dependence_trait`](@extref), `is_variable`, [`CTFlows.Flows.AbstractFlow`](@ref).
"""
function Traits.variable_dependence(
    ::AbstractFlow{<:Traits.TimeDependence,VD,<:Traits.AbstractDynamicsTrait}
) where {VD<:Traits.VariableDependence}
    return VD
end

"""
$(TYPEDSIGNATURES)

Extract the dynamics trait from an `AbstractFlow`.

# Returns
- `Type{<:AbstractDynamicsTrait}`: `StateDynamics` or `HamiltonianDynamics`.

See also: [`CTBase.Traits.AbstractDynamicsTrait`](@extref), [`CTFlows.Flows.AbstractStateFlow`](@ref), [`CTFlows.Flows.AbstractHamiltonianFlow`](@ref).
"""
function Traits.dynamics_trait(
    ::AbstractFlow{<:Traits.TimeDependence,<:Traits.VariableDependence,D}
) where {D<:Traits.AbstractDynamicsTrait}
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

See also: [`CTBase.Traits.AbstractADTrait`](@extref), [`CTBase.Traits.WithAD`](@extref), [`CTBase.Traits.WithoutAD`](@extref).
"""
Traits.ad_trait(::AbstractFlow) = Traits.WithoutAD

"""
$(TYPEDSIGNATURES)

Return the automatic differentiation capability trait of a Hamiltonian flow.

# Returns
- `Type{<:AbstractADTrait}`: The AD capability trait from the flow's system.

# Notes
- Delegates to the system's AD trait via `ad_trait(system(flow))`
- This enables dispatch based on whether the flow was built from a scalar Hamiltonian or a vector field

See also: [`CTBase.Traits.AbstractADTrait`](@extref), [`CTBase.Traits.ad_trait`](@extref), [`CTFlows.Systems.AbstractHamiltonianSystem`](@ref).
"""
function Traits.ad_trait(
    f::AbstractFlow{
        <:Traits.TimeDependence,<:Traits.VariableDependence,Traits.HamiltonianDynamics
    },
)
    return Traits.ad_trait(system(f))
end

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

See also: [`CTBase.Traits.AbstractVariableCostateCapability`](@extref), [`CTBase.Traits.SupportsVariableCostate`](@extref), [`CTBase.Traits.NoVariableCostate`](@extref).
"""
Traits.variable_costate_trait(::AbstractFlow) = Traits.NoVariableCostate

"""
$(TYPEDSIGNATURES)

Return the variable costate capability trait of a Hamiltonian flow.

# Returns
- `Type{<:AbstractVariableCostateCapability}`: The capability trait from the flow's system.

# Notes
- Delegates to the system's variable costate trait via `variable_costate_trait(system(flow))`
- This enables dispatch based on whether the flow's system can compute ∂H/∂v

See also: [`CTBase.Traits.AbstractVariableCostateCapability`](@extref), [`CTBase.Traits.variable_costate_trait`](@extref), [`CTFlows.Systems.AbstractHamiltonianSystem`](@ref).
"""
function Traits.variable_costate_trait(
    f::AbstractFlow{
        <:Traits.TimeDependence,<:Traits.VariableDependence,Traits.HamiltonianDynamics
    },
)
    return Traits.variable_costate_trait(system(f))
end

"""
$(TYPEDSIGNATURES)

Return the Hamiltonian `H(t, x, p, v)` underlying a Hamiltonian flow.

Delegates to the system-level getter [`CTFlows.Systems.hamiltonian`](@ref). The
returned object is callable as a scalar function of `(t, x, p, v)` (or the shorter
signatures allowed by the flow's time/variable dependence). It is available for flows
built from a scalar Hamiltonian — `HamiltonianSystem` (including the `:total` mode of
an OCP-with-control flow) and `PseudoHamiltonianSystem` (the `:partial` mode, where it
reconstructs the composed Hamiltonian). Flows built from a raw Hamiltonian vector field
carry no scalar Hamiltonian and are not supported.

This is the getter to use when writing a transversality condition on a free time in a
shooting method: with `v = t0` and/or `tf` a variable, the augmented flow integrates the
naive adjoint `ṗv = -∂H/∂v` (initialized at `0`), and the mitigated transversality
conditions read `p_{t0}(tf) = -H(t0, x0, p0, v)` and `p_{tf}(tf) = H(tf, xf, pf, v)`.

# Example
\`\`\`julia
H = CTFlows.Systems.hamiltonian(flow)
xf, pf, pvf = flow(t0, x0, p0, tf; variable = v, variable_costate = true)
s = pvf[idx_tf] - H(tf, xf, pf, v)   # transversality for free final time
\`\`\`

See also: [`CTFlows.Systems.hamiltonian`](@ref), [`CTFlows.Flows.system`](@ref).
"""
function Systems.hamiltonian(
    f::AbstractFlow{
        <:Traits.TimeDependence,<:Traits.VariableDependence,Traits.HamiltonianDynamics
    },
)
    return Systems.hamiltonian(system(f))
end

"""
$(TYPEDSIGNATURES)

Return the (symplectic) Hamiltonian vector field `X_H = (∂H/∂p, -∂H/∂x)` of a Hamiltonian
flow, as a [`CTBase.Data.HamiltonianVectorField`](@extref). Delegates to the system-level
[`CTFlows.Systems.hamiltonian_vector_field`](@ref), so it also covers flows built from a
pseudo-Hamiltonian (or an OCP) and a control law (`:partial` / `:total`), whose Hamiltonian
is a `CTBase.Data.ComposedHamiltonian`.

See also: [`CTFlows.Systems.hamiltonian`](@ref), [`CTFlows.Systems.vector_field`](@ref).
"""
function Systems.hamiltonian_vector_field(
    f::AbstractFlow{
        <:Traits.TimeDependence,<:Traits.VariableDependence,Traits.HamiltonianDynamics
    };
    kwargs...,
)
    return Systems.hamiltonian_vector_field(system(f); kwargs...)
end

"""
$(TYPEDSIGNATURES)

Return the vector field of a flow: the (symplectic) Hamiltonian vector field `X_H` for a
Hamiltonian flow. Alias of [`CTFlows.Systems.hamiltonian_vector_field`](@ref) on the
Hamiltonian side; see the `StateDynamics` method for state flows.

See also: [`CTFlows.Systems.hamiltonian_vector_field`](@ref).
"""
function Systems.vector_field(
    f::AbstractFlow{
        <:Traits.TimeDependence,<:Traits.VariableDependence,Traits.HamiltonianDynamics
    };
    kwargs...,
)
    return Systems.hamiltonian_vector_field(f; kwargs...)
end

"""
$(TYPEDSIGNATURES)

Return the underlying vector field `X(t, x, v)` of a state flow, as a
[`CTBase.Data.AbstractVectorField`](@extref). Delegates to the system-level
[`CTFlows.Systems.vector_field`](@ref).

See also: [`CTFlows.Systems.hamiltonian_vector_field`](@ref).
"""
function Systems.vector_field(
    f::AbstractFlow{
        <:Traits.TimeDependence,<:Traits.VariableDependence,Traits.StateDynamics
    },
)
    return Systems.vector_field(system(f))
end

"""
$(TYPEDSIGNATURES)

Return the pseudo-Hamiltonian `H̃(t, x, p, u, v)` underlying a Hamiltonian flow, when
available — i.e. when the flow was built from a pseudo-Hamiltonian (or an OCP) and a
control law, in either the `:partial` or the `:total` mode. Delegates to
[`CTFlows.Systems.pseudo_hamiltonian`](@ref).

# Throws
- `CTBase.Exceptions.IncorrectArgument`: for a flow that carries no control law.

See also: [`CTFlows.Systems.hamiltonian`](@ref), [`CTFlows.Systems.control_law`](@ref).
"""
function Systems.pseudo_hamiltonian(
    f::AbstractFlow{
        <:Traits.TimeDependence,<:Traits.VariableDependence,Traits.HamiltonianDynamics
    },
)
    return Systems.pseudo_hamiltonian(system(f))
end

"""
$(TYPEDSIGNATURES)

Return the control law `u(t, x, p, v)` carried by a Hamiltonian flow built from a
control law. Delegates to [`CTFlows.Systems.control_law`](@ref).

# Throws
- `CTBase.Exceptions.IncorrectArgument`: for a flow that carries no control law.

See also: [`CTFlows.Systems.pseudo_hamiltonian`](@ref).
"""
function Systems.control_law(
    f::AbstractFlow{
        <:Traits.TimeDependence,<:Traits.VariableDependence,Traits.HamiltonianDynamics
    },
)
    return Systems.control_law(system(f))
end

"""
$(TYPEDSIGNATURES)

Return a callable `(t, x, p, v) -> (∂H/∂x, ∂H/∂p)` for the true Hamiltonian of a
Hamiltonian flow. Delegates to [`CTFlows.Systems.get_hamiltonian_gradient`](@ref); the
`ad_backend` keyword (default: the system's backend) selects the AD backend.

See also: [`CTFlows.Systems.hamiltonian`](@ref), [`CTFlows.Systems.get_variable_gradient`](@ref).
"""
function Systems.get_hamiltonian_gradient(
    f::AbstractFlow{
        <:Traits.TimeDependence,<:Traits.VariableDependence,Traits.HamiltonianDynamics
    };
    kwargs...,
)
    return Systems.get_hamiltonian_gradient(system(f); kwargs...)
end

"""
$(TYPEDSIGNATURES)

Return a callable `(t, x, p, v) -> ∂H/∂v` for the true Hamiltonian of a Hamiltonian
flow — the quantity (before negation) driving `ṗv = -∂H/∂v`. Delegates to
[`CTFlows.Systems.get_variable_gradient`](@ref); the `ad_backend` keyword (default: the
system's backend) selects the AD backend.

See also: [`CTFlows.Systems.get_hamiltonian_gradient`](@ref).
"""
function Systems.get_variable_gradient(
    f::AbstractFlow{
        <:Traits.TimeDependence,<:Traits.VariableDependence,Traits.HamiltonianDynamics
    };
    kwargs...,
)
    return Systems.get_variable_gradient(system(f); kwargs...)
end

"""
$(TYPEDSIGNATURES)

Return a callable `(t, x, p, u, v) -> (∂H̃/∂x, ∂H̃/∂p)` for the pseudo-Hamiltonian of a
Hamiltonian flow (differentiated at fixed control), when available. Delegates to
[`CTFlows.Systems.get_pseudo_hamiltonian_gradient`](@ref); the `ad_backend` keyword
(default: the system's backend) selects the AD backend.

See also: [`CTFlows.Systems.pseudo_hamiltonian`](@ref), [`CTFlows.Systems.get_pseudo_variable_gradient`](@ref).
"""
function Systems.get_pseudo_hamiltonian_gradient(
    f::AbstractFlow{
        <:Traits.TimeDependence,<:Traits.VariableDependence,Traits.HamiltonianDynamics
    };
    kwargs...,
)
    return Systems.get_pseudo_hamiltonian_gradient(system(f); kwargs...)
end

"""
$(TYPEDSIGNATURES)

Return a callable `(t, x, p, u, v) -> ∂H̃/∂v` for the pseudo-Hamiltonian of a
Hamiltonian flow (differentiated at fixed control), when available. Delegates to
[`CTFlows.Systems.get_pseudo_variable_gradient`](@ref); the `ad_backend` keyword
(default: the system's backend) selects the AD backend.

See also: [`CTFlows.Systems.get_pseudo_hamiltonian_gradient`](@ref).
"""
function Systems.get_pseudo_variable_gradient(
    f::AbstractFlow{
        <:Traits.TimeDependence,<:Traits.VariableDependence,Traits.HamiltonianDynamics
    };
    kwargs...,
)
    return Systems.get_pseudo_variable_gradient(system(f); kwargs...)
end

"""
$(TYPEDSIGNATURES)

Return the associated `AbstractSystem` for the flow.

# Throws
- `CTBase.Exceptions.NotImplemented`: If not implemented by the concrete type.

See also: [`CTFlows.Flows.AbstractFlow`](@ref), [`CTFlows.Systems.AbstractSystem`](@ref).
"""
function system(flow::AbstractFlow)
    return throw(
        Exceptions.NotImplemented(
            "AbstractFlow system method not implemented";
            required_method="system(flow::$(typeof(flow)))",
            suggestion="Return the AbstractSystem associated with this flow.",
            context="AbstractFlow.system - required method implementation",
        ),
    )
end

"""
$(TYPEDSIGNATURES)

Return the associated `AbstractIntegrator` for the flow.

# Throws
- `CTBase.Exceptions.NotImplemented`: If not implemented by the concrete type.

See also: [`CTFlows.Flows.AbstractFlow`](@ref), [`CTSolvers.Integrators.AbstractIntegrator`](@extref).
"""
function integrator(flow::AbstractFlow)
    return throw(
        Exceptions.NotImplemented(
            "AbstractFlow integrator method not implemented";
            required_method="integrator(flow::$(typeof(flow)))",
            suggestion="Return the AbstractIntegrator associated with this flow.",
            context="AbstractFlow.integrator - required method implementation",
        ),
    )
end

"""
$(TYPEDSIGNATURES)

Display the flow in tree-style format with proper indentation for multi-line system and
integrator displays.

# Example
```julia-repl
julia> using CTFlows.Flows

julia> flow = Flow(system, integrator)
StateFlow
├─ system: VectorFieldSystem
│  ├─ time_dependence: Autonomous
│  ├─ variable_dependence: Fixed
│  └─ VectorField: autonomous, fixed (no variable), out-of-place
│     natural call: f(x)
│     uniform call: f(t, x, v)
└─ integrator: SciML (instance, id=:sciml)
   ├─ alg = Tsit5  [default]
   ├─ reltol = 1.0e-8  [user]
   └─ abstol = 1.0e-8  [user]
   Tip: use describe(SciML) to see all available options.
```
"""
function Base.show(io::IO, ::MIME"text/plain", flow::AbstractFlow)
    fmt = Display.format_codes(io)
    sys = system(flow)
    integ = integrator(flow)

    Display.print_header(io, nameof(typeof(flow)); fmt=fmt)

    # Nest the system's own (styled, possibly multi-line) display under the `system` branch.
    Display.print_field(io, "system", sys; fmt=fmt, value_style="")

    # Nest the integrator's own (styled, multi-line) text/plain display under the last branch.
    int_str = chomp(
        sprint(
            show,
            MIME("text/plain"),
            integ;
            context=IOContext(io, :color => get(io, :color, false)),
        ),
    )
    return Display.print_field(
        io, "integrator", int_str; last=true, fmt=fmt, value_style=""
    )
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
    fmt = Display.format_codes(io)
    sys = system(flow)
    integ = integrator(flow)
    print(io, fmt.name, nameof(typeof(flow)), fmt.reset, "(")
    parts = String[]
    push!(parts, "system=$(sys)")
    push!(parts, "integrator=$(nameof(typeof(integ)))")
    print(io, join(parts, ", "))
    return print(io, ")")
end
