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
- `opts...`: Keyword options passed to the integrator's strategy. Pass `method=:gpu`
  (a `Symbol`, or a token tuple) to build the flow for GPU execution — the integrator
  resolves to `SciML{GPU}`; the default (`method=:cpu`) builds a CPU flow. The `method`
  selector is accepted by **every** `Flow(...)` constructor and, for AD-dependent flows,
  also selects the GPU AD backend.

# Returns
- `CTFlows.Flows.Flow`: The complete flow ready for integration.

# Example
\`\`\`julia
using CTBase: Data
using CTFlows: Flows

vf = Data.VectorField((t, x, v) -> x, Traits.Autonomous(), Traits.Fixed())
flow = Flows.Flow(vf; reltol=1e-8)
\`\`\`

See also: [`CTFlows.Flows.Flow`](@extref), [`CTFlows.Systems.build_system`](@extref), [`CTFlows.Flows._build_integrator`](@extref), [`CTSolvers.Integrators.SciML`](@extref).
"""
function Flow(data::Data.VectorField; opts...)
    system = Systems.build_system(data)
    return build_flow(system, _build_integrator(opts))
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
using CTBase: Data
using CTFlows: Flows

hvf = Data.HamiltonianVectorField((x, p) -> (x, -p); is_autonomous=true, is_variable=false)
flow = Flows.Flow(hvf; reltol=1e-8)
```

See also: [`CTFlows.Flows.HamiltonianFlow`](@extref), [`CTFlows.Systems.build_system`](@extref), [`CTFlows.Flows._build_integrator`](@extref), [`CTSolvers.Integrators.SciML`](@extref).
"""
function Flow(data::Data.HamiltonianVectorField; opts...)
    system = Systems.build_system(data)
    return build_flow(system, _build_integrator(opts))
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
  Pass `method=:gpu` to build the flow for GPU execution: the AD backend resolves to
  `DifferentiationInterface{GPU}` (whose default backend is `AutoZygote`) and the integrator
  to `SciML{GPU}`. The default (`method=:cpu`) keeps `AutoForwardDiff` + `SciML{CPU}`.

# Returns
- `CTFlows.Flows.HamiltonianFlow`: The complete Hamiltonian flow ready for integration.

# Throws
- [`CTBase.Exceptions.IncorrectArgument`](@extref): If an option is unknown, ambiguous,
  or routed to the wrong strategy.
- [`CTBase.Exceptions.ExtensionError`](@extref): If the `CTFlowsSciMLIntegrator` extension is not loaded
  (required for `:sciml` strategy metadata).

# Example
```julia
using CTBase: Data
using CTFlows: Flows

h = Data.Hamiltonian((t, x, p, v) -> 0.5 * (x[1]^2 + p[1]^2); is_autonomous=true, is_variable=false)
flow = Flows.Flow(h; reltol=1e-8, ad_backend=ADTypes.AutoForwardDiff())
# flow isa CTFlows.Flows.HamiltonianFlow
```

# Notes
- The state dimension is inferred from the Hamiltonian's signature.
- Use the `state_dimension` argument overload if explicit dimension is needed.
- Requires the `CTFlowsSciMLIntegrator` extension to be loaded for integrator options.

See also: [`CTFlows.Flows.HamiltonianFlow`](@extref), [`CTFlows.Systems.build_system`](@extref),
[`CTFlows.Flows._route_flow_options`](@extref), [`CTFlows.Flows._build_flow_components`](@extref)
"""
function Flow(h::Data.AbstractHamiltonian; kwargs...)
    method, kw = _pop_method(kwargs)
    routed = _route_flow_options(Traits.WithAD, kw; method=method)
    components = _build_flow_components(Traits.WithAD, routed; method=method)
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
  [`CTFlows.Flows.Flow(ocp::CTModels.Models.Model, law::CTBase.Data.ControlLaw)`](@extref).

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

See also: [`CTFlows.Flows.OptimalControlFlow`](@extref), [`CTFlows.Flows.Flow`](@extref).
"""
function Flow(ocp::CTModels.Models.Model; kwargs...)
    return _flow_from_ocp(Traits.control_dependence(ocp), ocp; kwargs...)
end

"""
$(TYPEDSIGNATURES)

Build an `OptimalControlFlow` from a control-free OCP.

Constructs the OCP Hamiltonian, builds the Hamiltonian system with the chosen AD
backend, and wraps the resulting flow together with the OCP reference.

