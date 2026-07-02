# =============================================================================
# OCPHamiltonianFunctionFunction, OptimalControlFlow, and solution builder
# =============================================================================

# =============================================================================
# OCPHamiltonianFunction — OCP Hamiltonian H(t,x,p,v) = p·f(t,x,∅,v) + sp0·ℓ(t,x,∅,v)
#
# TD/VD are compile-time parameters so dispatch selects the right natural-arity
# method without runtime branches.  A single _ocp_H core does the work; scalar
# inputs (x or p as Number when n_x=1) are rewrapped to 1-vectors so the always-
# in-place CTModels dynamics receives the array it expects.
#
# sp0 = s·p⁰ where p⁰=-1: sp0=-1 for :min, sp0=+1 for :max.
# =============================================================================

struct OCPHamiltonianFunction{TD, VD, DF, LF} <: Function
    dynamics!::DF
    lagrange::LF
    sp0::Float64
    n::Int
end

# Aliases to keep method signatures concise
const _CTM_Auton    = CTModels.Components.Autonomous
const _CTM_NonAuton = CTModels.Components.NonAutonomous

# Rewrap a scalar to a 1-vector; leave arrays unchanged.
_asvec(z::Number)         = [z]
_asvec(z::AbstractVector) = z

function _ocp_H(h::OCPHamiltonianFunction, t, x, p, v)
    xv = _asvec(x)
    pv_arg = _asvec(p)
    if v === nothing
        T  = eltype(xv)
        u  = Vector{T}(undef, 0)
        r  = Vector{T}(undef, h.n)
        h.dynamics!(r, t, xv, u, u)
        val = sum(pv_arg .* r)
        h.lagrange === nothing || (val += h.sp0 * h.lagrange(t, xv, u, u))
    else
        vv = _asvec(v)
        T  = Base.promote_op(*, eltype(xv), eltype(vv))
        u  = Vector{T}(undef, 0)
        r  = Vector{T}(undef, h.n)
        h.dynamics!(r, t, xv, u, vv)
        val = sum(pv_arg .* r)
        h.lagrange === nothing || (val += h.sp0 * h.lagrange(t, xv, u, vv))
    end
    return val
end

(h::OCPHamiltonianFunction{_CTM_Auton,    Traits.Fixed,    DF, LF})(x, p)       where {DF, LF} = _ocp_H(h, 0.0, x, p, nothing)
(h::OCPHamiltonianFunction{_CTM_NonAuton, Traits.Fixed,    DF, LF})(t, x, p)    where {DF, LF} = _ocp_H(h, t,   x, p, nothing)
(h::OCPHamiltonianFunction{_CTM_Auton,    Traits.NonFixed, DF, LF})(x, p, v)    where {DF, LF} = _ocp_H(h, 0.0, x, p, v)
(h::OCPHamiltonianFunction{_CTM_NonAuton, Traits.NonFixed, DF, LF})(t, x, p, v) where {DF, LF} = _ocp_H(h, t,   x, p, v)

# =============================================================================
# _ocp_hamiltonian — builds an OCPHamiltonianFunction wrapped in Data.Hamiltonian
# =============================================================================

function _ocp_hamiltonian(ocp)
    n    = CTModels.Models.state_dimension(ocp)
    dyn! = CTModels.Models.dynamics(ocp)
    sp0  = CTModels.Components.criterion(ocp) === :min ? -1.0 : 1.0   # s*p⁰, p⁰=-1
    lag  = CTModels.Components.has_lagrange_cost(ocp) ?
               CTModels.Components.lagrange(ocp) : nothing
    TD   = Traits.time_dependence(ocp)       # Traits.Autonomous or NonAutonomous
    VD   = Traits.variable_dependence(ocp)   # Traits.Fixed or Traits.NonFixed
    h_raw = OCPHamiltonianFunction{TD, VD, typeof(dyn!), typeof(lag)}(dyn!, lag, sp0, n)
    return Data.Hamiltonian(h_raw, TD, VD)   # typed ctor → uniform (t,x,p,v) interface for AD
end

# =============================================================================
# OptimalControlFlow — thin AbstractFlow wrapper that carries the ocp reference
#
# The inner HamiltonianFlow handles all point-eval + variable_costate logic.
# This wrapper exists solely so the trajectory call can build a CTModels.Solution.
# =============================================================================

