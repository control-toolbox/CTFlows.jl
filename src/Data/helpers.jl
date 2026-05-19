"""
Internal helper functions for display formatting.

This module provides helper functions for generating user-friendly display
representations of VectorField and HamiltonianVectorField types.
"""

# =============================================================================
# Shared label helpers
# =============================================================================

"""
    _td_label(::Type{Autonomous}) -> String
    _td_label(::Type{NonAutonomous}) -> String

Return a user-friendly label for time dependence traits.

# Arguments
- `TD`: Type parameter for time dependence (`Autonomous` or `NonAutonomous`)

# Returns
- `String`: User-friendly label ("autonomous" or "non-autonomous")

See also: [`_vd_label`](@ref), [`_md_label`](@ref).
"""
function _td_label(::Type{Common.Autonomous})
    return "autonomous"
end
function _td_label(::Type{Common.NonAutonomous})
    return "non-autonomous"
end

"""
    _vd_label(::Type{Fixed}) -> String
    _vd_label(::Type{NonFixed}) -> String

Return a user-friendly label for variable dependence traits.

# Arguments
- `VD`: Type parameter for variable dependence (`Fixed` or `NonFixed`)

# Returns
- `String`: User-friendly label ("fixed (no variable)" or "variable")

See also: [`_td_label`](@ref), [`_md_label`](@ref).
"""
function _vd_label(::Type{Common.Fixed})
    return "fixed (no variable)"
end
function _vd_label(::Type{Common.NonFixed})
    return "variable"
end

"""
    _md_label(::Type{OutOfPlace}) -> String
    _md_label(::Type{InPlace}) -> String

Return a user-friendly label for mutability traits.

# Arguments
- `MD`: Type parameter for mutability (`OutOfPlace` or `InPlace`)

# Returns
- `String`: User-friendly label ("out-of-place" or "in-place")

See also: [`_td_label`](@ref), [`_vd_label`](@ref).
"""
function _md_label(::Type{Common.OutOfPlace})
    return "out-of-place"
end
function _md_label(::Type{Common.InPlace})
    return "in-place"
end

# =============================================================================
# VectorField-specific signature helpers
# =============================================================================

"""
    _natural_sig_vf(::Type{TD}, ::Type{VD}, ::Type{OutOfPlace}) where {TD, VD} -> String
    _natural_sig_vf(::Type{TD}, ::Type{VD}, ::Type{InPlace}) where {TD, VD} -> String

Return the natural call signature for a VectorField based on its traits.

# Arguments
- `TD`: Time dependence type (`Autonomous` or `NonAutonomous`)
- `VD`: Variable dependence type (`Fixed` or `NonFixed`)
- `MD`: Mutability type (`OutOfPlace` or `InPlace`)

# Returns
- `String`: Natural call signature (e.g., "f(x)", "f(t, x)", "f(dx, x)")

# Example
\`\`\`julia
_natural_sig_vf(Autonomous, Fixed, OutOfPlace)  # Returns "f(x)"
_natural_sig_vf(NonAutonomous, Fixed, OutOfPlace)  # Returns "f(t, x)"
_natural_sig_vf(Autonomous, Fixed, InPlace)  # Returns "f(dx, x)"
\`\`\`

See also: [`_uniform_sig_vf`](@ref).
"""
function _natural_sig_vf(::Type{TD}, ::Type{VD}, ::Type{Common.OutOfPlace}) where {TD, VD}
    args = String[]
    TD === Common.NonAutonomous && push!(args, "t")
    push!(args, "x")
    VD === Common.NonFixed && push!(args, "v")
    return "f(" * join(args, ", ") * ")"
end

function _natural_sig_vf(::Type{TD}, ::Type{VD}, ::Type{Common.InPlace}) where {TD, VD}
    args = ["dx"]
    TD === Common.NonAutonomous && push!(args, "t")
    push!(args, "x")
    VD === Common.NonFixed && push!(args, "v")
    return "f(" * join(args, ", ") * ")"
end

"""
    _uniform_sig_vf(::Type{OutOfPlace}) -> String
    _uniform_sig_vf(::Type{InPlace}) -> String

Return the uniform call signature for a VectorField.

The uniform signature always includes all arguments (t, x, v) regardless of traits,
and includes the derivative buffer (dx) for in-place variants.

# Arguments
- `MD`: Mutability type (`OutOfPlace` or `InPlace`)

# Returns
- `String`: Uniform call signature ("f(t, x, v)" or "f(dx, t, x, v)")

See also: [`_natural_sig_vf`](@ref).
"""
function _uniform_sig_vf(::Type{Common.OutOfPlace})
    return "f(t, x, v)"