See also: [`CTFlows.Flows.OptimalControlFlow`](@extref), [`CTFlows.Flows.Flow`](@extref), `CTFlows.Flows._ocp_hamiltonian`.
"""
function _flow_from_ocp(::Type{Traits.ControlFree}, ocp::CTModels.Models.Model; kwargs...)
    _reject_control_free_constraint(kwargs)
    method, kw = _pop_method(kwargs)
    routed = _route_flow_options(Traits.WithAD, kw; method=method)
    components = _build_flow_components(Traits.WithAD, routed; method=method)
    h = _ocp_hamiltonian(ocp)
    sys = Systems.build_system(h, components.backend)
    inner = build_flow(sys, components.integrator)
    state_sys = Systems.build_system(_ocp_state_vector_field(ocp))
    state_flow = build_flow(state_sys, components.integrator)
    return OptimalControlFlow(inner, ocp; state_flow=state_flow)
end

"""
$(TYPEDSIGNATURES)

Reject a `constraint` / `multiplier` keyword on a **control-free** `Flow(ocp)`.

Constrained flows are only defined for the with-control case `Flow(ocp, law; …)`, where
the constraint term `μ·g` enters the pseudo-Hamiltonian `H̃ + μ·g` alongside the control.
With no control law there is no pseudo-Hamiltonian to augment, so a state constraint has
no well-defined place in the control-free OCP Hamiltonian flow. Throws
[`CTBase.Exceptions.PreconditionError`](@extref).

See also: [`CTFlows.Flows.Flow`](@extref).
"""
function _reject_control_free_constraint(kwargs)
    (haskey(kwargs, :constraint) || haskey(kwargs, :multiplier)) && throw(
        Exceptions.PreconditionError(
            "constrained flows are not supported for control-free problems";
            reason="a `constraint`/`multiplier` pair augments the pseudo-Hamiltonian " *
                   "H̃ + μ·g with the control; a control-free Flow(ocp) has no control " *
                   "law and no pseudo-Hamiltonian to carry the constraint term",
            suggestion="use Flow(ocp, law; constraint=…, multiplier=…) with a control law",
            context="Flow(ocp; constraint=…, multiplier=…) — control-free constraint guard",
        ),
    )
    return nothing
end

"""
$(TYPEDSIGNATURES)

Reject `Flow(ocp)` construction from a with-control OCP.

Throws `PreconditionError` because this path assumes no control input. Use
`Flow(ocp, law)` to pass a control law that closes the loop.

See also: [`CTFlows.Flows.Flow`](@extref), `CTFlows.Flows._ocp_hamiltonian`.
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
  `H(t,x,p,v)=H̃(t,x,p,u(t,x,p,v),v)` and a [`CTFlows.Systems.HamiltonianSystem`](@extref);
  AD differentiates *through* the law (total derivative).
- `hamiltonian_type=:partial` — build a [`CTFlows.Systems.PseudoHamiltonianSystem`](@extref);
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

See also: [`CTFlows.Flows.Flow`](@extref), [`CTBase.Data.PseudoHamiltonian`](@extref),
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

See also: [`CTFlows.Flows._build_pseudo_flow`](@extref).
"""
function _flow_from_pseudo_hamiltonian(
    ::Type{Traits.DynClosedLoopFeedback},
    h̃::Data.PseudoHamiltonian,
    law::Data.ControlLaw;
    kwargs...,
)
    method, kw = _pop_method(kwargs)
    routed = _route_flow_options(
        Traits.WithAD, kw; method=method, action_defs=_flow_action_defs()
    )
    components = _build_flow_components(Traits.WithAD, routed; method=method)
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
`H̃` with the control law `u(t,x,p,v)` into a [`CTBase.Data.ComposedHamiltonian`](@extref)
`H(t,x,p,v) = H̃(t,x,p,u(t,x,p,v),v)`, wrap it in a
[`CTFlows.Systems.HamiltonianSystem`](@extref), and build the flow.

See also: [`CTFlows.Flows._build_pseudo_flow`](@extref), [`CTFlows.Systems.HamiltonianSystem`](@extref),
[`CTBase.Data.ComposedHamiltonian`](@extref).
"""
function _build_pseudo_flow(::Val{:total}, h̃, law, components)
    H = Data.ComposedHamiltonian(h̃, law)
    sys = Systems.build_system(H, components.backend)
    return build_flow(sys, components.integrator)
end

"""
$(TYPEDSIGNATURES)

Build the inner Hamiltonian flow for the `:partial` mode: wrap the pseudo-Hamiltonian
and control law in a [`CTFlows.Systems.PseudoHamiltonianSystem`](@extref) (AD at fixed `u`).

See also: [`CTFlows.Flows._build_pseudo_flow`](@extref),
[`CTFlows.Systems.PseudoHamiltonianSystem`](@extref).
"""
function _build_pseudo_flow(::Val{:partial}, h̃, law, components)
    sys = Systems.build_system(h̃, law, components.backend)
    return build_flow(sys, components.integrator)
end

