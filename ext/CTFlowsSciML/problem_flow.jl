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
    P <: SciMLBase.AbstractODEProblem,
    I <: Integrators.AbstractIntegrator
} <: AbstractFlow{Traits.NonAutonomous, Traits.NonFixed}
    prob::P
    integrator::I
end

Flows.system(f::SciMLProblemFlow) = nothing
Flows.integrator(f::SciMLProblemFlow) = f.integrator

# No-arg call: solve problem as-is with trajectory options
function (f::SciMLProblemFlow)(; unsafe = Common.__unsafe())
    opts = Integrators.build_options(f.integrator, nothing)
    sol = SciMLBase.solve(f.prob; opts...)
    _check_retcode(sol, unsafe)
    return SciMLIntegrationResult(sol)
end

# Remake call: modify initial condition, time span, and optionally parameter
function (f::SciMLProblemFlow)(
    t0::Real,
    x0,
    tf::Real;
    variable = Common.__variable(),
    unsafe = Common.__unsafe(),
)
    kw = (; u0 = x0, tspan = (t0, tf))
    if !(variable isa Common.NotProvided)
        kw = merge(kw, (; p = variable))
    end
    prob = SciMLBase.remake(f.prob; kw...)
    config = Configs.StatePointConfig(t0, x0, tf)
    opts = Integrators.build_options(f.integrator, config)
    sol = SciMLBase.solve(prob; opts...)
    _check_retcode(sol, unsafe)
    result = SciMLIntegrationResult(sol)
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
- `SciMLIntegrationResult`: The complete integration result with trajectory data.

# Example
```julia
prob = ODEProblem((du, u, p, t) -> du .= -p .* u, [1.0], (0.0, 1.0), 2.0)
flow = SciMLProblemFlow(prob, Integrators.SciML())

# Trajectory call: get full solution
sol = flow((0.0, 1.0), [1.0])
```
"""
function (f::SciMLProblemFlow)(
    tspan::Tuple{Real, Real},
    x0;
    variable = Common.__variable(),
    unsafe = Common.__unsafe(),
)
    kw = (; u0 = x0, tspan = tspan)
    if !(variable isa Common.NotProvided)
        kw = merge(kw, (; p = variable))
    end
    prob = SciMLBase.remake(f.prob; kw...)
    config = Configs.StateTrajectoryConfig(tspan, x0)
    opts = Integrators.build_options(f.integrator, config)
    sol = SciMLBase.solve(prob; opts...)
    _check_retcode(sol, unsafe)
    return SciMLIntegrationResult(sol)
end

function Base.show(io::IO, ::MIME"text/plain", f::SciMLProblemFlow)
    println(io, "SciMLProblemFlow")
    println(io, "  tspan: ", f.prob.tspan)
    println(io, "  u0: ", f.prob.u0)
    print(io, "  integrator: ")
    show(io, f.integrator)
    println(io)
    Flows._print_user_options(io, f.integrator)
end

function Base.show(io::IO, f::SciMLProblemFlow)
    print(io, "SciMLProblemFlow(tspan=", f.prob.tspan, ")")
end
