# --------------------------------------------------------------------------------------------
# Flow from a Hamiltonian Vector Field
function Flow(hv::HamiltonianVectorField; alg=__alg(), abstol=__abstol(), 
    reltol=__reltol(), saveat=__saveat(), kwargs_Flow...)

    function rhs!(dz::DCoTangent, z::CoTangent, λ, t::Time)
        n = size(z, 1) ÷ 2
        dz[:] = isempty(λ) ? hv(t, z[1:n], z[n+1:2*n]) : hv(t, z[1:n], z[n+1:2*n], λ...)
    end

    f = __Hamiltonian_Flow(alg, abstol, reltol, saveat; kwargs_Flow...)

    return CTFlow{DCoTangent, CoTangent, Time}(f, rhs!)

end;