"""
$(TYPEDEF)

Flow of the Hamiltonian system associated with a (control-free) optimal control
problem, built by [`CTFlows.Flows.Flow`](@ref) from a
[`CTModels.Models.Model`](@extref).

It is a thin [`CTFlows.Flows.AbstractFlow`](@ref) wrapper around an inner
`HamiltonianFlow`: point evaluation delegates to the inner flow (returning the
final state–costate pair), while a trajectory call integrates the system and
rebuilds a full [`CTModels.Solutions.Solution`](@extref) from the problem.

# Type Parameters
- `TD <: TimeDependence`: time-dependence trait, inherited from the problem.
- `VD <: VariableDependence`: variable-dependence trait, inherited from the problem.
- `IF`: type of the inner `HamiltonianFlow`.
- `M`: type of the wrapped optimal control problem model.

# Fields
- `flow::IF`: the inner Hamiltonian flow doing the integration.
- `ocp::M`: the optimal control problem, kept so trajectory calls can build a solution.

See also: [`CTFlows.Flows.Flow`](@ref), [`CTModels.Solutions.Solution`](@extref).
"""
struct OptimalControlFlow{
    TD <: Traits.TimeDependence,
    VD <: Traits.VariableDependence,
    IF,
    M,
} <: AbstractFlow{TD, VD, Traits.HamiltonianDynamics}
    flow::IF    # inner HamiltonianFlow
    ocp::M
end

function OptimalControlFlow(
    flow::Flow{TD, VD, Traits.HamiltonianDynamics},
    ocp,
) where {TD, VD}
    return OptimalControlFlow{TD, VD, typeof(flow), typeof(ocp)}(flow, ocp)
end

system(F::OptimalControlFlow)     = system(F.flow)
integrator(F::OptimalControlFlow) = integrator(F.flow)

# ── point eval — pure delegation ────────────────────────────────────────────

function (F::OptimalControlFlow)(
    t0::Real, x0, p0, tf::Real;
    variable          = Core.NotProvided,
    variable_costate::Bool = false,
    unsafe::Bool           = false,
)
    return F.flow(t0, x0, p0, tf; variable, variable_costate, unsafe)
end

# ── trajectory call — builds a CTModels.Solution ────────────────────────────

function (F::OptimalControlFlow)(
    tspan::Tuple{<:Real, <:Real}, x0, p0;
    variable = Core.NotProvided,
    unsafe::Bool = false,
)
    sol = F.flow(tspan, x0, p0; variable, unsafe)   # HamiltonianVectorFieldTrajectory
    return _build_ocp_solution(F.ocp, sol, variable, integrator(F.flow))
end

# =============================================================================
# Solution helpers
# =============================================================================

_variable_vector(::Core.NotProvidedType)  = Float64[]
_variable_vector(v::Number)             = [Float64(v)]
_variable_vector(v::AbstractVector)     = Float64.(v)

function _ocp_objective(ocp, x, v, t0, tf, integ)
    obj = 0.0
    if CTModels.Components.has_mayer_cost(ocp)
        may = CTModels.Components.mayer(ocp)
        obj += may(x(t0), x(tf), v)
    end
    if CTModels.Components.has_lagrange_cost(ocp)
        lag      = CTModels.Components.lagrange(ocp)
        u_empty  = Float64[]
        # Integrate ℓ̇(t) = lag(t, x(t), ∅, v) from t0 to tf.
        # Use a 1-element Vector so SciML always has a mutable in-place buffer.
        running  = Data.VectorField(
            (t, ℓ_vec) -> [lag(t, x(t), u_empty, v)];
            is_autonomous = false, is_variable = false,
        )
        cost_flow = build_flow(Systems.build_system(running), integ)
        ℓ_tf      = cost_flow(t0, [0.0], tf)   # returns [ℓ(tf)]
        obj      += ℓ_tf[1]
    end
    return obj
end

function _build_ocp_solution(
    ocp,
    sol::Trajectories.HamiltonianVectorFieldTrajectory,
    variable,
    integ,
)
    T      = collect(Float64, Trajectories.time_grid(sol))
    x      = Trajectories.state(sol)    # callable StateProjection: t -> x(t)
    p      = Trajectories.costate(sol)  # callable CostateProjection: t -> p(t)
    t0, tf = first(T), last(T)
    v      = _variable_vector(variable)
    u      = _ -> Float64[]          # empty control for control-free OCP
    obj    = _ocp_objective(ocp, x, v, t0, tf, integ)
    return CTModels.Solutions.build_solution(
        ocp, T, x, u, v, p;
        objective             = obj,
        iterations            = -1,
        constraints_violation = -1.0,
        message               = "Solution computed by CTFlows OCP flow",
        status                = :nostatusmessage,
        successful            = true,
        control_interpolation = :linear,
    )
end
