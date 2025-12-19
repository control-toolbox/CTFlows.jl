# ==============================================================================
# CTFlows.jl - Differential Geometry Module (V3)
# ==============================================================================
# This file contains differential geometry tools for control theory.
# V3 refactoring: wrapper-free API using pure Functions

# ==============================================================================
# Prefix System for Differential Geometry Functions
# ==============================================================================

"""
Prefix reference for differential geometry functions in the `@Lie` macro.

This constant stores a Symbol indicating which module should be used when the `@Lie` macro
expands Lie bracket `[X, Y]` and Poisson bracket `{H, G}` expressions. By default, it points
to `:CTFlows`, but can be changed via [`diffgeo_prefix!`](@ref) to support custom modules.

# Example

```julia-repl
julia> using CTFlows

julia> CTFlows.diffgeo_prefix()
:CTFlows

julia> CTFlows.diffgeo_prefix!(:MyModule)

julia> CTFlows.diffgeo_prefix()
:MyModule
```

See also: [`diffgeo_prefix`](@ref), [`diffgeo_prefix!`](@ref), [`@Lie`](@ref)
"""
const DIFFGEO_PREFIX = Ref(:CTFlows)

"""
$(TYPEDSIGNATURES)

Get the current differential geometry module prefix used by the `@Lie` macro.

# Returns

- `Symbol`: The current prefix (default: `:CTFlows`)

# Example

```julia-repl
julia> using CTFlows

julia> CTFlows.diffgeo_prefix()
:CTFlows
```

See also: [`diffgeo_prefix!`](@ref), [`@Lie`](@ref)
"""
diffgeo_prefix() = DIFFGEO_PREFIX[]

"""
$(TYPEDSIGNATURES)

Set the differential geometry module prefix for the `@Lie` macro.

This changes which module the `@Lie` macro will reference when expanding bracket expressions.
Useful when integrating with custom differential geometry implementations.

# Arguments

- `p::Symbol`: The new module prefix (e.g., `:MyCustomModule`)

# Example

```julia-repl
julia> using CTFlows

julia> CTFlows.diffgeo_prefix!(:MyModule)

julia> CTFlows.diffgeo_prefix()
:MyModule

julia> # Now @Lie macros will expand to MyModule.ad(...) instead of CTFlows.ad(...)

julia> CTFlows.diffgeo_prefix!(:CTFlows)  # Reset to default
```

See also: [`diffgeo_prefix`](@ref), [`@Lie`](@ref)
"""
function diffgeo_prefix!(p::Symbol)
    DIFFGEO_PREFIX[] = p
    return nothing
end

# ==============================================================================
# Unified ad() Function - Lie Derivative and Lie Bracket
# ==============================================================================

"""
$(TYPEDSIGNATURES)

Unified function for Lie derivative and Lie bracket using directional derivatives.

# Arguments
- `X::Function`: Vector field
- `foo::Function`: Either a scalar function (for Lie derivative) or vector field (for Lie bracket)
- `backend`: Automatic differentiation backend (default: `__backend()` = `AutoForwardDiff()`)
- `autonomous::Bool`: Whether functions are time-independent (default: `__autonomous()` = `true`)
- `variable::Bool`: Whether functions depend on extra variable (default: `__variable()` = `false`)

# Returns
- A function computing either:
  - Lie derivative `ad(X, f)(x) = ∇f(x)' * X(x)` if `foo` is scalar
  - Lie bracket `ad(X, Y)(x) = J_Y(x)*X(x) - J_X(x)*Y(x)` if `foo` is vector

# Mathematical Approach
Uses directional derivatives: `D_X foo(x) = d/dt [foo(x + t*X(x))]|_{t=0}`

# Examples
```julia-repl
julia> using CTFlows

# Lie derivative of a scalar function
julia> X(x) = [x[2], -x[1]]

julia> f(x) = x[1]^2 + x[2]^2

julia> Lf = CTFlows.ad(X, f)

julia> Lf([1.0, 2.0])
0.0

# Lie bracket of two vector fields
julia> Y(x) = [x[1], x[2]]

julia> Z = CTFlows.ad(X, Y)

julia> Z([1.0, 2.0])
2-element Vector{Float64}:
 -1.0
  2.0
```

See also: [`Lift`](@ref), [`Poisson`](@ref), [`@Lie`](@ref)
"""
function ad(
    X::Function,
    foo::Function;
    backend::AbstractADType=__backend(),
    autonomous::Bool=__autonomous(),
    variable::Bool=__variable(),
)
    TD = autonomous ? Autonomous : NonAutonomous
    VD = variable ? NonFixed : Fixed
    return ad(X, foo, TD, VD; backend=backend)
