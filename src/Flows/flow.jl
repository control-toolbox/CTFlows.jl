"""
$(TYPEDEF)

Concrete flow that combines an `AbstractSystem` with an `AbstractIntegrator`.

A `Flow` is the standard implementation of `AbstractFlow` that delegates
integration to the provided integrator and solution building to the system.

The `TD` and `VD` parameters encode the `TimeDependence` and `VariableDependence`
traits (Autonomous/NonAutonomous and Fixed/NonFixed) to enable compile-time dispatch.

# Fields
- `system::S`: The `AbstractSystem` to integrate.
- `integrator::I`: The `AbstractIntegrator` to use for integration.

# Example
```julia-repl
julia> using CTFlows.Flows, CTFlows.Systems

julia> system = FakeSystem()
FakeSystem()

julia> integrator = FakeIntegrator()
FakeIntegrator()

julia> flow = Flow(system, integrator)
Flow{FakeSystem, FakeIntegrator, Fixed}(system=FakeSystem(), integrator=FakeIntegrator)
```

See also: [`CTFlows.Flows.AbstractFlow`](@ref), [`CTFlows.Systems.AbstractSystem`](@ref), [`CTFlows.Integrators.AbstractIntegrator`](@ref).
"""
"""
$(TYPEDEF)

Concrete flow for state systems (non-Hamiltonian).

Combines a state system with an integrator for integration. The type parameters
encode the time-dependence and variable-dependence traits for compile-time dispatch.

# Type Parameters
- `TD <: TimeDependence`: Time dependence trait (Autonomous or NonAutonomous)
- `VD <: VariableDependence`: Variable dependence trait (Fixed or NonFixed)
- `S <: AbstractStateSystem{TD, VD}`: The state system type
- `I <: AbstractIntegrator`: The integrator type

# Fields
- `system::S`: The state system to integrate
- `integrator::I`: The integrator to use for integration

# Example
\`\`\`julia-repl
julia> using CTFlows.Flows, CTFlows.Systems, CTFlows.Integrators

julia> system = VectorFieldSystem(VectorField(x -> -x))

julia> integrator = SciML()

julia> flow = StateFlow(system, integrator)
StateFlow{...}
\`\`\`

See also: [`CTFlows.Flows.AbstractStateFlow`](@ref), [`CTFlows.Flows.HamiltonianFlow`](@ref).
"""
struct StateFlow{TD, VD, S<:Systems.AbstractStateSystem{TD, VD}, I<:Integrators.AbstractIntegrator} <: AbstractStateFlow{TD, VD, S}
    system::S
    integrator::I
end

"""
$(TYPEDEF)

Concrete flow for Hamiltonian systems.

Combines a Hamiltonian system with an integrator for integration. The type parameters
encode the time-dependence and variable-dependence traits for compile-time dispatch.

# Type Parameters
- `TD <: TimeDependence`: Time dependence trait (Autonomous or NonAutonomous)
- `VD <: VariableDependence`: Variable dependence trait (Fixed or NonFixed)
- `S <: AbstractHamiltonianSystem{TD, VD}`: The Hamiltonian system type
- `I <: AbstractIntegrator`: The integrator type

# Fields
- `system::S`: The Hamiltonian system to integrate
- `integrator::I`: The integrator to use for integration

# Example
\`\`\`julia-repl
julia> using CTFlows.Flows, CTFlows.Systems, CTFlows.Integrators

julia> system = HamiltonianVectorFieldSystem(VectorField(x -> -x), VectorField(p -> -p))

julia> integrator = SciML()

julia> flow = HamiltonianFlow(system, integrator)
HamiltonianFlow{...}
\`\`\`

See also: [`CTFlows.Flows.AbstractHamiltonianFlow`](@ref), [`CTFlows.Flows.StateFlow`](@ref).
"""
struct HamiltonianFlow{TD, VD, S<:Systems.AbstractHamiltonianSystem{TD, VD}, I<:Integrators.AbstractIntegrator} <: AbstractHamiltonianFlow{TD, VD, S}
    system::S
    integrator::I
end

