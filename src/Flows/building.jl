"""
$(TYPEDSIGNATURES)

High-level constructor for `Flow` from vector field data.

This constructor builds a complete flow by:
1. Building a `VectorFieldSystem` from the vector field data
2. Building a `SciML` integrator with the given options
3. Routing options through the integrator's CTSolvers strategy
4. Combining them into a callable `Flow`

# Arguments
- `data::CTFlows.Data.VectorField`: The vector field defining the system dynamics.
- `opts...`: Keyword options passed to the integrator's strategy.

# Returns
- `CTFlows.Flows.Flow`: The complete flow ready for integration.

# Example
\`\`\`julia
using CTFlows.Data, CTFlows.Flows, CTFlows.Common

vf = Data.VectorField((t, x, v) -> x, Traits.Autonomous(), Traits.Fixed())
flow = Flows.Flow(vf; reltol=1e-8)
\`\`\`

See also: [`CTFlows.Flows.Flow`](@ref), [`CTFlows.Systems.build_system`](@ref), [`CTFlows.Integrators.build_integrator`](@ref).
"""
function Flow(data::Data.VectorField; opts...)
    system = Systems.build_system(data)
    integrator = Integrators.build_integrator(; opts...)
    return build_flow(system, integrator)
end

"""
$(TYPEDSIGNATURES)

High-level constructor for `HamiltonianFlow` from Hamiltonian vector field data.

This constructor builds a complete Hamiltonian flow by:
1. Building a `HamiltonianVectorFieldSystem` from the Hamiltonian vector field data
2. Building a `SciML` integrator with the given options
3. Routing options through the integrator's CTSolvers strategy
4. Combining them into a callable `HamiltonianFlow`

# Arguments
- `data::CTFlows.Data.HamiltonianVectorField`: The Hamiltonian vector field defining the system dynamics.
- `opts...`: Keyword options passed to the integrator's strategy.

# Returns
- `CTFlows.Flows.HamiltonianFlow`: The complete Hamiltonian flow ready for integration.

# Example
```julia
using CTFlows.Data, CTFlows.Flows

hvf = Data.HamiltonianVectorField((x, p) -> (x, -p); is_autonomous=true, is_variable=false)
flow = Flows.Flow(hvf; reltol=1e-8)
```

See also: [`CTFlows.Flows.HamiltonianFlow`](@ref), [`CTFlows.Systems.build_system`](@ref), [`CTFlows.Integrators.build_integrator`](@ref).
"""
function Flow(data::Data.HamiltonianVectorField; opts...)
    system = Systems.build_system(data)
    integrator = Integrators.build_integrator(; opts...)
    return build_flow(system, integrator)
end

"""
$(TYPEDSIGNATURES)

High-level constructor for `HamiltonianFlow` from a scalar Hamiltonian.

This constructor builds a complete Hamiltonian flow by:
1. Routing keyword options to the appropriate strategy families (backend and integrator)
2. Building a concrete AD backend and integrator from the routed options
3. Building a `HamiltonianSystem` from the Hamiltonian and backend
4. Combining them into a callable `HamiltonianFlow`

# Arguments
- `h::CTFlows.Data.AbstractHamiltonian`: The scalar Hamiltonian function.
- `kwargs...`: Keyword options passed to the backend and integrator strategies.
  Options are automatically routed based on their names:
  - Backend options (e.g., `ad_backend`) → `:di` strategy
  - Integrator options (e.g., `reltol`, `abstol`, `alg`) → `:sciml` strategy

# Returns
- `CTFlows.Flows.HamiltonianFlow`: The complete Hamiltonian flow ready for integration.

# Throws
- [`CTBase.Exceptions.IncorrectArgument`](@extref): If an option is unknown, ambiguous,
  or routed to the wrong strategy.
- [`CTBase.Exceptions.ExtensionError`](@extref): If the `CTFlowsSciMLIntegrator` extension is not loaded
  (required for `:sciml` strategy metadata).

# Example
```julia
using CTFlows.Data, CTFlows.Flows

h = Data.Hamiltonian((t, x, p, v) -> 0.5 * (x[1]^2 + p[1]^2); is_autonomous=true, is_variable=false)
flow = Flows.Flow(h; reltol=1e-8, ad_backend=ADTypes.AutoForwardDiff())
# flow isa CTFlows.Flows.HamiltonianFlow
```

# Notes
- The state dimension is inferred from the Hamiltonian's signature.
- Use the `state_dimension` argument overload if explicit dimension is needed.
- Requires the `CTFlowsSciMLIntegrator` extension to be loaded for integrator options.

See also: [`CTFlows.Flows.HamiltonianFlow`](@ref), [`CTFlows.Systems.build_system`](@ref),
[`_route_flow_options`](@ref), [`_build_flow_components`](@ref)
"""
function Flow(h::Data.AbstractHamiltonian; kwargs...)
    routed     = _route_flow_options(kwargs)
    components = _build_flow_components(routed)
    sys        = Systems.build_system(h, components.backend)
    return build_flow(sys, components.integrator)
end

"""
$(TYPEDSIGNATURES)

High-level constructor for an `OptimalControlFlow` from a control-free OCP.

Builds a Hamiltonian flow directly from a `CTModels.Models.Model` with control
dimension 0, exploiting the OCP structure: state equation ẋ = f(t,x,∅,v) is
computed exactly (no AD), and only ṗ = −∂H/∂x uses automatic differentiation.

# Arguments
- `ocp::CTModels.Models.Model`: The optimal control problem model.
- `kwargs...`: Keyword options passed to the backend and integrator strategies
  (same as `Flow(h::Data.AbstractHamiltonian; kwargs...)`).

# Returns
- `OptimalControlFlow`: Wraps an inner `HamiltonianFlow` and exposes:
  - Point eval: `f(t0, x0, p0, tf; variable, variable_costate, unsafe)`
  - Trajectory: `f((t0,tf), x0, p0; variable)` → `CTModels.Solution`

See also: [`CTFlows.Flows.OptimalControlFlow`](@ref), [`CTFlows.Flows.Flow`](@ref).
"""
function Flow(ocp::CTModels.Models.Model; kwargs...)
    routed     = _route_flow_options(kwargs)
    components = _build_flow_components(routed)
    h          = _ocp_hamiltonian(ocp)
    sys        = Systems.build_system(h, components.backend)
    inner      = build_flow(sys, components.integrator)
    return OptimalControlFlow(inner, ocp)
end

function Flow(::CTModels.Models.Model, ::Any, args...; kwargs...)
    throw(Exceptions.PreconditionError(
        "Flow(ocp, …) with extra positional arguments is not supported for control-free OCPs";
        reason     = "this OCP is control-free (EmptyControlModel); passing a control law, " *
                     "state constraint or multiplier is not handled by this path",
        suggestion = "call Flow(ocp; kwargs…) — the control-free flow takes no control argument",
        context    = "Flow(ocp::CTModels.Models.Model) — control-free guard",
    ))
end

