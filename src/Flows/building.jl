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
[`CTFlows.Flows._route_flow_options`](@ref), [`CTFlows.Flows._build_flow_components`](@ref)
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
- **with control** (`WithControl`): throws a
  [`CTBase.Exceptions.PreconditionError`](@extref). Use `Flow(ocp, law)` instead,
  passing a control law to close the loop — see
  [`CTFlows.Flows.Flow(ocp::CTModels.Models.Model, law::CTBase.Data.ControlLaw)`](@ref).

# Arguments
- `ocp::CTModels.Models.Model`: The optimal control problem model.
- `kwargs...`: Keyword options passed to the backend and integrator strategies
  (same as `Flow(h::Data.AbstractHamiltonian; kwargs...)`).

# Returns
- `OptimalControlFlow` (control-free case): Wraps an inner `HamiltonianFlow` and exposes:
  - Point eval: `f(t0, x0, p0, tf; variable, variable_costate, unsafe)`
  - Trajectory: `f((t0,tf), x0, p0; variable)` → `CTModels.Solution`

# Throws
- [`CTBase.Exceptions.PreconditionError`](@extref): If the OCP carries a control input
  (use `Flow(ocp, law)` instead).

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

See also: [`CTFlows.Flows.OptimalControlFlow`](@ref), [`CTFlows.Flows.Flow`](@ref), `CTFlows.Flows._ocp_hamiltonian`.
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

Reject `Flow(ocp)` construction from a with-control OCP.

Throws `PreconditionError` because this path assumes no control input. Use
`Flow(ocp, law)` to pass a control law that closes the loop.

See also: [`CTFlows.Flows.Flow`](@ref), `CTFlows.Flows._ocp_hamiltonian`.
"""
function _flow_from_ocp(::Type{Traits.WithControl}, ::CTModels.Models.Model; kwargs...)
    return throw(
        Exceptions.PreconditionError(
            "Flow from a with-control OCP is not supported";
            reason="this path builds the flow from the OCP structure assuming no control " *
                   "(ẋ = f(t,x,∅,v)); a problem with a control input would require a control " *
                   "law u(t,x,p) from the maximisation of the pseudo-Hamiltonian",
            suggestion="use Flow(ocp, law) to pass a control law, or use a control-free OCP",
            context="Flow(ocp::CTModels.Models.Model) — control-dependence dispatch",
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

"""
$(TYPEDSIGNATURES)

Dispatch helper for [`CTFlows.Flows.Flow(h̃::CTBase.Data.PseudoHamiltonian, law::CTBase.Data.ControlLaw)`](@ref): build a
Hamiltonian flow from a `DynClosedLoop` law, routing on the `hamiltonian_type` action
option.

See also: [`CTFlows.Flows._build_pseudo_flow`](@ref).
"""
function _flow_from_pseudo_hamiltonian(
    ::Type{Traits.DynClosedLoopFeedback},
    h̃::Data.PseudoHamiltonian,
    law::Data.ControlLaw;
    kwargs...,
)
    routed = _route_flow_options(kwargs; action_defs=_flow_action_defs())
    components = _build_flow_components(routed)
    ht = _unwrap_option(get(routed.action, :hamiltonian_type, nothing), :total)
    return _build_pseudo_flow(Val(ht), h̃, law, components)
end

"""
$(TYPEDSIGNATURES)

Reject `OpenLoop`/`ClosedLoop` laws in [`CTFlows.Flows.Flow(h̃::CTBase.Data.PseudoHamiltonian, law::CTBase.Data.ControlLaw)`](@ref):
a pseudo-Hamiltonian `H̃(t,x,p,u,v)` depends on the costate `p`, which `OpenLoop`/`ClosedLoop`
laws do not provide.

See also: [`CTFlows.Flows.Flow(h̃::CTBase.Data.PseudoHamiltonian, law::CTBase.Data.ControlLaw)`](@ref).
"""
function _flow_from_pseudo_hamiltonian(
    ::Type{<:Union{Traits.OpenLoopFeedback,Traits.ClosedLoopFeedback}},
    ::Data.PseudoHamiltonian,
    ::Data.ControlLaw;
    kwargs...,
)
    return throw(
        Exceptions.PreconditionError(
            "Flow(h̃, law) requires a DynClosedLoop control law";
            reason="a pseudo-Hamiltonian H̃(t,x,p,u,v) depends on the costate p, but " *
                   "OpenLoop u(t,v) and ClosedLoop u(t,x,v) control laws do not take p",
            suggestion="use DynClosedLoop(u) to construct a control law u(t,x,p,v)",
            context="Flow(h̃::PseudoHamiltonian, law::ControlLaw) — feedback dispatch",
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
            got=":$ht",
            expected=":total or :partial",
            context="Flow(…, law::ControlLaw; hamiltonian_type=…)",
        ),
    )
end

# =============================================================================
# Flow from a controlled vector field and a control law (intermediate constructor)
# =============================================================================

"""
$(TYPEDSIGNATURES)

