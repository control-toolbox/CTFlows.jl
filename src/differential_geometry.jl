# ==============================================================================
# CTFlows.jl - Differential Geometry Module (V3)
# ==============================================================================
# This file contains differential geometry tools for control theory.
# V3 refactoring: wrapper-free API using pure Functions

# ==============================================================================
# Prefix System for Differential Geometry Functions
# ==============================================================================

"""
Prefix reference for differential geometry functions.
Allows customization of which module provides ad, Poisson, etc.
"""
const DIFFGEO_PREFIX = Ref(:CTFlows)

"""
$(TYPEDSIGNATURES)

Get the current differential geometry prefix.
"""
diffgeo_prefix() = DIFFGEO_PREFIX[]

"""
$(TYPEDSIGNATURES)

Set the differential geometry prefix.
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
- `backend`: Automatic differentiation backend (default: `AutoForwardDiff()`)
- `autonomous::Bool`: Whether functions are time-independent (default: `true`)
- `variable::Bool`: Whether functions depend on extra variable (default: `false`)

# Returns
- A function computing either:
  - Lie derivative `ad(X, f)(x) = ∇f(x)' * X(x)` if `foo` is scalar
  - Lie bracket `ad(X, Y)(x) = J_Y(x)*X(x) - J_X(x)*Y(x)` if `foo` is vector

# Mathematical Approach
Uses directional derivatives: `D_X foo(x) = d/dt [foo(x + t*X(x))]|_{t=0}`

# Examples
```julia-repl
# Lie derivative
julia> X(x) = [x[2], -x[1]]
julia> f(x) = x[1]^2 + x[2]^2
julia> Lf = ad(X, f)
julia> Lf([1.0, 2.0])  # Returns 0.0

# Lie bracket
julia> Y(x) = [x[1], x[2]]
julia> Z = ad(X, Y)
julia> Z([1.0, 2.0])  # Returns vector
```
"""
function ad(
    X::Function,
    foo::Function;
    backend=AutoForwardDiff(),
    autonomous::Bool=__autonomous(),
    variable::Bool=__variable(),
)
    if autonomous && !variable
        # Autonomous, no variable: (x) signature
        return function (x)
            X_x = X(x)
            g(t) = foo(x + t * X_x)
            dfoo = derivative(g, backend, 0.0)
            return _ad(X, foo, dfoo, x, X_x, backend)
        end
    elseif autonomous && variable
        # Autonomous with variable: (x, v) signature
        return function (x, v)
            X_x = X(x, v)
            g(t) = foo(x + t * X_x, v)
            dfoo = derivative(g, backend, 0.0)
            return _ad(X, foo, dfoo, x, X_x, backend, v)
        end
    elseif !autonomous && !variable
        # Non-autonomous, no variable: (t, x) signature
        return function (t, x)
            X_x = X(t, x)
            g(s) = foo(t, x + s * X_x)
            dfoo = derivative(g, backend, 0.0)
            return _ad(X, foo, dfoo, x, X_x, backend, t)
        end
    else
        # Non-autonomous with variable: (t, x, v) signature
        return function (t, x, v)
            X_x = X(t, x, v)
            g(s) = foo(t, x + s * X_x, v)
            dfoo = derivative(g, backend, 0.0)
            return _ad(X, foo, dfoo, x, X_x, backend, t, v)
        end
    end
end

"""
$(TYPEDSIGNATURES)

Internal dispatch for Lie derivative (scalar case).
"""
function _ad(X::Function, foo::Function, dfoo::Number, x, X_x, backend, args...)
    return dfoo  # Already ∇f(x)' * X(x)
end