"""
$(TYPEDSIGNATURES)

Throw an [`CTBase.Exceptions.IncorrectArgument`](@extref) for an unknown
`hamiltonian_type` value. Only `:total` and `:partial` are supported.

# Throws
- [`CTBase.Exceptions.IncorrectArgument`](@extref): when `ht` is not `:total` or `:partial`.

See also: [`CTFlows.Flows._build_pseudo_flow`](@extref).
"""
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
# Flow from a pseudo-Hamiltonian vector field and a control law
# (intermediate constructor, no AD)
# =============================================================================

"""
$(TYPEDSIGNATURES)

Build a `HamiltonianFlow` directly from a pseudo-Hamiltonian vector field
`h̃vf(t,x,p,u,v) = (ẋ,ṗ)` (already differentiated by the user — no AD) and a dynamic
closed-loop control law `u(t,x,p,v)`, without going through an OCP.

The vector-field analogue of [`CTFlows.Flows.Flow(h̃::CTBase.Data.PseudoHamiltonian, law::CTBase.Data.ControlLaw)`](@ref):
that constructor differentiates a scalar `H̃` by AD (`:total`/`:partial`); this one
takes `h̃vf` as the derivatives directly, so there is only **one mode** — no
`hamiltonian_type` option.

# Arguments
- `h̃vf::Data.PseudoHamiltonianVectorField`: the pseudo-Hamiltonian vector field.
- `law::Data.ControlLaw`: the control law; must carry `DynClosedLoopFeedback`.
- `opts...`: integrator strategy options (as for `Flow(hvf::Data.HamiltonianVectorField)`)
  — no AD-backend options, since there is no AD in this path.

# Throws
- [`CTBase.Exceptions.PreconditionError`](@extref): if the law is `OpenLoop`/`ClosedLoop`
  (a pseudo-Hamiltonian vector field needs the costate `p`, which those laws do not take).

See also: [`CTFlows.Flows.Flow`](@extref), [`CTBase.Data.PseudoHamiltonianVectorField`](@extref),
[`CTBase.Data.DynClosedLoop`](@extref).
"""
function Flow(h̃vf::Data.PseudoHamiltonianVectorField, law::Data.ControlLaw; opts...)
    return _flow_from_pseudo_hamiltonian_vf(Traits.feedback(law), h̃vf, law; opts...)
end

"""
$(TYPEDSIGNATURES)

Dispatch helper for [`CTFlows.Flows.Flow(h̃vf::CTBase.Data.PseudoHamiltonianVectorField, law::CTBase.Data.ControlLaw)`](@ref):
build a `PseudoHamiltonianVectorFieldSystem`-backed Hamiltonian flow from a
`DynClosedLoop` law.

See also: [`CTFlows.Systems.build_system`](@extref).
"""
function _flow_from_pseudo_hamiltonian_vf(
    ::Type{Traits.DynClosedLoopFeedback},
    h̃vf::Data.PseudoHamiltonianVectorField,
    law::Data.ControlLaw;
    opts...,
)
    sys = Systems.build_system(h̃vf, law)
    return build_flow(sys, _build_integrator(opts))
end

"""
$(TYPEDSIGNATURES)

Reject `OpenLoop`/`ClosedLoop` laws in [`CTFlows.Flows.Flow(h̃vf::CTBase.Data.PseudoHamiltonianVectorField, law::CTBase.Data.ControlLaw)`](@ref):
a pseudo-Hamiltonian vector field `h̃vf(t,x,p,u,v)` depends on the costate `p`, which
`OpenLoop`/`ClosedLoop` laws do not provide.

See also: [`CTFlows.Flows.Flow(h̃vf::CTBase.Data.PseudoHamiltonianVectorField, law::CTBase.Data.ControlLaw)`](@ref).
"""
function _flow_from_pseudo_hamiltonian_vf(
    ::Type{<:Union{Traits.OpenLoopFeedback,Traits.ClosedLoopFeedback}},
    ::Data.PseudoHamiltonianVectorField,
    ::Data.ControlLaw;
    opts...,
)
    return throw(
        Exceptions.PreconditionError(
            "Flow(h̃vf, law) requires a DynClosedLoop control law";
            reason="a pseudo-Hamiltonian vector field h̃vf(t,x,p,u,v) depends on the " *
                   "costate p, but OpenLoop u(t,v) and ClosedLoop u(t,x,v) control laws " *
                   "do not take p",
            suggestion="use DynClosedLoop(u) to construct a control law u(t,x,p,v)",
            context="Flow(h̃vf::PseudoHamiltonianVectorField, law::ControlLaw) — feedback dispatch",
        ),
    )
end

# =============================================================================
# Flow from a controlled vector field and a control law (intermediate constructor)
# =============================================================================