Build a [`CTFlows.Flows.ControlledFlow`](@ref) directly from a controlled vector field
`fc(t,x,u,v)` and an **open-loop** or **closed-loop** control law, without an OCP.

Dispatches on the law's [`CTBase.Traits.feedback`](@extref) trait: the control is
eliminated via a [`CTBase.Data.ComposedVectorField`](@extref) `g(t,x,v)=fc(t,x,u(...),v)`,
integrated as a state flow. A trajectory call returns a
[`CTFlows.Trajectories.ControlledTrajectory`](@ref) (state + reconstructed control, no
objective — there is no OCP).

# Throws
- [`CTBase.Exceptions.PreconditionError`](@extref): if the law is `DynClosedLoop` (that
  needs the costate; use [`CTFlows.Flows.Flow(h̃::CTBase.Data.PseudoHamiltonian, law::CTBase.Data.ControlLaw)`](@ref)).

See also: [`CTFlows.Flows.Flow`](@ref), [`CTBase.Data.ControlledVectorField`](@extref).
"""
function Flow(fc::Data.ControlledVectorField, law::Data.ControlLaw; kwargs...)
    return _flow_from_controlled_vf(Traits.feedback(law), fc, law; kwargs...)
end

"""
$(TYPEDSIGNATURES)

Dispatch helper for [`CTFlows.Flows.Flow(fc::CTBase.Data.ControlledVectorField, law::CTBase.Data.ControlLaw)`](@ref):
compose `fc` with an `OpenLoop`/`ClosedLoop` law into a [`CTFlows.Flows.ControlledFlow`](@ref)
with no OCP.

See also: [`CTFlows.Flows._controlled_flow`](@ref).
"""
function _flow_from_controlled_vf(
    ::Type{<:Union{Traits.OpenLoopFeedback,Traits.ClosedLoopFeedback}},
    fc::Data.ControlledVectorField,
    law::Data.ControlLaw;
    kwargs...,
)
    return _controlled_flow(fc, law, nothing; kwargs...)
end

"""
$(TYPEDSIGNATURES)

Reject a `DynClosedLoop` law in [`CTFlows.Flows.Flow(fc::CTBase.Data.ControlledVectorField, law::CTBase.Data.ControlLaw)`](@ref):
a dynamic closed-loop law `u(t,x,p,v)` needs the costate `p`, which a state flow of a
vector field does not have.

See also: [`CTFlows.Flows.Flow(h̃::CTBase.Data.PseudoHamiltonian, law::CTBase.Data.ControlLaw)`](@ref).
"""
function _flow_from_controlled_vf(
    ::Type{Traits.DynClosedLoopFeedback},
    ::Data.ControlledVectorField,
    ::Data.ControlLaw;
    kwargs...,
)
    return throw(
        Exceptions.PreconditionError(
            "Flow(fc, law) requires an OpenLoop or ClosedLoop control law";
            reason="a DynClosedLoop law u(t,x,p,v) needs the costate p, which a state " *
                   "flow of a vector field does not have",
            suggestion="use OpenLoop(u) or ClosedLoop(u); for a DynClosedLoop law use " *
                       "Flow(h̃, law) or Flow(ocp, law)",
            context="Flow(fc::ControlledVectorField, law::ControlLaw) — feedback dispatch",
        ),
    )
end

# =============================================================================
# Flow from an OCP and a control law
# =============================================================================

"""
$(TYPEDSIGNATURES)

Build a flow from an OCP and a **control law**.

Dispatches on the law's [`CTBase.Traits.feedback`](@extref) trait:
- `DynClosedLoop` → an [`CTFlows.Flows.OptimalControlFlow`](@ref) (Hamiltonian flow),
  using the `hamiltonian_type` action option (`:total` default, or `:partial`), the same
  way as [`CTFlows.Flows.Flow(h̃::CTBase.Data.PseudoHamiltonian, law::CTBase.Data.ControlLaw)`](@ref). The OCP's
  dynamics and cost supply the pseudo-Hamiltonian `H̃(t,x,p,u,v) = p·f + sp0·ℓ`; the
  trajectory call returns a [`CTModels.Solutions.Solution`](@extref) with the control
  reconstructed from the law.