"""
$(TYPEDSIGNATURES)

Build a `Flow` from an `AbstractSystem` and an `AbstractIntegrator`.

Constructs a concrete flow that combines the system and integrator for integration.
The resulting flow is callable and can be used with both point and trajectory configurations.

# Arguments
- `system::S`: The `AbstractSystem` to integrate.
- `integrator::I`: The `AbstractIntegrator` to use for integration.

# Returns
- `Flow`: A concrete flow combining the system and integrator.

# Example
\`\`\`julia-repl
julia> using CTFlows.Flows, CTFlows.Systems, CTFlows.Integrators

julia> system = VectorFieldSystem(VectorField(x -> -x))
VectorFieldSystem

julia> integrator = FakeIntegrator()
FakeIntegrator()

julia> flow = build_flow(system, integrator)
Flow{...}
\`\`\`

See also: [`CTFlows.Flows.Flow`](@ref), [`CTFlows.Systems.AbstractSystem`](@ref), [`CTFlows.Integrators.AbstractIntegrator`](@ref).
"""
"""
$(TYPEDSIGNATURES)

Build a `StateFlow` from a state system and an integrator.

# Arguments
- `system::S`: The state system to integrate.
- `integrator::I`: The integrator to use for integration.

# Returns
- `StateFlow`: A concrete state flow combining the system and integrator.

# Example
\`\`\`julia-repl
julia> using CTFlows.Flows, CTFlows.Systems, CTFlows.Integrators

julia> system = VectorFieldSystem(VectorField(x -> -x))

julia> integrator = SciML()

julia> flow = build_flow(system, integrator)
StateFlow{...}
\`\`\`

See also: [`CTFlows.Flows.StateFlow`](@ref), [`CTFlows.Flows.build_flow(::AbstractHamiltonianSystem, ::AbstractIntegrator)`](@ref).
"""
function build_flow(system::S, integrator::I) where {S<:Systems.AbstractStateSystem, I<:Integrators.AbstractIntegrator}
    return StateFlow(system, integrator)
end

"""
$(TYPEDSIGNATURES)

Build a `HamiltonianFlow` from a Hamiltonian system and an integrator.

# Arguments
- `system::S`: The Hamiltonian system to integrate.
- `integrator::I`: The integrator to use for integration.

# Returns
- `HamiltonianFlow`: A concrete Hamiltonian flow combining the system and integrator.

# Example
\`\`\`julia-repl
julia> using CTFlows.Flows, CTFlows.Systems, CTFlows.Integrators

julia> system = HamiltonianVectorFieldSystem(VectorField(x -> -x), VectorField(p -> -p))

julia> integrator = SciML()

julia> flow = build_flow(system, integrator)
HamiltonianFlow{...}
\`\`\`

See also: [`CTFlows.Flows.HamiltonianFlow`](@ref), [`CTFlows.Flows.build_flow(::AbstractStateSystem, ::AbstractIntegrator)`](@ref).
"""
function build_flow(system::S, integrator::I) where {S<:Systems.AbstractHamiltonianSystem, I<:Integrators.AbstractIntegrator}
    return HamiltonianFlow(system, integrator)
end

"""
$(TYPEDSIGNATURES)

Return the system associated with the flow.

# Returns
- `S`: The `AbstractSystem` stored in the flow.
"""
"""
$(TYPEDSIGNATURES)

Return the system associated with a `StateFlow`.

# Arguments
- `f::StateFlow`: The state flow.

# Returns
- `S`: The state system stored in the flow.

# Example
\`\`\`julia-repl
julia> using CTFlows.Flows

julia> flow = StateFlow(system, integrator)

julia> system(flow) === system
true
\`\`\`

See also: [`CTFlows.Flows.StateFlow`](@ref), [`CTFlows.Flows.integrator`](@ref).
"""
function system(f::StateFlow{TD, VD, S, I})::S where {TD, VD, S, I}
    return f.system
end

"""
$(TYPEDSIGNATURES)

Return the system associated with a `HamiltonianFlow`.

# Arguments
- `f::HamiltonianFlow`: The Hamiltonian flow.

# Returns
- `S`: The Hamiltonian system stored in the flow.

# Example
\`\`\`julia-repl
julia> using CTFlows.Flows

julia> flow = HamiltonianFlow(system, integrator)

julia> system(flow) === system
true
\`\`\`

See also: [`CTFlows.Flows.HamiltonianFlow`](@ref), [`CTFlows.Flows.integrator`](@ref).
"""
function system(f::HamiltonianFlow{TD, VD, S, I})::S where {TD, VD, S, I}
    return f.system
