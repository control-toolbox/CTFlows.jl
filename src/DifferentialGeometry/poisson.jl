# kwargs entry point
function Poisson(
    H::Function, G::Function;
    ad_backend::Union{ADTypes.AbstractADType, Common.NotProvided} = __dg_ad_backend(),
    is_autonomous::Bool = Common.__is_autonomous(),
    is_variable::Bool   = Common.__is_variable(),
)
    TD      = is_autonomous ? Traits.Autonomous : Traits.NonAutonomous
    VD      = is_variable   ? Traits.NonFixed   : Traits.Fixed
    backend = _resolve_backend(ad_backend)
    return _Poisson(H, G, backend, TD, VD)
end

# typed entry point (used by @Lie macro)
function Poisson(
    H::Function, G::Function,
    ::Type{TD}, ::Type{VD};
    ad_backend::Union{ADTypes.AbstractADType, Common.NotProvided} = __dg_ad_backend(),
) where {TD, VD}
    backend = _resolve_backend(ad_backend)
    return _Poisson(H, G, backend, TD, VD)
end

# Internal: Differentiation.gradient — 4 variants
function _Poisson(H, G, backend::Differentiation.AbstractADBackend, ::Type{Traits.Autonomous}, ::Type{Traits.Fixed})
    return function (x, p)
        gxH = Differentiation.gradient(backend, y -> H(y, p), x)
        gpH = Differentiation.gradient(backend, q -> H(x, q), p)
        gxG = Differentiation.gradient(backend, y -> G(y, p), x)
        gpG = Differentiation.gradient(backend, q -> G(x, q), p)
        return gpH' * gxG - gxH' * gpG
    end
end

function _Poisson(H, G, backend::Differentiation.AbstractADBackend, ::Type{Traits.NonAutonomous}, ::Type{Traits.Fixed})
    return function (t, x, p)
        gxH = Differentiation.gradient(backend, y -> H(t, y, p), x)
        gpH = Differentiation.gradient(backend, q -> H(t, x, q), p)
        gxG = Differentiation.gradient(backend, y -> G(t, y, p), x)
        gpG = Differentiation.gradient(backend, q -> G(t, x, q), p)
        return gpH' * gxG - gxH' * gpG
    end
end

function _Poisson(H, G, backend::Differentiation.AbstractADBackend, ::Type{Traits.Autonomous}, ::Type{Traits.NonFixed})
    return function (x, p, v)
        gxH = Differentiation.gradient(backend, y -> H(y, p, v), x)
        gpH = Differentiation.gradient(backend, q -> H(x, q, v), p)
        gxG = Differentiation.gradient(backend, y -> G(y, p, v), x)
        gpG = Differentiation.gradient(backend, q -> G(x, q, v), p)
        return gpH' * gxG - gxH' * gpG
    end
end

function _Poisson(H, G, backend::Differentiation.AbstractADBackend, ::Type{Traits.NonAutonomous}, ::Type{Traits.NonFixed})
    return function (t, x, p, v)
        gxH = Differentiation.gradient(backend, y -> H(t, y, p, v), x)
        gpH = Differentiation.gradient(backend, q -> H(t, x, q, v), p)
        gxG = Differentiation.gradient(backend, y -> G(t, y, p, v), x)
        gpG = Differentiation.gradient(backend, q -> G(t, x, q, v), p)
        return gpH' * gxG - gxH' * gpG
    end
end

# Typed overload: AbstractHamiltonian → Data.Hamiltonian
function Poisson(
    H::Data.AbstractHamiltonian{TD, VD},
    G::Data.AbstractHamiltonian{TD, VD};
    ad_backend::Union{ADTypes.AbstractADType, Common.NotProvided} = __dg_ad_backend(),
) where {TD, VD}
    backend = _resolve_backend(ad_backend)
    closure = _Poisson(H, G, backend, TD, VD)
    return Data.Hamiltonian(closure, TD, VD)
end

# TD/VD mismatch → IncorrectArgument
function Poisson(
    H::Data.AbstractHamiltonian{TD1, VD1},
    G::Data.AbstractHamiltonian{TD2, VD2};
    ad_backend::Union{ADTypes.AbstractADType, Common.NotProvided} = __dg_ad_backend(),
) where {TD1, VD1, TD2, VD2}
    throw(Exceptions.IncorrectArgument(
        "Poisson: TD/VD mismatch between H and G",
        got      = "H: $(TD1)/$(VD1), G: $(TD2)/$(VD2)",
        expected = "Both Hamiltonians must share the same TimeDependence and VariableDependence",
        context  = "Poisson on AbstractHamiltonian",
    ))
end
