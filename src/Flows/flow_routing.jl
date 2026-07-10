"""
$(TYPEDSIGNATURES)

Return the strategy families used for option routing in flow construction.

The returned `NamedTuple` maps family names to their abstract types, as expected
by [`CTBase.Orchestration.route_all_options`](@extref).

# Returns
- `NamedTuple`: `(backend, integrator)` mapped to their abstract types

# Example
```julia
# Get the strategy families for flow construction
fam = Flows._flow_families()
# Returns: (backend = CTBase.Differentiation.AbstractADBackend, integrator = CTFlows.Integrators.AbstractIntegrator)
```

See also: [`CTFlows.Flows._route_flow_options`](@ref), [`CTFlows.Flows.flow_registry`](@ref)
"""
function _flow_families()
    return (
        backend=Differentiation.AbstractADBackend, integrator=Integrators.AbstractIntegrator
    )
end

"""
$(TYPEDEF)

Strategy family description for flow construction.

This constant identifies the strategy families used in flow construction:
- `:di` - DifferentiationInterface family for AD backends
- `:sciml` - SciML family for ODE integrators

# Type
- `Tuple{Symbol, Symbol}`: Tuple of strategy family identifiers.

# Notes
- Used by [`CTFlows.Flows._route_flow_options`](@ref) and [`CTFlows.Flows._build_flow_components`](@ref).
- Passed to [`CTBase.Orchestration.route_all_options`](@extref) and [`CTBase.Orchestration.resolve_method`](@extref).

See also: [`CTFlows.Flows._route_flow_options`](@ref), [`CTFlows.Flows._build_flow_components`](@ref), [`CTFlows.Flows._flow_families`](@ref).
"""
const _FLOW_DESCRIPTION = (:di, :sciml)

"""
$(TYPEDSIGNATURES)

Route all keyword options to the appropriate strategy families for flow construction.

This function wraps [`CTBase.Orchestration.route_all_options`](@extref) with the
families specific to CTFlows flow construction. Options are routed to either the
backend family (`:di`) or the integrator family (`:sciml`).

# Arguments
- `kwargs`: All keyword arguments from the user's `Flow` call (strategy options only,
  no action-level options).

# Returns
- `NamedTuple` with fields:
  - `action`: action-level options (always empty for flows)
  - `strategies`: `NamedTuple` with `backend` and `integrator` sub-tuples

# Throws
- [`CTBase.Exceptions.IncorrectArgument`](@extref): If an option is unknown, ambiguous,
  or routed to the wrong strategy.

# Example
```julia
# Route options to backend and integrator
routed = Flows._route_flow_options((; reltol=1e-8, ad_backend=ADTypes.AutoForwardDiff()))
# routed.strategies.integrator contains (reltol = 1e-8,)
# routed.strategies.backend contains (ad_backend = AutoForwardDiff(),)
```

# Notes
- This function uses `:description` source mode for user-friendly error messages.
- No action-level options are defined for flows (empty `OptionDefinition` array).

See also: [`CTFlows.Flows._flow_families`](@ref), [`CTFlows.Flows._build_flow_components`](@ref),
[`CTBase.Orchestration.route_all_options`](@extref)
"""
function _route_flow_options(
    kwargs; action_defs::Vector{<:Options.OptionDefinition}=Options.OptionDefinition[]
)
    return Orchestration.route_all_options(
        _FLOW_DESCRIPTION,
        _flow_families(),
        action_defs,
        (; kwargs...),
        flow_registry();
        source_mode=:description,
    )
end

"""
$(TYPEDSIGNATURES)

Return the action-level option definitions for control flows: `hamiltonian_type`
(`:total` or `:partial`), and the paired `constraint` / `multiplier` options that turn
the flow into a constrained pseudo-Hamiltonian flow. All three are routed as first-class
action options so they are accepted only where meaningful (the control-law flow
constructors) and rejected as unknown options elsewhere.

See also: [`CTFlows.Flows._route_flow_options`](@ref), [`CTFlows.Flows._unwrap_option`](@ref).
"""
function _flow_action_defs()
    return [
        Options.OptionDefinition(;
            name=:hamiltonian_type,
            aliases=(),
            type=Symbol,
            default=:total,
            description="Hamiltonian type for DynClosedLoop flows: :total or :partial",
        ),
        Options.OptionDefinition(;
            name=:constraint,
            aliases=(),
            type=Any,
            default=nothing,
            description="Path constraint g for a constrained pseudo-Hamiltonian flow: " *
                        "a :path constraint label (Symbol), a CTBase.Data.PathConstraint, " *
                        "or a plain function with the OCP's natural arity. Paired with `multiplier`.",
        ),
        Options.OptionDefinition(;
            name=:multiplier,
            aliases=(),
            type=Any,
            default=nothing,
            description="Lagrange multiplier μ for the path constraint: a " *
                        "CTBase.Data.Multiplier or a plain function μ with the OCP's natural " *
                        "arity μ(x,p)/μ(t,x,p)/μ(x,p,v)/μ(t,x,p,v). Paired with `constraint`.",
        ),
    ]
end

"""
$(TYPEDSIGNATURES)

Read an action option value from a routed `action` NamedTuple entry: unwrap an
[`CTBase.Options.OptionValue`](@extref), or fall back when the entry is `nothing`.

See also: [`CTFlows.Flows._flow_action_defs`](@ref), [`CTFlows.Flows._route_flow_options`](@ref).
"""
_unwrap_option(opt::Options.OptionValue, fallback) = opt.value
_unwrap_option(opt, fallback) = opt === nothing ? fallback : opt

"""
$(TYPEDSIGNATURES)

Build concrete strategy instances from routed options.

Each strategy is constructed via
[`CTBase.Orchestration.build_strategy_from_resolved`](@extref) using the options
that were routed to its family by [`CTFlows.Flows._route_flow_options`](@ref).

# Arguments
- `routed`: Result of [`CTFlows.Flows._route_flow_options`](@ref) containing routed option values.

# Returns
- `NamedTuple{(:backend, :integrator)}`: Concrete strategy instances.

# Example
```julia
# Build concrete strategies from routed options
routed = Flows._route_flow_options((; reltol=1e-8))
components = Flows._build_flow_components(routed)
# components.backend isa CTBase.Differentiation.DifferentiationInterface
# components.integrator isa CTFlows.Integrators.SciML
```

See also: [`CTFlows.Flows._route_flow_options`](@ref), [`CTFlows.Flows.flow_registry`](@ref),
[`CTBase.Orchestration.build_strategy_from_resolved`](@extref)
"""
function _build_flow_components(routed)
    families = _flow_families()
    resolved = Orchestration.resolve_method(_FLOW_DESCRIPTION, families, flow_registry())
    backend = Orchestration.build_strategy_from_resolved(
        resolved, :backend, families, flow_registry(); routed.strategies.backend...
    )
    integrator = Orchestration.build_strategy_from_resolved(
        resolved, :integrator, families, flow_registry(); routed.strategies.integrator...
    )
    return (backend=backend, integrator=integrator)
end
