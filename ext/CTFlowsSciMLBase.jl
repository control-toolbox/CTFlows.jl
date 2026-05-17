"""
    CTFlowsSciMLBase

Package extension providing SciML-native types integration for CTFlows.
Activated automatically when `SciMLBase` is loaded together with `CTFlows`.

This extension provides:
- `SciMLFunctionSystem` — wraps a `SciMLBase.AbstractODEFunction` as a CTFlows system
- `SciMLProblemFlow` — wraps a `SciMLBase.AbstractODEProblem` as a CTFlows flow
- High-level `Flow(::AbstractODEFunction; ...)` and `Flow(::AbstractODEProblem; ...)` constructors

The extension depends only on `SciMLBase`, not on `DiffEqBase`.
"""
module CTFlowsSciMLBase

import DocStringExtensions: TYPEDEF, TYPEDSIGNATURES
import CTBase.Exceptions
using CTFlows: CTFlows
using CTFlows.Common: Common
using CTFlows.Systems: Systems
using CTFlows.Integrators: Integrators, SciML
using CTFlows.Flows: Flows, AbstractFlow, build_flow
using SciMLBase: SciMLBase

# =============================================================================
# SciMLBaseODEProblem — wrapper for dispatch disambiguation
# =============================================================================

"""
$(TYPEDEF)

Thin wrapper around a `SciMLBase.AbstractODEProblem` used to disambiguate
`Integrators.solve_problem` dispatch between `CTFlowsSciMLBase` and `CTFlowsSciML`.

When both extensions are loaded (i.e., when both `SciMLBase` and `DiffEqBase` are present),
`CTFlowsSciMLBase.solve_problem` dispatches on this wrapper type, while
`CTFlowsSciML.solve_problem` dispatches on the raw `SciMLBase.AbstractODEProblem`.

# Fields
- `prob::P`: The wrapped ODE problem.
"""
struct SciMLBaseODEProblem{P <: SciMLBase.AbstractODEProblem}
    prob::P
end

# =============================================================================
# SciMLFunctionSystem
# =============================================================================

"""
$(TYPEDEF)

Concrete `AbstractStateSystem` wrapping a `SciMLBase.AbstractODEFunction`.

Unlike CTFlows-native systems (`VectorFieldSystem`), this system passes `p = variable`
directly to the ODE — no `ODEParameters` wrapper — so users can pass arbitrary
SciML parameter objects.

The mutability trait is encoded in the `iip` type parameter of the wrapped function:
- `AbstractODEFunction{true}` → in-place `f!(du, u, p, t)`
- `AbstractODEFunction{false}` → out-of-place `f(u, p, t) -> du`

# Type Parameters
- `F <: SciMLBase.AbstractODEFunction`: The wrapped ODE function.

# Fields
- `f::F`: The wrapped SciML ODE function.
"""
struct SciMLFunctionSystem{
    F <: SciMLBase.AbstractODEFunction
} <: Systems.AbstractStateSystem{Common.NonAutonomous, Common.NonFixed}
    f::F
end

# In-place: rhs returns f directly (already has (du, u, p, t) signature)
Systems.rhs(sys::SciMLFunctionSystem{<:SciMLBase.AbstractODEFunction{true}}) = sys.f

# Fallback: rhs for out-of-place functions should use rhs_oop instead
function Systems.rhs(sys::SciMLFunctionSystem{<:SciMLBase.AbstractODEFunction{false}})
    throw(
        Exceptions.PreconditionError(
            "Cannot call rhs on out-of-place SciMLFunctionSystem",
            reason = "rhs is for in-place systems (du, u, p, t), but this system is out-of-place (u, p, t) -> du",
            suggestion = "Use rhs_oop(sys) instead for out-of-place functions",
            context = "SciMLFunctionSystem rhs/rhs_oop dispatch based on mutability",
        ),
    )
end

# Out-of-place: rhs_oop returns f directly (already has (u, p, t) -> du signature)
# Bool argument accepted for API uniformity, ignored
Systems.rhs_oop(
    sys::SciMLFunctionSystem{<:SciMLBase.AbstractODEFunction{false}},
    ::Bool = true,
) = sys.f

# Fallback: rhs_oop for in-place functions should use rhs instead
function Systems.rhs_oop(
    sys::SciMLFunctionSystem{<:SciMLBase.AbstractODEFunction{true}},
    ::Bool = true,
)
    throw(
        Exceptions.PreconditionError(
            "Cannot call rhs_oop on in-place SciMLFunctionSystem",
            reason = "rhs_oop is for out-of-place systems (u, p, t) -> du, but this system is in-place (du, u, p, t)",
            suggestion = "Use rhs(sys) instead for in-place functions",
            context = "SciMLFunctionSystem rhs/rhs_oop dispatch based on mutability",
        ),
    )
end

# =============================================================================
# build_problem for SciMLFunctionSystem
# =============================================================================