"""
$(TYPEDSIGNATURES)

Build a [`CTFlows.Flows.ControlledFlow`](@extref) directly from a controlled vector field
`fc(t,x,u,v)` and an **open-loop** or **closed-loop** control law, without an OCP.

Dispatches on the law's [`CTBase.Traits.feedback`](@extref) trait: the control is
eliminated via a [`CTBase.Data.ComposedVectorField`](@extref) `g(t,x,v)=fc(t,x,u(...),v)`,
integrated as a state flow. A trajectory call returns a
[`CTFlows.Trajectories.StateFlowTrajectory`](@extref) (state + reconstructed control, no
objective — there is no OCP).

# Throws
- [`CTBase.Exceptions.PreconditionError`](@extref): if the law is `DynClosedLoop` (that
  needs the costate; use [`CTFlows.Flows.Flow(h̃::CTBase.Data.PseudoHamiltonian, law::CTBase.Data.ControlLaw)`](@ref)).

See also: [`CTFlows.Flows.Flow`](@extref), [`CTBase.Data.ControlledVectorField`](@extref).
"""
function Flow(fc::Data.ControlledVectorField, law::Data.ControlLaw; kwargs...)
    return _flow_from_controlled_vf(Traits.feedback(law), fc, law; kwargs...)
end

"""
$(TYPEDSIGNATURES)

Dispatch helper for [`CTFlows.Flows.Flow(fc::CTBase.Data.ControlledVectorField, law::CTBase.Data.ControlLaw)`](@ref):
compose `fc` with an `OpenLoop`/`ClosedLoop` law into a [`CTFlows.Flows.ControlledFlow`](@extref)
with no OCP.

See also: [`CTFlows.Flows._controlled_flow`](@extref).
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
- `DynClosedLoop` → an [`CTFlows.Flows.OptimalControlFlow`](@extref) (Hamiltonian flow),
  using the `hamiltonian_type` action option (`:total` default, or `:partial`), the same
  way as [`CTFlows.Flows.Flow(h̃::CTBase.Data.PseudoHamiltonian, law::CTBase.Data.ControlLaw)`](@ref). The OCP's
  dynamics and cost supply the pseudo-Hamiltonian `H̃(t,x,p,u,v) = p·f + sp0·ℓ`; the
  trajectory call returns a [`CTModels.Solutions.Solution`](@extref) with the control
  reconstructed from the law.
- `OpenLoop`/`ClosedLoop` → a [`CTFlows.Flows.ControlledFlow`](@extref) (state flow): the
  control is eliminated via a [`CTBase.Data.ComposedVectorField`](@extref) and the OCP
  dynamics are integrated as a state flow; the trajectory call returns a
  [`CTFlows.Trajectories.StateFlowTrajectory`](@extref).

# Throws
- [`CTBase.Exceptions.PreconditionError`](@extref): if the OCP is control-free.
- [`CTBase.Exceptions.PreconditionError`](@extref): if a `DynClosedLoop` law is passed
  to the state-flow path (should not happen via this constructor).
- [`CTBase.Exceptions.IncorrectArgument`](@extref): if `hamiltonian_type` is invalid.

See also: [`CTFlows.Flows.Flow`](@extref), [`CTFlows.Flows.OptimalControlFlow`](@extref),
[`CTFlows.Flows.ControlledFlow`](@extref).
"""
function Flow(ocp::CTModels.Models.Model, law::Data.ControlLaw; kwargs...)
    return _flow_from_ocp_control(Traits.feedback(law), ocp, law; kwargs...)
end

# =============================================================================
# Convenience-constructor arity checking
# =============================================================================

"""
$(TYPEDSIGNATURES)

Natural arity expected of a raw convenience function (control law, constraint, or
multiplier) for an OCP with the given time/variable dependence.

The natural signatures of a control law `u(x,p)`, a constraint `g(x,u)` and a multiplier
`μ(x,p)` all share the same shape: 2 fixed arguments, plus `t` if the OCP is
non-autonomous, plus `v` if the OCP is non-fixed (`is_variable`).

# Arguments
- `ocp::CTModels.Models.Model`: the OCP, used to read its time/variable dependence.

# Returns
- `Int`: the expected number of positional arguments.

See also: [`CTFlows.Flows._arity_issue`](@extref).
"""
_expected_arity(ocp) = 2 + !Traits.is_autonomous(ocp) + Traits.is_variable(ocp)

