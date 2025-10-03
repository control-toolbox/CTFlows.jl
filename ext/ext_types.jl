const ctNumber = CTModels.ctNumber
const ctVector = Union{ctNumber,CTModels.ctVector}
const Time = ctNumber
const Times = AbstractVector{<:Time}
const State = ctVector
const Costate = ctVector
const Control = ctVector
const Variable = ctVector
const DState = ctVector
const DCostate = ctVector

# ---------------------------------------------------------------------------------------------------
"""
$(TYPEDEF)

A flow object for integrating Hamiltonian dynamics in optimal control.

Represents the time evolution of a Hamiltonian system using the canonical form of Hamilton's equations.
The struct holds the numerical integration setup and metadata for event handling.

# Fields
- `f::Function`: Flow integrator function, called like `f(t0, x0, p0, tf; ...)`.
- `rhs!::Function`: Right-hand side of the ODE system, used by solvers.
- `tstops::Times`: List of times at which integration should pause or apply discrete effects.
- `jumps::Vector{Tuple{Time,Costate}}`: List of jump discontinuities for the costate at given times.

# Usage
Instances of `HamiltonianFlow` are callable and forward arguments to the underlying flow function `f`.

# Example
```julia-repl
julia> flow = HamiltonianFlow(f, rhs!)
julia> xf, pf = flow(0.0, x0, p0, 1.0)
```
"""
struct HamiltonianFlow <: AbstractFlow{DCoTangent,CoTangent}
    f::Function      # f(args..., rhs): compute the flow
    rhs!::Function   # DifferentialEquations rhs
    tstops::Times    # stopping times
    jumps::Vector{Tuple{Time,Costate}} # specific jumps the integrator must perform
    function HamiltonianFlow(
        f,
        rhs!,
        tstops::Times=Vector{Time}(),
        jumps::Vector{Tuple{Time,Costate}}=Vector{Tuple{Time,Costate}}(),
    )
        return new(f, rhs!, tstops, jumps)
    end
end

# call F.f
function (F::HamiltonianFlow)(args...; kwargs...)
    return F.f(
        args...; jumps=F.jumps, _t_stops_interne=F.tstops, DiffEqRHS=F.rhs!, kwargs...
    )
end

# ---------------------------------------------------------------------------------------------------
"""
$(TYPEDEF)

A flow object for integrating general vector field dynamics.

Used for systems where the vector field is given explicitly, rather than derived from a Hamiltonian.
Useful in settings like controlled systems or classical mechanics outside the Hamiltonian framework.

# Fields
- `f::Function`: Flow integrator function.
- `rhs::Function`: ODE right-hand side function.
- `tstops::Times`: Event times (e.g., to trigger callbacks).
- `jumps::Vector{Tuple{Time,State}}`: Discrete jump events on the state trajectory.

# Example
```julia-repl
julia> flow = VectorFieldFlow(f, rhs)
julia> xf = flow(0.0, x0, 1.0)
```
"""
struct VectorFieldFlow <: AbstractFlow{DState,State}
    f::Function     # f(args..., rhs): compute the flow
    rhs::Function  # DifferentialEquations rhs
    tstops::Times   # stopping times
    jumps::Vector{Tuple{Time,State}} # specific jumps the integrator must perform
    function VectorFieldFlow(
        f,
        rhs,
        tstops::Times=Vector{Time}(),
        jumps::Vector{Tuple{Time,State}}=Vector{Tuple{Time,State}}(),
    )
        return new(f, rhs, tstops, jumps)
    end
end

# call F.f
function (F::VectorFieldFlow)(args...; kwargs...)
    return F.f(
        args...; jumps=F.jumps, _t_stops_interne=F.tstops, DiffEqRHS=F.rhs, kwargs...
    )
end

# ---------------------------------------------------------------------------------------------------
"""
$(TYPEDEF)

Generic flow object for arbitrary ODE systems with jumps and events.

A catch-all flow for general-purpose ODE integration. Supports dynamic typing and arbitrary state structures.

# Fields
- `f::Function`: Integrator function called with time span and initial conditions.
- `rhs::Function`: Right-hand side for the differential equation.
- `tstops::Times`: Times at which the integrator is forced to stop.
- `jumps::Vector{Tuple{Time,Any}}`: User-defined jumps applied to the state during integration.

# Example
```julia-repl
julia> flow = ODEFlow(f, rhs)
julia> result = flow(0.0, u0, 1.0)
```
"""
struct ODEFlow <: AbstractFlow{Any,Any}
    f::Function     # f(args..., rhs): compute the flow
    rhs::Function   # DifferentialEquations rhs
    tstops::Times   # stopping times
    jumps::Vector{Tuple{Time,Any}} # specific jumps the integrator must perform
    function ODEFlow(
        f,
        rhs!,
        tstops::Times=Vector{Time}(),
        jumps::Vector{Tuple{Time,Any}}=Vector{Tuple{Time,Any}}(),
    )
        return new(f, rhs!, tstops, jumps)
    end
