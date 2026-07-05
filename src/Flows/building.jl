"""
$(TYPEDSIGNATURES)

High-level constructor for `Flow` from vector field data.

This constructor builds a complete flow by:
1. Building a `VectorFieldSystem` from the vector field data
2. Building a `SciML` integrator with the given options
3. Routing options through the integrator's CTBase.Strategies strategy
4. Combining them into a callable `Flow`

# Arguments
- `data::CTBase.Data.VectorField`: The vector field defining the system dynamics.
- `opts...`: Keyword options passed to the integrator's strategy.

# Returns
- `CTFlows.Flows.Flow`: The complete flow ready for integration.

# Example
\`\`\`julia
using CTBase.Data, CTFlows.Flows

vf = Data.VectorField((t, x, v) -> x, Traits.Autonomous(), Traits.Fixed())
flow = Flows.Flow(vf; reltol=1e-8)
\`\`\`

See also: [`CTFlows.Flows.Flow`](@ref), [`CTFlows.Systems.build_system`](@ref), [`CTSolvers.Integrators.build_integrator`](@extref).
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
3. Routing options through the integrator's CTBase.Strategies strategy
4. Combining them into a callable `HamiltonianFlow`

# Arguments
- `data::CTBase.Data.HamiltonianVectorField`: The Hamiltonian vector field defining the system dynamics.
- `opts...`: Keyword options passed to the integrator's strategy.

# Returns
- `CTFlows.Flows.HamiltonianFlow`: The complete Hamiltonian flow ready for integration.

# Example
```julia
using CTBase.Data, CTFlows.Flows

hvf = Data.HamiltonianVectorField((x, p) -> (x, -p); is_autonomous=true, is_variable=false)
flow = Flows.Flow(hvf; reltol=1e-8)
```

See also: [`CTFlows.Flows.HamiltonianFlow`](@ref), [`CTFlows.Systems.build_system`](@ref), [`CTSolvers.Integrators.build_integrator`](@extref).
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
- `h::CTBase.Data.AbstractHamiltonian`: The scalar Hamiltonian function.
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
using CTBase.Data, CTFlows.Flows

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
    routed = _route_flow_options(kwargs)
    components = _build_flow_components(routed)
    sys = Systems.build_system(h, components.backend)
    return build_flow(sys, components.integrator)
end

"""
$(TYPEDSIGNATURES)

High-level constructor for an `OptimalControlFlow` from an optimal control problem.

Dispatches on the problem's [`CTBase.Traits.ControlDependence`](@extref) trait:

- **control-free** (`ControlFree`): builds a Hamiltonian flow directly from the OCP,
  exploiting the structure — the state equation `ẋ = f(t,x,∅,v)` is computed exactly
  (no AD) and only `ṗ = −∂H/∂x` uses automatic differentiation.
- **with control** (`WithControl`): currently unsupported — throws a
  [`CTBase.Exceptions.PreconditionError`](@extref). Closing the loop would require a
  control law `u(t,x,p)` from the maximisation of the pseudo-Hamiltonian, which this
  path does not build.

# Arguments
- `ocp::CTModels.Models.Model`: The optimal control problem model.
- `kwargs...`: Keyword options passed to the backend and integrator strategies
  (same as `Flow(h::Data.AbstractHamiltonian; kwargs...)`).

# Returns
- `OptimalControlFlow` (control-free case): Wraps an inner `HamiltonianFlow` and exposes:
  - Point eval: `f(t0, x0, p0, tf; variable, variable_costate, unsafe)`
  - Trajectory: `f((t0,tf), x0, p0; variable)` → `CTModels.Solution`

# Throws
- [`CTBase.Exceptions.PreconditionError`](@extref): If the OCP carries a control input.

See also: [`CTFlows.Flows.OptimalControlFlow`](@ref), [`CTFlows.Flows.Flow`](@ref).
"""
function Flow(ocp::CTModels.Models.Model; kwargs...)
    return _flow_from_ocp(Traits.control_dependence(ocp), ocp; kwargs...)
end

"""
$(TYPEDSIGNATURES)

