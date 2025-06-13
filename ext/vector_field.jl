"""
$(TYPEDSIGNATURES)

Returns a function that solves the ODE associated with a classical vector field.

This utility creates a flow integrator for systems of the form `dx/dt = f(t, x, v)`,
where `x` is the state and `v` is an external parameter. It supports integration over
a time span as well as direct queries for final state evaluation.

Two overloads are returned:
- `f(tspan, x0, v=default_variable; kwargs...)` returns the full solution trajectory.
- `f(t0, x0, tf, v=default_variable; kwargs...)` returns only the final state `x(tf)`.

Internally uses `OrdinaryDiffEq.solve`, with support for stopping times and jump discontinuities.

# Arguments
- `alg`: Integration algorithm (e.g. `Tsit5()`).
- `abstol`, `reltol`: Absolute and relative tolerances.
- `saveat`: Output time step or vector of times.
- `internalnorm`: Norm used for adaptive integration.
- `kwargs_Flow...`: Default solver options (overridden by explicit `kwargs` at call site).

# Example
```julia-repl
vf = (t, x, v) -> -v * x
flowfun = vector_field_usage(Tsit5(), 1e-8, 1e-8, 0.1, norm)
xf = flowfun(0.0, 1.0, 1.0, 2.0)
```
"""
function vector_field_usage(alg, abstol, reltol, saveat, internalnorm; kwargs_Flow...)

    # kwargs has priority wrt kwargs_flow
    function f(
        tspan::Tuple{Time,Time},
        x0::State,
        v::Variable=__thevariable(x0);
        jumps,
        _t_stops_interne,
        DiffEqRHS,
        tstops=__tstops(),
        callback=__callback(),
        kwargs...,
    )

        # ode
        ode = OrdinaryDiffEq.ODEProblem(DiffEqRHS, x0, tspan, v)

        # jumps and callbacks
        cb, t_stops_all = __callbacks(callback, jumps, nothing, _t_stops_interne, tstops)

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

    function f(t0::Time, x0::State, t::Time, v::Variable=__thevariable(x0); kwargs...)
        sol = f((t0, t), x0, v; kwargs...)
        return sol.u[end]
    end

    return f
end

# --------------------------------------------------------------------------------------------
"""
$(TYPEDSIGNATURES)

Constructs a flow object for a classical (non-Hamiltonian) vector field.

This creates a `VectorFieldFlow` that integrates the ODE system
`dx/dt = vf(t, x, v)` using DifferentialEquations.jl. It handles both fixed and
parametric dynamics, as well as jump discontinuities and event stopping.

# Keyword Arguments
- `alg`, `abstol`, `reltol`, `saveat`, `internalnorm`: Solver options.
- `kwargs_Flow...`: Additional arguments passed to the solver configuration.

# Example
```julia-repl
vf(t, x, v) = -v * x
flow = CTFlows.Flow(CTFlows.VectorField(vf))
x1 = flow(0.0, 1.0, 1.0)
```
"""
function CTFlows.Flow(
    vf::CTFlows.VectorField;
    alg=__alg(),
    abstol=__abstol(),
    reltol=__reltol(),
    saveat=__saveat(),
    internalnorm=__internalnorm(),
    kwargs_Flow...,
)
    f = vector_field_usage(alg, abstol, reltol, saveat, internalnorm; kwargs_Flow...)
    rhs = (x::State, v::Variable, t::Time) -> vf(t, x, v)
    return VectorFieldFlow(f, rhs)
end
