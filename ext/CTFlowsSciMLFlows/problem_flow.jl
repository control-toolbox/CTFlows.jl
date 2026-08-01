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
- `tspan::Tuple{Real, Real}`: Time span as a tuple (t0, tf).
- `x0`: Initial state vector.
- `variable`: The variable parameter value (optional, passed to remake).
- `unsafe`: If `true`, bypass ODE solver retcode checking; if `false`, throw `SolverFailure` on integration failure.

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
    tspan::Tuple{Real,Real}, x0; variable=Flows.__variable(), unsafe=Flows.__unsafe()
)
    kw = (; u0=x0, tspan=tspan)
    if !(variable isa Core.NotProvidedType)
        kw = merge(kw, (; p=variable))
    end
    prob = SciMLBase.remake(f.prob; kw...)
    config = Configs.StateTrajectoryConfig(tspan, x0)
    opts = Integrators.build_options(f.integrator, config)
    return CommonSolve.solve(prob, f.integrator; options=opts, unsafe)
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
