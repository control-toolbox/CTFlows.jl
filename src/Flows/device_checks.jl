# =============================================================================
# Checks done at the beginning of a flow call, before the integration (issue #436):
# the device of the flow against the arrays given, and the AD backend of the system.
# =============================================================================

"""
$(TYPEDSIGNATURES)

Device parameter (`CTBase.Strategies.CPU` or `CTBase.Strategies.GPU`) of an integrator, or
`nothing` for an integrator that is not device-parameterized.
"""
_integrator_device(::Integrators.SciML{P}) where {P} = P
_integrator_device(::Any) = nothing

"""
$(TYPEDSIGNATURES)

The ADTypes backend of the system of a flow: the backend of an AD system, `nothing` for an
AD-free one.

See also: [`CTBase.Traits.ad_trait`](@extref), [`CTFlows.Systems.backend`](@extref).
"""
_system_ad_backend(sys) = _system_ad_backend(Traits.ad_trait(sys), sys)
_system_ad_backend(::Type{Traits.WithAD}, sys) = _adtypes_backend(Systems.backend(sys))
_system_ad_backend(::Type{Traits.WithoutAD}, sys) = nothing

"""
$(TYPEDSIGNATURES)

The ADTypes backend wrapped by an AD backend strategy: only the `DifferentiationInterface`
strategy wraps one (any other strategy, e.g. a user-defined one, gives `nothing`).
"""
function _adtypes_backend(backend::Differentiation.DifferentiationInterface)
    return Differentiation.ad_backend(backend)
end
_adtypes_backend(::Differentiation.AbstractADBackend) = nothing

"""
$(TYPEDSIGNATURES)

Initial arrays of a call configuration whose placement is checked: the state, and the
costate of a Hamiltonian configuration (the variable costate is a host object by design).
"""
_call_arrays(config::Configs.AbstractStateConfig) = (Configs.initial_state(config),)
function _call_arrays(
    config::Union{
        Configs.AbstractHamiltonianConfig,Configs.AbstractAugmentedHamiltonianConfig
    },
)
    return (Configs.initial_state(config), Configs.initial_costate(config))
end
_call_arrays(::Configs.AbstractConfig) = ()

"""
$(TYPEDSIGNATURES)

Whether `x` is a dense host array. Numbers (a 1-D state is a scalar) and device arrays are
not.
"""
_is_host_array(x) = x isa Array

"""
$(TYPEDSIGNATURES)

Element type of a value of the call: the element type of an array, the type of a number,
`nothing` for anything else (no variable, `NotProvided`).
"""
_value_eltype(x::AbstractArray) = eltype(x)
_value_eltype(x::Number) = typeof(x)
_value_eltype(::Any) = nothing

"""
$(TYPEDSIGNATURES)

Whether `AutoMooncake` can differentiate through a value of element type `T`: an IEEE
float or an integer (an integer time is promoted by the integrator). A `ForwardDiff.Dual`
(the flow differentiated by an outer ForwardDiff) or a `BigFloat` is refused by Mooncake.
"""
_mooncake_eltype(::Type{<:Union{Base.IEEEFloat,Integer}}) = true
_mooncake_eltype(::Type{<:Real}) = false
_mooncake_eltype(::Any) = true

"""
$(TYPEDSIGNATURES)

Check a flow call before the integration:
- a GPU flow (`method=:gpu`) needs device arrays, not host arrays;
- the `AutoMooncake` backend needs IEEE floats in the state, the costate, the times and the
  variable (no outer ForwardDiff through the flow);
- the package of the AD backend of the system is loaded (see
  [`CTBase.Differentiation.check_backend`](@extref)).

Each check raises a structured error at the call, instead of a raw error from the AD
backend deep inside the integration. `variable` is the variable of the call (`nothing` if
none).

# Throws
- `CTBase.Exceptions.PreconditionError`: For a host array under `method=:gpu`, or a
  non-IEEE element type with the `AutoMooncake` backend.
- `CTBase.Exceptions.ExtensionError`: If the package of the AD backend is not loaded.

See also: [`CTFlows.Flows._core_invoke_flow`](@extref).
"""
function _check_call(flow::AbstractFlow, config::Configs.AbstractConfig; variable=nothing)
    sys = system(flow)
    host = filter(_is_host_array, _call_arrays(config))
    isempty(host) || _check_host_arrays(_integrator_device(integrator(flow)), host)
    _check_ad_eltypes(
        _system_ad_backend(sys),
        (_call_arrays(config)..., Configs.tspan(config)..., variable),
    )
    Traits.ad_trait(sys) === Traits.WithAD &&
        Differentiation.check_backend(Systems.backend(sys))
    return nothing
end

"""
$(TYPEDSIGNATURES)

Reject host arrays when the flow is a GPU flow. `device` is the device parameter of the
integrator, `host` the host arrays of the call.
"""
function _check_host_arrays(device, host)
    if device === Strategies.GPU
        throw(
            Exceptions.PreconditionError(
                "A GPU flow (method=:gpu) was called with a host array";
                reason="a flow built with method=:gpu integrates device arrays (e.g. CuArray), but the initial condition is a $(typeof(first(host)))",
                suggestion="pass device arrays (e.g. CUDA.CuArray(x0)), or build the flow without method=:gpu to integrate host arrays",
                context="flow call",
            ),
        )
    end
    return nothing
end

"""
$(TYPEDSIGNATURES)

Reject, for the `AutoMooncake` backend `ad`, the values of the call (state, costate, times,
variable) whose element type Mooncake cannot differentiate through (see
[`CTFlows.Flows._mooncake_eltype`](@extref)). Other backends accept every element type here.
"""
_check_ad_eltypes(::Any, values) = nothing
function _check_ad_eltypes(::ADTypes.AutoMooncake, values)
    for x in values
        T = _value_eltype(x)
        (T === nothing || _mooncake_eltype(T)) && continue
        throw(
            Exceptions.PreconditionError(
                "The AutoMooncake backend cannot differentiate values of type $T";
                reason="Mooncake differentiates IEEE floats only (Float64, Float32, Float16); a ForwardDiff.Dual comes from differentiating the flow itself with ForwardDiff (nested AD), which Mooncake does not support",
                suggestion="use ad_backend=AutoForwardDiff() (the default of the CPU method) to differentiate through the flow with ForwardDiff, or differentiate the flow with finite differences (e.g. AutoFiniteDiff())",
                context="flow call",
            ),
        )
    end
    return nothing
end
