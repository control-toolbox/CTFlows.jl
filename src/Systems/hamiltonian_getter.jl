# ==============================================================================
# hamiltonian_vector_field getter — Public API for accessing X_H
# ==============================================================================

# ==============================================================================
# Out-of-place closure factories (4 variants)
# ==============================================================================

"""
$(TYPEDSIGNATURES)

Create an out-of-place Hamiltonian vector field closure for the Autonomous/Fixed case.

The closure computes the Hamiltonian vector field X_H = (∂H/∂p, -∂H/∂x) for an autonomous
Hamiltonian system with fixed parameters. The signature is `(x, p) -> (∂p, -∂x)`.

# Arguments
- `h::Data.Hamiltonian`: The scalar Hamiltonian function.
- `backend::Differentiation.AbstractADBackend`: The AD backend for gradient computation.
- `::Type{Traits.Autonomous}: Type parameter indicating autonomous time dependence.
- `::Type{Traits.Fixed}`: Type parameter indicating fixed variable dependence.

# Returns
- `Function`: A closure `(x, p) -> (∂p, -∂x)` computing the Hamiltonian vector field.

# Notes
- This is an internal factory function used by [`CTFlows.Systems.hamiltonian_vector_field`](@ref).
- The closure uses automatic differentiation via the provided backend to compute gradients.

See also: [`CTFlows.Systems.hamiltonian_vector_field`](@ref), [`CTBase.Differentiation.hamiltonian_gradient`](@ref)
"""
function _make_oop_hvf(h, backend, ::Type{Traits.Autonomous}, ::Type{Traits.Fixed})
    return (x, p) -> begin
        ∂x, ∂p = Differentiation.hamiltonian_gradient(backend, h, nothing, x, p, nothing)
        return (∂p, -∂x)
    end
end

"""
$(TYPEDSIGNATURES)

Create an out-of-place Hamiltonian vector field closure for the NonAutonomous/Fixed case.

The closure computes the Hamiltonian vector field X_H = (∂H/∂p, -∂H/∂x) for a non-autonomous
Hamiltonian system with fixed parameters. The signature is `(t, x, p) -> (∂p, -∂x)`.

# Arguments
- `h::Data.Hamiltonian`: The scalar Hamiltonian function.
- `backend::Differentiation.AbstractADBackend`: The AD backend for gradient computation.
- `::Type{Traits.NonAutonomous}`: Type parameter indicating non-autonomous time dependence.
- `::Type{Traits.Fixed}`: Type parameter indicating fixed variable dependence.

# Returns
- `Function`: A closure `(t, x, p) -> (∂p, -∂x)` computing the Hamiltonian vector field.

# Notes
- This is an internal factory function used by [`CTFlows.Systems.hamiltonian_vector_field`](@ref).
- The closure uses automatic differentiation via the provided backend to compute gradients.

See also: [`CTFlows.Systems.hamiltonian_vector_field`](@ref), [`CTBase.Differentiation.hamiltonian_gradient`](@ref)
"""
function _make_oop_hvf(h, backend, ::Type{Traits.NonAutonomous}, ::Type{Traits.Fixed})
    return (t, x, p) -> begin
        ∂x, ∂p = Differentiation.hamiltonian_gradient(backend, h, t, x, p, nothing)
        return (∂p, -∂x)
    end
end