end

"""
$(TYPEDSIGNATURES)

Unified function for Lie derivative and Lie bracket with explicit type parameters.

This method accepts types directly for better performance through compile-time dispatch.

# Arguments
- `X::Function`: Vector field
- `foo::Function`: Either a scalar function (for Lie derivative) or vector field (for Lie bracket)
- `TD::Type{<:TimeDependence}`: Time dependence type (Autonomous or NonAutonomous)
- `VD::Type{<:VariableDependence}`: Variable dependence type (Fixed or NonFixed)
- `backend`: Automatic differentiation backend (default: `__backend()`)
"""
function ad(
    X::Function,
    foo::Function,
    ::Type{TD},
    ::Type{VD};
    backend::AbstractADType=__backend(),
) where {TD<:TimeDependence,VD<:VariableDependence}
    return _ad(X, foo, backend, TD, VD)
end

# ==============================================================================
# Internal ad() implementations with type dispatch
# ==============================================================================

"""
$(TYPEDSIGNATURES)

Internal implementation: Autonomous, Fixed (signature: x -> ...)
"""
function _ad(
    X::Function, foo::Function, backend, ::Type{Autonomous}, ::Type{Fixed}
)
    return function (x)
        X_x = X(x)
        g(t) = foo(x + t * X_x)
        dfoo = derivative(g, backend, 0.0)
        return _ad_result(X, foo, dfoo, x, X_x, backend)
    end
end

"""
$(TYPEDSIGNATURES)

Internal implementation: Autonomous, NonFixed (signature: (x, v) -> ...)
"""
function _ad(
    X::Function, foo::Function, backend, ::Type{Autonomous}, ::Type{NonFixed}
)
    return function (x, v)
        X_x = X(x, v)
        g(t) = foo(x + t * X_x, v)
        dfoo = derivative(g, backend, 0.0)
        return _ad_result(X, foo, dfoo, x, X_x, backend, v)
    end
end

"""
$(TYPEDSIGNATURES)

Internal implementation: NonAutonomous, Fixed (signature: (t, x) -> ...)
"""
function _ad(
    X::Function, foo::Function, backend, ::Type{NonAutonomous}, ::Type{Fixed}
)
    return function (t, x)
        X_x = X(t, x)
        g(s) = foo(t, x + s * X_x)
        dfoo = derivative(g, backend, 0.0)
        return _ad_result(X, foo, dfoo, x, X_x, backend, t)
    end
end

"""
$(TYPEDSIGNATURES)

Internal implementation: NonAutonomous, NonFixed (signature: (t, x, v) -> ...)
"""
function _ad(
    X::Function, foo::Function, backend, ::Type{NonAutonomous}, ::Type{NonFixed}
)
    return function (t, x, v)
        X_x = X(t, x, v)
        g(s) = foo(t, x + s * X_x, v)
        dfoo = derivative(g, backend, 0.0)
        return _ad_result(X, foo, dfoo, x, X_x, backend, t, v)
    end
end

# ==============================================================================
# Result computation dispatch (Lie derivative vs Lie bracket)
# ==============================================================================

"""
$(TYPEDSIGNATURES)

Compute result for Lie derivative (scalar case).
"""
function _ad_result(X::Function, foo::Function, dfoo::Number, x, X_x, backend, args...)
    return dfoo  # Already ∇f(x)' * X(x)
end

"""
$(TYPEDSIGNATURES)

Compute result for Lie bracket (vector case).
"""
function _ad_result(
    X::Function, foo::Function, dfoo::AbstractVector, x, X_x, backend, args...
)
    # dfoo = J_Y(x) * X(x)
    # Compute J_X(x) * Y(x) using directional derivative
    Y_x = foo(x, args...)
    h(t) = X(x + t * Y_x, args...)
    dX = derivative(h, backend, 0.0)

    return dfoo - dX  # J_Y(x)*X(x) - J_X(x)*Y(x)
end

# ==============================================================================
# Lift Function - Hamiltonian Lift (V3: returns pure Function)
# ==============================================================================

