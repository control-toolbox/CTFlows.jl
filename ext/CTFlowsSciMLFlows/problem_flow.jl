# =============================================================================
# SciMLProblemFlow
# =============================================================================

"""
$(TYPEDEF)

Concrete `AbstractFlow` wrapping a `SciMLBase.AbstractODEProblem` directly.

Unlike `StateFlow` which wraps an `AbstractSystem` and an `AbstractIntegrator`,
`SciMLProblemFlow` wraps a fully-assembled ODE problem. The `system` method returns
`nothing` because there is no CTFlows `AbstractSystem` to extract.

The flow supports three call modes:
- **No-arg call** `f(; unsafe)` — solves the problem as-is with trajectory options.
- **Point call** `f(t0, x0, tf; variable, unsafe)` — calls `SciMLBase.remake` first with point options, returns final state only.
- **Trajectory call** `f(tspan, x0; variable, unsafe)` — calls `SciMLBase.remake` first with trajectory options, returns complete solution.

# Type Parameters
- `P <: SciMLBase.AbstractODEProblem`: The wrapped ODE problem.
- `I <: Integrators.AbstractIntegrator`: The integrator strategy (typically `SciML`).

# Fields
- `prob::P`: The wrapped ODE problem (contains u0, tspan, p).
- `integrator::I`: The integrator strategy (provides options via `build_options`).

# Example
```julia
using SciMLBase, CTFlows

prob = ODEProblem((du, u, p, t) -> du .= -p .* u, [1.0], (0.0, 1.0), 2.0)
flow = SciMLProblemFlow(prob, Integrators.SciML())

# No-arg call: solve as-is
sol = flow(; unsafe=false)

# Point call: modify initial condition and time span, returns final state
xf = flow(0.5, [2.0], 2.0; variable=3.0, unsafe=false)

# Trajectory call: modify initial condition and time span, returns complete solution
sol = flow((0.5, 2.0), [2.0]; variable=3.0, unsafe=false)
```
"""
struct SciMLProblemFlow{
    P<:SciMLBase.AbstractODEProblem,I<:Integrators.AbstractIntegrator
} <: Flows.AbstractFlow{Traits.NonAutonomous,Traits.NonFixed,Traits.StateDynamics}
    prob::P
    integrator::I
end

Flows.system(f::SciMLProblemFlow) = nothing
Flows.integrator(f::SciMLProblemFlow) = f.integrator

"""
$(TYPEDSIGNATURES)

No-arg call for `SciMLProblemFlow`: solve the problem as-is with trajectory options.

Uses the problem's original initial condition, time span, and parameter. Returns
the complete integration result with trajectory data.

# Arguments
- `f::SciMLProblemFlow`: The SciML problem flow to solve.
- `unsafe=Flows.__unsafe()`: If `true`, bypass ODE solver retcode checking; if `false`, throw `SolverFailure` on integration failure.

# Returns
- `AbstractIntegrationResult`: The complete integration result with trajectory data.

See also: [`CTFlowsSciMLFlows.SciMLProblemFlow`](@extref), [`CTFlows.Integrators.build_options`](@extref).
"""
function (f::SciMLProblemFlow)(; unsafe=Flows.__unsafe())
    opts = Integrators.build_options(f.integrator, nothing)
    return CommonSolve.solve(f.prob, f.integrator; options=opts, unsafe)
end

"""
$(TYPEDSIGNATURES)

Point call for `SciMLProblemFlow`: modify initial condition and time span, return final state.

Calls `SciMLBase.remake` to modify the problem with new initial condition and time span,
then solves with point configuration options (minimal memory usage). Returns only the
final state, not the full trajectory.

# Arguments
- `f::SciMLProblemFlow`: The SciML problem flow to solve.
- `t0::Real`: Initial time.
- `x0`: Initial state vector.
- `tf::Real`: Final time.
- `variable=Flows.__variable()`: The variable parameter value (optional, passed to remake).
- `unsafe=Flows.__unsafe()`: If `true`, bypass ODE solver retcode checking; if `false`, throw `SolverFailure` on integration failure.

# Returns
- The final state vector.

See also: [`CTFlowsSciMLFlows.SciMLProblemFlow`](@extref), [`CTFlows.Configs.StateEndPointConfig`](@extref).
"""
function (f::SciMLProblemFlow)(
    t0::Real, x0, tf::Real; variable=Flows.__variable(), unsafe=Flows.__unsafe()
)
    kw = (; u0=x0, tspan=(t0, tf))
    if !(variable isa Core.NotProvidedType)
        kw = merge(kw, (; p=variable))
    end
    prob = SciMLBase.remake(f.prob; kw...)
    config = Configs.StateEndPointConfig(t0, x0, tf)
    opts = Integrators.build_options(f.integrator, config)
    result = CommonSolve.solve(prob, f.integrator; options=opts, unsafe)
    return Integrators.final_state(result)