"""
$(TYPEDSIGNATURES)

Create an out-of-place Hamiltonian vector field closure for the Autonomous/NonFixed case.

The closure computes the Hamiltonian vector field X_H = (∂H/∂p, -∂H/∂x) for an autonomous
Hamiltonian system with variable parameters. The signature is `(x, p, v; variable_costate=false) -> (∂p, -∂x)`
or `(x, p, v; variable_costate=true) -> (∂p, -∂x, -∂v)` when the variable costate is requested.

# Arguments
- `h::Data.Hamiltonian`: The scalar Hamiltonian function.
- `backend::Differentiation.AbstractADBackend`: The AD backend for gradient computation.
- `::Type{Traits.Autonomous}`: Type parameter indicating autonomous time dependence.
- `::Type{Traits.NonFixed}`: Type parameter indicating non-fixed variable dependence.

# Returns
- `Function`: A closure `(x, p, v; variable_costate=false)` computing the Hamiltonian vector field.

# Notes
- This is an internal factory function used by [`CTFlows.Systems.hamiltonian_vector_field`](@ref).
- When `variable_costate=true`, the closure also returns `-∂H/∂v` (the negative gradient with respect to variables).
- The closure uses automatic differentiation via the provided backend to compute gradients.

See also: [`CTFlows.Systems.hamiltonian_vector_field`](@ref), [`CTBase.Differentiation.hamiltonian_gradient`](@ref), [`CTBase.Differentiation.variable_gradient`](@ref)
"""
function _make_oop_hvf(h, backend, ::Type{Traits.Autonomous}, ::Type{Traits.NonFixed})
    return (x, p, v; variable_costate::Bool=false) -> begin
        ∂x, ∂p = Differentiation.hamiltonian_gradient(backend, h, nothing, x, p, v)
        variable_costate || return (∂p, -∂x)
        ∂v = Differentiation.variable_gradient(backend, h, nothing, x, p, v)
        return (∂p, -∂x, -∂v)
    end
end

"""
$(TYPEDSIGNATURES)

Create an out-of-place Hamiltonian vector field closure for the NonAutonomous/NonFixed case.

The closure computes the Hamiltonian vector field X_H = (∂H/∂p, -∂H/∂x) for a non-autonomous
Hamiltonian system with variable parameters. The signature is `(t, x, p, v; variable_costate=false) -> (∂p, -∂x)`
or `(t, x, p, v; variable_costate=true) -> (∂p, -∂x, -∂v)` when the variable costate is requested.

# Arguments
- `h::Data.Hamiltonian`: The scalar Hamiltonian function.
- `backend::Differentiation.AbstractADBackend`: The AD backend for gradient computation.
- `::Type{Traits.NonAutonomous}`: Type parameter indicating non-autonomous time dependence.
- `::Type{Traits.NonFixed}`: Type parameter indicating non-fixed variable dependence.

# Returns
- `Function`: A closure `(t, x, p, v; variable_costate=false)` computing the Hamiltonian vector field.

# Notes
- This is an internal factory function used by [`CTFlows.Systems.hamiltonian_vector_field`](@ref).
- When `variable_costate=true`, the closure also returns `-∂H/∂v` (the negative gradient with respect to variables).
- The closure uses automatic differentiation via the provided backend to compute gradients.

See also: [`CTFlows.Systems.hamiltonian_vector_field`](@ref), [`CTBase.Differentiation.hamiltonian_gradient`](@ref), [`CTBase.Differentiation.variable_gradient`](@ref)
"""
function _make_oop_hvf(h, backend, ::Type{Traits.NonAutonomous}, ::Type{Traits.NonFixed})
    return (t, x, p, v; variable_costate::Bool=false) -> begin
        ∂x, ∂p = Differentiation.hamiltonian_gradient(backend, h, t, x, p, v)
        variable_costate || return (∂p, -∂x)
        ∂v = Differentiation.variable_gradient(backend, h, t, x, p, v)
        return (∂p, -∂x, -∂v)
    end
end

# ==============================================================================
# In-place closure factories (4 variants)
# ==============================================================================

"""
$(TYPEDSIGNATURES)

Create an in-place Hamiltonian vector field closure for the Autonomous/Fixed case.

The closure computes the Hamiltonian vector field X_H = (∂H/∂p, -∂H/∂x) for an autonomous
Hamiltonian system with fixed parameters, writing the result in-place. The signature is
`(dx, dp, x, p) -> nothing` and fills `dx .= ∂p, dp .= -∂x`.

# Arguments
- `h::Data.Hamiltonian`: The scalar Hamiltonian function.
- `backend::Differentiation.AbstractADBackend`: The AD backend for gradient computation.
- `::Type{Traits.Autonomous}`: Type parameter indicating autonomous time dependence.
- `::Type{Traits.Fixed}`: Type parameter indicating fixed variable dependence.

# Returns
- `Function`: A closure `(dx, dp, x, p) -> nothing` that fills the output arrays in-place.

# Notes
- This is an internal factory function used by [`CTFlows.Systems.hamiltonian_vector_field`](@ref).
- The closure uses automatic differentiation via the provided backend to compute gradients.
- Output arrays `dx` and `dp` must be pre-allocated with the correct dimensions.

See also: [`CTFlows.Systems.hamiltonian_vector_field`](@ref), [`CTBase.Differentiation.hamiltonian_gradient`](@ref)
"""
function _make_ip_hvf(h, backend, ::Type{Traits.Autonomous}, ::Type{Traits.Fixed})
    return (dx, dp, x, p) -> begin
        ∂x, ∂p = Differentiation.hamiltonian_gradient(backend, h, nothing, x, p, nothing)
        dx .= ∂p
        dp .= .-∂x
        return nothing
    end