"""
$(TYPEDSIGNATURES)

Natural-syntax example for a raw convenience function, given its symbol and second
argument name and an OCP's time/variable dependence — used in arity-mismatch messages.

# Arguments
- `label::AbstractString`: the symbol name shown in the example (e.g. `"u"`).
- `second::AbstractString`: the name of the second natural argument (`"p"` for a control
  law/multiplier, `"u"` for a constraint).
- `ocp::CTModels.Models.Model`: the OCP, used to read its time/variable dependence.

# Returns
- `String`: e.g. `"u(t, x, p)"`.

See also: [`CTFlows.Flows._arity_issue`](@extref).
"""
function _natural_syntax(label::AbstractString, second::AbstractString, ocp)
    args = String[]
    Traits.is_autonomous(ocp) || push!(args, "t")
    push!(args, "x", second)
    Traits.is_variable(ocp) && push!(args, "v")
    return "$label($(join(args, ", ")))"
end

"""
$(TYPEDSIGNATURES)

Check the arity of a raw convenience function `f` against the natural arity expected for
an OCP with the given time/variable dependence.

Mirrors the mutability-detection pattern used for vector fields
(`CTBase.Data._detect_mutability_vf`): a single-method guard makes arity detection
unambiguous via `first(methods(f)).nargs`. Unlike that pattern, this check **skips**
(returns `nothing`) rather than throws when `f` has more than one method — the caller
cannot tell which arity the user intended, so no diagnostic is possible.

# Arguments
- `f::Function`: the raw function to inspect (control law, constraint, or multiplier).
- `ocp::CTModels.Models.Model`: the OCP, used to infer the expected arity.
- `label::AbstractString`: the symbol name used in the natural-syntax example (e.g. `"u"`).
- `second::AbstractString`: the name of the second natural argument (`"p"` for a control
  law/multiplier, `"u"` for a constraint).
- `kind::AbstractString`: a human-readable description of the role (e.g. `"control law"`),
  used in the diagnostic message.

# Returns
- `Nothing`: if the arity matches, or if `f` has more than one method (ambiguous).
- `String`: a one-line diagnostic naming the expected natural syntax, otherwise.

See also: [`CTFlows.Flows._expected_arity`](@extref), [`CTFlows.Flows._natural_syntax`](@extref).
"""
function _arity_issue(
    f::Function, ocp, label::AbstractString, second::AbstractString, kind::AbstractString
)
    length(methods(f)) == 1 || return nothing
    arity = first(methods(f)).nargs - 1
    expected = _expected_arity(ocp)
    arity == expected && return nothing
    syntax = _natural_syntax(label, second, ocp)
    return "$kind `$label` has arity $arity, expected $expected — natural syntax is `$syntax`"
end

"""
$(TYPEDSIGNATURES)

No arity issues for a `nothing` spec — skip the check.

See also: [`CTFlows.Flows._spec_arity_issues!`](@extref).
"""
_spec_arity_issues!(issues, ocp, ::Nothing, label, second, kind) = nothing

"""
$(TYPEDSIGNATURES)

Check the arity of a single `Function` spec against the OCP's expected arity and push
an issue string into `issues` if they differ.

See also: [`CTFlows.Flows._check_convenience_arities`](@extref),
[`CTFlows.Flows._arity_issue`](@extref).
"""
function _spec_arity_issues!(
    issues,
    ocp,
    spec::Function,
    label::AbstractString,
    second::AbstractString,
    kind::AbstractString,
)
    issue = _arity_issue(spec, ocp, label, second, kind)
    issue === nothing || push!(issues, issue)
    return nothing
end
"""
$(TYPEDSIGNATURES)

Check the arity of each `Function` element in a `Tuple` spec against the OCP's expected
arity, pushing an issue string per mismatch into `issues`. Non-`Function` elements are
skipped.

See also: [`CTFlows.Flows._check_convenience_arities`](@extref),
[`CTFlows.Flows._arity_issue`](@extref).
"""
function _spec_arity_issues!(
    issues,
    ocp,
    spec::Tuple,
    label::AbstractString,
    second::AbstractString,
    kind::AbstractString,
)
    for (i, s) in enumerate(spec)
        s isa Function || continue
        issue = _arity_issue(s, ocp, "$label$i", second, "$kind #$i")
        issue === nothing || push!(issues, issue)
    end
    return nothing
end
"""
$(TYPEDSIGNATURES)

Fallback for an already-resolved spec (not a `Function` or `Tuple`): no arity check
needed.

See also: [`CTFlows.Flows._check_convenience_arities`](@extref).
"""
_spec_arity_issues!(issues, ocp, spec, label, second, kind) = nothing