- `OpenLoop`/`ClosedLoop` → a [`CTFlows.Flows.ControlledFlow`](@ref) (state flow): the
  control is eliminated via a [`CTBase.Data.ComposedVectorField`](@extref) and the OCP
  dynamics are integrated as a state flow; the trajectory call returns a
  [`CTFlows.Trajectories.ControlledTrajectory`](@ref).

# Throws
- [`CTBase.Exceptions.PreconditionError`](@extref): if the OCP is control-free.
- [`CTBase.Exceptions.PreconditionError`](@extref): if a `DynClosedLoop` law is passed
  to the state-flow path (should not happen via this constructor).
- [`CTBase.Exceptions.IncorrectArgument`](@extref): if `hamiltonian_type` is invalid.

See also: [`CTFlows.Flows.Flow`](@ref), [`CTFlows.Flows.OptimalControlFlow`](@ref),
[`CTFlows.Flows.ControlledFlow`](@ref).
"""
function Flow(ocp::CTModels.Models.Model, law::Data.ControlLaw; kwargs...)
    return _flow_from_ocp_control(Traits.feedback(law), ocp, law; kwargs...)
end

"""
$(TYPEDSIGNATURES)

Convenience constructor: wrap a raw control function `u` in a
[`CTBase.Data.DynClosedLoop`](@extref) control law and delegate to
[`CTFlows.Flows.Flow(ocp::CTModels.Models.Model, law::CTBase.Data.ControlLaw)`](@ref).

The control law is given **the same time/variable dependence as the OCP**
(`is_autonomous(ocp)`, `is_variable(ocp)`), so `u` **must** have the matching natural
arity — `(x,p)`, `(t,x,p)`, `(x,p,v)`, or `(t,x,p,v)` for
autonomous/fixed, non-autonomous/fixed, autonomous/non-fixed, non-autonomous/non-fixed
respectively. To use a control law whose traits differ from the OCP's (e.g. a
time-varying feedback on an autonomous OCP), build the
[`CTBase.Data.DynClosedLoop`](@extref) explicitly and call
[`CTFlows.Flows.Flow(ocp::CTModels.Models.Model, law::CTBase.Data.ControlLaw)`](@ref).

See also: [`CTFlows.Flows.Flow(ocp::CTModels.Models.Model, law::CTBase.Data.ControlLaw)`](@ref).
"""
function Flow(ocp::CTModels.Models.Model, u::Function; kwargs...)
    law = Data.DynClosedLoop(
        u; is_autonomous=Traits.is_autonomous(ocp), is_variable=Traits.is_variable(ocp)
    )
    return Flow(ocp, law; kwargs...)
end

"""
$(TYPEDSIGNATURES)

Build an [`CTFlows.Flows.OptimalControlFlow`](@ref) from the OCP pseudo-Hamiltonian and
a `DynClosedLoop` law, dispatching on the `hamiltonian_type` action option.

See also: [`CTFlows.Flows._build_pseudo_flow`](@ref), [`CTFlows.Flows._ocp_pseudo_hamiltonian`](@ref).
"""
function _flow_from_ocp_control(
    ::Type{Traits.DynClosedLoopFeedback},
    ocp::CTModels.Models.Model,
    law::Data.ControlLaw;
    kwargs...,
)
    Traits.control_dependence(ocp) === Traits.WithControl || throw(
        Exceptions.PreconditionError(
            "Flow(ocp, law) requires a with-control OCP";
            reason="the OCP is control-free (no control input), so a control law cannot be applied",
            suggestion="use Flow(ocp; kwargs…) for a control-free OCP",
            context="Flow(ocp, law::ControlLaw) — control-dependence check",
        ),
    )
    routed = _route_flow_options(kwargs; action_defs=_flow_action_defs())
    components = _build_flow_components(routed)
    ht = _unwrap_option(get(routed.action, :hamiltonian_type, nothing), :total)
    cspec = _unwrap_option(get(routed.action, :constraint, nothing), nothing)
    mspec = _unwrap_option(get(routed.action, :multiplier, nothing), nothing)
    h̃ = _ocp_pseudo_hamiltonian_for(ocp, Val(ht), cspec, mspec)
    inner = _build_pseudo_flow(Val(ht), h̃, law, components)
    return OptimalControlFlow(inner, ocp, law)
end

"""
$(TYPEDSIGNATURES)

Select the pseudo-Hamiltonian for an OCP + control-law flow, given the resolved
`hamiltonian_type` and the (optional) `constraint`/`multiplier` action options.

