"""
$(TYPEDSIGNATURES)

Compute the Poisson bracket of two Hamiltonian functions using keyword arguments.

Returns a function representing the Poisson bracket `{H, G} = ∇ₚH' * ∇ₓG - ∇ₓH' * ∇ₚG`.
The time dependence and variable dependence are inferred from the `is_autonomous` and
`is_variable` keyword arguments.

# Arguments
- `H::Function`: First Hamiltonian function (returns a scalar).
- `G::Function`: Second Hamiltonian function (returns a scalar).
- `ad_backend::Union{ADTypes.AbstractADType, Common.NotProvided}`: AD backend to use (default: global backend).
- `is_autonomous::Bool`: Whether the functions are time-independent (default: from global config).
- `is_variable::Bool`: Whether the functions depend on a variable parameter (default: from global config).

# Returns
- A function with signature depending on TD/VD:
  - Autonomous/Fixed: `(x, p) -> result`
  - NonAutonomous/Fixed: `(t, x, p) -> result`
  - Autonomous/NonFixed: `(x, p, v) -> result`
  - NonAutonomous/NonFixed: `(t, x, p, v) -> result`

# Example
```julia
using CTFlows.DifferentialGeometry

H = (x, p) -> p[1]^2 / 2 + x[1]^2
G = (x, p) -> x[1] * p[1]

B = Poisson(H, G)
B([1.0, 2.0], [0.5, 1.0])  # Returns 1.0
```

See also: [`CTFlows.DifferentialGeometry.Poisson(H::Function, G::Function, ::Type{TD}, ::Type{VD})`](@ref), [`CTFlows.DifferentialGeometry.ad`](@ref), [`CTFlows.DifferentialGeometry.Lift`](@ref)
"""
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

"""
$(TYPEDSIGNATURES)

Compute the Poisson bracket of two Hamiltonian functions with explicit type parameters.

Returns a function representing the Poisson bracket `{H, G} = ∇ₚH' * ∇ₓG - ∇ₓH' * ∇ₚG`.
This typed entry point is used by the [`@Lie`](@ref) macro for compile-time dispatch.

# Arguments
- `H::Function`: First Hamiltonian function (returns a scalar).
- `G::Function`: Second Hamiltonian function (returns a scalar).
- `::Type{TD}`: Time dependence type ([`CTFlows.Traits.Autonomous`](@extref) or [`CTFlows.Traits.NonAutonomous`](@extref)).
- `::Type{VD}`: Variable dependence type ([`CTFlows.Traits.Fixed`](@extref) or [`CTFlows.Traits.NonFixed`](@extref)).
- `ad_backend::Union{ADTypes.AbstractADType, Common.NotProvided}`: AD backend to use (default: global backend).

# Returns
- A function with signature depending on TD/VD.

# Example
```julia
using CTFlows.DifferentialGeometry
using CTFlows.Traits

H = (x, p) -> p[1]^2 / 2 + x[1]^2
G = (x, p) -> x[1] * p[1]

B = Poisson(H, G, Traits.Autonomous, Traits.Fixed)
B([1.0, 2.0], [0.5, 1.0])  # Returns 1.0
```

See also: [`CTFlows.DifferentialGeometry.Poisson(H::Function, G::Function)`](@ref), [`CTFlows.DifferentialGeometry.@Lie`](@ref), [`CTFlows.DifferentialGeometry.ad`](@ref)
"""
function Poisson(
    H::Function, G::Function,
    ::Type{TD}, ::Type{VD};
    ad_backend::Union{ADTypes.AbstractADType, Common.NotProvided} = __dg_ad_backend(),
) where {TD, VD}
    backend = _resolve_backend(ad_backend)
    return _Poisson(H, G, backend, TD, VD)
end

# Internal: Differentiation.gradient — 4 variants
"""
Internal implementation of Poisson bracket for Autonomous/Fixed case.

Computes `{H, G} = ∇ₚH' * ∇ₓG - ∇ₓH' * ∇ₚG` using AD gradients.

# Arguments
- `H`: First Hamiltonian function.
- `G`: Second Hamiltonian function.
- `backend::Differentiation.AbstractADBackend`: AD backend.
- `::Type{Traits.Autonomous}`: Time dependence type.
- `::Type{Traits.Fixed}`: Variable dependence type.

# Returns
- A function `(x, p) -> result`.
"""
function _Poisson(H, G, backend::Differentiation.AbstractADBackend, ::Type{Traits.Autonomous}, ::Type{Traits.Fixed})
    return function (x, p)
        gxH = Differentiation.gradient(backend, y -> H(y, p), x)
        gpH = Differentiation.gradient(backend, q -> H(x, q), p)
        gxG = Differentiation.gradient(backend, y -> G(y, p), x)
        gpG = Differentiation.gradient(backend, q -> G(x, q), p)
        return gpH' * gxG - gxH' * gpG
    end