end

function (F::ODEFlow)(args...; kwargs...)
    return F.f(
        args...; jumps=F.jumps, _t_stops_interne=F.tstops, DiffEqRHS=F.rhs, kwargs...
    )
end

# ---------------------------------------------------------------------------------------------------
"""
$(TYPEDEF)

Wraps the low-level ODE solution, control feedback law, model structure, and problem parameters.

# Fields
- `ode_sol::Any`: The ODE solution (from DifferentialEquations.jl).
- `feedback_control::ControlLaw`: Feedback control law `u(t, x, p, v)`.
- `ocp::Model`: The optimal control model used.
- `variable::Variable`: External or design parameters of the control problem.

# Usage
You can evaluate the flow solution like a callable ODE solution.

# Example
```julia-repl
julia> sol = OptimalControlFlowSolution(ode_sol, u, model, v)
julia> x = sol(t)
```
"""
struct OptimalControlFlowSolution
    # 
    ode_sol::Any
    feedback_control::CTFlows.ControlLaw # the control law in state-costate feedback form, that is u(t, x, p, v)
    ocp::CTModels.Model
    variable::Variable
end

(OCFS::OptimalControlFlowSolution)(args...; kwargs...) = OCFS.ode_sol(args...; kwargs...)

"""
$(TYPEDSIGNATURES)

Constructs an `OptimalControlSolution` from an `OptimalControlFlowSolution`.

This evaluates the objective (Mayer and/or Lagrange costs), extracts the time-dependent state,
costate, and control trajectories, and builds a full `CTModels.Solution`.

Returns a `CTModels.Solution` ready for evaluation, reporting, or analysis.

# Keyword Arguments
- `alg`: Optional solver for computing Lagrange integral, if needed.
- Additional kwargs passed to the internal solver.

# Example
```julia-repl
julia> sol = Solution(optflow_solution)
```
"""
function CTModels.Solution(ocfs::OptimalControlFlowSolution; kwargs...)
    ocp = ocfs.ocp
    n = CTModels.state_dimension(ocp)
    T = ocfs.ode_sol.t
    v = ocfs.variable
    x(t) = ocfs.ode_sol(t)[rg(1, n)]
    p(t) = ocfs.ode_sol(t)[rg(n + 1, 2n)]
    function make_control(v)
        return t -> ocfs.feedback_control(t, x(t), p(t), v)
    end
    u = make_control(v)

    # the obj must be computed and pass to OptimalControlSolution
    t0 = T[1]
    tf = T[end]

    may = CTFlows.__mayer(ocp)
    lag = CTFlows.__lagrange(ocp)

    obj = CTModels.has_mayer_cost(ocp) ? may(x(t0), x(tf), v) : 0
    if CTModels.has_lagrange_cost(ocp)
        try
            ϕ(_, _, t) = [lag(t, x(t), u(t), v)]
            tspan = (t0, tf)
            x0 = [0.0]
            prob = ODEProblem(ϕ, x0, tspan)
            alg = :alg ∈ keys(kwargs) ? kwargs[:alg] : __alg()
            ode_sol = solve(prob, alg; kwargs...)
            obj += ode_sol(tf)[1]
        catch e
            obj = NaN
        end
    end

    # 
    kwargs_OCS = obj==NaN ? () : (objective=obj,)
    sol = CTModels.build_solution(
        ocp,
        Vector{Float64}(T), #::Vector{Float64},
        deepcopy(t -> x(t)),
        deepcopy(t -> u(t)),
        v isa Number ? Float64[v] : Float64.(v), #::Vector{Float64},
        deepcopy(t -> p(t));
        iterations=-1,
        constraints_violation=-1.0,
        message="Solution obtained from flow",
        status=:nostatusmessage,
        successful=true,
        kwargs_OCS...,
    )

    return sol
end

