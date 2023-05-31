
#=
# --------------------------------------------------------------------------------------------
# Flow from a function: equivalent to flow from a Hamiltonian
"""
	Flow(f::Function, description...; kwargs_Flow...)

TBW
"""
function Flow(f::Function, autonomous::Bool=true; 
                alg=__alg(), abstol=__abstol(), 
                reltol=__reltol(), saveat=__saveat(), kwargs_Flow...)
    return Flow(Hamiltonian(f, autonomous=autonomous), alg=alg, abstol=abstol, 
        reltol=reltol, saveat=saveat, kwargs_Flow...)
end
=#