# ==============================================================================
# hamiltonian_vector_field getter — Public API for accessing X_H
# ==============================================================================

# ==============================================================================
# Getter functors — callable structs replacing the per-trait closure factories.
#
# `HVFOoPFunctor` / `HVFIpFunctor` store the Hamiltonian and the AD backend in fields
# and compute X_H = (∂H/∂p, -∂H/∂x) on call. Being `<: Function` lets them be stored in
# a `Data.HamiltonianVectorField` (whose field is constrained `F <: Function`). The call
# operator is dispatched on the time/variable-dependence traits carried by the wrapped
# Hamiltonian `H`, mirroring the call operators of `CTBase.Data.Hamiltonian`.
# ==============================================================================

"""
$(TYPEDEF)

Out-of-place Hamiltonian vector field functor: computes `X_H = (∂H/∂p, -∂H/∂x)` from a
scalar Hamiltonian by automatic differentiation, allocating and returning the result.

# Fields
- `h::H`: the scalar Hamiltonian.
- `backend::B`: the AD backend used to compute the gradients.

# Call signatures

Dispatched on the Hamiltonian's time/variable-dependence traits:
- Autonomous/Fixed — `(x, p) -> (∂p, -∂x)`
- NonAutonomous/Fixed — `(t, x, p) -> (∂p, -∂x)`
- Autonomous/NonFixed — `(x, p, v; variable_costate=false) -> (∂p, -∂x)`, or
  `(∂p, -∂x, -∂v)` when `variable_costate=true`
- NonAutonomous/NonFixed — `(t, x, p, v; variable_costate=false) -> (∂p, -∂x)`, or
  `(∂p, -∂x, -∂v)` when `variable_costate=true`

See also: [`CTFlows.Systems.HVFIpFunctor`](@ref), [`CTFlows.Systems.hamiltonian_vector_field`](@ref).
"""
struct HVFOoPFunctor{H<:Data.AbstractHamiltonian,B<:Differentiation.AbstractADBackend} <:
       Function
    h::H
    backend::B
end

function (g::HVFOoPFunctor{<:Data.AbstractHamiltonian{Traits.Autonomous,Traits.Fixed}})(
    x, p
)
    ∂x, ∂p = Differentiation.hamiltonian_gradient(g.backend, g.h, nothing, x, p, nothing)
    return (∂p, -∂x)
end

function (g::HVFOoPFunctor{<:Data.AbstractHamiltonian{Traits.NonAutonomous,Traits.Fixed}})(
    t, x, p
)
    ∂x, ∂p = Differentiation.hamiltonian_gradient(g.backend, g.h, t, x, p, nothing)
    return (∂p, -∂x)
end

function (g::HVFOoPFunctor{<:Data.AbstractHamiltonian{Traits.Autonomous,Traits.NonFixed}})(
    x, p, v; variable_costate::Bool=false
)
    ∂x, ∂p = Differentiation.hamiltonian_gradient(g.backend, g.h, nothing, x, p, v)
    variable_costate || return (∂p, -∂x)
    ∂v = Differentiation.variable_gradient(g.backend, g.h, nothing, x, p, v)
    return (∂p, -∂x, -∂v)
end

function (g::HVFOoPFunctor{
    <:Data.AbstractHamiltonian{Traits.NonAutonomous,Traits.NonFixed}
})(
    t, x, p, v; variable_costate::Bool=false
)
    ∂x, ∂p = Differentiation.hamiltonian_gradient(g.backend, g.h, t, x, p, v)
    variable_costate || return (∂p, -∂x)
    ∂v = Differentiation.variable_gradient(g.backend, g.h, t, x, p, v)
    return (∂p, -∂x, -∂v)
end