end

"""
$(TYPEDSIGNATURES)

Create an in-place Hamiltonian vector field closure for the NonAutonomous/Fixed case.

The closure computes the Hamiltonian vector field X_H = (∂H/∂p, -∂H/∂x) for a non-autonomous
Hamiltonian system with fixed parameters, writing the result in-place. The signature is
`(dx, dp, t, x, p) -> nothing` and fills `dx .= ∂p, dp .= -∂x`.

# Arguments
- `h::Data.Hamiltonian`: The scalar Hamiltonian function.
- `backend::Differentiation.AbstractADBackend`: The AD backend for gradient computation.
- `::Type{Traits.NonAutonomous}`: Type parameter indicating non-autonomous time dependence.
- `::Type{Traits.Fixed}`: Type parameter indicating fixed variable dependence.

# Returns
- `Function`: A closure `(dx, dp, t, x, p) -> nothing` that fills the output arrays in-place.

# Notes
- This is an internal factory function used by [`CTFlows.Systems.hamiltonian_vector_field`](@ref).
- The closure uses automatic differentiation via the provided backend to compute gradients.
- Output arrays `dx` and `dp` must be pre-allocated with the correct dimensions.

See also: [`CTFlows.Systems.hamiltonian_vector_field`](@ref), [`CTBase.Differentiation.hamiltonian_gradient`](@ref)
"""
function _make_ip_hvf(h, backend, ::Type{Traits.NonAutonomous}, ::Type{Traits.Fixed})
    return (dx, dp, t, x, p) -> begin
        ∂x, ∂p = Differentiation.hamiltonian_gradient(backend, h, t, x, p, nothing)
        dx .= ∂p
        dp .= .-∂x
        return nothing
    end
end

"""
$(TYPEDSIGNATURES)

Create an in-place Hamiltonian vector field closure for the Autonomous/NonFixed case.

The closure computes the Hamiltonian vector field X_H = (∂H/∂p, -∂H/∂x) for an autonomous
Hamiltonian system with variable parameters, writing the result in-place. The signature is
`(dx, dp, x, p, v) -> nothing` and fills `dx .= ∂p, dp .= -∂x`.

# Arguments
- `h::Data.Hamiltonian`: The scalar Hamiltonian function.
- `backend::Differentiation.AbstractADBackend`: The AD backend for gradient computation.
- `::Type{Traits.Autonomous}`: Type parameter indicating autonomous time dependence.
- `::Type{Traits.NonFixed}`: Type parameter indicating non-fixed variable dependence.

# Returns
- `Function`: A closure `(dx, dp, x, p, v; dpv=nothing, variable_costate=false) -> nothing` that fills the output arrays in-place.

# Notes
- This is an internal factory function used by [`CTFlows.Systems.hamiltonian_vector_field`](@ref).
- The closure uses automatic differentiation via the provided backend to compute gradients.
- Output arrays `dx` and `dp` must be pre-allocated with the correct dimensions.
- When `variable_costate=true`, `dpv` must be a pre-allocated mutable array matching the shape of `v`; it is filled with `-∂H/∂v`.

# Throws
- `Exceptions.PreconditionError`: When `variable_costate=true && dpv === nothing`.

See also: [`CTFlows.Systems.hamiltonian_vector_field`](@ref), [`CTBase.Differentiation.hamiltonian_gradient`](@ref), [`CTBase.Differentiation.variable_gradient`](@ref)
"""
function _make_ip_hvf(h, backend, ::Type{Traits.Autonomous}, ::Type{Traits.NonFixed})
    return (dx, dp, x, p, v; dpv=nothing, variable_costate::Bool=false) -> begin
        ∂x, ∂p = Differentiation.hamiltonian_gradient(backend, h, nothing, x, p, v)
        dx .= ∂p
        dp .= .-∂x
        if variable_costate
            dpv === nothing && throw(
                Exceptions.PreconditionError(
                    "dpv buffer must be provided when variable_costate=true";
                    context="hamiltonian_vector_field IP Autonomous/NonFixed",
                ),
            )
            ∂v = Differentiation.variable_gradient(backend, h, nothing, x, p, v)
            dpv .= .-∂v
        end
        return nothing
    end
