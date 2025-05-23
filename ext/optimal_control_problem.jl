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
    ocp::CTModels.Model,
    u_::CTFlows.ControlLaw;
    alg=__alg(),
    abstol=__abstol(),
    reltol=__reltol(),
    saveat=__saveat(),
    internalnorm=__internalnorm(),
    kwargs_Flow...,
)
    h, u = __create_hamiltonian(ocp, u_) # construction of the Hamiltonian
    return __ocp_Flow(ocp, h, u, alg, abstol, reltol, saveat, internalnorm; kwargs_Flow...)
end

function CTFlows.Flow(
    ocp::CTModels.Model,
    u_::Function;
    autonomous::Bool=__autonomous(),
    variable::Bool=__variable(ocp),
    alg=__alg(),
    abstol=__abstol(),
    reltol=__reltol(),
    saveat=__saveat(),
    internalnorm=__internalnorm(),
    kwargs_Flow...,
)
    h, u = __create_hamiltonian(ocp, u_; autonomous=autonomous, variable=variable) # construction of the Hamiltonian
    return __ocp_Flow(ocp, h, u, alg, abstol, reltol, saveat, internalnorm; kwargs_Flow...)
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
    ocp::CTModels.Model,
    u_::Union{CTFlows.ControlLaw{<:Function,T,V},CTFlows.FeedbackControl{<:Function,T,V}},
    g_::Union{CTFlows.MixedConstraint{<:Function,T,V},CTFlows.StateConstraint{<:Function,T,V}},
    μ_::Union{CTFlows.Multiplier{<:Function,T,V}};
    alg=__alg(),
    abstol=__abstol(),
    reltol=__reltol(),
    saveat=__saveat(),
    internalnorm=__internalnorm(),
    kwargs_Flow...,
) where {T,V}
    h, u = __create_hamiltonian(ocp, u_, g_, μ_) # construction of the Hamiltonian
    return __ocp_Flow(ocp, h, u, alg, abstol, reltol, saveat, internalnorm; kwargs_Flow...)
end

function CTFlows.Flow(
    ocp::CTModels.Model,
    u_::Function,
    g_::Function,
    μ_::Function;
    autonomous::Bool=__autonomous(),
    variable::Bool=__variable(ocp),
    alg=__alg(),
    abstol=__abstol(),
    reltol=__reltol(),
    saveat=__saveat(),
    internalnorm=__internalnorm(),
    kwargs_Flow...,
)
    h, u = __create_hamiltonian(ocp, u_, g_, μ_; autonomous=autonomous, variable=variable) # construction of the Hamiltonian
    return __ocp_Flow(ocp, h, u, alg, abstol, reltol, saveat, internalnorm; kwargs_Flow...)
end

# ---------------------------------------------------------------------------------------------------
function __ocp_Flow(
    ocp::CTModels.Model,
    h::CTFlows.Hamiltonian,
    u::CTFlows.ControlLaw,
    alg,
    abstol,
    reltol,
    saveat,
    internalnorm;
    kwargs_Flow...,
)
    rhs! = rhs(h) # right and side: same as for a flow from a Hamiltonian
    f = hamiltonian_usage(alg, abstol, reltol, saveat, internalnorm; kwargs_Flow...) # flow function
    kwargs_Flow = (kwargs_Flow..., alg=alg, abstol=abstol, reltol=reltol, saveat=saveat, internalnorm=internalnorm)
    return OptimalControlFlow(f, rhs!, u, ocp, kwargs_Flow)
end