"""
$(TYPEDEF)

In-place Hamiltonian vector field functor: writes `X_H = (∂H/∂p, -∂H/∂x)` into the
preallocated buffers `dx`, `dp`.

# Fields
- `h::H`: the scalar Hamiltonian.
- `backend::B`: the AD backend used to compute the gradients.

# Call signatures

Dispatched on the Hamiltonian's time/variable-dependence traits:
- Autonomous/Fixed — `(dx, dp, x, p) -> nothing`
- NonAutonomous/Fixed — `(dx, dp, t, x, p) -> nothing`
- Autonomous/NonFixed — `(dx, dp, x, p, v; dpv=nothing, variable_costate=false) -> nothing`
- NonAutonomous/NonFixed — `(dx, dp, t, x, p, v; dpv=nothing, variable_costate=false) -> nothing`

When `variable_costate=true`, the preallocated buffer `dpv` (matching the shape of `v`)
is filled with `-∂H/∂v`; it must be provided or a `PreconditionError` is thrown.

# Throws
- `Exceptions.PreconditionError`: when `variable_costate=true` and `dpv` is `nothing`.

See also: [`CTFlows.Systems.HVFOoPFunctor`](@ref), [`CTFlows.Systems.hamiltonian_vector_field`](@ref).
"""
struct HVFIpFunctor{H<:Data.AbstractHamiltonian,B<:Differentiation.AbstractADBackend} <:
       Function
    h::H
    backend::B
end

function (g::HVFIpFunctor{<:Data.AbstractHamiltonian{Traits.Autonomous,Traits.Fixed}})(
    dx, dp, x, p
)
    ∂x, ∂p = Differentiation.hamiltonian_gradient(g.backend, g.h, nothing, x, p, nothing)
    dx .= ∂p
    dp .= .-∂x
    return nothing
end

function (g::HVFIpFunctor{<:Data.AbstractHamiltonian{Traits.NonAutonomous,Traits.Fixed}})(
    dx, dp, t, x, p
)
    ∂x, ∂p = Differentiation.hamiltonian_gradient(g.backend, g.h, t, x, p, nothing)
    dx .= ∂p
    dp .= .-∂x
    return nothing
end

function (g::HVFIpFunctor{<:Data.AbstractHamiltonian{Traits.Autonomous,Traits.NonFixed}})(
    dx, dp, x, p, v; dpv=nothing, variable_costate::Bool=false
)
    ∂x, ∂p = Differentiation.hamiltonian_gradient(g.backend, g.h, nothing, x, p, v)
    dx .= ∂p
    dp .= .-∂x
    if variable_costate
        dpv === nothing && throw(
            Exceptions.PreconditionError(
                "dpv buffer must be provided when variable_costate=true";
                context="hamiltonian_vector_field IP Autonomous/NonFixed",
            ),
        )
        ∂v = Differentiation.variable_gradient(g.backend, g.h, nothing, x, p, v)
        dpv .= .-∂v
    end
    return nothing
end

function (g::HVFIpFunctor{<:Data.AbstractHamiltonian{Traits.NonAutonomous,Traits.NonFixed}})(
    dx, dp, t, x, p, v; dpv=nothing, variable_costate::Bool=false
)
    ∂x, ∂p = Differentiation.hamiltonian_gradient(g.backend, g.h, t, x, p, v)
    dx .= ∂p
    dp .= .-∂x
    if variable_costate
        dpv === nothing && throw(
            Exceptions.PreconditionError(
                "dpv buffer must be provided when variable_costate=true";
                context="hamiltonian_vector_field IP NonAutonomous/NonFixed",
            ),
        )
        ∂v = Differentiation.variable_gradient(g.backend, g.h, t, x, p, v)
        dpv .= .-∂v
    end
    return nothing
end

# ==============================================================================
# Getter overloads
# ==============================================================================