"""
$(TYPEDSIGNATURES)

Construct the Hamiltonian lift of a vector field (pure function).

# Arguments
- `f::Function`: Vector field function
- `autonomous::Bool`: Whether the function is autonomous (default: `__autonomous()` = `true`)
- `variable::Bool`: Whether the function depends on an additional variable (default: `__variable()` = `false`)

# Returns
- A callable function computing the Hamiltonian lift `H(x, p) = p' * f(x)`

# Examples
```julia-repl
julia> f(x) = [x[1]^2, x[2]^2]
julia> H = Lift(f)
julia> H([1.0, 2.0], [0.5, 0.5])  # Returns 2.5

julia> g(t, x) = [t*x[1], x[2]]
julia> H2 = Lift(g; autonomous=false)
julia> H2(1.0, [1.0, 2.0], [0.5, 0.5])  # Returns 1.5
```
"""
function Lift(f::Function; autonomous::Bool=__autonomous(), variable::Bool=__variable())
    TD = autonomous ? Autonomous : NonAutonomous
    VD = variable ? NonFixed : Fixed
    return Lift(f, TD, VD)
end

"""
$(TYPEDSIGNATURES)

Construct the Hamiltonian lift with explicit type parameters.

# Arguments
- `f::Function`: Vector field function
- `TD::Type{<:TimeDependence}`: Time dependence type
- `VD::Type{<:VariableDependence}`: Variable dependence type
"""
function Lift(
    f::Function,
    ::Type{TD},
    ::Type{VD},
) where {TD<:TimeDependence,VD<:VariableDependence}
    return _Lift(f, TD, VD)
end

# Internal implementations
_Lift(f::Function, ::Type{Autonomous}, ::Type{Fixed}) = (x, p) -> p' * f(x)
_Lift(f::Function, ::Type{Autonomous}, ::Type{NonFixed}) = (x, p, v) -> p' * f(x, v)
_Lift(f::Function, ::Type{NonAutonomous}, ::Type{Fixed}) = (t, x, p) -> p' * f(t, x)
_Lift(f::Function, ::Type{NonAutonomous}, ::Type{NonFixed}) =
    (t, x, p, v) -> p' * f(t, x, v)

# ==============================================================================
# Poisson Bracket (V3: works with pure Functions)
# ==============================================================================

"""
$(TYPEDSIGNATURES)

Poisson bracket of two Hamiltonian functions (pure functions).

# Arguments
- `H::Function`: First Hamiltonian function
- `G::Function`: Second Hamiltonian function
- `backend`: Automatic differentiation backend (default: `__backend()` = `AutoForwardDiff()`)
- `autonomous::Bool`: Whether functions are time-independent (default: `__autonomous()` = `true`)
- `variable::Bool`: Whether functions depend on extra variable (default: `__variable()` = `false`)

# Returns
- A function computing the Poisson bracket `{H, G}(x, p) = ∇ₚH'·∇ₓG - ∇ₓH'·∇ₚG`

# Examples
```julia-repl
julia> H(x, p) = x[1]^2 + p[1]^2
julia> G(x, p) = x[2]^2 + p[2]^2
julia> PB = Poisson(H, G)
julia> PB([1.0, 2.0], [0.5, 0.5])  # Returns Poisson bracket value
```
"""
function Poisson(
    H::Function,
    G::Function;
    backend::AbstractADType=__backend(),
    autonomous::Bool=__autonomous(),
    variable::Bool=__variable(),
)
    TD = autonomous ? Autonomous : NonAutonomous
    VD = variable ? NonFixed : Fixed
    return Poisson(H, G, TD, VD; backend=backend)
end

"""
$(TYPEDSIGNATURES)

Poisson bracket with explicit type parameters.

# Arguments
- `H::Function`: First Hamiltonian function
- `G::Function`: Second Hamiltonian function
- `TD::Type{<:TimeDependence}`: Time dependence type
- `VD::Type{<:VariableDependence}`: Variable dependence type
- `backend`: Automatic differentiation backend (default: `__backend()`)
"""
function Poisson(
    H::Function,
    G::Function,
    ::Type{TD},
    ::Type{VD};
    backend::AbstractADType=__backend(),
) where {TD<:TimeDependence,VD<:VariableDependence}
    return _Poisson(H, G, backend, TD, VD)
end

# Internal implementations
function _Poisson(H::Function, G::Function, backend, ::Type{Autonomous}, ::Type{Fixed})
    return function (x, p)
        grad_x_H = ctgradient(y -> H(y, p), backend, x)
        grad_p_H = ctgradient(q -> H(x, q), backend, p)
        grad_x_G = ctgradient(y -> G(y, p), backend, x)
        grad_p_G = ctgradient(q -> G(x, q), backend, p)
        return grad_p_H' * grad_x_G - grad_x_H' * grad_p_G
    end
