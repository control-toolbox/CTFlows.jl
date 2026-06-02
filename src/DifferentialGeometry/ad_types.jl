# InPlace guard: dispatches on the MD *type* (captured from the where clause — fully static)
_check_outofplace(::Type{Traits.OutOfPlace}) = nothing
function _check_outofplace(::Type{MD}) where {MD <: Traits.AbstractMutabilityTrait}
    throw(Exceptions.NotImplemented(
        "ad is not implemented for InPlace vector fields",
        required_method = "Use an OutOfPlace VectorField",
        suggestion      = "Reconstruct the VectorField without in-place flag",
        context         = "ad on AbstractVectorField",
    ))
end

# HVF guard: dispatch on type hierarchy (runtime — MD params don't encode HVF vs plain VF)
_check_not_hvf(::Data.AbstractVectorField)            = nothing
function _check_not_hvf(X::Data.AbstractHamiltonianVectorField)
    throw(Exceptions.NotImplemented(
        "ad on AbstractHamiltonianVectorField is not implemented (signature is (x,p), not (x))",
        suggestion = "Use ad on a plain VectorField",
        context    = "ad on AbstractVectorField",
    ))
end

# Lie bracket: VectorField + VectorField → VectorField

function ad(
    X::Data.AbstractVectorField{TD, VD, MDX},
    Y::Data.AbstractVectorField{TD, VD, MDY};
    ad_backend::Union{ADTypes.AbstractADType, Common.NotProvided} = __dg_ad_backend(),
) where {TD, VD, MDX, MDY}
    _check_not_hvf(X); _check_not_hvf(Y)
    _check_outofplace(MDX)    # static dispatch on type parameter — no runtime call
    _check_outofplace(MDY)
    backend  = _resolve_backend(ad_backend)
    closure  = _ad(X, Y, backend, TD, VD)
    return Data.VectorField(closure, TD, VD, Traits.OutOfPlace)  # typed constructor, explicit mutability
end

# Lie derivative: VectorField + scalar Function → Function
function ad(
    X::Data.AbstractVectorField{TD, VD, MDX},
    f::Function;
    ad_backend::Union{ADTypes.AbstractADType, Common.NotProvided} = __dg_ad_backend(),
) where {TD, VD, MDX}
    _check_not_hvf(X)
    _check_outofplace(MDX)    # static dispatch
    backend = _resolve_backend(ad_backend)
    return _ad(X, f, backend, TD, VD)  # scalar output → returns a plain Function
end

# TD/VD mismatch → IncorrectArgument
function ad(
    X::Data.AbstractVectorField{TD1, VD1, MDX},
    Y::Data.AbstractVectorField{TD2, VD2, MDY};
    ad_backend::Union{ADTypes.AbstractADType, Common.NotProvided} = __dg_ad_backend(),
) where {TD1, VD1, MDX, TD2, VD2, MDY}
    throw(Exceptions.IncorrectArgument(
        "ad: TD/VD mismatch between X and Y",
        got      = "X: $(TD1)/$(VD1), Y: $(TD2)/$(VD2)",
        expected = "Both arguments must share the same TimeDependence and VariableDependence",
        context  = "ad on AbstractVectorField",
    ))
end
