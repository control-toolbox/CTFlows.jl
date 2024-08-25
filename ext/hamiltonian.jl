
"""
$(TYPEDSIGNATURES)

Returns a function that solves ODE problem associated to Hamiltonian vector field.
"""
function hamiltonian_usage(alg, abstol, reltol, saveat; kwargs_Flow...)

    function f(
        tspan::Tuple{Time,Time},
        x0::State,
        p0::Costate,
        v::Variable = __variable(x0, p0);
        jumps,
        _t_stops_interne,
        DiffEqRHS,
        tstops = __tstops(),
        callback = __callback(),
        kwargs...,
    )

        # ode
        ode = OrdinaryDiffEq.ODEProblem(DiffEqRHS, [x0; p0], tspan, v)

        # jumps and callbacks
        n = size(x0, 1)
        cb, t_stops_all =
            __callbacks(callback, jumps, rg(n + 1, 2n), _t_stops_interne, tstops)

        # solve
        sol = OrdinaryDiffEq.solve(
            ode,
            alg = alg,
            abstol = abstol,
            reltol = reltol,
            saveat = saveat,
            tstops = t_stops_all,
            callback = cb;
            kwargs_Flow...,
            kwargs...,
        )

        return sol
    end

    function f(
        t0::Time,
        x0::State,
        p0::Costate,
        tf::Time,
        v::Variable = __variable(x0, p0);
        kwargs...,
    )
        sol = f((t0, tf), x0, p0, v; kwargs...)
        n = size(x0, 1)
        return sol[rg(1, n), end], sol[rg(n + 1, 2n), end]
    end

    return f

end

"""
$(TYPEDSIGNATURES)

The right and side from a Hamiltonian.
"""
function rhs(h::AbstractHamiltonian)
    function rhs!(dz::DCoTangent, z::CoTangent, v::Variable, t::Time)
        n = size(z, 1) ÷ 2
        foo(z) = h(t, z[rg(1, n)], z[rg(n + 1, 2n)], v)
        dh = ctgradient(foo, z)
        dz[1:n] = dh[n+1:2n]
        dz[n+1:2n] = -dh[1:n]
    end
    return rhs!
end

# --------------------------------------------------------------------------------------------
# Flow from a Hamiltonian
function CTFlows.Flow(
    h::AbstractHamiltonian;
    alg = __alg(),
    abstol = __abstol(),
    reltol = __reltol(),
    saveat = __saveat(),
    kwargs_Flow...,
)
    #
    f = hamiltonian_usage(alg, abstol, reltol, saveat; kwargs_Flow...)
    rhs! = rhs(h)
    return HamiltonianFlow(f, rhs!)
end

# --------------------------------------------------------------------------------------------
# Flow from a Hamiltonian Vector Field
function CTFlows.Flow(
    hv::HamiltonianVectorField;
    alg = __alg(),
    abstol = __abstol(),
    reltol = __reltol(),
    saveat = __saveat(),
    kwargs_Flow...,
)
    #
    f = hamiltonian_usage(alg, abstol, reltol, saveat; kwargs_Flow...)
    function rhs!(dz::DCoTangent, z::CoTangent, v::Variable, t::Time)
        n = size(z, 1) ÷ 2
        dz[rg(1, n)], dz[rg(n + 1, 2n)] = hv(t, z[rg(1, n)], z[rg(n + 1, 2n)], v)
    end
    return HamiltonianFlow(f, rhs!)
end
