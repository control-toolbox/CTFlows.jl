# ---------------------------------------------------------------------------------------------------
"""
$(TYPEDSIGNATURES)

Flow from an optimal control problem and a control function in feedback form.

# Example
```jldoctest
julia> f = Flow(ocp, (x, p) -> p)
```

!!! warning

    The time dependence of the control function must be consistent with the time dependence of the optimal control problem.
    The dimension of the output of the control function must be consistent with the dimension usage of the control of the optimal control problem.
"""
function CTFlows.Flow(
    ocp::OptimalControlModel{T,V},
    u_::Union{Function,ControlLaw{<:Function,T,V}};
    alg=__alg(),
    abstol=__abstol(),
    reltol=__reltol(),
    saveat=__saveat(),
    kwargs_Flow...,
) where {T,V}
    h, u = __create_hamiltonian(ocp, u_) # construction of the Hamiltonian
    return __ocp_Flow(ocp, h, u, alg, abstol, reltol, saveat; kwargs_Flow...)
end

# ---------------------------------------------------------------------------------------------------
"""
$(TYPEDSIGNATURES)

Flow from an optimal control problem, a control function in feedback form, a state constraint and its 
associated multiplier in feedback form.

# Example
```jldoctest
julia> ocp = Model(autonomous=false)
julia> f = Flow(ocp, (t, x, p) -> p[1], (t, x, u) -> x[1] - 1, (t, x, p) -> x[1]+p[1])
```

!!! warning

    The time dependence of the control function must be consistent with the time dependence of the optimal control problem.
    The dimension of the output of the control function must be consistent with the dimension usage of the control of the optimal control problem.
"""
function CTFlows.Flow(
    ocp::OptimalControlModel{T,V},
    u_::Union{Function,ControlLaw{<:Function,T,V},FeedbackControl{<:Function,T,V}},
    g_::Union{Function,MixedConstraint{<:Function,T,V},StateConstraint{<:Function,T,V}},
    μ_::Union{Function,Multiplier{<:Function,T,V}};
    alg=__alg(),
    abstol=__abstol(),
    reltol=__reltol(),
    saveat=__saveat(),
    kwargs_Flow...,
) where {T,V}
    h, u = __create_hamiltonian(ocp, u_, g_, μ_) # construction of the Hamiltonian
    return __ocp_Flow(ocp, h, u, alg, abstol, reltol, saveat; kwargs_Flow...)
end

# ---------------------------------------------------------------------------------------------------
function __ocp_Flow(
    ocp::OptimalControlModel{T,V},
    h::Hamiltonian,
    u::ControlLaw,
    alg,
    abstol,
    reltol,
    saveat;
    kwargs_Flow...,
) where {T,V}
    rhs! = rhs(h) # right and side: same as for a flow from a Hamiltonian
    f = hamiltonian_usage(alg, abstol, reltol, saveat; kwargs_Flow...) # flow function
    kwargs_Flow = (kwargs_Flow..., alg=alg, abstol=abstol, reltol=reltol, saveat=saveat)
    return OptimalControlFlow(f, rhs!, u, ocp, kwargs_Flow)
end
