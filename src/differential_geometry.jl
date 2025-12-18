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
function ad(X::Function, foo::Function; backend=AutoForwardDiff(), autonomous::Bool=true, variable::Bool=false)
    if autonomous && !variable
        # Autonomous, no variable: (x) signature
        function L(x)
            X_x = X(x)
            g(t) = foo(x + t * X_x)
            dfoo = derivative(g, backend, 0.0)
            return _ad(X, foo, dfoo, x, X_x, backend)
        end
        return L
    elseif autonomous && variable
        # Autonomous with variable: (x, v) signature
        function L(x, v)
            X_x = X(x, v)
            g(t) = foo(x + t * X_x, v)
            dfoo = derivative(g, backend, 0.0)
            return _ad(X, foo, dfoo, x, X_x, backend, v)
        end
        return L
    elseif !autonomous && !variable
        # Non-autonomous, no variable: (t, x) signature
        function L(t, x)
            X_x = X(t, x)
            g(s) = foo(t, x + s * X_x)
            dfoo = derivative(g, backend, 0.0)
            return _ad(X, foo, dfoo, x, X_x, backend, t)
        end
        return L
    else
        # Non-autonomous with variable: (t, x, v) signature
        function L(t, x, v)
            X_x = X(t, x, v)
            g(s) = foo(t, x + s * X_x, v)
            dfoo = derivative(g, backend, 0.0)
            return _ad(X, foo, dfoo, x, X_x, backend, t, v)
        end
        return L
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
function _ad(X::Function, foo::Function, dfoo::AbstractVector, x, X_x, backend, args...)
    # dfoo = J_Y(x) * X(x)
    # Compute J_X(x) * Y(x) using directional derivative
    Y_x = foo(x, args...)
    h(t) = X(x + t * Y_x, args...)
    dX = derivative(h, backend, 0.0)
    
    return dfoo - dX  # J_Y(x)*X(x) - J_X(x)*Y(x)
end

# ==============================================================================
# Existing Functions
# ==============================================================================

"""
$(TYPEDSIGNATURES)

Construct the Hamiltonian lift of a `VectorField`.

# Arguments
- `X::VectorField`: The vector field to lift. Its signature determines if it is autonomous and/or variable.

# Returns
- A `HamiltonianLift` callable object representing the Hamiltonian lift of `X`.

# Examples
```julia-repl
julia> HL = Lift(VectorField(x -> [x[1]^2, x[2]^2], autonomous=true, variable=false))
julia> HL([1, 0], [0, 1])  # returns 0

julia> HL2 = Lift(VectorField((t, x, v) -> [t + x[1]^2, x[2]^2 + v], autonomous=false, variable=true))
julia> HL2(1, [1, 0], [0, 1], 1)  # returns 1

julia> H = Lift(x -> 2x)
julia> H(1, 1)  # returns 2

julia> H2 = Lift((t, x, v) -> 2x + t - v, autonomous=false, variable=true)
julia> H2(1, 1, 1, 1)  # returns 2

# Alternative syntax using symbols for autonomy and variability
julia> H3 = Lift((t, x, v) -> 2x + t - v, NonAutonomous, NonFixed)
julia> H3(1, 1, 1, 1)  # returns 2
```
"""
function Lift(X::VectorField)::HamiltonianLift
    return HamiltonianLift(X)
end

"""
$(TYPEDSIGNATURES)

Construct the Hamiltonian lift of a function.

# Arguments
- `X::Function`: The function representing the vector field.
- `autonomous::Bool=true`: Whether the function is autonomous (time-independent).
- `variable::Bool=false`: Whether the function depends on an additional variable argument.

# Returns
- A callable function computing the Hamiltonian lift, 
(and variants depending on `autonomous` and `variable`).

# Details
Depending on the `autonomous` and `variable` flags, the returned function has one of the following call signatures:
- `(x, p)` if `autonomous=true` and `variable=false`
- `(x, p, v)` if `autonomous=true` and `variable=true`
- `(t, x, p)` if `autonomous=false` and `variable=false`
- `(t, x, p, v)` if `autonomous=false` and `variable=true`

# Examples
```julia-repl
julia> H = Lift(x -> 2x)
julia> H(1, 1)  # returns 2

julia> H2 = Lift((t, x, v) -> 2x + t - v, autonomous=false, variable=true)
julia> H2(1, 1, 1, 1)  # returns 2
```
"""
function Lift(
    X::Function; autonomous::Bool=__autonomous(), variable::Bool=__variable()
)::Function
    return @match (autonomous, variable) begin
        (true, false) => (x, p) -> p' * X(x)
        (true, true) => (x, p, v) -> p' * X(x, v)
        (false, false) => (t, x, p) -> p' * X(t, x)
        _ => (t, x, p, v) -> p' * X(t, x, v)
    end