end

"""
$(TYPEDSIGNATURES)

Return the integrator associated with the flow.

# Returns
- `I`: The `AbstractIntegrator` stored in the flow.
"""
"""
$(TYPEDSIGNATURES)

Return the integrator associated with a `StateFlow`.

# Arguments
- `f::StateFlow`: The state flow.

# Returns
- `I`: The integrator stored in the flow.

# Example
\`\`\`julia-repl
julia> using CTFlows.Flows

julia> flow = StateFlow(system, integrator)

julia> integrator(flow) === integrator
true
\`\`\`

See also: [`CTFlows.Flows.StateFlow`](@ref), [`CTFlows.Flows.system`](@ref).
"""
function integrator(f::StateFlow{TD, VD, S, I})::I where {TD, VD, S, I}
    return f.integrator
end

"""
$(TYPEDSIGNATURES)

Return the integrator associated with a `HamiltonianFlow`.

# Arguments
- `f::HamiltonianFlow`: The Hamiltonian flow.

# Returns
- `I`: The integrator stored in the flow.

# Example
\`\`\`julia-repl
julia> using CTFlows.Flows

julia> flow = HamiltonianFlow(system, integrator)

julia> integrator(flow) === integrator
true
\`\`\`

See also: [`CTFlows.Flows.HamiltonianFlow`](@ref), [`CTFlows.Flows.system`](@ref).
"""
function integrator(f::HamiltonianFlow{TD, VD, S, I})::I where {TD, VD, S, I}
    return f.integrator
end

# =============================================================================
# Flow callable — compile-time dispatch on variable trait.
#
# Calling a Fixed flow with `variable=v` → Error.
# Calling a NonFixed flow without `variable` → Error.
#
# The error is thrown by the inner `solve` method.
#
# =============================================================================

"""
$(TYPEDSIGNATURES)

Convenience call `flow(t0, x0, tf)` — builds a `PointConfig` internally.

# Arguments
- `f::Flow`: The flow to integrate.
- `t0`: Initial time.
- `x0`: Initial state vector.
- `tf`: Final time.
- `variable`: The variable parameter value (required for NonFixed systems, optional for Fixed systems).
- `unsafe`: If `true`, bypass ODE solver retcode checking; if `false`, throw `SolverFailure` on integration failure.

# Returns
- The integrated solution.

See also: [`CTFlows.Common.PointConfig`](@ref), [`CTFlows.Flows.call`](@ref).
"""
"""
$(TYPEDSIGNATURES)

Convenience call for `StateFlow` with point configuration.

Builds a `PointConfig` internally and calls the flow with it.

# Arguments
- `f::StateFlow`: The state flow to integrate.
- `t0::Real`: Initial time.
- `x0`: Initial state vector.
- `tf::Real`: Final time.
- `variable`: The variable parameter value (required for NonFixed systems, optional for Fixed systems).
- `unsafe`: If `true`, bypass ODE solver retcode checking; if `false`, throw `SolverFailure` on integration failure.

# Returns
- The integrated solution (type varies by system).

# Example
\`\`\`julia-repl
julia> using CTFlows.Flows

julia> flow = StateFlow(system, integrator)

julia> sol = flow(0.0, [1.0, 0.0], 1.0)
\`\`\`

See also: [`CTFlows.Common.PointConfig`](@ref), [`CTFlows.Flows.call`](@ref).
"""
function (f::StateFlow)(
    t0::Real,
    x0,
    tf::Real;
    variable=Common.__variable(),
    unsafe=Common.__unsafe(),
)
    return call(f, Common.PointConfig(t0, x0, tf); variable=variable, unsafe=unsafe)
end

