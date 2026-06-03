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

See also: [`CTFlows.Systems.hamiltonian_vector_field`](@ref), [`CTFlows.Differentiation.hamiltonian_gradient`](@ref)
"""
function _make_oop_hvf(h, backend, ::Type{Traits.Autonomous}, ::Type{Traits.Fixed})
    return (x, p) -> begin
        ∂x, ∂p = Differentiation.hamiltonian_gradient(backend, h, nothing, x, p, nothing, nothing)
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

See also: [`CTFlows.Systems.hamiltonian_vector_field`](@ref), [`CTFlows.Differentiation.hamiltonian_gradient`](@ref)
"""
function _make_oop_hvf(h, backend, ::Type{Traits.NonAutonomous}, ::Type{Traits.Fixed})
    return (t, x, p) -> begin
        ∂x, ∂p = Differentiation.hamiltonian_gradient(backend, h, t, x, p, nothing, nothing)
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

See also: [`CTFlows.Systems.hamiltonian_vector_field`](@ref), [`CTFlows.Differentiation.hamiltonian_gradient`](@ref), [`CTFlows.Differentiation.variable_gradient`](@ref)
"""
function _make_oop_hvf(h, backend, ::Type{Traits.Autonomous}, ::Type{Traits.NonFixed})
    return (x, p, v; variable_costate::Bool=false) -> begin
        ∂x, ∂p = Differentiation.hamiltonian_gradient(backend, h, nothing, x, p, v, nothing)
        variable_costate || return (∂p, -∂x)
        ∂v = Differentiation.variable_gradient(backend, h, nothing, x, p, v, nothing)
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

See also: [`CTFlows.Systems.hamiltonian_vector_field`](@ref), [`CTFlows.Differentiation.hamiltonian_gradient`](@ref), [`CTFlows.Differentiation.variable_gradient`](@ref)
"""
function _make_oop_hvf(h, backend, ::Type{Traits.NonAutonomous}, ::Type{Traits.NonFixed})
    return (t, x, p, v; variable_costate::Bool=false) -> begin
        ∂x, ∂p = Differentiation.hamiltonian_gradient(backend, h, t, x, p, v, nothing)
        variable_costate || return (∂p, -∂x)
        ∂v = Differentiation.variable_gradient(backend, h, t, x, p, v, nothing)
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

See also: [`CTFlows.Systems.hamiltonian_vector_field`](@ref), [`CTFlows.Differentiation.hamiltonian_gradient`](@ref)
"""
function _make_ip_hvf(h, backend, ::Type{Traits.Autonomous}, ::Type{Traits.Fixed})
    return (dx, dp, x, p) -> begin
        ∂x, ∂p = Differentiation.hamiltonian_gradient(backend, h, nothing, x, p, nothing, nothing)
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

See also: [`CTFlows.Systems.hamiltonian_vector_field`](@ref), [`CTFlows.Differentiation.hamiltonian_gradient`](@ref)
"""
function _make_ip_hvf(h, backend, ::Type{Traits.NonAutonomous}, ::Type{Traits.Fixed})
    return (dx, dp, t, x, p) -> begin
        ∂x, ∂p = Differentiation.hamiltonian_gradient(backend, h, t, x, p, nothing, nothing)
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

See also: [`CTFlows.Systems.hamiltonian_vector_field`](@ref), [`CTFlows.Differentiation.hamiltonian_gradient`](@ref), [`CTFlows.Differentiation.variable_gradient`](@ref)
"""
function _make_ip_hvf(h, backend, ::Type{Traits.Autonomous}, ::Type{Traits.NonFixed})
    return (dx, dp, x, p, v; dpv=nothing, variable_costate::Bool=false) -> begin
        ∂x, ∂p = Differentiation.hamiltonian_gradient(backend, h, nothing, x, p, v, nothing)
        dx .= ∂p
        dp .= .-∂x
        if variable_costate
            dpv === nothing && throw(Exceptions.PreconditionError(
                "dpv buffer must be provided when variable_costate=true";
                context = "hamiltonian_vector_field IP Autonomous/NonFixed",
            ))
            ∂v = Differentiation.variable_gradient(backend, h, nothing, x, p, v, nothing)
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

See also: [`CTFlows.Systems.hamiltonian_vector_field`](@ref), [`CTFlows.Differentiation.hamiltonian_gradient`](@ref), [`CTFlows.Differentiation.variable_gradient`](@ref)
"""
function _make_ip_hvf(h, backend, ::Type{Traits.NonAutonomous}, ::Type{Traits.NonFixed})
    return (dx, dp, t, x, p, v; dpv=nothing, variable_costate::Bool=false) -> begin
        ∂x, ∂p = Differentiation.hamiltonian_gradient(backend, h, t, x, p, v, nothing)
        dx .= ∂p
        dp .= .-∂x
        if variable_costate
            dpv === nothing && throw(Exceptions.PreconditionError(
                "dpv buffer must be provided when variable_costate=true";
                context = "hamiltonian_vector_field IP NonAutonomous/NonFixed",
            ))
            ∂v = Differentiation.variable_gradient(backend, h, t, x, p, v, nothing)
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
- `ad_backend`: AD backend type (default: `Common.__ad_backend()` = `AutoForwardDiff()`) or an `AbstractADBackend` instance.
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