end

"""
Internal implementation of Poisson bracket for NonAutonomous/Fixed case.

# Arguments
- `H`: First Hamiltonian function.
- `G`: Second Hamiltonian function.
- `backend::Differentiation.AbstractADBackend`: AD backend.
- `::Type{Traits.NonAutonomous}`: Time dependence type.
- `::Type{Traits.Fixed}`: Variable dependence type.

# Returns
- A function `(t, x, p) -> result`.
"""
function _Poisson(H, G, backend::Differentiation.AbstractADBackend, ::Type{Traits.NonAutonomous}, ::Type{Traits.Fixed})
    return function (t, x, p)
        gxH = Differentiation.gradient(backend, y -> H(t, y, p), x)
        gpH = Differentiation.gradient(backend, q -> H(t, x, q), p)
        gxG = Differentiation.gradient(backend, y -> G(t, y, p), x)
        gpG = Differentiation.gradient(backend, q -> G(t, x, q), p)
        return gpH' * gxG - gxH' * gpG
    end
end

"""
Internal implementation of Poisson bracket for Autonomous/NonFixed case.

# Arguments
- `H`: First Hamiltonian function.
- `G`: Second Hamiltonian function.
- `backend::Differentiation.AbstractADBackend`: AD backend.
- `::Type{Traits.Autonomous}`: Time dependence type.
- `::Type{Traits.NonFixed}`: Variable dependence type.

# Returns
- A function `(x, p, v) -> result`.
"""
function _Poisson(H, G, backend::Differentiation.AbstractADBackend, ::Type{Traits.Autonomous}, ::Type{Traits.NonFixed})
    return function (x, p, v)
        gxH = Differentiation.gradient(backend, y -> H(y, p, v), x)
        gpH = Differentiation.gradient(backend, q -> H(x, q, v), p)
        gxG = Differentiation.gradient(backend, y -> G(y, p, v), x)
        gpG = Differentiation.gradient(backend, q -> G(x, q, v), p)
        return gpH' * gxG - gxH' * gpG
    end
end

"""
Internal implementation of Poisson bracket for NonAutonomous/NonFixed case.

# Arguments
- `H`: First Hamiltonian function.
- `G`: Second Hamiltonian function.
- `backend::Differentiation.AbstractADBackend`: AD backend.
- `::Type{Traits.NonAutonomous}`: Time dependence type.
- `::Type{Traits.NonFixed}`: Variable dependence type.

# Returns
- A function `(t, x, p, v) -> result`.
"""
function _Poisson(H, G, backend::Differentiation.AbstractADBackend, ::Type{Traits.NonAutonomous}, ::Type{Traits.NonFixed})
    return function (t, x, p, v)
        gxH = Differentiation.gradient(backend, y -> H(t, y, p, v), x)
        gpH = Differentiation.gradient(backend, q -> H(t, x, q, v), p)
        gxG = Differentiation.gradient(backend, y -> G(t, y, p, v), x)
        gpG = Differentiation.gradient(backend, q -> G(t, x, q, v), p)
        return gpH' * gxG - gxH' * gpG
    end
end

"""
$(TYPEDSIGNATURES)

Compute the Poisson bracket of two typed Hamiltonians.

Returns a new [`Data.Hamiltonian`](@ref) representing the Poisson bracket `{H, G}`.
Both Hamiltonians must share the same time dependence and variable dependence.

# Arguments
- `H::Data.AbstractHamiltonian{TD, VD}`: First Hamiltonian.
- `G::Data.AbstractHamiltonian{TD, VD}`: Second Hamiltonian.
- `ad_backend::Union{ADTypes.AbstractADType, Common.NotProvided}`: AD backend to use (default: global backend).

# Returns
- `Data.Hamiltonian{TD, VD}`: The Poisson bracket as a Hamiltonian.

# Example
```julia
using CTFlows.DifferentialGeometry
using CTFlows.Data
using CTFlows.Traits

H = Hamiltonian((x, p) -> p[1]^2 / 2 + x[1]^2, Traits.Autonomous, Traits.Fixed)
G = Hamiltonian((x, p) -> x[1] * p[1], Traits.Autonomous, Traits.Fixed)

B = Poisson(H, G)
B([1.0, 2.0], [0.5, 1.0])  # Returns 1.0
```

See also: [`CTFlows.DifferentialGeometry.Poisson(H::Function, G::Function)`](@ref), [`CTFlows.DifferentialGeometry.ad`](@ref)
"""
function Poisson(
    H::Data.AbstractHamiltonian{TD, VD},
    G::Data.AbstractHamiltonian{TD, VD};
    ad_backend::Union{ADTypes.AbstractADType, Common.NotProvided} = __dg_ad_backend(),
) where {TD, VD}
    backend = _resolve_backend(ad_backend)
    closure = _Poisson(H, G, backend, TD, VD)
    return Data.Hamiltonian(closure, TD, VD)
