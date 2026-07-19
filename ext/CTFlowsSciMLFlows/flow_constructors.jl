# =============================================================================
# High-level Flow constructors
# =============================================================================

"""
    Flow(f::SciMLBase.AbstractODEFunction; opts...)

Create a `Flow` from a SciML ODE function.

Delegates to the standard CTFlows pipeline:
1. Wraps `f` in a `SciMLFunctionSystem`
2. Builds a `SciML` integrator from `kwargs`
3. Constructs a `StateFlow` via `build_flow`

# Arguments
- `f::SciMLBase.AbstractODEFunction`: The ODE function to wrap.
- `opts...`: Passed to the `SciML` integrator constructor (e.g., `reltol=1e-10`).

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
function Flows.Flow(f::SciMLBase.AbstractODEFunction; opts...)
    sys = SciMLFunctionSystem(f)
    integ = Flows._build_integrator(opts)
    return build_flow(sys, integ)
end

"""
    Flow(prob::SciMLBase.AbstractODEProblem; opts...)

Create a `Flow` from a SciML ODE problem.

Constructs a `SciMLProblemFlow` directly, which wraps the problem and a `SciML` integrator.
This bypasses the standard CTFlows system-building pipeline since the problem is already
fully assembled (includes u0, tspan, and p).

# Arguments
- `prob::SciMLBase.AbstractODEProblem`: The ODE problem to wrap.
- `opts...`: Passed to the `SciML` integrator constructor (e.g., `reltol=1e-10`).

# Returns
- `SciMLProblemFlow`: The flow for the given problem.

# Example
```julia
using SciMLBase, CTFlows

prob = ODEProblem((du, u, p, t) -> du .= -p .* u, [1.0], (0.0, 1.0), 2.0)
flow = Flow(prob; reltol=1e-10)
result = flow(; unsafe=false)  # No-arg call: solve as-is
xf = Integrators.final_state(result)
result = flow(0.5, [2.0], 2.0; variable=3.0, unsafe=false)  # Remake call
xf = Integrators.final_state(result)
```
"""
function Flows.Flow(prob::SciMLBase.AbstractODEProblem; opts...)
    integ = Flows._build_integrator(opts)
    return SciMLProblemFlow(prob, integ)
end
