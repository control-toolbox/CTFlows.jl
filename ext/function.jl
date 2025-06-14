"""
$(TYPEDSIGNATURES)

Builds a solver function for general ODE problems using `OrdinaryDiffEq.solve`.

This utility constructs a reusable solver function that:
- handles optional parameters and control variables,
- integrates with event-based `CallbackSet` mechanisms (including jumps),
- supports both full solutions and one-step propagation,
- merges solver-specific and global keyword arguments.

# Returns
A function `f` that can be called in two ways:
- `f(tspan, x0, v=nothing; kwargs...)` returns the full `ODESolution`.
- `f(t0, x0, tf, v=nothing; kwargs...)` returns only the final state `x(tf)`.

# Arguments
- `alg`: The numerical integration algorithm (e.g., `Tsit5()`).
- `abstol`: Absolute tolerance for the solver.
- `reltol`: Relative tolerance for the solver.
- `saveat`: Optional time steps for solution saving.
- `internalnorm`: Norm function used internally for error control.
- `kwargs_Flow`: Keyword arguments propagated to the solver (unless overridden).

# Example
```julia-repl
julia> f = ode_usage(Tsit5(), 1e-6, 1e-6, 0.1, InternalNorm())
julia> sol = f((0.0, 1.0), [1.0, 0.0], [0.0]; jumps=[], _t_stops_interne=[], DiffEqRHS=my_rhs)
```
"""
function ode_usage(alg, abstol, reltol, saveat, internalnorm; kwargs_Flow...)

    # kwargs has priority wrt kwargs_flow
    function f(
        tspan::Tuple{Time,Time},
        x0,
        v=nothing;
        jumps,
        _t_stops_interne,
        DiffEqRHS,
        tstops=__tstops(),
        callback=__callback(),
        kwargs...,
    )

        # ode
        ode = if isnothing(v)
            OrdinaryDiffEq.ODEProblem(DiffEqRHS, x0, tspan)
        else
            OrdinaryDiffEq.ODEProblem(DiffEqRHS, x0, tspan, v)
        end

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

    function f(t0::Time, x0, tf::Time, v=nothing; kwargs...)
        sol = f((t0, tf), x0, v; kwargs...)
        return sol.u[end]
    end

    return f
end

# --------------------------------------------------------------------------------------------
"""
$(TYPEDSIGNATURES)

Constructs a `Flow` from a user-defined dynamical system given as a Julia function.

This high-level interface handles:
- autonomous and non-autonomous systems,
- presence or absence of additional variables (`v`),
- selection of ODE solvers and tolerances,
- and integrates with the CTFlows event system (e.g., jumps, callbacks).

# Arguments
- `dyn`: A function defining the vector field. Its signature must match the values of `autonomous` and `variable`.
- `autonomous`: Whether the dynamics are time-independent (`false` by default).
- `variable`: Whether the dynamics depend on a control or parameter `v`.
- `alg`, `abstol`, `reltol`, `saveat`, `internalnorm`: Solver settings passed to `OrdinaryDiffEq.solve`.
- `kwargs_Flow`: Additional keyword arguments passed to the solver.

# Returns
An `ODEFlow` object, wrapping both the full solver and its right-hand side (RHS).

# Supported Function Signatures for `dyn`
Depending on the `(autonomous, variable)` flags:
- `(false, false)`: `dyn(x)`
- `(false, true)`:  `dyn(x, v)`
- `(true, false)`:  `dyn(t, x)`
- `(true, true)`:   `dyn(t, x, v)`

# Example
```julia-repl
julia> dyn(t, x, v) = [-x[1] + v[1] * sin(t)]
julia> flow = CTFlows.Flow(dyn; autonomous=true, variable=true)
julia> xT = flow((0.0, 1.0), [1.0], [0.1])
```
"""
function CTFlows.Flow(
    dyn::Function;
    autonomous=__autonomous(),
    variable=__variable(),
    alg=__alg(),
    abstol=__abstol(),
    reltol=__reltol(),
    saveat=__saveat(),
    internalnorm=__internalnorm(),
    kwargs_Flow...,
)
    #
    f = ode_usage(alg, abstol, reltol, saveat, internalnorm; kwargs_Flow...)
    rhs = @match (!autonomous, variable) begin
        (true, true) => ((x, v, t::Time) -> dyn(t, x, v))
        (true, false) => ((x, v, t::Time) -> dyn(t, x))
        (false, true) => ((x, v, t::Time) -> dyn(x, v))
        (false, false) => ((x, v, t::Time) -> dyn(x))
    end
    #
    return ODEFlow(f, rhs)
end