- Neither given → the plain [`CTFlows.Flows._ocp_pseudo_hamiltonian`](@ref).
- Both given → a constrained pseudo-Hamiltonian
  `H̃(t,x,p,u,v) + μ(t,x,p,v)·g(t,x,u,v)` via
  [`CTFlows.Flows._ocp_constrained_pseudo_hamiltonian`](@ref). Only the `:total` mode is
  supported for now (`:partial` is planned for a later release).
- Exactly one given → [`CTBase.Exceptions.IncorrectArgument`](@extref) (they are paired).

See also: [`CTFlows.Flows._resolve_constraint`](@ref), [`CTFlows.Flows._resolve_multiplier`](@ref).
"""
function _ocp_pseudo_hamiltonian_for(ocp, ::Val, cspec, mspec)
    (cspec === nothing) == (mspec === nothing) || throw(
        Exceptions.IncorrectArgument(
            "`constraint` and `multiplier` must be given together";
            got=cspec === nothing ? "only `multiplier`" : "only `constraint`",
            expected="both `constraint` and `multiplier`, or neither",
            context="Flow(ocp, law; constraint=…, multiplier=…) — pairing check",
        ),
    )
    cspec === nothing && return _ocp_pseudo_hamiltonian(ocp)
    g = _resolve_constraint(ocp, cspec)
    μ = _resolve_multiplier(ocp, mspec)
    return _ocp_constrained_pseudo_hamiltonian(ocp, g, μ)
end

# Constrained + :partial is not yet supported (planned for a later release): reject it
# before building anything, so the error is raised at construction with a clear message.
function _ocp_pseudo_hamiltonian_for(ocp, ::Val{:partial}, cspec, mspec)
    if !(cspec === nothing && mspec === nothing)
        throw(
            Exceptions.IncorrectArgument(
                "constrained flows are not yet supported with hamiltonian_type=:partial";
                got="constraint/multiplier with :partial",
                expected="hamiltonian_type=:total for a constrained flow",
                context="Flow(ocp, law; constraint=…, multiplier=…, hamiltonian_type=:partial)",
            ),
        )
    end
    return _ocp_pseudo_hamiltonian(ocp)
end

"""
$(TYPEDSIGNATURES)

Build a [`CTFlows.Flows.ControlledFlow`](@ref) (state flow) from the OCP controlled
dynamics and an `OpenLoop`/`ClosedLoop` law.

See also: [`CTFlows.Flows._controlled_flow`](@ref), [`CTFlows.Flows._ocp_controlled_vector_field`](@ref).
"""
function _flow_from_ocp_control(
    ::Type{<:Union{Traits.OpenLoopFeedback,Traits.ClosedLoopFeedback}},
    ocp::CTModels.Models.Model,
    law::Data.ControlLaw;
    kwargs...,
)
    Traits.control_dependence(ocp) === Traits.WithControl || throw(
        Exceptions.PreconditionError(
            "Flow(ocp, law) requires a with-control OCP";
            reason="the OCP is control-free (no control input), so a control law cannot be applied",
            suggestion="use Flow(ocp; kwargs…) for a control-free OCP",
            context="Flow(ocp, law::ControlLaw) — control-dependence check",
        ),
    )
    fc = _ocp_controlled_vector_field(ocp)
    return _controlled_flow(fc, law, ocp; kwargs...)
end

"""
$(TYPEDSIGNATURES)

Build a [`CTFlows.Flows.ControlledFlow`](@ref) from a controlled vector field, an
open-loop/closed-loop control law, and an optional OCP (for the objective): compose into
a [`CTBase.Data.ComposedVectorField`](@extref), build a `VectorFieldSystem`, and wrap the
resulting state flow together with the OCP reference (or `nothing`) and the law.
"""
function _controlled_flow(
    fc::Data.ControlledVectorField, law::Data.ControlLaw, ocp; kwargs...
)
    g = Data.ComposedVectorField(fc, law)
    system = Systems.build_system(g)
    integrator = Integrators.build_integrator(; kwargs...)
    return ControlledFlow(build_flow(system, integrator), ocp, law)
end

function Flow(::CTModels.Models.Model, ::Any, args...; kwargs...)
    return throw(
        Exceptions.PreconditionError(
            "Flow(ocp, …) with extra positional arguments is not supported";
            reason="passing a control law, state constraint or multiplier as a positional " *
                   "argument is not handled by the OCP flow constructor",
            suggestion="call Flow(ocp; kwargs…) — the OCP flow takes no positional argument beyond the model",
            context="Flow(ocp::CTModels.Models.Model) — positional-argument guard",
        ),
    )
end