Build an `OptimalControlFlow` from a control-free OCP.

Constructs the OCP Hamiltonian, builds the Hamiltonian system with the chosen AD
backend, and wraps the resulting flow together with the OCP reference.

See also: [`CTFlows.Flows.OptimalControlFlow`](@ref), [`CTFlows.Flows.Flow`](@ref), `_ocp_hamiltonian`.
"""
function _flow_from_ocp(::Type{Traits.ControlFree}, ocp::CTModels.Models.Model; kwargs...)
    routed = _route_flow_options(kwargs)
    components = _build_flow_components(routed)
    h = _ocp_hamiltonian(ocp)
    sys = Systems.build_system(h, components.backend)
    inner = build_flow(sys, components.integrator)
    return OptimalControlFlow(inner, ocp)
end

"""
$(TYPEDSIGNATURES)

Reject `Flow` construction from a with-control OCP.

Throws `PreconditionError` because this path assumes no control input. A control
law `u(t,x,p)` is required to build the Hamiltonian flow from a with-control OCP.

See also: [`CTFlows.Flows.Flow`](@ref), `_ocp_hamiltonian`.
"""
function _flow_from_ocp(::Type{Traits.WithControl}, ::CTModels.Models.Model; kwargs...)
    return throw(
        Exceptions.PreconditionError(
            "Flow from a with-control OCP is not supported";
            reason = "this path builds the flow from the OCP structure assuming no control " *
                     "(ẋ = f(t,x,∅,v)); a problem with a control input would require a control " *
                     "law u(t,x,p) from the maximisation of the pseudo-Hamiltonian",
            suggestion = "build the Hamiltonian flow yourself from a control law, e.g. " *
                         "Flow(Hamiltonian(...)), or use a control-free OCP",
            context = "Flow(ocp::CTModels.Models.Model) — control-dependence dispatch",
        ),
    )
end

# =============================================================================
# Flow from a pseudo-Hamiltonian and a control law (intermediate constructor)
# =============================================================================

"""
$(TYPEDSIGNATURES)

Build a `HamiltonianFlow` directly from a pseudo-Hamiltonian `H̃(t,x,p,u,v)` and a
dynamic closed-loop control law `u(t,x,p,v)`, without going through an OCP.

Dispatches on the control law's [`CTBase.Traits.feedback`](@extref) trait, then on the
`hamiltonian_type` keyword:

- `hamiltonian_type=:total` (default) — build a [`CTBase.Data.ComposedHamiltonian`](@extref)
  `H(t,x,p,v)=H̃(t,x,p,u(t,x,p,v),v)` and a [`CTFlows.Systems.HamiltonianSystem`](@ref);
  AD differentiates *through* the law (total derivative).
- `hamiltonian_type=:partial` — build a [`CTFlows.Systems.PseudoHamiltonianSystem`](@ref);
  AD takes partials of `H̃` at the fixed feedback value `u`. Coincides with `:total` only
  where the feedback is stationary (`∂H̃/∂u = 0`).

# Arguments
- `h̃::Data.PseudoHamiltonian`: the pseudo-Hamiltonian.
- `law::Data.ControlLaw`: the control law; must carry `DynClosedLoopFeedback`.
- `hamiltonian_type::Symbol=:total`: `:total` or `:partial`.
- `kwargs...`: backend / integrator strategy options (as for `Flow(h::AbstractHamiltonian)`).

# Throws
- [`CTBase.Exceptions.PreconditionError`](@extref): if the law is `OpenLoop`/`ClosedLoop`
  (a pseudo-Hamiltonian needs the costate `p`, which those laws do not take).
- [`CTBase.Exceptions.IncorrectArgument`](@extref): if `hamiltonian_type` is not
  `:total` or `:partial`.