"""
$(TYPEDSIGNATURES)

Build an `ODEProblem` from a `SciMLFunctionSystem` and configuration.

Bypasses `ODEParameters`: passes `variable` directly as `p` to the ODE.
The mutability of the problem (iip vs oop) is determined by the function's trait,
not by the mutability of `u0`. A defensive check ensures in-place functions are not
used with immutable `u0`.

# Arguments
- `integ::SciML`: The SciML integrator strategy.
- `sys::SciMLFunctionSystem`: The SciML function system.
- `config::Common.AbstractConfig`: The configuration containing initial condition and time span.
- `variable`: The variable parameter passed directly as `p` (no wrapper).

# Returns
- `SciMLBaseODEProblem`: Wrapped ODE problem ready for solving.

# Throws
- `CTBase.Exceptions.PreconditionError`: If the function is in-place but `u0` is immutable.
"""
function Integrators.build_problem(
    integ::SciML,
    sys::SciMLFunctionSystem,
    config::Common.AbstractConfig;
    variable,
)
    u0   = Common.initial_condition(config)
    tspan = Common.tspan(config)
    
    # Determine mutability from the function's trait, not from u0
    if SciMLBase.isinplace(sys.f)
        # In-place function: check that u0 is mutable
        if !ismutable(u0)
            throw(
                Exceptions.PreconditionError(
                    "In-place function requires mutable initial condition",
                    reason = "The ODE function is in-place (du, u, p, t) but u0 is immutable",
                    suggestion = "Use a mutable initial condition (e.g., Vector, MVector instead of SVector) or an out-of-place function",
                    context = "SciMLFunctionSystem build_problem",
                ),
            )
        end
        f! = Systems.rhs(sys)
        prob = SciMLBase.ODEProblem(f!, u0, tspan, variable)
    else
        # Out-of-place function: use rhs_oop
        f = Systems.rhs_oop(sys, false)
        prob = SciMLBase.ODEProblem(f, u0, tspan, variable)
    end
    
    return SciMLBaseODEProblem(prob)
end

# =============================================================================
# SciMLBaseIntegrationResult
# =============================================================================

"""
$(TYPEDEF)

Integration result wrapping a `SciMLBase.AbstractODESolution`.

Defined in `CTFlowsSciMLBase` (depends only on `SciMLBase`, not `DiffEqBase`),
parallel to `SciMLIntegrationResult` in `CTFlowsSciML`.

# Fields
- `ode_sol::S`: The raw SciML ODE solution.
"""
struct SciMLBaseIntegrationResult{
    S <: SciMLBase.AbstractODESolution
} <: Integrators.AbstractIntegrationResult
    ode_sol::S
end

Integrators.final_state(r::SciMLBaseIntegrationResult)        = last(r.ode_sol.u)
Integrators.times(r::SciMLBaseIntegrationResult)              = r.ode_sol.t
Integrators.evaluate_at(r::SciMLBaseIntegrationResult, t)     = r.ode_sol(t)

# =============================================================================
# _check_retcode — private helper
# =============================================================================

"""
    _check_retcode(sol, unsafe)

Check the return code of a SciML ODE solution and throw `SolverFailure` if integration failed.

# Arguments
- `sol`: A SciML ODE solution with a `retcode` field.
- `unsafe::Bool`: If `true`, bypass retcode checking; if `false`, throw on failure.

# Throws
- `CTBase.Exceptions.SolverFailure`: If `!unsafe` and the retcode indicates failure.
"""
function _check_retcode(sol, unsafe)
    if !unsafe && !SciMLBase.successful_retcode(sol.retcode)
        throw(Exceptions.SolverFailure(
            "ODE integration failed";
            retcode = string(sol.retcode),
            suggestion = "Try tightening tolerances (reltol, abstol) or changing the solver algorithm.",
            context = "SciMLBase solve_problem",
        ))
    end
end

# =============================================================================
# solve_problem for SciMLBaseODEProblem
# =============================================================================

"""
$(TYPEDSIGNATURES)

Solve a wrapped `SciMLBaseODEProblem` using resolved options.

Dispatches on `SciMLBaseODEProblem` to stay disjoint from `CTFlowsSciML.solve_problem`
(which dispatches on raw `SciMLBase.AbstractODEProblem`).

# Arguments
- `integ::SciML`: The SciML integrator strategy.
- `prob::SciMLBaseODEProblem`: The wrapped ODE problem to solve.
- `options::Dict{Symbol,<:Any}`: Resolved solver options.
- `unsafe=Common.__unsafe()`: If `true`, bypass retcode checking; if `false`, throw `SolverFailure` on integration failure.

# Returns
- `SciMLBaseIntegrationResult`: The integration result wrapping the SciML ODE solution.
"""
function Integrators.solve_problem(
    integ::SciML,
    prob::SciMLBaseODEProblem,
    options::Dict{Symbol,<:Any};
    unsafe = Common.__unsafe(),
)
    sol = SciMLBase.solve(prob.prob; options...)
    _check_retcode(sol, unsafe)
    return SciMLBaseIntegrationResult(sol)
end

# =============================================================================
# Base.show for SciMLFunctionSystem
# =============================================================================

function Base.show(io::IO, sys::SciMLFunctionSystem{F}) where F
    iip = SciMLBase.isinplace(sys.f)
    mut = iip ? "in-place" : "out-of-place"
    println(io, "SciMLFunctionSystem")
    print(io, "  wraps: ODEFunction: non-autonomous, variable, ", mut)
