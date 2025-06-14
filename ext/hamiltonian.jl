"""
$(TYPEDSIGNATURES)

Constructs a solver function for Hamiltonian systems, with configurable solver options.

Returns a callable object that integrates Hamilton's equations from an initial state `(x0, p0)`
over a time span `tspan = (t0, tf)`, with optional external parameters.

The returned function has two methods:
- `f(tspan, x0, p0, v=default_variable; kwargs...)` → returns the full trajectory (solution object).
- `f(t0, x0, p0, tf, v=default_variable; kwargs...)` → returns only the final `(x, p)` state.

Internally, it uses `OrdinaryDiffEq.solve` and supports events and callbacks.

# Arguments
- `alg`: integration algorithm (e.g. `Tsit5()`).
- `abstol`, `reltol`: absolute and relative tolerances.
- `saveat`: time points for saving.
- `internalnorm`: norm used for adaptive integration.
- `kwargs_Flow...`: additional keyword arguments for the solver.

# Example
```julia-repl
julia> flowfun = hamiltonian_usage(Tsit5(), 1e-8, 1e-8, 0.1, norm)
julia> xf, pf = flowfun(0.0, x0, p0, 1.0)
```
"""
function hamiltonian_usage(alg, abstol, reltol, saveat, internalnorm; kwargs_Flow...)
    function f(
        tspan::Tuple{Time,Time},
        x0::State,
        p0::Costate,
        v::Variable=__thevariable(x0, p0);
        jumps,
        _t_stops_interne,
        DiffEqRHS,
        tstops=__tstops(),
        callback=__callback(),
        kwargs...,
    )

        # ode
        ode = OrdinaryDiffEq.ODEProblem(DiffEqRHS, [x0; p0], tspan, v)

        # jumps and callbacks
        n = size(x0, 1)
        cb, t_stops_all = __callbacks(
            callback, jumps, rg(n + 1, 2n), _t_stops_interne, tstops
        )

        # solve
        sol = OrdinaryDiffEq.solve(
            ode;
            alg=alg,
            abstol=abstol,
            reltol=reltol,
            saveat=saveat,
            internalnorm=internalnorm,
            tstops=t_stops_all,
            callback=cb,
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
        v::Variable=__thevariable(x0, p0);
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

Constructs the right-hand side of Hamilton's equations from a scalar Hamiltonian function.

Given a Hamiltonian `h(t, x, p, l)` (or `h(x, p)` in the autonomous case), returns
an in-place function `rhs!(dz, z, v, t)` suitable for numerical integration.

This function computes the canonical Hamiltonian vector field using automatic differentiation:
```julia-repl
dz[1:n]     =  ∂H/∂p
dz[n+1:2n]  = -∂H/∂x
```

# Arguments
- `h`: a subtype of `CTFlows.AbstractHamiltonian` defining the scalar Hamiltonian.

# Returns
- `rhs!`: a function for use in an ODE solver.
"""
function rhs(h::CTFlows.AbstractHamiltonian)
    function rhs!(dz::DCoTangent, z::CoTangent, v::Variable, t::Time)
        n = size(z, 1) ÷ 2
        foo(z) = h(t, z[rg(1, n)], z[rg(n + 1, 2n)], v)
        dh = ctgradient(foo, z)
        dz[1:n] = dh[(n + 1):(2n)]
        return dz[(n + 1):(2n)] = -dh[1:n]
    end
    return rhs!
end

# --------------------------------------------------------------------------------------------
"""
$(TYPEDSIGNATURES)

Constructs a Hamiltonian flow from a scalar Hamiltonian.

This method builds a numerical integrator that simulates the evolution of a Hamiltonian system
given a Hamiltonian function `h(t, x, p, l)` or `h(x, p)`.

Internally, it computes the right-hand side of Hamilton’s equations via automatic differentiation
and returns a `HamiltonianFlow` object.

# Keyword Arguments
- `alg`, `abstol`, `reltol`, `saveat`, `internalnorm`: solver options.
- `kwargs_Flow...`: forwarded to the solver.

# Example
```julia-repl
julia> H(x, p) = dot(p, p) + dot(x, x)
julia> flow = CTFlows.Flow(CTFlows.Hamiltonian(H))
julia> xf, pf = flow(0.0, x0, p0, 1.0)
```
"""
function CTFlows.Flow(
    h::CTFlows.AbstractHamiltonian;
    alg=__alg(),
    abstol=__abstol(),
    reltol=__reltol(),
    saveat=__saveat(),
    internalnorm=__internalnorm(),
    kwargs_Flow...,
)
    #
    f = hamiltonian_usage(alg, abstol, reltol, saveat, internalnorm; kwargs_Flow...)
    rhs! = rhs(h)
    return HamiltonianFlow(f, rhs!)
end

# --------------------------------------------------------------------------------------------
"""
$(TYPEDSIGNATURES)

Constructs a Hamiltonian flow from a precomputed Hamiltonian vector field.

This method assumes you already provide the Hamiltonian vector field `(dx/dt, dp/dt)`
instead of deriving it from a scalar Hamiltonian.

Returns a `HamiltonianFlow` object that integrates the given system.

# Keyword Arguments
- `alg`, `abstol`, `reltol`, `saveat`, `internalnorm`: solver options.
- `kwargs_Flow...`: forwarded to the solver.

# Example
```julia-repl
julia> hv(t, x, p, l) = (∇ₚH, -∇ₓH)
julia> flow = CTFlows.Flow(CTFlows.HamiltonianVectorField(hv))
julia> xf, pf = flow(0.0, x0, p0, 1.0, l)
```
"""
function CTFlows.Flow(
    hv::CTFlows.HamiltonianVectorField;
    alg=__alg(),
    abstol=__abstol(),
    reltol=__reltol(),
    saveat=__saveat(),
    internalnorm=__internalnorm(),
    kwargs_Flow...,
)
    #
    f = hamiltonian_usage(alg, abstol, reltol, saveat, internalnorm; kwargs_Flow...)
    function rhs!(dz::DCoTangent, z::CoTangent, v::Variable, t::Time)
        n = size(z, 1) ÷ 2
        return dz[rg(1, n)], dz[rg(n + 1, 2n)] = hv(t, z[rg(1, n)], z[rg(n + 1, 2n)], v)
    end
    return HamiltonianFlow(f, rhs!)
end