See also: [`CTFlows.Flows.Flow`](@ref), [`CTBase.Data.PseudoHamiltonian`](@extref),
[`CTBase.Data.DynClosedLoop`](@extref).
"""
function Flow(h̃::Data.PseudoHamiltonian, law::Data.ControlLaw; kwargs...)
    return _flow_from_pseudo_hamiltonian(Traits.feedback(law), h̃, law; kwargs...)
end

function _flow_from_pseudo_hamiltonian(
    ::Type{Traits.DynClosedLoopFeedback},
    h̃::Data.PseudoHamiltonian,
    law::Data.ControlLaw;
    kwargs...,
)
    routed = _route_flow_options(kwargs; action_defs = _flow_action_defs())
    components = _build_flow_components(routed)
    ht = _unwrap_option(get(routed.action, :hamiltonian_type, nothing), :total)
    return _build_pseudo_flow(Val(ht), h̃, law, components)
end

function _flow_from_pseudo_hamiltonian(
    ::Type{<:Union{Traits.OpenLoopFeedback,Traits.ClosedLoopFeedback}},
    ::Data.PseudoHamiltonian,
    ::Data.ControlLaw;
    kwargs...,
)
    return throw(
        Exceptions.PreconditionError(
            "Flow(h̃, law) requires a DynClosedLoop control law";
            reason = "a pseudo-Hamiltonian H̃(t,x,p,u,v) depends on the costate p, but " *
                     "OpenLoop u(t,v) and ClosedLoop u(t,x,v) control laws do not take p",
            suggestion = "use DynClosedLoop(u) to construct a control law u(t,x,p,v)",
            context = "Flow(h̃::PseudoHamiltonian, law::ControlLaw) — feedback dispatch",
        ),
    )
end

"""
$(TYPEDSIGNATURES)

Build the inner Hamiltonian flow for the `:total` mode: compose the pseudo-Hamiltonian
with the control law into a [`CTBase.Data.ComposedHamiltonian`](@extref) and wrap it in a
[`CTFlows.Systems.HamiltonianSystem`](@ref) (AD through the law).
"""
function _build_pseudo_flow(::Val{:total}, h̃, law, components)
    H = Data.ComposedHamiltonian(h̃, law)
    sys = Systems.build_system(H, components.backend)
    return build_flow(sys, components.integrator)
end

"""
$(TYPEDSIGNATURES)

Build the inner Hamiltonian flow for the `:partial` mode: wrap the pseudo-Hamiltonian
and control law in a [`CTFlows.Systems.PseudoHamiltonianSystem`](@ref) (AD at fixed `u`).
"""
function _build_pseudo_flow(::Val{:partial}, h̃, law, components)
    sys = Systems.build_system(h̃, law, components.backend)
    return build_flow(sys, components.integrator)
end

function _build_pseudo_flow(::Val{ht}, h̃, law, components) where {ht}
    return throw(
        Exceptions.IncorrectArgument(
            "unknown hamiltonian_type :$ht";
            got = ":$ht",
            expected = ":total or :partial",
            context = "Flow(…, law::ControlLaw; hamiltonian_type=…)",
        ),
    )
end

# =============================================================================
# Flow from an OCP and a control law
# =============================================================================

"""
$(TYPEDSIGNATURES)

Build an `OptimalControlFlow` from an OCP and a **control law** (dynamic closed-loop
feedback `u(t,x,p,v)`).

Dispatches on the law's [`CTBase.Traits.feedback`](@extref) trait, then on the
`hamiltonian_type` action option (`:total` default, or `:partial`), the same way as
[`Flow(h̃::Data.PseudoHamiltonian, law::Data.ControlLaw)`](@ref). The OCP's dynamics and
cost supply the pseudo-Hamiltonian `H̃(t,x,p,u,v) = p·f + sp0·ℓ`; the trajectory call
returns a [`CTModels.Solutions.Solution`](@extref) with the control reconstructed from
the law.

# Throws
- [`CTBase.Exceptions.PreconditionError`](@extref): if the OCP is control-free.
- [`CTBase.Exceptions.NotImplemented`](@extref): if the law is `OpenLoop`/`ClosedLoop`
  (state-only flows are not wired yet).
- [`CTBase.Exceptions.IncorrectArgument`](@extref): if `hamiltonian_type` is invalid.

