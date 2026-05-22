function scalarize(x::AbstractVector, ::Number) 
    @assert length(x) == 1
    return x[1]
end
scalarize(x, ::Any) = x