"""
$(TYPEDSIGNATURES)

Check the arities of the raw functions passed to an OCP convenience constructor — the
control law `u`, and (if given as raw `Function`s) the `constraint`/`multiplier` specs —
against the OCP's time/variable dependence.

Collects every mismatch (a function with a single method and a wrong arity) into one
[`CTBase.Exceptions.IncorrectArgument`](@extref), naming the expected natural syntax for
each and suggesting the explicit constructors as an escape hatch. Functions with more than
one method are skipped (arity cannot be determined); `Tuple` constraint/multiplier specs
are checked element-wise; `nothing` is skipped (no spec given).

# Arguments
- `ocp::CTModels.Models.Model`: the OCP.
- `u`: the control-law spec (`nothing` or a raw `Function`).
- `cspec`: the `constraint` spec (`nothing`, `Symbol`, `Function`, `Tuple`, or
  `CTBase.Data.PathConstraint`).
- `mspec`: the `multiplier` spec (`nothing`, `Function`, `Tuple`, or `CTBase.Data.Multiplier`).

A control-free OCP is skipped entirely (no throw): a control law's arity is only
meaningful relative to an OCP that actually has a control, and a control-free OCP is
already rejected with a clearer, more fundamental `PreconditionError` downstream.

# Throws
- [`CTBase.Exceptions.IncorrectArgument`](@extref): if at least one raw function has a
  single method and a mismatched arity, on a with-control OCP.

See also: [`CTFlows.Flows._arity_issue`](@extref), [`CTFlows.Flows._spec_arity_issues!`](@extref).
"""
function _check_convenience_arities(ocp, u, cspec, mspec)
    Traits.control_dependence(ocp) === Traits.WithControl || return nothing
    issues = String[]
    _spec_arity_issues!(issues, ocp, u, "u", "p", "control law")
    _spec_arity_issues!(issues, ocp, cspec, "g", "u", "constraint")
    _spec_arity_issues!(issues, ocp, mspec, "μ", "p", "multiplier")
    isempty(issues) && return nothing
    return throw(
        Exceptions.IncorrectArgument(
            "convenience-constructor arity mismatch ($(length(issues)) issue(s))";
            got=join(issues, "; "),
            expected="each raw function's arity to match the OCP's time/variable dependence",
            suggestion="pass explicit constructors instead — Data.DynClosedLoop/Data.OpenLoop/Data.ClosedLoop " *
                       "for the control law, Data.MixedConstraint/Data.StateConstraint/Data.ControlConstraint " *
                       "for the constraint, Data.Multiplier for the multiplier — with the time/variable " *
                       "dependence you intend; this check only runs when the raw function has a single " *
                       "method (skipped if ambiguous, e.g. multiple dispatch or default arguments)",
            context="Flow(ocp, u::Function; constraint=…, multiplier=…) — convenience arity check",
        ),
    )
end

"""
$(TYPEDSIGNATURES)

Convenience constructor: wrap a raw control function `u` in a
[`CTBase.Data.DynClosedLoop`](@extref) control law and delegate to
[`CTFlows.Flows.Flow(ocp::CTModels.Models.Model, law::CTBase.Data.ControlLaw)`](@extref).

The control law is given **the same time/variable dependence as the OCP**
(`is_autonomous(ocp)`, `is_variable(ocp)`), so `u` **must** have the matching natural
arity — `(x,p)`, `(t,x,p)`, `(x,p,v)`, or `(t,x,p,v)` for
autonomous/fixed, non-autonomous/fixed, autonomous/non-fixed, non-autonomous/non-fixed
respectively. To use a control law whose traits differ from the OCP's (e.g. a
time-varying feedback on an autonomous OCP), build the
[`CTBase.Data.DynClosedLoop`](@extref) explicitly and call
[`CTFlows.Flows.Flow(ocp::CTModels.Models.Model, law::CTBase.Data.ControlLaw)`](@extref).

If `u` (and, when given as raw `Function`s, the `constraint`/`multiplier` keyword specs)
has a single method, its arity is checked against the OCP's time/variable dependence —
see [`CTFlows.Flows._check_convenience_arities`](@extref).

# Throws
- [`CTBase.Exceptions.IncorrectArgument`](@extref): if `u`, `constraint`, or `multiplier`
  has a single method and a mismatched arity.

See also: [`CTFlows.Flows.Flow(ocp::CTModels.Models.Model, law::CTBase.Data.ControlLaw)`](@extref),
[`CTFlows.Flows._check_convenience_arities`](@extref).
"""
function Flow(ocp::CTModels.Models.Model, u::Function; kwargs...)
    _check_convenience_arities(
        ocp, u, get(kwargs, :constraint, nothing), get(kwargs, :multiplier, nothing)
    )
    law = Data.DynClosedLoop(
        u; is_autonomous=Traits.is_autonomous(ocp), is_variable=Traits.is_variable(ocp)
    )
    return Flow(ocp, law; kwargs...)
end