end

function _Poisson(H::Function, G::Function, backend, ::Type{Autonomous}, ::Type{NonFixed})
    return function (x, p, v)
        grad_x_H = ctgradient(y -> H(y, p, v), backend, x)
        grad_p_H = ctgradient(q -> H(x, q, v), backend, p)
        grad_x_G = ctgradient(y -> G(y, p, v), backend, x)
        grad_p_G = ctgradient(q -> G(x, q, v), backend, p)
        return grad_p_H' * grad_x_G - grad_x_H' * grad_p_G
    end
end

function _Poisson(H::Function, G::Function, backend, ::Type{NonAutonomous}, ::Type{Fixed})
    return function (t, x, p)
        grad_x_H = ctgradient(y -> H(t, y, p), backend, x)
        grad_p_H = ctgradient(q -> H(t, x, q), backend, p)
        grad_x_G = ctgradient(y -> G(t, y, p), backend, x)
        grad_p_G = ctgradient(q -> G(t, x, q), backend, p)
        return grad_p_H' * grad_x_G - grad_x_H' * grad_p_G
    end
end

function _Poisson(H::Function, G::Function, backend, ::Type{NonAutonomous}, ::Type{NonFixed})
    return function (t, x, p, v)
        grad_x_H = ctgradient(y -> H(t, y, p, v), backend, x)
        grad_p_H = ctgradient(q -> H(t, x, q, v), backend, p)
        grad_x_G = ctgradient(y -> G(t, y, p, v), backend, x)
        grad_p_G = ctgradient(q -> G(t, x, q, v), backend, p)
        return grad_p_H' * grad_x_G - grad_x_H' * grad_p_G
    end
end

# ==============================================================================
# Time Derivative
# ==============================================================================

"""
$(TYPEDSIGNATURES)

Partial derivative with respect to time of a function.

# Example
```julia-repl
julia> ∂ₜ((t,x) -> t*x)(0,8)
8
```
"""
∂ₜ(f) = (t, args...) -> ctgradient(y -> f(y, args...), t)

# ==============================================================================
# @Lie Macro (V3: uses prefix system, no wrappers)
# ==============================================================================

"""
$(TYPEDSIGNATURES)

Macro for Lie brackets and Poisson brackets with mathematical notation.

Uses type dispatch for better performance - expands to typed method calls.

# Syntax
- `@Lie [X, Y]` - Lie bracket (expands to `CTFlows.ad(X, Y, Autonomous, Fixed)`)
- `@Lie {H, G}` - Poisson bracket (expands to `CTFlows.Poisson(H, G, Autonomous, Fixed)`)
- `@Lie {H, G} autonomous=false` - With options (expands to `CTFlows.Poisson(H, G, NonAutonomous, Fixed)`)

# Examples
```julia-repl
julia> X(x) = [x[2], -x[1]]
julia> Y(x) = [x[1], x[2]]
julia> Z = @Lie [X, Y]
julia> Z([1.0, 2.0])

julia> H(x, p) = x[1]^2 + p[1]^2
julia> G(x, p) = x[2]^2 + p[2]^2
julia> PB = @Lie {H, G}
julia> PB([1.0, 2.0], [0.5, 0.5])
```
"""
macro Lie(expr::Expr, args...)
    # Parse options - default values
    autonomous = __autonomous()
    variable = __variable()

    for arg in args
        if @capture(arg, autonomous = val_)
            autonomous = val
        elseif @capture(arg, variable = val_)
            variable = val
        end
    end

    # Convert Bool to Type at compile time
    TD = autonomous ? :Autonomous : :NonAutonomous
    VD = variable ? :NonFixed : :Fixed

    prefix = diffgeo_prefix()

    function fun(x)
        is_lie, is_poisson = @capture(x, [a_, b_]), @capture(x, {c_, d_})

        if is_lie
            # Lie bracket: @Lie [X, Y] -> CTFlows.ad(X, Y, CTFlows.Autonomous, CTFlows.Fixed)
            return :(
                $prefix.ad($a, $b, $prefix.$TD, $prefix.$VD)
            )
        elseif is_poisson
            # Poisson bracket: @Lie {H, G} -> CTFlows.Poisson(H, G, CTFlows.Autonomous, CTFlows.Fixed)
            return :(
                $prefix.Poisson($c, $d, $prefix.$TD, $prefix.$VD)
            )
        else
            return x
        end
    end

    return esc(postwalk(fun, expr))
end