end

"""
$(TYPEDSIGNATURES)

Create an in-place Hamiltonian vector field closure for the NonAutonomous/NonFixed case.

The closure computes the Hamiltonian vector field X_H = (∂H/∂p, -∂H/∂x) for a non-autonomous
Hamiltonian system with variable parameters, writing the result in-place. The signature is
`(dx, dp, t, x, p, v) -> nothing` and fills `dx .= ∂p, dp .= -∂x`.

# Arguments
- `h::Data.Hamiltonian`: The scalar Hamiltonian function.
- `backend::Differentiation.AbstractADBackend`: The AD backend for gradient computation.
- `::Type{Traits.NonAutonomous}`: Type parameter indicating non-autonomous time dependence.
- `::Type{Traits.NonFixed}`: Type parameter indicating non-fixed variable dependence.

# Returns
- `Function`: A closure `(dx, dp, t, x, p, v; dpv=nothing, variable_costate=false) -> nothing` that fills the output arrays in-place.

# Notes
- This is an internal factory function used by [`CTFlows.Systems.hamiltonian_vector_field`](@ref).
- The closure uses automatic differentiation via the provided backend to compute gradients.
- Output arrays `dx` and `dp` must be pre-allocated with the correct dimensions.
- When `variable_costate=true`, `dpv` must be a pre-allocated mutable array matching the shape of `v`; it is filled with `-∂H/∂v`.

# Throws
- `Exceptions.PreconditionError`: When `variable_costate=true && dpv === nothing`.

See also: [`CTFlows.Systems.hamiltonian_vector_field`](@ref), [`CTBase.Differentiation.hamiltonian_gradient`](@ref), [`CTBase.Differentiation.variable_gradient`](@ref)
"""
function _make_ip_hvf(h, backend, ::Type{Traits.NonAutonomous}, ::Type{Traits.NonFixed})
    return (dx, dp, t, x, p, v; dpv=nothing, variable_costate::Bool=false) -> begin
        ∂x, ∂p = Differentiation.hamiltonian_gradient(backend, h, t, x, p, v)
        dx .= ∂p
        dp .= .-∂x
        if variable_costate
            dpv === nothing && throw(
                Exceptions.PreconditionError(
                    "dpv buffer must be provided when variable_costate=true";
                    context="hamiltonian_vector_field IP NonAutonomous/NonFixed",
                ),
            )
            ∂v = Differentiation.variable_gradient(backend, h, t, x, p, v)
            dpv .= .-∂v
        end
        return nothing
    end
end

# ==============================================================================
# Getter overloads
# ==============================================================================

