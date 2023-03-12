# concatenate two flows with a prescribed switching time
function concatenate(F::CTFlow{D, U, T}, g::Tuple{MyNumber, CTFlow{D, U, T}}) where {D, U, T}
    #
    t_switch, G = g
    function rhs!(du::D, u::U, p, t::T)
        t < t_switch ? F.rhs!(du, u, p, t) : G.rhs!(du, u, p, t)
    end
    #
    tstops = F.tstops
    append!(tstops, G.tstops)
    append!(tstops, t_switch)
    tstops = unique(sort(tstops))
    # on choisit le f de F, c-a-d que l'on considère les options de F
    return CTFlow{D, U, T}(F.f, rhs!, tstops)
end

*(F::CTFlow{D, U, T}, g::Tuple{MyNumber, CTFlow{D, U, T}}) where {D, U, T} = concatenate(F, g)