end

"""
$(TYPEDSIGNATURES)

Error method for mismatched time/variable dependence in Hamiltonian Poisson bracket.

This method is called when two Hamiltonians have different time dependence or variable
dependence types, which is not allowed for the Poisson bracket operation.

# Arguments
- `H::Data.AbstractHamiltonian{TD1, VD1}`: First Hamiltonian.
- `G::Data.AbstractHamiltonian{TD2, VD2}`: Second Hamiltonian with mismatched TD/VD.
- `ad_backend::Union{ADTypes.AbstractADType, Common.NotProvided}`: AD backend (unused).

# Throws
- `Exceptions.IncorrectArgument`: Always thrown with details about the TD/VD mismatch.

# Notes
This is a fallback error method that provides a clear error message when the types do not
match. Use the matching TD/VD version for valid operations.

See also: [`CTFlows.DifferentialGeometry.Poisson(H::AbstractHamiltonian{TD, VD}, G::AbstractHamiltonian{TD, VD})`](@ref)
"""
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

"""
$(TYPEDSIGNATURES)

Disambiguator error method for two VectorField operands in Poisson bracket.

This overload resolves the ambiguity between the one-sided error methods when both
arguments are `AbstractVectorField`. It is always an error; use `ad(X, Y)` instead.

# Throws
- `Exceptions.IncorrectArgument`: Always thrown with suggestion to use Lie bracket.

See also: [`CTFlows.DifferentialGeometry.ad(X::AbstractVectorField, Y::AbstractVectorField)`](@ref)
"""
function Poisson(
    ::Data.AbstractVectorField, ::Data.AbstractVectorField;
    ad_backend::Union{ADTypes.AbstractADType, Common.NotProvided} = __dg_ad_backend(),
)
    throw(Exceptions.IncorrectArgument(
        "Poisson is not defined for AbstractVectorField operands";
        suggestion = "Use ad(X, Y) for the Lie bracket of VectorFields",
        context    = "Poisson on AbstractVectorField",
    ))
end

"""
$(TYPEDSIGNATURES)

Error method for VectorField as first operand in Poisson bracket.

# Throws
- `Exceptions.IncorrectArgument`: Always thrown with suggestion to use Lie bracket.
"""
function Poisson(
    ::Data.AbstractVectorField, ::Any;
    ad_backend::Union{ADTypes.AbstractADType, Common.NotProvided} = __dg_ad_backend(),
)
    throw(Exceptions.IncorrectArgument(
        "Poisson is not defined for AbstractVectorField operands";
        suggestion = "Use ad(X, Y) for the Lie bracket of VectorFields",
        context    = "Poisson on AbstractVectorField",
    ))
end

"""
$(TYPEDSIGNATURES)

Error method for VectorField as second operand in Poisson bracket.

This is a symmetric companion to `Poisson(::AbstractVectorField, ::Any)`, handling the case
where the second argument is a VectorField and the first is some other type.

# Arguments
- `::Any`: First operand.
- `::Data.AbstractVectorField`: VectorField second operand (not allowed in Poisson bracket).
- `ad_backend::Union{ADTypes.AbstractADType, Common.NotProvided}`: AD backend (unused).

# Throws
- `Exceptions.IncorrectArgument`: Always thrown with suggestion to use Lie bracket.

See also: [`CTFlows.DifferentialGeometry.ad(X::AbstractVectorField, Y::AbstractVectorField)`](@ref)
"""
function Poisson(
    ::Any, ::Data.AbstractVectorField;
    ad_backend::Union{ADTypes.AbstractADType, Common.NotProvided} = __dg_ad_backend(),
)
    throw(Exceptions.IncorrectArgument(
        "Poisson is not defined for AbstractVectorField operands";
        suggestion = "Use ad(X, Y) for the Lie bracket of VectorFields",
        context    = "Poisson on AbstractVectorField",
    ))
end