"""
$(TYPEDSIGNATURES)

Get the Hamiltonian vector field from a scalar Hamiltonian function.

This function computes the Hamiltonian vector field X_H = (∂H/∂p, -∂H/∂x) for a given scalar
Hamiltonian function using automatic differentiation. The returned vector field is a closure
with the correct signature based on the Hamiltonian's time and variable dependence traits.

# Arguments
- `h::Data.Hamiltonian{F, TD, VD}`: The scalar Hamiltonian function with traits `TD` (time dependence) and `VD` (variable dependence).
- `ad_backend`: AD backend type (default: `Differentiation.__ad_backend()` = `AutoForwardDiff()`) or an `AbstractADBackend` instance.
- `inplace::Bool`: Whether to return an in-place closure (default: `Common.__hvf_inplace()` = `false`).

# Returns
- `Data.HamiltonianVectorField`: The Hamiltonian vector field with correct traits matching the input Hamiltonian.

# Notes
- If `ad_backend` is an `AbstractADBackend` instance, it is used directly; otherwise it is wrapped via `Differentiation.build_ad_backend`.
- The closure signature depends on the Hamiltonian's traits:
  - Autonomous/Fixed: `(x, p) -> (∂p, -∂x)` or `(dx, dp, x, p) -> nothing` (in-place)
  - NonAutonomous/Fixed: `(t, x, p) -> (∂p, -∂x)` or `(dx, dp, t, x, p) -> nothing` (in-place)
  - Autonomous/NonFixed: `(x, p, v; variable_costate=false) -> (∂p, -∂x)` or `(x, p, v; variable_costate=true) -> (∂p, -∂x, -∂v)`
  - NonAutonomous/NonFixed: `(t, x, p, v; variable_costate=false) -> (∂p, -∂x)` or `(t, x, p, v; variable_costate=true) -> (∂p, -∂x, -∂v)`

See also: [`CTFlows.Systems.HamiltonianSystem`](@ref), [`CTFlows.Systems.HamiltonianVectorFieldSystem`](@ref), [`CTBase.Data.HamiltonianVectorField`](@ref)
"""
function hamiltonian_vector_field(
    h::Data.Hamiltonian{F,TD,VD};
    ad_backend=Differentiation.__ad_backend(),
    inplace::Bool=Common.__hvf_inplace(),
) where {F,TD,VD}
    # If ad_backend is an AbstractADBackend instance, use it directly; otherwise wrap it
    backend = if ad_backend isa Differentiation.AbstractADBackend
        ad_backend
    else
        Differentiation.build_ad_backend(; ad_backend=ad_backend)
    end
    f = inplace ? _make_ip_hvf(h, backend, TD, VD) : _make_oop_hvf(h, backend, TD, VD)
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

See also: [`CTFlows.Systems.HamiltonianVectorFieldSystem`](@ref), [`CTBase.Data.HamiltonianVectorField`](@ref)
"""
function hamiltonian_vector_field(
    sys::HamiltonianVectorFieldSystem; inplace::Bool=Common.__hvf_inplace()
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
- `inplace::Bool`: Whether to return an in-place closure (default: `Common.__hvf_inplace()` = `false`).

# Returns
- `Data.HamiltonianVectorField`: The Hamiltonian vector field with correct traits matching the system's Hamiltonian.

# Notes
- This overload uses the AD backend stored in `sys.backend` for gradient computation.
- The `inplace` parameter controls whether the returned closure writes results in-place.
- Delegates to [`CTFlows.Systems.hamiltonian_vector_field`](@ref).

See also: [`CTFlows.Systems.HamiltonianSystem`](@ref), [`CTBase.Data.Hamiltonian`](@ref), [`CTBase.Differentiation.AbstractADBackend`](@ref)
"""
function hamiltonian_vector_field(
    sys::HamiltonianSystem; inplace::Bool=Common.__hvf_inplace()
)
    ad_backend = Differentiation.ad_backend(sys.backend)
    return hamiltonian_vector_field(sys.h; ad_backend=ad_backend, inplace=inplace)
end

"""
$(TYPEDSIGNATURES)

Get the Hamiltonian vector field from any `AbstractHamiltonianSystem`, dispatching on `ad_trait`.

- `WithAD` systems: computes the vector field via automatic differentiation using
  `hamiltonian(sys)` and `backend(sys)` (protocol methods the system must implement).
- `WithoutAD` systems: throws `NotImplemented` — the system must implement
  `hamiltonian_vector_field` directly (as `HamiltonianVectorFieldSystem` does).

See also: [`CTFlows.Systems.HamiltonianSystem`](@ref), [`CTFlows.Systems.HamiltonianVectorFieldSystem`](@ref).
"""
function hamiltonian_vector_field(
    sys::AbstractHamiltonianSystem; inplace::Bool=Common.__hvf_inplace(), kwargs...
)
    return _hamiltonian_vector_field_by_ad(Traits.ad_trait(sys), sys; inplace=inplace)
end

function _hamiltonian_vector_field_by_ad(
    ::Type{Traits.WithAD},
    sys::AbstractHamiltonianSystem;
    inplace::Bool=Common.__hvf_inplace(),
)
    ad_backend = Differentiation.ad_backend(backend(sys))
    return hamiltonian_vector_field(
        hamiltonian(sys); ad_backend=ad_backend, inplace=inplace
    )
end

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