end
function _uniform_sig_vf(::Type{Common.InPlace})
    return "f(dx, t, x, v)"
end

# =============================================================================
# HamiltonianVectorField-specific signature helpers
# =============================================================================

"""
    _natural_sig_hvf(::Type{TD}, ::Type{VD}, ::Type{OutOfPlace}) where {TD, VD} -> String
    _natural_sig_hvf(::Type{TD}, ::Type{VD}, ::Type{InPlace}) where {TD, VD} -> String

Return the natural call signature for a HamiltonianVectorField based on its traits.

# Arguments
- `TD`: Time dependence type (`Autonomous` or `NonAutonomous`)
- `VD`: Variable dependence type (`Fixed` or `NonFixed`)
- `MD`: Mutability type (`OutOfPlace` or `InPlace`)

# Returns
- `String`: Natural call signature (e.g., "f(x, p)", "f(t, x, p)", "f(dx, dp, x, p)")

# Example
\`\`\`julia
_natural_sig_hvf(Autonomous, Fixed, OutOfPlace)  # Returns "f(x, p)"
_natural_sig_hvf(NonAutonomous, Fixed, OutOfPlace)  # Returns "f(t, x, p)"
_natural_sig_hvf(Autonomous, Fixed, InPlace)  # Returns "f(dx, dp, x, p)"
\`\`\`

See also: [`_uniform_sig_hvf`](@ref).
"""
function _natural_sig_hvf(::Type{TD}, ::Type{VD}, ::Type{Common.OutOfPlace}) where {TD, VD}
    args = String[]
    TD === Common.NonAutonomous && push!(args, "t")
    push!(args, "x")
    push!(args, "p")
    VD === Common.NonFixed && push!(args, "v")
    return "f(" * join(args, ", ") * ")"
end

function _natural_sig_hvf(::Type{TD}, ::Type{VD}, ::Type{Common.InPlace}) where {TD, VD}
    args = ["dx", "dp"]
    TD === Common.NonAutonomous && push!(args, "t")
    push!(args, "x")
    push!(args, "p")
    VD === Common.NonFixed && push!(args, "v")
    return "f(" * join(args, ", ") * ")"
end

"""
    _uniform_sig_hvf(::Type{OutOfPlace}) -> String
    _uniform_sig_hvf(::Type{InPlace}) -> String

Return the uniform call signature for a HamiltonianVectorField.

The uniform signature always includes all arguments (t, x, p, v) regardless of traits,
and includes the derivative buffers (dx, dp) for in-place variants.

# Arguments
- `MD`: Mutability type (`OutOfPlace` or `InPlace`)

# Returns
- `String`: Uniform call signature ("f(t, x, p, v)" or "f(dx, dp, t, x, p, v)")

See also: [`_natural_sig_hvf`](@ref).
"""
function _uniform_sig_hvf(::Type{Common.OutOfPlace})
    return "f(t, x, p, v)"
end
function _uniform_sig_hvf(::Type{Common.InPlace})
    return "f(dx, dp, t, x, p, v)"
end

# =============================================================================
# Hamiltonian-specific signature helpers
# =============================================================================

"""
    _natural_sig_h(::Type{TD}, ::Type{VD}) where {TD, VD} -> String

Return the natural call signature for a Hamiltonian based on its traits.

# Arguments
- `TD`: Time dependence type (`Autonomous` or `NonAutonomous`)
- `VD`: Variable dependence type (`Fixed` or `NonFixed`)

# Returns
- `String`: Natural call signature (e.g., "h(x, p)", "h(t, x, p)")

# Example
\`\`\`julia
_natural_sig_h(Autonomous, Fixed)  # Returns "h(x, p)"
_natural_sig_h(NonAutonomous, Fixed)  # Returns "h(t, x, p)"
\`\`\`

See also: [`_uniform_sig_h`](@ref).
"""
function _natural_sig_h(::Type{TD}, ::Type{VD}) where {TD, VD}
    args = String[]
    TD === Common.NonAutonomous && push!(args, "t")
    push!(args, "x")
    push!(args, "p")
    VD === Common.NonFixed && push!(args, "v")
    return "h(" * join(args, ", ") * ")"
end

"""
    _uniform_sig_h() -> String

Return the uniform call signature for a Hamiltonian.

The uniform signature always includes all arguments (t, x, p, v) regardless of traits.

# Returns
- `String`: Uniform call signature ("h(t, x, p, v)")

See also: [`_natural_sig_h`](@ref).
"""
function _uniform_sig_h()
    return "h(t, x, p, v)"
end