end

# ---------------------------------------------------------------------------
# Lie derivative of a scalar function along a vector field or a function: L_X(f) = X⋅f

# (postulate)
# (X⋅f)(x)    = f'(x)⋅X(x)
# (X⋅f)(t, x) = ∂ₓf(t, x)⋅X(t, x)
# (g⋅f)(x) = f'(x)⋅G(x) with G the vector of g
"""
Lie derivative of a scalar function along a vector field in the autonomous case.

Example:
```julia-repl
julia> φ = x -> [x[2], -x[1]]
julia> X = VectorField(φ)
julia> f = x -> x[1]^2 + x[2]^2
julia> (X⋅f)([1, 2])
0
```
"""
function ⋅(
    X::VectorField{<:Function,Autonomous,<:VariableDependence}, f::Function
)::Function
    return (x, args...) -> ctgradient(y -> f(y, args...), x)' * X(x, args...)
end

"""
Lie derivative of a scalar function along a vector field in the nonautonomous case.

Example:
```julia-repl
julia> φ = (t, x, v) -> [t + x[2] + v[1], -x[1] + v[2]]
julia> X = VectorField(φ, NonAutonomous, NonFixed)
julia> f = (t, x, v) -> t + x[1]^2 + x[2]^2
julia> (X⋅f)(1, [1, 2], [2, 1])
10
```
"""
function ⋅(
    X::VectorField{<:Function,NonAutonomous,<:VariableDependence}, f::Function
)::Function
    return (t, x, args...) -> ctgradient(y -> f(t, y, args...), x)' * X(t, x, args...)
end

"""
Lie derivative of a scalar function along a function (considered autonomous and non-variable).

Example:
```julia-repl
julia> φ = x -> [x[2], -x[1]]
julia> f = x -> x[1]^2 + x[2]^2
julia> (φ⋅f)([1, 2])
0
julia> φ = (t, x, v) -> [t + x[2] + v[1], -x[1] + v[2]]
julia> f = (t, x, v) -> t + x[1]^2 + x[2]^2
julia> (φ⋅f)(1, [1, 2], [2, 1])
MethodError
```
"""
function ⋅(X::Function, f::Function)::Function
    return ⋅(VectorField(X, Autonomous, Fixed), f)
end

"""
Lie derivative of a scalar function along a vector field.

Example:
```julia-repl
julia> φ = x -> [x[2], -x[1]]
julia> X = VectorField(φ)
julia> f = x -> x[1]^2 + x[2]^2
julia> Lie(X,f)([1, 2])
0
julia> φ = (t, x, v) -> [t + x[2] + v[1], -x[1] + v[2]]
julia> X = VectorField(φ, NonAutonomous, NonFixed)
julia> f = (t, x, v) -> t + x[1]^2 + x[2]^2
julia> Lie(X, f)(1, [1, 2], [2, 1])
10
```
"""
Lie(X::VectorField, f::Function)::Function = X ⋅ f

"""
Lie derivative of a scalar function along a function with specified dependencies.

Example:
```julia-repl
julia> φ = x -> [x[2], -x[1]]
julia> f = x -> x[1]^2 + x[2]^2
julia> Lie(φ,f)([1, 2])
0
julia> φ = (t, x, v) -> [t + x[2] + v[1], -x[1] + v[2]]
julia> f = (t, x, v) -> t + x[1]^2 + x[2]^2
julia> Lie(φ, f, autonomous=false, variable=true)(1, [1, 2], [2, 1])
10
```
"""
function Lie(
    X::Function, f::Function; autonomous::Bool=__autonomous(), variable::Bool=__variable()
)::Function
    return Lie(VectorField(X; autonomous=autonomous, variable=variable), f)
