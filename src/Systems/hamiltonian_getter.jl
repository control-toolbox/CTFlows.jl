# ==============================================================================
# hamiltonian_vector_field getter — Public API for accessing X_H
# ==============================================================================

# ==============================================================================
# Out-of-place closure factories (4 variants)
# ==============================================================================

"""
    _make_oop_hvf(h, backend, ::Type{Traits.Autonomous}, ::Type{Traits.Fixed})

Create an out-of-place Hamiltonian vector field closure for Autonomous/Fixed case.
Signature: (x, p) -> (∂p, -∂x)
"""
function _make_oop_hvf(h, backend, ::Type{Traits.Autonomous}, ::Type{Traits.Fixed})
    return (x, p) -> begin
        ∂x, ∂p = Differentiation.hamiltonian_gradient(backend, h, nothing, x, p, nothing, nothing)
        return (∂p, -∂x)
    end
end

"""
    _make_oop_hvf(h, backend, ::Type{Traits.NonAutonomous}, ::Type{Traits.Fixed})

Create an out-of-place Hamiltonian vector field closure for NonAutonomous/Fixed case.
Signature: (t, x, p) -> (∂p, -∂x)
"""
function _make_oop_hvf(h, backend, ::Type{Traits.NonAutonomous}, ::Type{Traits.Fixed})
    return (t, x, p) -> begin
        ∂x, ∂p = Differentiation.hamiltonian_gradient(backend, h, t, x, p, nothing, nothing)
        return (∂p, -∂x)
    end
end

"""
    _make_oop_hvf(h, backend, ::Type{Traits.Autonomous}, ::Type{Traits.NonFixed})

Create an out-of-place Hamiltonian vector field closure for Autonomous/NonFixed case.
Signature: (x, p, v) -> (∂p, -∂x) or (∂p, -∂x, -∂v) if variable_costate=true
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
    _make_oop_hvf(h, backend, ::Type{Traits.NonAutonomous}, ::Type{Traits.NonFixed})

Create an out-of-place Hamiltonian vector field closure for NonAutonomous/NonFixed case.
Signature: (t, x, p, v) -> (∂p, -∂x) or (∂p, -∂x, -∂v) if variable_costate=true
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
    _make_ip_hvf(h, backend, ::Type{Traits.Autonomous}, ::Type{Traits.Fixed})

Create an in-place Hamiltonian vector field closure for Autonomous/Fixed case.
Signature: (dx, dp, x, p) -> nothing; fills dx .= ∂p, dp .= -∂x
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
    _make_ip_hvf(h, backend, ::Type{Traits.NonAutonomous}, ::Type{Traits.Fixed})

Create an in-place Hamiltonian vector field closure for NonAutonomous/Fixed case.
Signature: (dx, dp, t, x, p) -> nothing; fills dx .= ∂p, dp .= -∂x
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
    _make_ip_hvf(h, backend, ::Type{Traits.Autonomous}, ::Type{Traits.NonFixed})

Create an in-place Hamiltonian vector field closure for Autonomous/NonFixed case.
Signature: (dx, dp, x, p, v) -> nothing; fills dx .= ∂p, dp .= -∂x, optionally dpv .= -∂v
"""
function _make_ip_hvf(h, backend, ::Type{Traits.Autonomous}, ::Type{Traits.NonFixed})
    return (dx, dp, x, p, v) -> begin
        ∂x, ∂p = Differentiation.hamiltonian_gradient(backend, h, nothing, x, p, v, nothing)
        dx .= ∂p
        dp .= .-∂x
        return nothing
    end
end

"""
    _make_ip_hvf(h, backend, ::Type{Traits.NonAutonomous}, ::Type{Traits.NonFixed})

Create an in-place Hamiltonian vector field closure for NonAutonomous/NonFixed case.
Signature: (dx, dp, t, x, p, v) -> nothing; fills dx .= ∂p, dp .= -∂x, optionally dpv .= -∂v
"""
function _make_ip_hvf(h, backend, ::Type{Traits.NonAutonomous}, ::Type{Traits.NonFixed})
    return (dx, dp, t, x, p, v) -> begin
        ∂x, ∂p = Differentiation.hamiltonian_gradient(backend, h, t, x, p, v, nothing)
        dx .= ∂p
        dp .= .-∂x
        return nothing
    end
end

# ==============================================================================
# Getter overloads
# ==============================================================================

"""
$(TYPEDSIGNATURES)

Get the Hamiltonian vector field from a scalar Hamiltonian function.

# Arguments
- `h::Data.Hamiltonian`: The scalar Hamiltonian function.
- `ad_backend`: AD backend type (default: `__ad_backend()` = `AutoForwardDiff()`) or `AbstractADBackend` instance.
- `inplace`: Whether to return in-place closure (default: `__hvf_inplace()` = `false`).

# Returns
- `Data.HamiltonianVectorField`: The Hamiltonian vector field with correct traits.

# TODO: docstring
"""
function hamiltonian_vector_field(
    h::Data.Hamiltonian{F, TD, VD};
    ad_backend = Differentiation.__ad_backend(),
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

Get the Hamiltonian vector field from a HamiltonianVectorFieldSystem (trivial getter).

# Arguments
- `sys::HamiltonianVectorFieldSystem`: The system with pre-stored HVF.

# Returns
- `Data.HamiltonianVectorField`: The stored Hamiltonian vector field.

# TODO: docstring
"""
function hamiltonian_vector_field(sys::HamiltonianVectorFieldSystem)
    return sys.hvf
end

"""
$(TYPEDSIGNATURES)

Get the Hamiltonian vector field from a HamiltonianSystem (AD-backed).

# Arguments
- `sys::HamiltonianSystem`: The system with Hamiltonian and AD backend.
- `inplace`: Whether to return in-place closure (default: `__hvf_inplace()` = `false`).

# Returns
- `Data.HamiltonianVectorField`: The Hamiltonian vector field with correct traits.

# TODO: docstring
"""
function hamiltonian_vector_field(sys::HamiltonianSystem; inplace::Bool = Common.__hvf_inplace())
    ad_backend = Differentiation.ad_backend(sys.backend)
    return hamiltonian_vector_field(sys.h; ad_backend=ad_backend, inplace=inplace)
end

"""
$(TYPEDSIGNATURES)

Contract stub for unsupported system types.

# TODO: docstring
"""
function hamiltonian_vector_field(::AbstractHamiltonianSystem; kwargs...)
    throw(Exceptions.NotImplemented(
        "hamiltonian_vector_field not implemented for this system type";
        required_method = "hamiltonian_vector_field(sys::HamiltonianSystem, ...)",
        suggestion = "Use a HamiltonianSystem (AD-backed) or a HamiltonianVectorFieldSystem to get a Hamiltonian vector field",
        context = "hamiltonian_vector_field getter",
    ))
end