"""
$(TYPEDSIGNATURES)

Convenience call for `HamiltonianFlow` with point configuration.

Builds a `HamiltonianPointConfig` internally and calls the flow with it.

# Arguments
- `f::HamiltonianFlow`: The Hamiltonian flow to integrate.
- `t0::Real`: Initial time.
- `x0`: Initial state vector.
- `p0`: Initial costate vector.
- `tf::Real`: Final time.
- `variable`: The variable parameter value (required for NonFixed systems, optional for Fixed systems).
- `unsafe`: If `true`, bypass ODE solver retcode checking; if `false`, throw `SolverFailure` on integration failure.

# Returns
- The integrated solution (type varies by system).

# Example
\`\`\`julia-repl
julia> using CTFlows.Flows

julia> flow = HamiltonianFlow(system, integrator)

julia> sol = flow(0.0, [1.0, 0.0], [0.5, 0.3], 1.0)
\`\`\`

See also: [`CTFlows.Common.HamiltonianPointConfig`](@ref), [`CTFlows.Flows.call`](@ref).
"""
function (f::HamiltonianFlow)(
    t0::Real,
    x0,
    p0,
    tf::Real;
    variable=Common.__variable(),
    unsafe=Common.__unsafe(),
)
    return call(f, Common.HamiltonianPointConfig(t0, x0, p0, tf); variable=variable, unsafe=unsafe)
end

"""
$(TYPEDSIGNATURES)

Convenience call `flow((t0, tf), x0)` — builds a `TrajectoryConfig` internally.

# Arguments
- `f::Flow{S, I, VD}`: The flow to integrate.
- `tspan::Tuple`: Time span as a tuple (t0, tf).
- `x0`: Initial state vector.
- `variable`: The variable parameter value (required for NonFixed systems, optional for Fixed systems).
- `unsafe`: If `true`, bypass ODE solver retcode checking; if `false`, throw `SolverFailure` on integration failure.

# Returns
- The integrated solution.

See also: [`CTFlows.Common.TrajectoryConfig`](@ref), [`CTFlows.Flows.call`](@ref).
"""
"""
$(TYPEDSIGNATURES)

Convenience call for `StateFlow` with trajectory configuration.

Builds a `TrajectoryConfig` internally and calls the flow with it.

# Arguments
- `f::StateFlow`: The state flow to integrate.
- `tspan::Tuple{Real, Real}`: Time span as a tuple (t0, tf).
- `x0`: Initial state vector.
- `variable`: The variable parameter value (required for NonFixed systems, optional for Fixed systems).
- `unsafe`: If `true`, bypass ODE solver retcode checking; if `false`, throw `SolverFailure` on integration failure.

# Returns
- The integrated solution (type varies by system).

# Example
\`\`\`julia-repl
julia> using CTFlows.Flows

julia> flow = StateFlow(system, integrator)

julia> sol = flow((0.0, 1.0), [1.0, 0.0])
\`\`\`

See also: [`CTFlows.Common.TrajectoryConfig`](@ref), [`CTFlows.Flows.call`](@ref).
"""
function (f::StateFlow)(
    tspan::Tuple{Real, Real},
    x0;
    variable=Common.__variable(),
    unsafe=Common.__unsafe(),
)
    return call(f, Common.TrajectoryConfig(tspan, x0); variable=variable, unsafe=unsafe)
end

"""
$(TYPEDSIGNATURES)

Convenience call for `HamiltonianFlow` with trajectory configuration.

Builds a `HamiltonianTrajectoryConfig` internally and calls the flow with it.

# Arguments
- `f::HamiltonianFlow`: The Hamiltonian flow to integrate.
- `tspan::Tuple{Real, Real}`: Time span as a tuple (t0, tf).
- `x0`: Initial state vector.
- `p0`: Initial costate vector.
- `variable`: The variable parameter value (required for NonFixed systems, optional for Fixed systems).
- `unsafe`: If `true`, bypass ODE solver retcode checking; if `false`, throw `SolverFailure` on integration failure.

# Returns
- The integrated solution (type varies by system).

# Example
\`\`\`julia-repl
julia> using CTFlows.Flows

julia> flow = HamiltonianFlow(system, integrator)

julia> sol = flow((0.0, 1.0), [1.0, 0.0], [0.5, 0.3])
\`\`\`

See also: [`CTFlows.Common.HamiltonianTrajectoryConfig`](@ref), [`CTFlows.Flows.call`](@ref).
"""
function (f::HamiltonianFlow)(
    tspan::Tuple{Real, Real},
    x0,
    p0;
    variable=Common.__variable(),
    unsafe=Common.__unsafe(),
)
    return call(f, Common.HamiltonianTrajectoryConfig(tspan, x0, p0); variable=variable, unsafe=unsafe)
end