"""
$(TYPEDSIGNATURES)

Internal dispatch for Lie bracket (vector case).
"""
function _ad(
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
- `autonomous::Bool=true`: Whether the function is autonomous (time-independent)
- `variable::Bool=false`: Whether the function depends on an additional variable argument

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
    if autonomous && !variable
        return (x, p) -> p' * f(x)
    elseif autonomous && variable
        return (x, p, v) -> p' * f(x, v)
    elseif !autonomous && !variable
        return (t, x, p) -> p' * f(t, x)
    else
        return (t, x, p, v) -> p' * f(t, x, v)
    end
end

# ==============================================================================
# Poisson Bracket (V3: works with pure Functions)
# ==============================================================================

"""
$(TYPEDSIGNATURES)

Poisson bracket of two Hamiltonian functions (pure functions).

# Arguments
- `H::Function`: First Hamiltonian function
- `G::Function`: Second Hamiltonian function
- `autonomous::Bool=true`: Whether functions are time-independent
- `variable::Bool=false`: Whether functions depend on extra variable

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
    H::Function, G::Function; autonomous::Bool=__autonomous(), variable::Bool=__variable()
)
    if autonomous && !variable
        return function (x, p)
            # {H, G} = ∇ₚH'·∇ₓG - ∇ₓH'·∇ₚG
            grad_x_H = ctgradient(y -> H(y, p), x)
            grad_p_H = ctgradient(q -> H(x, q), p)
            grad_x_G = ctgradient(y -> G(y, p), x)
            grad_p_G = ctgradient(q -> G(x, q), p)
            return grad_p_H' * grad_x_G - grad_x_H' * grad_p_G
        end
    elseif autonomous && variable
        return function (x, p, v)
            grad_x_H = ctgradient(y -> H(y, p, v), x)
            grad_p_H = ctgradient(q -> H(x, q, v), p)
            grad_x_G = ctgradient(y -> G(y, p, v), x)
            grad_p_G = ctgradient(q -> G(x, q, v), p)
            return grad_p_H' * grad_x_G - grad_x_H' * grad_p_G
        end
    elseif !autonomous && !variable
        return function (t, x, p)
            grad_x_H = ctgradient(y -> H(t, y, p), x)
            grad_p_H = ctgradient(q -> H(t, x, q), p)
            grad_x_G = ctgradient(y -> G(t, y, p), x)
            grad_p_G = ctgradient(q -> G(t, x, q), p)
            return grad_p_H' * grad_x_G - grad_x_H' * grad_p_G
        end
    else
        return function (t, x, p, v)
            grad_x_H = ctgradient(y -> H(t, y, p, v), x)
            grad_p_H = ctgradient(q -> H(t, x, q, v), p)
            grad_x_G = ctgradient(y -> G(t, y, p, v), x)
            grad_p_G = ctgradient(q -> G(t, x, q, v), p)
            return grad_p_H' * grad_x_G - grad_x_H' * grad_p_G
        end
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

# Syntax
- `@Lie [X, Y]` - Lie bracket (expands to `CTFlows.ad(X, Y)`)
- `@Lie {H, G}` - Poisson bracket (expands to `CTFlows.Poisson(H, G)`)
- `@Lie {H, G} autonomous=false` - With options

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
    # Parse options
    autonomous = __autonomous()
    variable = __variable()

    for arg in args
        if @capture(arg, autonomous = val_)
            autonomous = val
        elseif @capture(arg, variable = val_)
            variable = val
        end
    end

    prefix = diffgeo_prefix()

    function fun(x)
        is_lie, is_poisson = @capture(x, [a_, b_]), @capture(x, {c_, d_})

        if is_lie
            # Lie bracket: @Lie [X, Y] -> CTFlows.ad(X, Y; autonomous=..., variable=...)
            return :(
                $prefix.ad(
                $a, $b; autonomous=$(autonomous), variable=$(variable)
            )
            )
        elseif is_poisson
            # Poisson bracket: @Lie {H, G} -> CTFlows.Poisson(H, G; autonomous=..., variable=...)
            return :(
                $prefix.Poisson(
                $c, $d; autonomous=$(autonomous), variable=$(variable)
            )
            )
        else
            return x
        end
    end

    return esc(postwalk(fun, expr))
end