end

function Base.show(io::IO, ::MIME"text/plain", sys::SciMLFunctionSystem)
    show(io, sys)
end

# =============================================================================
# SciMLProblemFlow
# =============================================================================

"""
$(TYPEDEF)

Concrete `AbstractFlow` wrapping a `SciMLBase.AbstractODEProblem` directly.

Unlike `StateFlow` which wraps an `AbstractSystem` and an `AbstractIntegrator`,
`SciMLProblemFlow` wraps a fully-assembled ODE problem. The `system` method returns
`nothing` because there is no CTFlows `AbstractSystem` to extract.

The flow supports two call modes:
- **No-arg call** `f(; unsafe)` — solves the problem as-is with trajectory options.
- **Remake call** `f(t0, x0, tf; variable, unsafe)` — calls `SciMLBase.remake` first with point options.

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
flow = CTFlowsSciMLBase.SciMLProblemFlow(prob, Integrators.SciML())

# No-arg call: solve as-is
sol = flow(; unsafe=false)

# Remake call: modify initial condition and time span
xf = flow(0.5, [2.0], 2.0; variable=3.0, unsafe=false)
```
"""
struct SciMLProblemFlow{
    P <: SciMLBase.AbstractODEProblem,
    I <: Integrators.AbstractIntegrator
} <: AbstractFlow{Common.NonAutonomous, Common.NonFixed}
    prob::P
    integrator::I
end

Flows.system(f::SciMLProblemFlow) = nothing
Flows.integrator(f::SciMLProblemFlow) = f.integrator

# No-arg call: solve problem as-is with trajectory options
function (f::SciMLProblemFlow; unsafe = Common.__unsafe())
    opts = Integrators.build_options(f.integrator, nothing)
    sol = SciMLBase.solve(f.prob; opts...)
    _check_retcode(sol, unsafe)
    return sol
end

# Remake call: modify initial condition, time span, and optionally parameter
function (f::SciMLProblemFlow)(
    t0::Real,
    x0,
    tf::Real;
    variable = nothing,
    unsafe = Common.__unsafe(),
)
    kw = (; u0 = x0, tspan = (t0, tf))
    if !isnothing(variable)
        kw = merge(kw, (; p = variable))
    end
    prob = SciMLBase.remake(f.prob; kw...)
    config = Common.StatePointConfig(t0, x0, tf)
    opts = Integrators.build_options(f.integrator, config)
    sol = SciMLBase.solve(prob; opts...)
    _check_retcode(sol, unsafe)
    return last(sol.u)
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

# =============================================================================
# High-level Flow constructors
# =============================================================================

"""
    Flow(f::SciMLBase.AbstractODEFunction; kwargs...)

Create a `Flow` from a SciML ODE function.

Delegates to the standard CTFlows pipeline:
1. Wraps `f` in a `SciMLFunctionSystem`
2. Builds a `SciML` integrator from `kwargs`
3. Constructs a `StateFlow` via `build_flow`

# Arguments
- `f::SciMLBase.AbstractODEFunction`: The ODE function to wrap.
- `kwargs...`: Passed to the `SciML` integrator constructor (e.g., `reltol=1e-10`).

# Returns
- `StateFlow`: The flow for the given function.

# Example
```julia
using SciMLBase, CTFlows

f = ODEFunction((du, u, p, t) -> du .= -p .* u)
flow = Flow(f; reltol=1e-10)
xf = flow(0.0, [1.0], 1.0; variable=2.0)
```
"""
function Flows.Flow(f::SciMLBase.AbstractODEFunction; kwargs...)
    sys = SciMLFunctionSystem(f)
    integ = Integrators.SciML(; kwargs...)
    return build_flow(sys, integ)
end

"""
    Flow(prob::SciMLBase.AbstractODEProblem; kwargs...)

Create a `Flow` from a SciML ODE problem.

Constructs a `SciMLProblemFlow` directly, which wraps the problem and a `SciML` integrator.
This bypasses the standard CTFlows system-building pipeline since the problem is already
fully assembled (includes u0, tspan, and p).

# Arguments
- `prob::SciMLBase.AbstractODEProblem`: The ODE problem to wrap.
- `kwargs...`: Passed to the `SciML` integrator constructor (e.g., `reltol=1e-10`).

# Returns
- `SciMLProblemFlow`: The flow for the given problem.

# Example
```julia
using SciMLBase, CTFlows

prob = ODEProblem((du, u, p, t) -> du .= -p .* u, [1.0], (0.0, 1.0), 2.0)
flow = Flow(prob; reltol=1e-10)
sol = flow(; unsafe=false)  # No-arg call: solve as-is
xf = flow(0.5, [2.0], 2.0; variable=3.0, unsafe=false)  # Remake call
```
"""
function Flows.Flow(prob::SciMLBase.AbstractODEProblem; kwargs...)
    integ = Integrators.SciML(; kwargs...)
    return SciMLProblemFlow(prob, integ)
end

end # module CTFlowsSciMLBase
