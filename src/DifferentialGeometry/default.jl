# Default AD backend sentinel — uses global DG_AD_BACKEND when not overridden
__dg_ad_backend()::Common.NotProvided = Common.NotProvided()

# Global default backend ref — built once at module load
const DG_AD_BACKEND = Ref{Differentiation.AbstractADBackend}(
    Differentiation.build_ad_backend()   # AutoForwardDiff via Common.__ad_backend()
)

"""
$(TYPEDSIGNATURES)

Return the current global automatic differentiation backend used by DifferentialGeometry operations.

The backend is used by [`CTFlows.DifferentialGeometry.ad`](@ref), [`CTFlows.DifferentialGeometry.Poisson`](@ref), and [`CTFlows.DifferentialGeometry.∂ₜ`](@ref) when no explicit
`ad_backend` keyword argument is provided.

# Returns
- `Differentiation.AbstractADBackend`: The current AD backend.

# Example
```julia
using CTFlows.DifferentialGeometry

backend = dg_ad_backend()
```

See also: [`CTFlows.DifferentialGeometry.dg_ad_backend!`](@ref), [`CTFlows.DifferentialGeometry.ad`](@ref), [`CTFlows.DifferentialGeometry.Poisson`](@ref), [`CTFlows.DifferentialGeometry.∂ₜ`](@ref)
"""
dg_ad_backend() = DG_AD_BACKEND[]

"""
$(TYPEDSIGNATURES)

Set the global automatic differentiation backend used by DifferentialGeometry operations.

This function rebuilds the backend from an ADTypes backend type. The new backend will be
used by [`CTFlows.DifferentialGeometry.ad`](@ref), [`CTFlows.DifferentialGeometry.Poisson`](@ref), and [`CTFlows.DifferentialGeometry.∂ₜ`](@ref) when no explicit `ad_backend`
keyword argument is provided.

# Arguments
- `ad_backend::ADTypes.AbstractADType`: The ADTypes backend type to use (e.g., `AutoForwardDiff()`).

# Returns
- `nothing`

# Example
```julia
using CTFlows.DifferentialGeometry
using ADTypes

dg_ad_backend!(AutoForwardDiff())
```

See also: [`CTFlows.DifferentialGeometry.dg_ad_backend`](@ref), [`CTFlows.DifferentialGeometry.ad`](@ref), [`CTFlows.DifferentialGeometry.Poisson`](@ref), [`CTFlows.DifferentialGeometry.∂ₜ`](@ref)
"""
function dg_ad_backend!(ad_backend::ADTypes.AbstractADType)
    DG_AD_BACKEND[] = Differentiation.build_ad_backend(; ad_backend = ad_backend)
    return nothing
end

# Resolution: NotProvided → global ref; ADTypes.AbstractADType → build fresh backend
"""
Resolve the AD backend from a keyword argument.

If `NotProvided`, returns the global backend. If an ADTypes backend,
builds a fresh backend from the ADType.

# Arguments
- `::Common.NotProvided`: Sentinel value indicating no backend specified.
- `ad_backend::ADTypes.AbstractADType`: ADTypes backend type to build.

# Returns
- `Differentiation.AbstractADBackend`: The resolved backend.
"""
_resolve_backend(::Common.NotProvided) = DG_AD_BACKEND[]
_resolve_backend(ad_backend::ADTypes.AbstractADType) = Differentiation.build_ad_backend(; ad_backend = ad_backend)
