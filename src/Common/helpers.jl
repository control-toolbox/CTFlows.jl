"""
    make_coerce(x) -> coerce_fn

Return a coercion function for the given shape.

For scalars (`Number`), returns `only` which extracts a single element from a 1-element vector.
For arrays (`AbstractVector`, `AbstractMatrix`), returns `identity` which is a no-op.

# Arguments
- `x`: A value whose type determines the coercion strategy.

# Returns
- `Function`: A coercion function with signature `(y) -> coerced_y`.

# Example
```julia-repl
julia> using CTFlows.Common

julia> coerce_scalar = make_coerce(1.0)
julia> coerce_scalar([5.0])
5.0

julia> coerce_vector = make_coerce([1.0, 2.0])
julia> coerce_vector([3.0, 4.0])
2-element Vector{Float64}:
 3.0
 4.0
```

See also: [`CTFlows.Systems.build_rhs`](@ref), [`CTFlows.Systems.build_oop_rhs`](@ref).
"""
make_coerce(::Number) = only
make_coerce(::AbstractVector) = identity
make_coerce(::AbstractMatrix) = identity