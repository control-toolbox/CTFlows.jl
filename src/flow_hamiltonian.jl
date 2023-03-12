# --------------------------------------------------------------------------------------------
# Flow from a Hamiltonian
function Flow(h::Hamiltonian; alg=__alg(), abstol=__abstol(), 
    reltol=__reltol(), saveat=__saveat(), kwargs_Flow...)

    function rhs!(dz::DCoTangent, z::CoTangent, λ, t::Time)
        n = size(z, 1) ÷ 2
        foo = isempty(λ) ? (z -> h(t, z[1:n], z[n+1:2*n])) : (z -> h(t, z[1:n], z[n+1:2*n], λ...))
        dh = ctgradient(foo, z)
        dz[1:n] = dh[n+1:2n]
        dz[n+1:2n] = -dh[1:n]
    end

    f = __Hamiltonian_Flow(alg, abstol, reltol, saveat; kwargs_Flow...)

    return CTFlow{DCoTangent, CoTangent, Time}(f, rhs!)

end