See also: [`CTFlows.Flows.Flow`](@ref), [`CTFlows.Flows.OptimalControlFlow`](@ref).
"""
function Flow(ocp::CTModels.Models.Model, law::Data.ControlLaw; kwargs...)
    return _flow_from_ocp_control(Traits.feedback(law), ocp, law; kwargs...)
end

"""
$(TYPEDSIGNATURES)

Convenience constructor: wrap a raw control function `u` in a
[`CTBase.Data.DynClosedLoop`](@extref) control law and delegate to
[`Flow(ocp::CTModels.Models.Model, law::Data.ControlLaw)`](@ref).

The control law is given **the same time/variable dependence as the OCP**
(`is_autonomous(ocp)`, `is_variable(ocp)`), so `u` **must** have the matching natural
arity — `(x,p)`, `(t,x,p)`, `(x,p,v)`, or `(t,x,p,v)` for
autonomous/fixed, non-autonomous/fixed, autonomous/non-fixed, non-autonomous/non-fixed
respectively. To use a control law whose traits differ from the OCP's (e.g. a
time-varying feedback on an autonomous OCP), build the
[`CTBase.Data.DynClosedLoop`](@extref) explicitly and call
[`Flow(ocp::CTModels.Models.Model, law::Data.ControlLaw)`](@ref).

See also: [`Flow(ocp::CTModels.Models.Model, law::Data.ControlLaw)`](@ref).
"""
function Flow(ocp::CTModels.Models.Model, u::Function; kwargs...)
    law = Data.DynClosedLoop(
        u;
        is_autonomous = Traits.is_autonomous(ocp),
        is_variable = Traits.is_variable(ocp),
    )
    return Flow(ocp, law; kwargs...)
end

function _flow_from_ocp_control(
    ::Type{Traits.DynClosedLoopFeedback},
    ocp::CTModels.Models.Model,
    law::Data.ControlLaw;
    kwargs...,
)
    Traits.control_dependence(ocp) === Traits.WithControl || throw(
        Exceptions.PreconditionError(
            "Flow(ocp, law) requires a with-control OCP";
            reason = "the OCP is control-free (no control input), so a control law cannot be applied",
            suggestion = "use Flow(ocp; kwargs…) for a control-free OCP",
            context = "Flow(ocp, law::ControlLaw) — control-dependence check",
        ),
    )
    routed = _route_flow_options(kwargs; action_defs = _flow_action_defs())
    components = _build_flow_components(routed)
    ht = _unwrap_option(get(routed.action, :hamiltonian_type, nothing), :total)
    h̃ = _ocp_pseudo_hamiltonian(ocp)
    inner = _build_pseudo_flow(Val(ht), h̃, law, components)
    return OptimalControlFlow(inner, ocp, law)
end

function _flow_from_ocp_control(
    ::Type{<:Union{Traits.OpenLoopFeedback,Traits.ClosedLoopFeedback}},
    ::CTModels.Models.Model,
    ::Data.ControlLaw;
    kwargs...,
)
    return throw(
        Exceptions.NotImplemented(
            "Flow(ocp, law) with an OpenLoop/ClosedLoop control law is not implemented yet";
            required_method = "Flow(ocp, law::ControlLaw{…,OpenLoopFeedback/ClosedLoopFeedback,…})",
            suggestion = "use a DynClosedLoop control law u(t,x,p,v); state-only flows will be wired later",
            context = "Flow(ocp, law::ControlLaw) — feedback dispatch",
        ),
    )
end

function Flow(::CTModels.Models.Model, ::Any, args...; kwargs...)
    return throw(
        Exceptions.PreconditionError(
            "Flow(ocp, …) with extra positional arguments is not supported";
            reason = "passing a control law, state constraint or multiplier as a positional " *
                     "argument is not handled by the OCP flow constructor",
            suggestion = "call Flow(ocp; kwargs…) — the OCP flow takes no positional argument beyond the model",
            context = "Flow(ocp::CTModels.Models.Model) — positional-argument guard",
        ),
    )
end