See also: [`CTFlows.Systems.HamiltonianSystem`](@ref), [`CTFlows.Systems.HamiltonianVectorFieldSystem`](@ref), [`CTFlows.Data.HamiltonianVectorField`](@ref)
"""
function hamiltonian_vector_field(
    h::Data.Hamiltonian{F, TD, VD};
    ad_backend = Common.__ad_backend(),
    inplace::Bool = Common.__hvf_inplace(),
) where {F, TD, VD}
    # If ad_backend is an AbstractADBackend instance, use it directly; otherwise wrap it
    backend = if ad_backend isa Differentiation.AbstractADBackend
        ad_backend
    else
        Differentiation.build_ad_backend(; ad_backend=ad_backend, prepare_cache=false)
    end
    f = inplace ? _make_ip_hvf(h, backend, TD, VD) : _make_oop_hvf(h, backend, TD, VD)
    return Data.HamiltonianVectorField(f;
        is_autonomous = TD <: Traits.Autonomous,
        is_variable   = VD <: Traits.NonFixed,
        is_inplace    = inplace,
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

See also: [`CTFlows.Systems.HamiltonianVectorFieldSystem`](@ref), [`CTFlows.Data.HamiltonianVectorField`](@ref)
"""
function hamiltonian_vector_field(sys::HamiltonianVectorFieldSystem)
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
- Delegates to [`CTFlows.Systems.hamiltonian_vector_field(h::Data.Hamiltonian; ...)`](@ref).

See also: [`CTFlows.Systems.HamiltonianSystem`](@ref), [`CTFlows.Data.Hamiltonian`](@ref), [`CTFlows.Differentiation.AbstractADBackend`](@ref)
"""
function hamiltonian_vector_field(sys::HamiltonianSystem; inplace::Bool = Common.__hvf_inplace())
    ad_backend = Differentiation.ad_backend(sys.backend)
    return hamiltonian_vector_field(sys.h; ad_backend=ad_backend, inplace=inplace)
end

"""
$(TYPEDSIGNATURES)

Contract stub for unsupported system types.

This method throws a `NotImplemented` exception when called on an `AbstractHamiltonianSystem`
subtype that does not have a specific implementation. This ensures that only supported system
types (`HamiltonianSystem` and `HamiltonianVectorFieldSystem`) can be used to obtain a Hamiltonian
vector field.

# Arguments
- `::AbstractHamiltonianSystem`: Any Hamiltonian system type (catch-all for unsupported types).
- `kwargs...`: Additional keyword arguments (ignored).

# Throws
- `CTBase.Exceptions.NotImplemented`: Always thrown for unsupported system types with a helpful error message.

# Notes
- This is a contract stub following the CTFlows pattern of providing explicit error messages for unimplemented methods.
- The error message suggests using `HamiltonianSystem` (AD-backed) or `HamiltonianVectorFieldSystem` instead.

See also: [`CTFlows.Systems.HamiltonianSystem`](@ref), [`CTFlows.Systems.HamiltonianVectorFieldSystem`](@ref), [`CTBase.Exceptions.NotImplemented`](@extref)
"""
function hamiltonian_vector_field(::AbstractHamiltonianSystem; kwargs...)
    throw(Exceptions.NotImplemented(
        "hamiltonian_vector_field not implemented for this system type";
        required_method = "hamiltonian_vector_field(sys::HamiltonianSystem, ...)",
        suggestion = "Use a HamiltonianSystem (AD-backed) or a HamiltonianVectorFieldSystem to get a Hamiltonian vector field",
        context = "hamiltonian_vector_field getter",
    ))
end