end

"""
$(TYPEDSIGNATURES)

Convenience call for `SciMLProblemFlow` with trajectory configuration.

Builds a `StateTrajectoryConfig` internally and returns the complete solution.

# Arguments
- `f::SciMLProblemFlow`: The SciML problem flow to solve.
- `tspan::Configs.TimeSpec`: Time span `(t0, tf)`, or an output grid `(t0, t1, …, tf)` (see [`CTFlows.Configs.TimeSpec`](@extref)).
- `x0`: Initial state vector.
- `variable`: The variable parameter value (optional, passed to remake).
- `unsafe`: If `true`, bypass ODE solver retcode checking; if `false`, throw `SolverFailure` on integration failure.
- `grid`: Generated output grid from the span: an integer `n`, `UniformGrid(n)` or `AdaptiveGrid(n)` (see [`CTFlows.Configs.AbstractGrid`](@extref)). Default `nothing`: unlike the other flows, a `SciMLProblemFlow` applies no default grid and exposes the raw SciML output (the problem's own `saveat`, or the solver steps).

# Returns
- `AbstractIntegrationResult`: The complete integration result with trajectory data.

# Example
```julia
prob = ODEProblem((du, u, p, t) -> du .= -p .* u, [1.0], (0.0, 1.0), 2.0)
flow = SciMLProblemFlow(prob, Integrators.SciML())

# Trajectory call: get full solution
sol = flow((0.0, 1.0), [1.0])
```
"""
function (f::SciMLProblemFlow)(
    tspan::Configs.TimeSpec,
    x0;
    variable=Flows.__variable(),
    unsafe=Flows.__unsafe(),
    grid=nothing,
)
    config = Configs.StateTrajectoryConfig(tspan, x0; grid=grid)
    _check_problem_saveat(f.prob, config)
    Flows._check_output_grid(f, config)
    kw = (; u0=x0, tspan=Configs.tspan(config))
    if !(variable isa Core.NotProvidedType)
        kw = merge(kw, (; p=variable))
    end
    prob = SciMLBase.remake(f.prob; kw...)
    opts = Integrators.build_options(f.integrator, config)
    result = CommonSolve.solve(prob, f.integrator; options=opts, unsafe)
    curve = Trajectories._plotted_curve(t -> Integrators.evaluate_at(result, t))
    bounds = collect(Configs.tspan(config))
    return Trajectories.apply_generated_grid(result, Configs.output_grid(config), curve, bounds)
end

"""
$(TYPEDSIGNATURES)

Reject an output grid given at the call when the wrapped problem stores its own `saveat`.

# Throws
- `CTBase.Exceptions.IncorrectArgument`: If a grid is given and `prob.kwargs` has `saveat`.
"""
function _check_problem_saveat(prob, config)
    Configs.output_grid(config) === nothing && return nothing
    if hasproperty(prob, :kwargs) && haskey(prob.kwargs, :saveat)
        throw(
            Exceptions.IncorrectArgument(
                "Two output grids given: `saveat` in the ODE problem and a grid at the call";
                got="saveat in the problem's keyword arguments, and a grid at the call",
                expected="a single output grid",
                suggestion="Remove `saveat` from the problem, or call the flow with the time span (t0, tf) only.",
                context="SciMLProblemFlow trajectory call",
            ),
        )
    end
    return nothing
end

function Base.show(io::IO, ::MIME"text/plain", f::SciMLProblemFlow)
    fmt = Display.format_codes(io)
    Display.print_header(io, "SciMLProblemFlow"; fmt=fmt)
    Display.print_field(io, "tspan", f.prob.tspan; fmt=fmt)
    Display.print_field(io, "u0", f.prob.u0; fmt=fmt)
    # Nest the integrator's own (styled, multi-line) text/plain display under the last branch.
    int_str = chomp(
        sprint(
            show,
            MIME("text/plain"),
            f.integrator;
            context=IOContext(io, :color => get(io, :color, false)),
        ),
    )
    return Display.print_field(
        io, "integrator", int_str; last=true, fmt=fmt, value_style=""
    )
end

"""
$(TYPEDSIGNATURES)

Display a compact representation of a `SciMLProblemFlow`.

Shows the time span, initial condition, and integrator information.

# Arguments
- `io::IO`: The IO stream to write to.
- `f::SciMLProblemFlow`: The SciML problem flow to display.

See also: [`CTFlowsSciMLFlows.SciMLProblemFlow`](@extref).
"""
function Base.show(io::IO, f::SciMLProblemFlow)
    fmt = Display.format_codes(io)
    return print(io, fmt.name, "SciMLProblemFlow", fmt.reset, "(tspan=", f.prob.tspan, ")")
end