"""
$(TYPEDSIGNATURES)

Get the Hamiltonian vector field from a Hamiltonian.

This function computes the Hamiltonian vector field `X_H = (∂H/∂p, -∂H/∂x)` (also known as
the **symplectic gradient** of `H`) for a given Hamiltonian using automatic
differentiation. It accepts any [`CTBase.Data.AbstractHamiltonian`](@extref) — a scalar
`Hamiltonian` or a `ComposedHamiltonian` (as produced by an OCP + control law) — so it also
covers pseudo-Hamiltonian flows. The returned vector field wraps a callable
[`CTFlows.Systems.HVFOoPFunctor`](@ref) or [`CTFlows.Systems.HVFIpFunctor`](@ref) whose
call signature matches the Hamiltonian's time and variable dependence traits.

# Arguments
- `h::Data.AbstractHamiltonian{TD, VD}`: The Hamiltonian with traits `TD` (time dependence) and `VD` (variable dependence).
- `ad_backend::Differentiation.AbstractADBackend`: The AD backend to use (default: `__hvf_ad_backend()` = `Differentiation.DifferentiationInterface()`, the CPU default).
- `inplace::Bool`: Whether to return an in-place functor (default: `__hvf_inplace()` = `false`).

# Returns
- `Data.HamiltonianVectorField`: The Hamiltonian vector field with correct traits matching the input Hamiltonian.

# Notes
- `ad_backend` must already be a fully-built strategy (e.g. from `Flow`'s registry-based routing,
  or constructed directly as `Differentiation.DifferentiationInterface{Strategies.GPU}(...)`).
  This function does not build or device-select a backend from a raw `ADTypes.AbstractADType`.
- The functor call signature depends on the Hamiltonian's traits:
  - Autonomous/Fixed: `(x, p) -> (∂p, -∂x)` or `(dx, dp, x, p) -> nothing` (in-place)
  - NonAutonomous/Fixed: `(t, x, p) -> (∂p, -∂x)` or `(dx, dp, t, x, p) -> nothing` (in-place)
  - Autonomous/NonFixed: `(x, p, v; variable_costate=false) -> (∂p, -∂x)` or `(x, p, v; variable_costate=true) -> (∂p, -∂x, -∂v)`
  - NonAutonomous/NonFixed: `(t, x, p, v; variable_costate=false) -> (∂p, -∂x)` or `(t, x, p, v; variable_costate=true) -> (∂p, -∂x, -∂v)`

See also: [`CTFlows.Systems.HamiltonianSystem`](@ref), [`CTFlows.Systems.HamiltonianVectorFieldSystem`](@ref), [`CTBase.Data.HamiltonianVectorField`](@extref)
"""
function hamiltonian_vector_field(
    h::Data.AbstractHamiltonian{TD,VD};
    ad_backend::Differentiation.AbstractADBackend=__hvf_ad_backend(),
    inplace::Bool=__hvf_inplace(),
) where {TD<:Traits.TimeDependence,VD<:Traits.VariableDependence}
    f = inplace ? HVFIpFunctor(h, ad_backend) : HVFOoPFunctor(h, ad_backend)
    return Data.HamiltonianVectorField(
        f;
        is_autonomous=TD <: Traits.Autonomous,
        is_variable=VD <: Traits.NonFixed,
        is_inplace=inplace,
    )
end

"""
$(TYPEDSIGNATURES)

Get the Hamiltonian vector field from a HamiltonianVectorFieldSystem.

This is a trivial getter that returns the pre-stored Hamiltonian vector field from the system.
No computation is performed since the vector field is already constructed.

# Arguments
- `sys::HamiltonianVectorFieldSystem`: The system with a pre-stored Hamiltonian vector field.

# Returns
- `Data.HamiltonianVectorField`: The stored Hamiltonian vector field (identical to `sys.hvf`).

# Notes
- This overload is used when the Hamiltonian vector field is already known and stored, avoiding
  redundant automatic differentiation.
- The returned vector field is identical to `sys.hvf` (same object reference).

See also: [`CTFlows.Systems.HamiltonianVectorFieldSystem`](@ref), [`CTBase.Data.HamiltonianVectorField`](@extref)
"""
function hamiltonian_vector_field(
    sys::HamiltonianVectorFieldSystem; inplace::Bool=__hvf_inplace()
)
    return sys.hvf
end