end

"""
Partial derivative with respect to time of a function.

Example:
```julia-repl
julia> ∂ₜ((t,x) -> t*x)(0,8)
8
```
"""
∂ₜ(f) = (t, args...) -> ctgradient(y -> f(y, args...), t)

"""
"Directional derivative" of a vector field in the autonomous case,
used internally for computing the Lie bracket.

Example:
```julia-repl
julia> X = VectorField(x -> [x[2], -x[1]])
julia> Y = VectorField(x -> [x[1], x[2]])
julia> (X ⅋ Y)([1, 2])
[2, -1]
```
"""
function ⅋(
    X::VectorField{<:Function,Autonomous,V}, Y::VectorField{<:Function,Autonomous,V}
)::VectorField{<:Function,Autonomous,V} where {V<:VariableDependence}
    return VectorField(
        (x, args...) -> if x isa ctNumber
            ctgradient(y -> Y(y, args...), x) * X(x, args...)
        else
            ctjacobian(y -> Y(y, args...), x) * X(x, args...)
        end, Autonomous, V
    )
end

"""
"Directional derivative" of a vector field in the nonautonomous case,
used internally for computing the Lie bracket.

Example:
```julia-repl
julia> X = VectorField((t, x, v) -> [t + v[1] + v[2] + x[2], -x[1]], NonFixed, NonAutonomous)
julia> Y = VectorField((t, x, v) ->  [v[1] + v[2] + x[1], x[2]], NonFixed, NonAutonomous)
julia> (X ⅋ Y)(1, [1, 2], [2, 3])
[8, -1]
```
"""
function ⅋(
    X::VectorField{<:Function,NonAutonomous,V}, Y::VectorField{<:Function,NonAutonomous,V}
)::VectorField{<:Function,NonAutonomous,V} where {V<:VariableDependence}
    return VectorField(
        (t, x, args...) -> if x isa ctNumber
            ctgradient(y -> Y(t, y, args...), x) * X(t, x, args...)
        else
            ctjacobian(y -> Y(t, y, args...), x) * X(t, x, args...)
        end,
        NonAutonomous,
        V,
    )
end

# ---------------------------------------------------------------------------
# Lie bracket of two vector fields: [X, Y] = Lie(X, Y)
# [X, Y]⋅f = (X∘Y - Y∘X)⋅f = (X⅋Y - Y⅋X)⋅f
"""
Lie bracket of two vector fields in the autonomous case.

Example:
```julia-repl
julia> f = x -> [x[2], 2x[1]]
julia> g = x -> [3x[2], -x[1]]
julia> X = VectorField(f)
julia> Y = VectorField(g)
julia> Lie(X, Y)([1, 2])
[7, -14]
```
"""
function Lie(
    X::VectorField{<:Function,Autonomous,V}, Y::VectorField{<:Function,Autonomous,V}
)::VectorField{<:Function,Autonomous,V} where {V<:VariableDependence}
    return VectorField(
        (x, args...) -> (X ⅋ Y)(x, args...) - (Y ⅋ X)(x, args...), Autonomous, V
    )
end

"""
Lie bracket of two vector fields in the nonautonomous case.

Example:
```julia-repl
julia> f = (t, x, v) -> [t + x[2] + v, -2x[1] - v]
julia> g = (t, x, v) -> [t + 3x[2] + v, -x[1] - v]
julia> X = VectorField(f, NonAutonomous, NonFixed)
julia> Y = VectorField(g, NonAutonomous, NonFixed)
julia> Lie(X, Y)(1, [1, 2], 1)
[-7, 12]
```
"""
function Lie(
    X::VectorField{<:Function,NonAutonomous,V}, Y::VectorField{<:Function,NonAutonomous,V}
)::VectorField{<:Function,NonAutonomous,V} where {V<:VariableDependence}
    return VectorField(
        (t, x, args...) -> (X ⅋ Y)(t, x, args...) - (Y ⅋ X)(t, x, args...), NonAutonomous, V
    )
