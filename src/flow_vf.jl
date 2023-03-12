# --------------------------------------------------------------------------------------------
# Flow of a vector field
function Flow(vf::VectorField; alg=__alg(), abstol=__abstol(), 
    reltol=__reltol(), saveat=__saveat(), kwargs_Flow...)

    function rhs!(dx::DState, x::State, λ, t::Time)
        dx[:] = isempty(λ) ? vf(t, x) : vf(t, x, λ...)
    end

    f = __Classical_Flow(alg, abstol, reltol, saveat; kwargs_Flow...)

    return CTFlow{DState, State, Time}(f, rhs!)

end