"""
$(TYPEDSIGNATURES)

Get the Hamiltonian vector field from a HamiltonianSystem (AD-backed).

This function extracts the Hamiltonian and AD backend from the system and delegates to the
Hamiltonian overload to compute the vector field via automatic differentiation.

# Arguments
- `sys::HamiltonianSystem`: The system containing a Hamiltonian and AD backend.
- `inplace::Bool`: Whether to return an in-place closure (default: `__hvf_inplace()` = `false`).

# Returns
- `Data.HamiltonianVectorField`: The Hamiltonian vector field with correct traits matching the system's Hamiltonian.

# Notes
- This overload uses the AD backend returned by `backend(sys)` for gradient computation,
  passed through as-is (no unwrapping/rewrapping), so a device-specific backend (e.g.
  `DifferentiationInterface{Strategies.GPU}`) is preserved.
- The `inplace` parameter controls whether the returned closure writes results in-place.
- Delegates to [`CTFlows.Systems.hamiltonian_vector_field`](@ref).

See also: [`CTFlows.Systems.HamiltonianSystem`](@ref), [`CTBase.Data.Hamiltonian`](@extref), [`CTBase.Differentiation.AbstractADBackend`](@extref)
"""
function hamiltonian_vector_field(sys::HamiltonianSystem; inplace::Bool=__hvf_inplace())
    return hamiltonian_vector_field(sys.h; ad_backend=backend(sys), inplace=inplace)
end

"""
$(TYPEDSIGNATURES)

Get the Hamiltonian vector field from any `AbstractHamiltonianSystem`, dispatching on `ad_trait`.

- `WithAD` systems: computes the vector field via automatic differentiation using
  `hamiltonian(sys)` and `backend(sys)` (protocol methods the system must implement).
- `WithoutAD` systems: throws `NotImplemented` — the system must implement
  `hamiltonian_vector_field` directly (as `HamiltonianVectorFieldSystem` does).

# Throws
- `Exceptions.NotImplemented`: when the system's AD trait is `WithoutAD` and no
  specialized `hamiltonian_vector_field` overload exists for the system type.

See also: [`CTFlows.Systems.HamiltonianSystem`](@ref), [`CTFlows.Systems.HamiltonianVectorFieldSystem`](@ref).
"""
function hamiltonian_vector_field(
    sys::AbstractHamiltonianSystem; inplace::Bool=__hvf_inplace(), kwargs...
)
    return _hamiltonian_vector_field_by_ad(Traits.ad_trait(sys), sys; inplace=inplace)
end

"""
$(TYPEDSIGNATURES)

Compute the Hamiltonian vector field for a `WithAD` system via automatic differentiation.

Delegates to `hamiltonian_vector_field(hamiltonian(sys); ...)` using the AD backend
stored in the system.

See also: [`CTFlows.Systems.hamiltonian_vector_field`](@ref), [`CTFlows.Systems.HamiltonianSystem`](@ref).
"""
function _hamiltonian_vector_field_by_ad(
    ::Type{Traits.WithAD}, sys::AbstractHamiltonianSystem; inplace::Bool=__hvf_inplace()
)
    return hamiltonian_vector_field(
        hamiltonian(sys); ad_backend=backend(sys), inplace=inplace
    )
end

"""
$(TYPEDSIGNATURES)

Throw `NotImplemented` for a `WithoutAD` system that does not provide a specialized
`hamiltonian_vector_field` overload.

# Throws
- `Exceptions.NotImplemented`: always, with a suggestion to implement
  `hamiltonian_vector_field` for the system type or use `HamiltonianVectorFieldSystem`.

See also: [`CTFlows.Systems.hamiltonian_vector_field`](@ref), [`CTFlows.Systems.HamiltonianVectorFieldSystem`](@ref).
"""
function _hamiltonian_vector_field_by_ad(
    ::Type{Traits.WithoutAD}, sys::AbstractHamiltonianSystem; kwargs...
)
    return throw(
        Exceptions.NotImplemented(
            "hamiltonian_vector_field not implemented for this WithoutAD system type";
            required_method="hamiltonian_vector_field(sys::$(typeof(sys)))",
            suggestion="Implement hamiltonian_vector_field for your system type, or use HamiltonianVectorFieldSystem",
            context="hamiltonian_vector_field getter",
        ),
    )
end