end

# ---------------------------------------------------------------------------
# Poisson bracket of two Hamiltonian functions: {f, g} = Poisson(f, g)
# f(z) = p⋅X(x), g(z) = p⋅Y(x), z = (x, p) => {f,g}(z) = p⋅[X,Y](x) 
# {f, g}(z) = g'(z)⋅F(z), where F is the Hamiltonian vector field of f
# actually, z = (x, p)
"""
$(TYPEDSIGNATURES)

Poisson bracket of two Hamiltonian functions (subtype of AbstractHamiltonian). Autonomous case.

Returns a Hamiltonian representing the Poisson bracket `{f, g}` of two autonomous Hamiltonian functions `f` and `g`.

# Example
```julia-repl
julia> f = (x, p) -> x[2]^2 + 2x[1]^2 + p[1]^2
julia> g = (x, p) -> 3x[2]^2 - x[1]^2 + p[2]^2 + p[1]
julia> F = Hamiltonian(f)
julia> G = Hamiltonian(g)
julia> Poisson(f, g)([1, 2], [2, 1])     # -20
julia> Poisson(f, G)([1, 2], [2, 1])     # -20
julia> Poisson(F, g)([1, 2], [2, 1])     # -20
```
"""
function Poisson(
    f::AbstractHamiltonian{Autonomous,V}, g::AbstractHamiltonian{Autonomous,V}
)::Hamiltonian{<:Function,Autonomous,V} where {V<:VariableDependence}
    function fg(x, p, args...)
        n = size(x, 1)
        ff, gg = @match n begin
            1 => (z -> f(z[1], z[2], args...), z -> g(z[1], z[2], args...))
            _ => (
                z -> f(z[1:n], z[(n + 1):2n], args...),
                z -> g(z[1:n], z[(n + 1):2n], args...),
            )
        end
        df = ctgradient(ff, [x; p])
        dg = ctgradient(gg, [x; p])
        return df[(n + 1):2n]' * dg[1:n] - df[1:n]' * dg[(n + 1):2n]
    end
    return Hamiltonian(fg, Autonomous, V)
end

"""
$(TYPEDSIGNATURES)

Poisson bracket of two Hamiltonian functions. Non-autonomous case.

Returns a Hamiltonian representing `{f, g}` where `f` and `g` are time-dependent.

# Example
```julia-repl
julia> f = (t, x, p, v) -> t*v[1]*x[2]^2 + 2x[1]^2 + p[1]^2 + v[2]
julia> g = (t, x, p, v) -> 3x[2]^2 - x[1]^2 + p[2]^2 + p[1] + t - v[2]
julia> F = Hamiltonian(f, autonomous=false, variable=true)
julia> G = Hamiltonian(g, autonomous=false, variable=true)
julia> Poisson(F, G)(2, [1, 2], [2, 1], [4, 4])     # -76
julia> Poisson(f, g, NonAutonomous, NonFixed)(2, [1, 2], [2, 1], [4, 4])     # -76
```
"""
function Poisson(
    f::AbstractHamiltonian{NonAutonomous,V}, g::AbstractHamiltonian{NonAutonomous,V}
)::Hamiltonian{<:Function,NonAutonomous,V} where {V<:VariableDependence}
    function fg(t, x, p, args...)
        n = size(x, 1)
        ff, gg = @match n begin
            1 => (z -> f(t, z[1], z[2], args...), z -> g(t, z[1], z[2], args...))
            _ => (
                z -> f(t, z[1:n], z[(n + 1):2n], args...),
                z -> g(t, z[1:n], z[(n + 1):2n], args...),
            )
        end
        df = ctgradient(ff, [x; p])
        dg = ctgradient(gg, [x; p])
        return df[(n + 1):2n]' * dg[1:n] - df[1:n]' * dg[(n + 1):2n]
    end
    return Hamiltonian(fg, NonAutonomous, V)
end