"""
$(TYPEDSIGNATURES)

Build an [`CTFlows.Flows.OptimalControlFlow`](@extref) from the OCP pseudo-Hamiltonian and
a `DynClosedLoop` law, dispatching on the `hamiltonian_type` action option.

If `constraint`/`multiplier` are given as raw `Function`s with a single method, their
arity is checked against the OCP's time/variable dependence — see
[`CTFlows.Flows._check_convenience_arities`](@extref). `law` itself is not checked here: it
may have been built explicitly with traits that deliberately differ from the OCP's (the
arity of a raw `u` is only checked in
[`CTFlows.Flows.Flow(ocp::CTModels.Models.Model, u::Function)`](@ref), which builds the
law itself from the OCP's traits).

# Throws
- [`CTBase.Exceptions.IncorrectArgument`](@extref): if `constraint` or `multiplier` has a
  single method and a mismatched arity.

See also: [`CTFlows.Flows._build_pseudo_flow`](@extref), [`CTFlows.Flows._ocp_pseudo_hamiltonian`](@extref),
[`CTFlows.Flows._check_convenience_arities`](@extref).
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
    method, kw = _pop_method(kwargs)
    routed = _route_flow_options(
        Traits.WithAD, kw; method=method, action_defs=_flow_action_defs()
    )
    components = _build_flow_components(Traits.WithAD, routed; method=method)
    ht = _unwrap_option(get(routed.action, :hamiltonian_type, nothing), :total)
    cspec = _unwrap_option(get(routed.action, :constraint, nothing), nothing)
    mspec = _unwrap_option(get(routed.action, :multiplier, nothing), nothing)
    _check_convenience_arities(ocp, nothing, cspec, mspec)
    _validate_constraint_pair(cspec, mspec)
    inner = _build_ocp_pseudo_flow(Val(ht), ocp, law, components, cspec, mspec)
    return OptimalControlFlow(inner, ocp, law)
end

"""
$(TYPEDSIGNATURES)

Validate the `constraint`/`multiplier` pairing: they must be given **together** (both or
neither), and for multiple constraints both must be tuples of equal length (element `i` of
`constraint` pairs with element `i` of `multiplier`).

# Throws
- [`CTBase.Exceptions.IncorrectArgument`](@extref): if exactly one of the two is given; if one
  is a tuple and the other is not; or if the two tuples have different lengths.

See also: [`CTFlows.Flows._build_ocp_pseudo_flow`](@extref), [`CTFlows.Flows._CombinedConstraint`](@extref).
"""
function _validate_constraint_pair(cspec, mspec)
    (cspec === nothing) == (mspec === nothing) || throw(
        Exceptions.IncorrectArgument(
            "`constraint` and `multiplier` must be given together";
            got=cspec === nothing ? "only `multiplier`" : "only `constraint`",
            expected="both `constraint` and `multiplier`, or neither",
            context="Flow(ocp, law; constraint=…, multiplier=…) — pairing check",
        ),
    )
    # Multiple constraints: if either side is a tuple, both must be tuples of equal length
    # (element `i` of `constraint` pairs with element `i` of `multiplier`).
    if cspec isa Tuple || mspec isa Tuple
        (cspec isa Tuple && mspec isa Tuple) || throw(
            Exceptions.IncorrectArgument(
                "`constraint` and `multiplier` must both be tuples for multiple constraints";
                got=if cspec isa Tuple
                    "tuple `constraint`, non-tuple `multiplier`"
                else
                    "non-tuple `constraint`, tuple `multiplier`"
                end,
                expected="both `constraint` and `multiplier` given as tuples",
                context="Flow(ocp, law; constraint=(…,), multiplier=(…,)) — pairing check",
            ),
        )
        length(cspec) == length(mspec) || throw(
            Exceptions.IncorrectArgument(
                "`constraint` and `multiplier` tuples must have the same length";
                got="$(length(cspec)) constraints, $(length(mspec)) multipliers",
                expected="matched tuple lengths",
                context="Flow(ocp, law; constraint=(…,), multiplier=(…,)) — pairing check",
            ),
        )
    end
    return nothing
end

"""
$(TYPEDSIGNATURES)

Build the inner Hamiltonian flow of an OCP + control-law flow, dispatching on the
`hamiltonian_type` and on the presence of a `constraint`/`multiplier` pair (already
validated by [`CTFlows.Flows._validate_constraint_pair`](@extref)).

- **`:total`** — bake the constraint into the pseudo-Hamiltonian
  `H̃(t,x,p,u,v) + μ(t,x,p,v)·g(t,x,u,v)` (via
  [`CTFlows.Flows._ocp_constrained_pseudo_hamiltonian`](@extref)) and compose with the law;
  AD differentiates through `H̃`, `μ`, `g` and the law (total derivative). Unconstrained →
  the plain [`CTFlows.Flows._ocp_pseudo_hamiltonian`](@extref).
