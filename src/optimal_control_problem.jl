"""
$(TYPEDSIGNATURES)

Constructs the Hamiltonian: 

H(t, x, p) = p f(t, x, u(t, x, p))
"""
function makeH(f::Dynamics, u::ControlLaw)
    return (t, x, p) -> p'*f(t, x, u(t, x, p))
end

"""
$(TYPEDSIGNATURES)

Constructs the Hamiltonian: 

H(t, x, p) = p ⋅ f(t, x, u(t, x, p)) + s p⁰ f⁰(t, x, u(t, x, p))
"""
function makeH(f::Dynamics, u::ControlLaw, f⁰::Lagrange, p⁰::ctNumber, s::ctNumber)
    function H(t, x, p)
        u_ = u(t, x, p)
        return p'*f(t, x, u_) + s*p⁰*f⁰(t, x, u_)
    end
    return H
end

"""
$(TYPEDSIGNATURES)

Constructs the Hamiltonian: 

H(t, x, p) = p ⋅ f(t, x, u(t, x, p)) + μ(t, x, p) ⋅ g(t, x, u(t, x, p))
"""
function makeH(f::Dynamics, u::ControlLaw, g::MixedConstraint, μ::Multiplier)
    function H(t, x, p)
        u_ = u(t, x, p)
        return p'*f(t, x, u_) + μ(t, x, p)'*g(t, x, u_)
    end
    return H
end

"""
$(TYPEDSIGNATURES)

Constructs the Hamiltonian: 

H(t, x, p) = p ⋅ f(t, x, u(t, x, p)) + s p⁰ f⁰(t, x, u(t, x, p)) + μ(t, x, p) ⋅ g(t, x, u(t, x, p))
"""
function makeH(f::Dynamics, u::ControlLaw, f⁰::Lagrange, p⁰::ctNumber, s::ctNumber, g::MixedConstraint, μ::Multiplier)
    function H(t, x, p)
        u_ = u(t, x, p)
        return p'*f(t, x, u_) + s*p⁰*f⁰(t, x, u_) + μ(t, x, p)'*g(t, x, u_)
    end
    return H
end

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
function Flow(ocp::OptimalControlModel{T, V}, u_::Function; alg=__alg(), abstol=__abstol(), 
    reltol=__reltol(), saveat=__saveat(), kwargs_Flow...) where {T, V}

    #  data
    p⁰ = -1.
    f  = ocp.dynamics
    f⁰ = ocp.lagrange
    s  = ismin(ocp) ? 1.0 : -1.0 #

    # construction of the Hamiltonian
    if f ≠ nothing
        u = ControlLaw(u_, T, V) # consistency is needed
        h = Hamiltonian(f⁰ ≠ nothing ? makeH(f, u, f⁰, p⁰, s) : makeH(f, u), NonAutonomous, V)
    else 
        error("no dynamics in ocp")
    end

    # right and side: same as for a flow from a Hamiltonian
    rhs! = rhs(h)

    # flow function
    f = hamiltonian_usage(alg, abstol, reltol, saveat; kwargs_Flow...)

    # construction of the OptimalControlFlow
    return OptimalControlFlow{DCoTangent, CoTangent, Time}(f, rhs!, u, ocp)

end

"""
$(TYPEDSIGNATURES)

Flow from an optimal control problem, a control function in feedback form, a state constraint and its 
associated multiplier in feedback form.

# Example
```jldoctest
julia> ocp = Model(time_dependence=:nonautonomous)
julia> f = Flow(ocp, (t, x, p) -> p[1], (t, x) -> x[1] - 1, (t, x, p) -> x[1]+p[1])
```

!!! warning

    The time dependence of the control function must be consistent with the time dependence of the optimal control problem.
    The dimension of the output of the control function must be consistent with the dimension usage of the control of the optimal control problem.
"""
function Flow(ocp::OptimalControlModel{T, V}, u_::Function, g_::Function, μ_::Function; alg=__alg(), abstol=__abstol(),
    reltol=__reltol(), saveat=__saveat(), kwargs_Flow...) where {T, V}
    
    # data
    p⁰ = -1.
    f  = ocp.dynamics
    f⁰ = ocp.lagrange
    s  = ismin(ocp) ? 1.0 : -1.0 #

    # construction of the Hamiltonian
    if f ≠ nothing
        u = ControlLaw(u_, T, V) # consistency is needed
        g = MixedConstraint(g_, T, V) # consistency is needed
        μ = Multiplier(μ_, T, V) # consistency is needed
        h = Hamiltonian(f⁰ ≠ nothing ? makeH(f, u, f⁰, p⁰, s, g, μ) : makeH(f, u, g, μ), NonAutonomous, V)
    else 
        error("no dynamics in ocp")
    end

    # right and side: same as for a flow from a Hamiltonian
    rhs! = rhs(h)

    # flow function
    f = hamiltonian_usage(alg, abstol, reltol, saveat; kwargs_Flow...)

    # construction of the OptimalControlFlow
    return OptimalControlFlow{DCoTangent, CoTangent, Time}(f, rhs!, u, ocp)

end