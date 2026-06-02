# Function → Function (f doit prendre t comme premier argument)
function ∂ₜ(
    f::Function;
    ad_backend::Union{ADTypes.AbstractADType, Common.NotProvided} = __dg_ad_backend(),
)
    backend = _resolve_backend(ad_backend)
    return (t, args...) -> Differentiation.derivative(backend, s -> f(s, args...), t)
end

# AbstractHamiltonianVectorField{TD,VD,MD} → HamiltonianVectorField{NonAutonomous,VD,OutOfPlace}
# DOIT ÊTRE AVANT l'overload AbstractVectorField (plus spécifique dans la hiérarchie)
function ∂ₜ(
    X::Data.AbstractHamiltonianVectorField{TD, VD, MD};
    ad_backend::Union{ADTypes.AbstractADType, Common.NotProvided} = __dg_ad_backend(),
) where {TD, VD, MD}
    _check_outofplace(MD)
    backend = _resolve_backend(ad_backend)
    closure = _∂ₜ_hvf(X, backend, TD, VD)
    return Data.HamiltonianVectorField(closure, Traits.NonAutonomous, VD, Traits.OutOfPlace)
end

# Autonomous HVF: call signature (x,p) ou (x,p,v) — s ignoré → dérivée = 0
_∂ₜ_hvf(X, b::Differentiation.AbstractADBackend, ::Type{Traits.Autonomous},    ::Type{Traits.Fixed})    = (t, x, p)    -> Differentiation.derivative(b, s -> X(x, p),    t)
_∂ₜ_hvf(X, b::Differentiation.AbstractADBackend, ::Type{Traits.Autonomous},    ::Type{Traits.NonFixed}) = (t, x, p, v) -> Differentiation.derivative(b, s -> X(x, p, v), t)
# NonAutonomous HVF: call signature (t,x,p) ou (t,x,p,v)
_∂ₜ_hvf(X, b::Differentiation.AbstractADBackend, ::Type{Traits.NonAutonomous}, ::Type{Traits.Fixed})    = (t, x, p)    -> Differentiation.derivative(b, s -> X(s, x, p),    t)
_∂ₜ_hvf(X, b::Differentiation.AbstractADBackend, ::Type{Traits.NonAutonomous}, ::Type{Traits.NonFixed}) = (t, x, p, v) -> Differentiation.derivative(b, s -> X(s, x, p, v), t)

# AbstractVectorField{TD,VD,MD} → VectorField{NonAutonomous,VD,OutOfPlace}
# (attrape les VF simples ; HVF géré par l'overload ci-dessus)
function ∂ₜ(
    X::Data.AbstractVectorField{TD, VD, MD};
    ad_backend::Union{ADTypes.AbstractADType, Common.NotProvided} = __dg_ad_backend(),
) where {TD, VD, MD}
    _check_outofplace(MD)
    backend = _resolve_backend(ad_backend)
    closure = _∂ₜ_vf(X, backend, TD, VD)
    return Data.VectorField(closure, Traits.NonAutonomous, VD, Traits.OutOfPlace)
end

# Autonomous VF: call signature (x) ou (x,v) — s ignoré → dérivée = 0
_∂ₜ_vf(X, b::Differentiation.AbstractADBackend, ::Type{Traits.Autonomous},    ::Type{Traits.Fixed})    = (t, x)    -> Differentiation.derivative(b, s -> X(x),    t)
_∂ₜ_vf(X, b::Differentiation.AbstractADBackend, ::Type{Traits.Autonomous},    ::Type{Traits.NonFixed}) = (t, x, v) -> Differentiation.derivative(b, s -> X(x, v), t)
# NonAutonomous VF
_∂ₜ_vf(X, b::Differentiation.AbstractADBackend, ::Type{Traits.NonAutonomous}, ::Type{Traits.Fixed})    = (t, x)    -> Differentiation.derivative(b, s -> X(s, x),    t)
_∂ₜ_vf(X, b::Differentiation.AbstractADBackend, ::Type{Traits.NonAutonomous}, ::Type{Traits.NonFixed}) = (t, x, v) -> Differentiation.derivative(b, s -> X(s, x, v), t)

# AbstractHamiltonian{TD,VD} → Hamiltonian{NonAutonomous,VD}
function ∂ₜ(
    H::Data.AbstractHamiltonian{TD, VD};
    ad_backend::Union{ADTypes.AbstractADType, Common.NotProvided} = __dg_ad_backend(),
) where {TD, VD}
    backend = _resolve_backend(ad_backend)
    closure = _∂ₜ_ham(H, backend, TD, VD)
    return Data.Hamiltonian(closure, Traits.NonAutonomous, VD)
end

# Autonomous Ham: call signature (x,p) ou (x,p,v) — dérivée = 0
_∂ₜ_ham(H, b::Differentiation.AbstractADBackend, ::Type{Traits.Autonomous},    ::Type{Traits.Fixed})    = (t, x, p)    -> Differentiation.derivative(b, s -> H(x, p),    t)
_∂ₜ_ham(H, b::Differentiation.AbstractADBackend, ::Type{Traits.Autonomous},    ::Type{Traits.NonFixed}) = (t, x, p, v) -> Differentiation.derivative(b, s -> H(x, p, v), t)
# NonAutonomous Ham
_∂ₜ_ham(H, b::Differentiation.AbstractADBackend, ::Type{Traits.NonAutonomous}, ::Type{Traits.Fixed})    = (t, x, p)    -> Differentiation.derivative(b, s -> H(s, x, p),    t)
_∂ₜ_ham(H, b::Differentiation.AbstractADBackend, ::Type{Traits.NonAutonomous}, ::Type{Traits.NonFixed}) = (t, x, p, v) -> Differentiation.derivative(b, s -> H(s, x, p, v), t)
