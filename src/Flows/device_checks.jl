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

Check a flow call before the integration:
- a GPU flow (`method=:gpu`) needs device arrays, not host arrays;
- the `AutoMooncake` backend does not support host arrays yet;
- the package of the AD backend of the system is loaded (see
  [`CTBase.Differentiation.check_backend`](@extref)).

Each check raises a structured error at the call, instead of a raw `MethodError` from the
AD backend deep inside the integration.

# Throws
- `CTBase.Exceptions.PreconditionError`: For a host array under `method=:gpu`, or with the
  `AutoMooncake` backend.
- `CTBase.Exceptions.ExtensionError`: If the package of the AD backend is not loaded.

See also: [`CTFlows.Flows._core_invoke_flow`](@extref).
"""
function _check_call(flow::AbstractFlow, config::Configs.AbstractConfig)
    sys = system(flow)
    host = filter(_is_host_array, _call_arrays(config))
    if !isempty(host)
        _check_host_arrays(
            _integrator_device(integrator(flow)), _system_ad_backend(sys), host
        )
    end
    Traits.ad_trait(sys) === Traits.WithAD &&
        Differentiation.check_backend(Systems.backend(sys))
    return nothing
end

"""
$(TYPEDSIGNATURES)

Reject host arrays when the flow is a GPU flow or differentiates with `AutoMooncake`.
`device` is the device parameter of the integrator, `ad` the ADTypes backend of the system
(`nothing` if AD-free), `host` the host arrays of the call.
"""
function _check_host_arrays(device, ad, host)
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
    if ad isa ADTypes.AutoMooncake
        throw(
            Exceptions.PreconditionError(
                "The AutoMooncake backend does not support host arrays yet";
                reason="Mooncake returns structural tangents for the views the Hamiltonian splitter builds on a host array (a MethodError at the first gradient); device arrays work",
                suggestion="use ad_backend=AutoForwardDiff() on host arrays (the default of the CPU method), or device arrays with method=:gpu — see https://github.com/control-toolbox/CTFlows.jl/issues/448",
                context="flow call",
            ),
        )
    end
    return nothing
end
