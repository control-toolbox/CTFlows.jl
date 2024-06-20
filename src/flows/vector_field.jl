# ---------------------------------------------------------------------------------------------------
# This is the flow returned by the function Flow
# The call to the flow is given after.
struct VectorFieldFlow <: AbstractFlow
    f::Function         # f(args..., rhs): compute the flow
    rhs!::Function      # OrdinaryDiffEq rhs
    function VectorFieldFlow(f, rhs!)
        return new(f, rhs!)
    end
end

# call F.f
(F::VectorFieldFlow)(args...; kwargs...) = begin
    F.f(args...; rhs=F.rhs!, kwargs...)
end