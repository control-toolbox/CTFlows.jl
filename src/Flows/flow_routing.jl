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
function _flow_families(::Type{Traits.WithAD})
    return (
        backend=Differentiation.AbstractADBackend, integrator=Integrators.AbstractIntegrator
    )
end

"""
$(TYPEDSIGNATURES)

Strategy families for an AD-free flow: only the `:sciml` integrator (no `:di` backend, since
no scalar Hamiltonian is differentiated).
"""
function _flow_families(::Type{Traits.WithoutAD})
    return (integrator=Integrators.AbstractIntegrator,)
end

# Back-compat: the full (WithAD) families.
_flow_families() = _flow_families(Traits.WithAD)

"""
$(TYPEDSIGNATURES)

Base method description for a flow plan, per AD trait. The device token (`:cpu`) is **explicit**:
the flow registry is parameterized (`[CPU, GPU]`), so a device token is required —
[`CTBase.Strategies.extract_global_parameter_from_method`](@extref) throws otherwise. The bare
`:cpu` reproduces the pre-parameterization CPU behaviour exactly (`SciML{CPU}` metadata ≡ old).
"""
_flow_base_description(::Type{Traits.WithAD}) = (:di, :sciml, :cpu)
_flow_base_description(::Type{Traits.WithoutAD}) = (:sciml, :cpu)

"""
$(TYPEDSIGNATURES)

Candidate descriptions (the `:cpu`/`:gpu` device variants) against which a user `method` is
completed via [`CTBase.Descriptions.complete`](@extref).
"""
_available_flow_methods(::Type{Traits.WithAD}) = ((:di, :sciml, :cpu), (:di, :sciml, :gpu))
_available_flow_methods(::Type{Traits.WithoutAD}) = ((:sciml, :cpu), (:sciml, :gpu))

# Normalize a user-supplied `method` into a token tuple (or `nothing` for the default).
_as_method_tokens(::Nothing) = nothing
_as_method_tokens(m::Symbol) = (m,)
_as_method_tokens(m::Tuple{Vararg{Symbol}}) = m

"""
$(TYPEDSIGNATURES)

Resolve the effective method description for a flow from its AD trait and an optional user
`method` (a `Symbol` such as `:gpu`, or a token tuple). `method === nothing` yields the base
(CPU) description; otherwise the tokens are completed against
[`CTFlows.Flows._available_flow_methods`](@ref).
"""
function _flow_description(ad_trait, method)
    tokens = _as_method_tokens(method)
    tokens === nothing && return _flow_base_description(ad_trait)
    return Descriptions.complete(tokens...; descriptions=_available_flow_methods(ad_trait))
end

"""
$(TYPEDSIGNATURES)

Split a flow constructor's keyword arguments into `(method, rest)`: the device selection
(`method=:gpu`, a `Symbol` or token tuple; `nothing` if absent) and the remaining strategy
options. `method` rides along in every constructor's `kwargs...` and is popped here, at the
routing boundary, so it is never mistaken for a strategy option.

See also: [`CTFlows.Flows._flow_description`](@ref), [`CTFlows.Flows._route_flow_options`](@ref).
"""
function _pop_method(kwargs)
    nt = (; kwargs...)
    method = get(nt, :method, nothing)
    return method, Base.structdiff(nt, NamedTuple{(:method,)})
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
const _FLOW_DESCRIPTION = _flow_base_description(Traits.WithAD)

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
    ad_trait,
    kwargs;
    method=nothing,
    action_defs::Vector{<:Options.OptionDefinition}=Options.OptionDefinition[],
)
    return Orchestration.route_all_options(
        _flow_description(ad_trait, method),
        _flow_families(ad_trait),
        action_defs,
        (; kwargs...),
        flow_registry();
        source_mode=:description,
    )
end

# Back-compat: default to the WithAD plan (the full `:di`/`:sciml` families).
function _route_flow_options(
    kwargs; action_defs::Vector{<:Options.OptionDefinition}=Options.OptionDefinition[]
)
    return _route_flow_options(Traits.WithAD, kwargs; action_defs=action_defs)
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
- `ad_trait`: `Traits.WithAD` (builds `:di` backend + `:sciml` integrator) or `Traits.WithoutAD`
  (builds only the `:sciml` integrator).
- `routed`: Result of [`CTFlows.Flows._route_flow_options`](@ref) containing routed option values.
- `method`: Optional device selection (`Symbol`/token tuple, e.g. `:gpu`) threaded into the
  resolved global strategy parameter (`CPU`/`GPU`) for **all** families at once.

# Returns
- `NamedTuple`: concrete strategy instances keyed by family — `(integrator,)` for `WithoutAD`,
  `(backend, integrator)` for `WithAD`.

# Example
```julia
routed = Flows._route_flow_options(Traits.WithAD, (; reltol=1e-8))
components = Flows._build_flow_components(Traits.WithAD, routed)
# components.backend isa CTBase.Differentiation.DifferentiationInterface
# components.integrator isa CTFlows.Integrators.SciML
```

See also: [`CTFlows.Flows._route_flow_options`](@ref), [`CTFlows.Flows.flow_registry`](@ref),
[`CTBase.Orchestration.build_strategy_from_resolved`](@extref)
"""
function _build_flow_components(ad_trait, routed; method=nothing)
    families = _flow_families(ad_trait)
    resolved = Orchestration.resolve_method(
        _flow_description(ad_trait, method), families, flow_registry()
    )
    built = map(keys(families)) do family
        Orchestration.build_strategy_from_resolved(
            resolved, family, families, flow_registry();
            getproperty(routed.strategies, family)...,
        )
    end
    return NamedTuple{keys(families)}(built)
end

# Back-compat: default to the WithAD plan (backend + integrator).
_build_flow_components(routed) = _build_flow_components(Traits.WithAD, routed)

"""
$(TYPEDSIGNATURES)

Build the SciML integrator for an **AD-free** flow (`Traits.WithoutAD`) directly from a flow
constructor's keyword arguments, honouring a `method=:gpu` device selection popped from them.

Shared by the AD-free constructors (`Flow(VectorField)`, `Flow(HamiltonianVectorField)`,
controlled-vector-field flows, `Flow(ODEFunction)`, `Flow(ODEProblem)`), which build only an
integrator (no `:di` AD backend). Routing through the `WithoutAD` plan means an `ad_backend`
option is correctly rejected here as unknown (there is no AD backend to configure).

See also: [`CTFlows.Flows._build_flow_components`](@ref), [`CTFlows.Flows._pop_method`](@ref).
"""
function _build_integrator(opts)
    method, kwargs = _pop_method(opts)
    routed = _route_flow_options(Traits.WithoutAD, kwargs; method=method)
    return _build_flow_components(Traits.WithoutAD, routed; method=method).integrator
end