- **`:partial`** — build a [`CTFlows.Systems.ConstrainedPseudoHamiltonianSystem`](@extref)
  carrying the base `H̃`, the law, `g` and `μ` separately; the RHS freezes the multiplier
  value `μ` alongside the control `u` and differentiates only through `g`. Unconstrained →
  a [`CTFlows.Systems.PseudoHamiltonianSystem`](@extref).

See also: [`CTFlows.Flows._resolve_constraint`](@extref), [`CTFlows.Flows._resolve_multiplier`](@extref),
[`CTFlows.Flows._build_pseudo_flow`](@extref).
"""
function _build_ocp_pseudo_flow(::Val{:total}, ocp, law, components, cspec, mspec)
    h̃ = if cspec === nothing
        _ocp_pseudo_hamiltonian(ocp)
    else
        _ocp_constrained_pseudo_hamiltonian(
            ocp, _resolve_constraint(ocp, cspec), _resolve_multiplier(ocp, mspec)
        )
    end
    return _build_pseudo_flow(Val(:total), h̃, law, components)
end

"""
$(TYPEDSIGNATURES)

Build the inner flow for the `:partial` mode from an OCP pseudo-Hamiltonian and a
control law. When a constraint spec (`cspec`) is provided, resolve it together with the
multiplier spec (`mspec`) and build a
[`CTFlows.Systems.ConstrainedPseudoHamiltonianSystem`](@extref); otherwise delegate to
[`CTFlows.Flows._build_pseudo_flow`](@extref).

See also: [`CTFlows.Flows._build_pseudo_flow`](@extref),
[`CTFlows.Systems.ConstrainedPseudoHamiltonianSystem`](@extref),
[`CTFlows.Flows._resolve_constraint`](@extref), [`CTFlows.Flows._resolve_multiplier`](@extref).
"""
function _build_ocp_pseudo_flow(::Val{:partial}, ocp, law, components, cspec, mspec)
    h̃ = _ocp_pseudo_hamiltonian(ocp)
    cspec === nothing && return _build_pseudo_flow(Val(:partial), h̃, law, components)
    g = _resolve_constraint(ocp, cspec)
    μ = _resolve_multiplier(ocp, mspec)
    sys = Systems.build_system(h̃, law, g, μ, components.backend)
    return build_flow(sys, components.integrator)
end

"""
$(TYPEDSIGNATURES)

Unknown `hamiltonian_type`: delegate to the (throwing) unconstrained fallback so the
error message and type match `Flow(h̃, law; hamiltonian_type=…)`.

See also: [`CTFlows.Flows._build_pseudo_flow`](@extref).
"""
function _build_ocp_pseudo_flow(::Val{ht}, ocp, law, components, cspec, mspec) where {ht}
    return _build_pseudo_flow(Val(ht), _ocp_pseudo_hamiltonian(ocp), law, components)
end

"""
$(TYPEDSIGNATURES)

Build a [`CTFlows.Flows.ControlledFlow`](@extref) (state flow) from the OCP controlled
dynamics and an `OpenLoop`/`ClosedLoop` law.

See also: [`CTFlows.Flows._controlled_flow`](@extref), [`CTFlows.Flows._ocp_controlled_vector_field`](@extref).
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

Build a [`CTFlows.Flows.ControlledFlow`](@extref) from a controlled vector field, an
open-loop/closed-loop control law, and an optional OCP (for the objective): compose into
a [`CTBase.Data.ComposedVectorField`](@extref), build a `VectorFieldSystem`, and wrap the
resulting state flow together with the OCP reference (or `nothing`) and the law.
"""
function _controlled_flow(
    fc::Data.ControlledVectorField, law::Data.ControlLaw, ocp; kwargs...
)
    g = Data.ComposedVectorField(fc, law)
    system = Systems.build_system(g)
    return ControlledFlow(build_flow(system, _build_integrator(kwargs)), ocp, law)
end

"""
$(TYPEDSIGNATURES)

Reject `Flow(ocp, …)` with extra positional arguments beyond the model. Only
`Flow(ocp; kwargs…)` (control-free) and `Flow(ocp, law; kwargs…)` (with a control law)
are supported.

# Throws
- [`CTBase.Exceptions.PreconditionError`](@extref): when extra positional arguments are passed.

See also: [`CTFlows.Flows.Flow`](@extref).
"""
function Flow(::CTModels.Models.Model, ::Any, args...; kwargs...)
    return throw(
        Exceptions.PreconditionError(
            "Flow(ocp, …) with extra positional arguments is not supported";
            reason="passing a control law, state constraint or multiplier as a positional " *
                   "argument is not handled by the OCP flow constructor",
            suggestion="Flow(ocp, u) takes the control law positionally; pass constraint/multiplier as keywords: Flow(ocp, u; constraint=g, multiplier=μ)",
            context="Flow(ocp::CTModels.Models.Model) — positional-argument guard",
        ),
    )
end