# ---------------------------------------------------------------------------------------------------
"""
$(TYPEDEF)

A flow object representing the solution of an optimal control problem.

Supports Hamiltonian-based and classical formulations. Provides call overloads for different control settings:
- Fixed external variables
- Parametric (non-fixed) control problems

# Fields
- `f::Function`: Main integrator that receives the RHS and other arguments.
- `rhs!::Function`: ODE right-hand side.
- `tstops::Times`: Times where the solver should stop (e.g., nonsmooth dynamics).
- `jumps::Vector{Tuple{Time,Costate}}`: Costate jump conditions.
- `feedback_control::ControlLaw`: Feedback law `u(t, x, p, v)`.
- `ocp::Model`: The optimal control problem definition.
- `kwargs_Flow::Any`: Extra solver arguments.

# Call Signatures
- `F(t0, x0, p0, tf; kwargs...)`: Solves with fixed variable dimension.
- `F(t0, x0, p0, tf, v; kwargs...)`: Solves with parameter `v`.
- `F(tspan, x0, p0; ...)`: Solves and returns a full `OptimalControlSolution`.

# Example
```julia-repl
julia> flow = OptimalControlFlow(...)
julia> sol = flow(0.0, x0, p0, 1.0)
julia> opt_sol = flow((0.0, 1.0), x0, p0)
```
"""
struct OptimalControlFlow{VD} <: AbstractFlow{DCoTangent,CoTangent}
    # 
    f::Function      # the mere function which depends on the kind of flow (Hamiltonian or classical) 
    # this function takes a right and side as input
    rhs!::Function   # the right and side of the form: rhs!(du::D, u::U, p::V, t::T)
    tstops::Times    # specific times  the integrator must stop
    # useful when the rhs is not smooth at such times
    jumps::Vector{Tuple{Time,Costate}} # specific jumps the integrator must perform
    feedback_control::CTFlows.ControlLaw # the control law in feedback form, that is u(t, x, p, v)
    ocp::CTModels.Model # the optimal control problem
    kwargs_Flow::Any     #

    # constructor
    function OptimalControlFlow(
        f::Function,
        rhs!::Function,
        u::CTFlows.ControlLaw,
        ocp::CTModels.Model,
        kwargs_Flow,
        tstops::Times=Vector{Time}(),
        jumps::Vector{Tuple{Time,Costate}}=Vector{Tuple{Time,Costate}}(),
    )
        VD = if CTModels.variable_dimension(ocp)==0
            CTFlows.Fixed
        else
            CTFlows.NonFixed
        end
        return new{VD}(f, rhs!, tstops, jumps, u, ocp, kwargs_Flow)
    end
end

# call F.f
function (F::OptimalControlFlow{CTFlows.Fixed})(
    t0::Time, x0::State, p0::Costate, tf::Time; kwargs...
)
    return F.f(
        t0,
        x0,
        p0,
        tf;
        jumps=F.jumps,
        _t_stops_interne=F.tstops,
        DiffEqRHS=F.rhs!,
        kwargs...,
    )
end

function (F::OptimalControlFlow{CTFlows.NonFixed})(
    t0::Time,
    x0::State,
    p0::Costate,
    tf::Time,
    v::Variable=__thevariable(t0, x0, p0, tf, F.ocp);
    kwargs...,
)
    return F.f(
        t0,
        x0,
        p0,
        tf,
        v;
        jumps=F.jumps,
        _t_stops_interne=F.tstops,
        DiffEqRHS=F.rhs!,
        kwargs...,
    )
end

# call F.f and then, construct an optimal control solution
function (F::OptimalControlFlow{CTFlows.Fixed})(
    tspan::Tuple{Time,Time}, x0::State, p0::Costate; kwargs...
)
    ode_sol = F.f(
        tspan, x0, p0; jumps=F.jumps, _t_stops_interne=F.tstops, DiffEqRHS=F.rhs!, kwargs...
    )
    flow_sol = OptimalControlFlowSolution(
        ode_sol, F.feedback_control, F.ocp, __thevariable(x0, p0)
    )
    return CTModels.Solution(flow_sol; F.kwargs_Flow..., kwargs...)
end

function (F::OptimalControlFlow{CTFlows.NonFixed})(
    tspan::Tuple{Time,Time},
    x0::State,
    p0::Costate,
    v::Variable=__thevariable(tspan[1], x0, p0, tspan[2], F.ocp);
    kwargs...,
)
    ode_sol = F.f(
        tspan,
        x0,
        p0,
        v;
        jumps=F.jumps,
        _t_stops_interne=F.tstops,
        DiffEqRHS=F.rhs!,
        kwargs...,
    )
    flow_sol = OptimalControlFlowSolution(ode_sol, F.feedback_control, F.ocp, v)
    return CTModels.Solution(flow_sol; F.kwargs_Flow..., kwargs...)
end
