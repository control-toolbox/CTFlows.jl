# Default AD backend sentinel — uses global DG_AD_BACKEND when not overridden
__dg_ad_backend()::Common.NotProvided = Common.NotProvided()

# Global default backend ref — built once at module load
const DG_AD_BACKEND = Ref{Differentiation.AbstractADBackend}(
    Differentiation.build_ad_backend()   # AutoForwardDiff via Common.__ad_backend()
)

# Getter
dg_ad_backend() = DG_AD_BACKEND[]

# Setter — rebuilds the backend from an ADTypes backend
function dg_ad_backend!(ad_backend::ADTypes.AbstractADType)
    DG_AD_BACKEND[] = Differentiation.build_ad_backend(; ad_backend = ad_backend)
    return nothing
end

# Resolution: NotProvided → global ref; ADTypes.AbstractADType → build fresh backend
_resolve_backend(::Common.NotProvided) = DG_AD_BACKEND[]
_resolve_backend(ad_backend::ADTypes.AbstractADType) = Differentiation.build_ad_backend(; ad_backend = ad_backend)