"""
$(TYPEDSIGNATURES)

Poisson bracket of two HamiltonianLift vector fields.

Returns the HamiltonianLift corresponding to the Lie bracket of vector fields `f.X` and `g.X`.

# Example
```julia-repl
julia> f = x -> [x[1]^2 + x[2]^2, 2x[1]^2]
julia> g = x -> [3x[2]^2, x[2] - x[1]^2]
julia> F = Lift(f)
julia> G = Lift(g)
julia> Poisson(F, G)([1, 2], [2, 1])     # -64

julia> f = (t, x, v) -> [t*v[1]*x[2]^2, 2x[1]^2 + v[2]]
julia> g = (t, x, v) -> [3x[2]^2 - x[1]^2, t - v[2]]
julia> F = Lift(f, NonAutonomous, NonFixed)
julia> G = Lift(g, NonAutonomous, NonFixed)
julia> Poisson(F, G)(2, [1, 2], [2, 1], [4, 4])     # 100
```
"""
function Poisson(
    f::HamiltonianLift{T,V}, g::HamiltonianLift{T,V}
)::HamiltonianLift{<:VectorField,T,V} where {T<:TimeDependence,V<:VariableDependence}
    return HamiltonianLift(Lie(f.X, g.X))
end

"""
$(TYPEDSIGNATURES)

Poisson bracket of two functions. The time and variable dependence are specified with keyword arguments.

Returns a Hamiltonian computed from the functions promoted as Hamiltonians.

# Example
```julia-repl
julia> f = (x, p) -> x[2]^2 + 2x[1]^2 + p[1]^2
julia> g = (x, p) -> 3x[2]^2 - x[1]^2 + p[2]^2 + p[1]
julia> Poisson(f, g)([1, 2], [2, 1])     # -20

julia> f = (t, x, p, v) -> t*v[1]*x[2]^2 + 2x[1]^2 + p[1]^2 + v[2]
julia> g = (t, x, p, v) -> 3x[2]^2 - x[1]^2 + p[2]^2 + p[1] + t - v[2]
julia> Poisson(f, g, autonomous=false, variable=true)(2, [1, 2], [2, 1], [4, 4])     # -76
```
"""
function Poisson(
    f::Function, g::Function; autonomous::Bool=__autonomous(), variable::Bool=__variable()
)::Hamiltonian
    return Poisson(
        Hamiltonian(f; autonomous=autonomous, variable=variable),
        Hamiltonian(g; autonomous=autonomous, variable=variable),
    )
end

"""
$(TYPEDSIGNATURES)

Poisson bracket of a function and a Hamiltonian.

Returns a Hamiltonian representing `{f, g}` where `g` is already a Hamiltonian.

# Example
```julia-repl
julia> f = (x, p) -> x[2]^2 + 2x[1]^2 + p[1]^2
julia> g = (x, p) -> 3x[2]^2 - x[1]^2 + p[2]^2 + p[1]
julia> G = Hamiltonian(g)
julia> Poisson(f, G)([1, 2], [2, 1])     # -20

julia> f = (t, x, p, v) -> t*v[1]*x[2]^2 + 2x[1]^2 + p[1]^2 + v[2]
julia> g = (t, x, p, v) -> 3x[2]^2 - x[1]^2 + p[2]^2 + p[1] + t - v[2]
julia> G = Hamiltonian(g, autonomous=false, variable=true)
julia> Poisson(f, G)(2, [1, 2], [2, 1], [4, 4])     # -76
```
"""
function Poisson(
    f::Function, g::AbstractHamiltonian{TD,VD}
)::Hamiltonian where {TD<:TimeDependence,VD<:VariableDependence}
    return Poisson(Hamiltonian(f, TD, VD), g)
end

