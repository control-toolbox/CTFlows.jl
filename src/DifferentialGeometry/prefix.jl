"""
Prefix reference for the CTFlows package used in `@Lie` macro generated code.

This `Ref` stores the symbol of the root package that the `@Lie` macro uses to
qualify generated function calls (e.g., `CTFlows.DifferentialGeometry._lie_mac`).
"""
const DIFFGEO_PREFIX = Ref{Symbol}(:CTFlows)

"""
$(TYPEDSIGNATURES)

Return the current package prefix used by the `@Lie` macro for qualified function calls.

The prefix is used to qualify generated function calls in macro expansion (e.g.,
`CTFlows.DifferentialGeometry._lie_mac`). This allows the macro to work correctly
when CTFlows is used as a dependency in other packages.

# Returns
- `Symbol`: The current package prefix (default: `:CTFlows`).

# Example
```julia
using CTFlows.DifferentialGeometry

prefix = diffgeo_prefix()  # Returns :CTFlows
```

See also: [`CTFlows.DifferentialGeometry.diffgeo_prefix!`](@ref), [`CTFlows.DifferentialGeometry.@Lie`](@ref)
"""
diffgeo_prefix()::Symbol = DIFFGEO_PREFIX[]

"""
$(TYPEDSIGNATURES)

Set the package prefix used by the `@Lie` macro for qualified function calls.

This function allows overriding the default prefix when CTFlows is used as a dependency
in other packages. The new prefix will be used in all subsequent `@Lie` macro expansions.

# Arguments
- `p::Symbol`: The new package prefix symbol.

# Returns
- `nothing`

# Example
```julia
using CTFlows.DifferentialGeometry

diffgeo_prefix!(:MyPackage)  # Set custom prefix
```

See also: [`CTFlows.DifferentialGeometry.diffgeo_prefix`](@ref), [`CTFlows.DifferentialGeometry.@Lie`](@ref)
"""
diffgeo_prefix!(p::Symbol) = (DIFFGEO_PREFIX[] = p; nothing)