"""
$(TYPEDSIGNATURES)

Poisson bracket of a Hamiltonian and a function.

Returns a Hamiltonian representing `{f, g}` where `f` is already a Hamiltonian.

# Example
```julia-repl
julia> f = (x, p) -> x[2]^2 + 2x[1]^2 + p[1]^2
julia> g = (x, p) -> 3x[2]^2 - x[1]^2 + p[2]^2 + p[1]
julia> F = Hamiltonian(f)
julia> Poisson(F, g)([1, 2], [2, 1])     # -20

julia> f = (t, x, p, v) -> t*v[1]*x[2]^2 + 2x[1]^2 + p[1]^2 + v[2]
julia> g = (t, x, p, v) -> 3x[2]^2 - x[1]^2 + p[2]^2 + p[1] + t - v[2]
julia> F = Hamiltonian(f, autonomous=false, variable=true)
julia> Poisson(F, g)(2, [1, 2], [2, 1], [4, 4])     # -76
```
"""
function Poisson(
    f::AbstractHamiltonian{TD,VD}, g::Function
)::Hamiltonian where {TD<:TimeDependence,VD<:VariableDependence}
    return Poisson(f, Hamiltonian(g, TD, VD))
end

# ---------------------------------------------------------------------------
# Macros

# @Lie [X, Y], for Lie brackets
# @Lie {X, Y}, for Poisson brackets
"""
$(TYPEDSIGNATURES)

Compute Lie or Poisson brackets.

This macro provides a unified notation to define recursively nested Lie brackets (for vector fields) or Poisson brackets (for Hamiltonians).

### Syntax

- `@Lie [F, G]`: computes the Lie bracket `[F, G]` of two vector fields.
- `@Lie [[F, G], H]`: supports arbitrarily nested Lie brackets.
- `@Lie {H, K}`: computes the Poisson bracket `{H, K}` of two Hamiltonians.
- `@Lie {{H, K}, L}`: supports arbitrarily nested Poisson brackets.
- `@Lie expr autonomous = false`: specifies a non-autonomous system.
- `@Lie expr variable = true`: indicates presence of an auxiliary variable `v`.

Keyword-like arguments can be provided to control the evaluation context for Poisson brackets with raw functions:
- `autonomous = Bool`: whether the system is time-independent (default: `true`).
- `variable = Bool`: whether the system depends on an extra variable `v` (default: `false`).

### Bracket type detection

- Square brackets `[...]` denote Lie brackets between `VectorField` objects.
- Curly brackets `{...}` denote Poisson brackets between `Hamiltonian` objects or between raw functions.
- The macro automatically dispatches to `Lie` or `Poisson` depending on the input pattern.

### Return

A callable object representing the specified Lie or Poisson bracket expression. The returned function can be evaluated like any other vector field or Hamiltonian.

---

### Examples

#### ■ Lie brackets with `VectorField` (autonomous)
```julia-repl
julia> F1 = VectorField(x -> [0, -x[3], x[2]])
julia> F2 = VectorField(x -> [x[3], 0, -x[1]])
julia> L = @Lie [F1, F2]
julia> L([1.0, 2.0, 3.0])
3-element Vector{Float64}:
  2.0
 -1.0
  0.0
```

#### ■ Lie brackets with `VectorField` (non-autonomous, with auxiliary variable)
```julia-repl
julia> F1 = VectorField((t, x, v) -> [0, -x[3], x[2]]; autonomous=false, variable=true)
julia> F2 = VectorField((t, x, v) -> [x[3], 0, -x[1]]; autonomous=false, variable=true)
julia> L = @Lie [F1, F2]
julia> L(0.0, [1.0, 2.0, 3.0], 1.0)
3-element Vector{Float64}:
  2.0
 -1.0
  0.0
```

#### ■ Poisson brackets with `Hamiltonian` (autonomous)
```julia-repl
julia> H1 = Hamiltonian((x, p) -> x[1]^2 + p[2]^2)
julia> H2 = Hamiltonian((x, p) -> x[2]^2 + p[1]^2)
julia> P = @Lie {H1, H2}
julia> P([1.0, 1.0], [3.0, 2.0])
-4.0
```

#### ■ Poisson brackets with `Hamiltonian` (non-autonomous, with variable)
```julia-repl
julia> H1 = Hamiltonian((t, x, p, v) -> x[1]^2 + p[2]^2 + v; autonomous=false, variable=true)
julia> H2 = Hamiltonian((t, x, p, v) -> x[2]^2 + p[1]^2 + v; autonomous=false, variable=true)
julia> P = @Lie {H1, H2}
julia> P(1.0, [1.0, 3.0], [4.0, 2.0], 3.0)
8.0
```

#### ■ Poisson brackets from raw functions
```julia-repl
julia> H1 = (x, p) -> x[1]^2 + p[2]^2
julia> H2 = (x, p) -> x[2]^2 + p[1]^2
julia> P = @Lie {H1, H2}
julia> P([1.0, 1.0], [3.0, 2.0])
-4.0
```

#### ■ Poisson bracket with non-autonomous raw functions
```julia-repl
julia> H1 = (t, x, p) -> x[1]^2 + p[2]^2 + t
julia> H2 = (t, x, p) -> x[2]^2 + p[1]^2 + t
julia> P = @Lie {H1, H2} autonomous = false
julia> P(3.0, [1.0, 2.0], [4.0, 1.0])
-8.0
```

#### ■ Nested brackets
```julia-repl
julia> F = VectorField(x -> [-x[1], x[2], x[3]])
julia> G = VectorField(x -> [x[3], -x[2], 0])
julia> H = VectorField(x -> [0, 0, -x[1]])
julia> nested = @Lie [[F, G], H]
julia> nested([1.0, 2.0, 3.0])
3-element Vector{Float64}:
  2.0
  0.0
 -6.0
```

```julia-repl
julia> H1 = (x, p) -> x[2]*x[1]^2 + p[1]^2
julia> H2 = (x, p) -> x[1]*p[2]^2
julia> H3 = (x, p) -> x[1]*p[2] + x[2]*p[1]
julia> nested_poisson = @Lie {{H1, H2}, H3}
julia> nested_poisson([1.0, 2.0], [0.5, 1.0])
14.0
```

#### ■ Mixed expressions with arithmetic
```julia-repl
julia> F1 = VectorField(x -> [0, -x[3], x[2]])
julia> F2 = VectorField(x -> [x[3], 0, -x[1]])
julia> x = [1.0, 2.0, 3.0]
julia> @Lie [F1, F2](x) + 3 * [F1, F2](x)
3-element Vector{Float64}:
  8.0
 -4.0
  0.0
```

```julia-repl
julia> H1 = (x, p) -> x[1]^2
julia> H2 = (x, p) -> p[1]^2
julia> H3 = (x, p) -> x[1]*p[1]
julia> x = [1.0, 2.0, 3.0]
julia> p = [3.0, 2.0, 1.0]
julia> @Lie {H1, H2}(x, p) + 2 * {H2, H3}(x, p)
24.0
```
"""
macro Lie(expr::Expr, args...)
    autonomous = true
    variable = false

    # Parse keyword args
    for arg in args
        @match arg begin
            :(autonomous = $a) => (autonomous = a)
            :(variable = $a) => (variable = a)
            _ => throw(ArgumentError("Invalid argument: $arg"))
        end
    end

    # Check for mixed usage of Lie and Poisson brackets
    has_lie = Ref(false)
    has_poisson = Ref(false)

    function check_mixed_usage(x)
        function walker(e)
            if @capture(e, [_, _])
                has_lie[] = true
            elseif @capture(e, {_, _})
                has_poisson[] = true
            end
            return e
        end
        postwalk(walker, x)

        if has_lie[] && has_poisson[]
            throw(
                ArgumentError("Cannot mix Lie and Poisson brackets in the same expression.")
            )
        end
        return nothing
    end

    check_mixed_usage(expr)

    # Transform Lie and Poisson bracket expressions
    function fun(x)
        is_lie, is_poisson = @capture(x, [a_, b_]), @capture(x, {c_, d_})

        if is_lie
            # Just return Lie call with interpolation
            return :(Lie($a, $b))
        elseif is_poisson
            # Return a quoted block with if...else for runtime type checks
            return quote
                if isa($c, Function) && isa($d, Function)
                    Poisson(
                        Hamiltonian($c; autonomous=($(autonomous)), variable=($(variable))),
                        Hamiltonian($d; autonomous=($(autonomous)), variable=($(variable))),
                    )
                else
                    Poisson($c, $d)
                end
            end
        else
            return x
        end
    end

    return esc(postwalk(fun, expr))
end
