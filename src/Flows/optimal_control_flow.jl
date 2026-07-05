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

"""
$(TYPEDEF)

Internal callable representing the Hamiltonian of a control-free optimal control problem.

Computes `H(t,x,p,v) = p·f(t,x,∅,v) + sp0·ℓ(t,x,∅,v)` where `sp0 = s·p⁰` with `p⁰=-1`
(`sp0=-1` for `:min`, `sp0=+1` for `:max`). The time-dependence (`TD`) and
variable-dependence (`VD`) traits are compile-time parameters so that dispatch
selects the correct natural-arity call signature without runtime branches.

# Type Parameters
- `TD`: time-dependence trait (`Autonomous` or `NonAutonomous`).
- `VD`: variable-dependence trait (`Fixed` or `NonFixed`).
- `DF`: type of the in-place dynamics function.
- `LF`: type of the Lagrange cost function (or `Nothing`).

# Fields
- `dynamics!::DF`: in-place dynamics `f!(r, t, x, u, v)` from the OCP.
- `lagrange::LF`: Lagrange cost `ℓ(t, x, u, v)` or `nothing` if absent.
- `sp0::Float64`: sign-weighted multiplier `s·p⁰`.
- `n::Int`: state dimension.

See also: [`CTFlows.Flows.OptimalControlFlow`](@ref), `_ocp_H`, `_ocp_hamiltonian`.
"""
struct OCPHamiltonianFunction{TD,VD,DF,LF} <: Function
    dynamics!::DF
    lagrange::LF
    sp0::Float64
    n::Int
end

# Aliases to keep method signatures concise
const _CTM_Auton = CTModels.Components.Autonomous
const _CTM_NonAuton = CTModels.Components.NonAutonomous

"""
Rewrap a scalar to a 1-vector; leave arrays unchanged.

This ensures the always-in-place CTModels dynamics receives the array it expects,
even when the state or costate is a scalar `Number` (which happens when `n_x=1`).

See also: [`OCPHamiltonianFunction`](@ref), `_ocp_H`.
"""
_asvec(z::Number) = [z]
_asvec(z::AbstractVector) = z

"""
$(TYPEDSIGNATURES)

Core computation of the OCP Hamiltonian value `H(t,x,p,v)`.

Rewraps scalar `x` and `p` to 1-vectors via `_asvec`, calls the in-place dynamics,
and accumulates `p·f + sp0·ℓ`. When `v === nothing` the variable is treated as an
empty vector (used by `Fixed`-trait call paths).

See also: [`OCPHamiltonianFunction`](@ref), `_asvec`.
"""
function _ocp_H(h::OCPHamiltonianFunction, t, x, p, v)
    xv = _asvec(x)
    pv_arg = _asvec(p)
    if v === nothing
        T = eltype(xv)
        u = Vector{T}(undef, 0)
        r = Vector{T}(undef, h.n)
        h.dynamics!(r, t, xv, u, u)
        val = sum(pv_arg .* r)
        h.lagrange === nothing || (val += h.sp0 * h.lagrange(t, xv, u, u))
    else
        vv = _asvec(v)
        T = Base.promote_op(*, eltype(xv), eltype(vv))
        u = Vector{T}(undef, 0)
        r = Vector{T}(undef, h.n)
        h.dynamics!(r, t, xv, u, vv)
        val = sum(pv_arg .* r)
        h.lagrange === nothing || (val += h.sp0 * h.lagrange(t, xv, u, vv))
    end
    return val
end

function (h::OCPHamiltonianFunction{_CTM_Auton,Traits.Fixed,DF,LF})(x, p) where {DF,LF}
    return _ocp_H(h, 0.0, x, p, nothing)
end
function (h::OCPHamiltonianFunction{_CTM_NonAuton,Traits.Fixed,DF,LF})(
    t,
    x,
    p,
) where {DF,LF}
    return _ocp_H(h, t, x, p, nothing)
end
function (h::OCPHamiltonianFunction{_CTM_Auton,Traits.NonFixed,DF,LF})(
    x,
    p,
    v,
) where {DF,LF}
    return _ocp_H(h, 0.0, x, p, v)
end
function (h::OCPHamiltonianFunction{_CTM_NonAuton,Traits.NonFixed,DF,LF})(
    t,
    x,
    p,
    v,
) where {DF,LF}
    return _ocp_H(h, t, x, p, v)
end

# =============================================================================
# _ocp_hamiltonian — builds an OCPHamiltonianFunction wrapped in Data.Hamiltonian
# =============================================================================

"""
$(TYPEDSIGNATURES)

Build an `OCPHamiltonianFunction` from a control-free OCP and wrap it in a
`Data.Hamiltonian`.

Extracts the state dimension, dynamics, criterion sign, Lagrange cost, and
time/variable-dependence traits from the OCP, then constructs a typed
`OCPHamiltonianFunction` and wraps it so the downstream AD pipeline receives a
uniform `(t, x, p, v)` interface.

See also: [`OCPHamiltonianFunction`](@ref), [`CTFlows.Flows.OptimalControlFlow`](@ref), [`CTFlows.Flows.Flow`](@ref).
"""
function _ocp_hamiltonian(ocp)
    n = CTModels.Models.state_dimension(ocp)
    dyn! = CTModels.Models.dynamics(ocp)
    sp0 = CTModels.Components.criterion(ocp) === :min ? -1.0 : 1.0   # s*p⁰, p⁰=-1
    lag = if CTModels.Components.has_lagrange_cost(ocp)
        CTModels.Components.lagrange(ocp)
    else
        nothing
    end
    TD = Traits.time_dependence(ocp)       # Traits.Autonomous or NonAutonomous
    VD = Traits.variable_dependence(ocp)   # Traits.Fixed or Traits.NonFixed
    h_raw = OCPHamiltonianFunction{TD,VD,typeof(dyn!),typeof(lag)}(dyn!, lag, sp0, n)
    return Data.Hamiltonian(h_raw, TD, VD)   # typed ctor → uniform (t,x,p,v) interface for AD
end

# =============================================================================
# OCPPseudoHamiltonianFunction — OCP pseudo-Hamiltonian
#   H̃(t,x,p,u,v) = p·f(t,x,u,v) + sp0·ℓ(t,x,u,v)
#
# Same pattern as OCPHamiltonianFunction, but the control u is an explicit argument
# (not eliminated). Used for both the :total path (composed with a control law via
# Data.ComposedHamiltonian) and the :partial path (PseudoHamiltonianSystem).
# =============================================================================

"""
$(TYPEDEF)

Internal callable representing the pseudo-Hamiltonian of an optimal control problem:
`H̃(t,x,p,u,v) = p·f(t,x,u,v) + sp0·ℓ(t,x,u,v)` with `sp0 = s·p⁰` (`p⁰=-1`). Unlike
[`OCPHamiltonianFunction`](@ref), the control `u` is an explicit argument.

# Type Parameters
- `TD`, `VD`: time- and variable-dependence traits (compile-time dispatch on arity).
- `DF`: type of the in-place dynamics function.
- `LF`: type of the Lagrange cost function (or `Nothing`).

# Fields
- `dynamics!::DF`: in-place dynamics `f!(r, t, x, u, v)` from the OCP.
- `lagrange::LF`: Lagrange cost `ℓ(t, x, u, v)` or `nothing`.
- `sp0::Float64`: sign-weighted multiplier `s·p⁰`.
- `n::Int`: state dimension.

See also: [`OCPHamiltonianFunction`](@ref), `_ocp_pseudo_hamiltonian`,
[`CTBase.Data.PseudoHamiltonian`](@extref).
"""
struct OCPPseudoHamiltonianFunction{TD,VD,DF,LF} <: Function
    dynamics!::DF
    lagrange::LF
    sp0::Float64
    n::Int
end

"""
$(TYPEDSIGNATURES)

Core computation of the OCP pseudo-Hamiltonian value `H̃(t,x,p,u,v)`. Rewraps scalar
`x`, `p`, `u`, `v` to 1-vectors via `_asvec` (CTModels dynamics is always in-place on
arrays), calls the dynamics, and accumulates `p·f + sp0·ℓ`.

See also: [`OCPPseudoHamiltonianFunction`](@ref), `_asvec`.
"""
function _ocp_pseudo_H(h::OCPPseudoHamiltonianFunction, t, x, p, u, v)
    xv = _asvec(x)
    pv_arg = _asvec(p)
    uv = _asvec(u)
    if v === nothing
        T = Base.promote_op(*, eltype(xv), eltype(uv))
        vv = Vector{T}(undef, 0)
    else
        vv = _asvec(v)
        T = Base.promote_op(*, Base.promote_op(*, eltype(xv), eltype(uv)), eltype(vv))
    end
    r = Vector{T}(undef, h.n)
    h.dynamics!(r, t, xv, uv, vv)
    val = sum(pv_arg .* r)
    h.lagrange === nothing || (val += h.sp0 * h.lagrange(t, xv, uv, vv))
    return val
end

function (h::OCPPseudoHamiltonianFunction{_CTM_Auton,Traits.Fixed,DF,LF})(
    x,
    p,
    u,
) where {DF,LF}
    return _ocp_pseudo_H(h, 0.0, x, p, u, nothing)
end
function (h::OCPPseudoHamiltonianFunction{_CTM_NonAuton,Traits.Fixed,DF,LF})(
    t,
    x,
    p,
    u,
) where {DF,LF}
    return _ocp_pseudo_H(h, t, x, p, u, nothing)
end
function (h::OCPPseudoHamiltonianFunction{_CTM_Auton,Traits.NonFixed,DF,LF})(
    x,
    p,
    u,
    v,
) where {DF,LF}
    return _ocp_pseudo_H(h, 0.0, x, p, u, v)
end
function (h::OCPPseudoHamiltonianFunction{_CTM_NonAuton,Traits.NonFixed,DF,LF})(
    t,
    x,
    p,
    u,
    v,
) where {DF,LF}
    return _ocp_pseudo_H(h, t, x, p, u, v)
end

"""
$(TYPEDSIGNATURES)

Build an [`OCPPseudoHamiltonianFunction`](@ref) from an OCP and wrap it in a
[`CTBase.Data.PseudoHamiltonian`](@extref), giving the uniform `(t,x,p,u,v)` interface
used by the pseudo-Hamiltonian AD pipeline.

See also: [`OCPPseudoHamiltonianFunction`](@ref), `_ocp_hamiltonian`.
"""
function _ocp_pseudo_hamiltonian(ocp)
    n = CTModels.Models.state_dimension(ocp)
    dyn! = CTModels.Models.dynamics(ocp)
    sp0 = CTModels.Components.criterion(ocp) === :min ? -1.0 : 1.0
    lag = if CTModels.Components.has_lagrange_cost(ocp)
        CTModels.Components.lagrange(ocp)
    else
        nothing
    end
    TD = Traits.time_dependence(ocp)
    VD = Traits.variable_dependence(ocp)
    h_raw = OCPPseudoHamiltonianFunction{TD,VD,typeof(dyn!),typeof(lag)}(dyn!, lag, sp0, n)
    return Data.PseudoHamiltonian(h_raw, TD, VD)
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
- `CL`: type of the control law (`Nothing` for a control-free OCP, a
  `CTBase.Data.ControlLaw` when the flow was built from an OCP and a control law).

# Fields
- `flow::IF`: the inner Hamiltonian flow doing the integration.
- `ocp::M`: the optimal control problem, kept so trajectory calls can build a solution.
- `law::CL`: the control law, used to reconstruct `u(t)` along the trajectory (or
  `nothing` for control-free problems).

See also: [`CTFlows.Flows.Flow`](@ref), [`CTModels.Solutions.Solution`](@extref).
"""
struct OptimalControlFlow{
    TD<:Traits.TimeDependence,
    VD<:Traits.VariableDependence,
    IF,
    M,
    CL,
} <: AbstractFlow{TD,VD,Traits.HamiltonianDynamics}
    flow::IF    # inner HamiltonianFlow
    ocp::M
    law::CL
end

function OptimalControlFlow(
    flow::Flow{TD,VD,Traits.HamiltonianDynamics},
    ocp,
    law = nothing,
) where {TD,VD}
    return OptimalControlFlow{TD,VD,typeof(flow),typeof(ocp),typeof(law)}(flow, ocp, law)
end

system(F::OptimalControlFlow) = system(F.flow)
integrator(F::OptimalControlFlow) = integrator(F.flow)

# ── point eval — pure delegation ────────────────────────────────────────────

function (F::OptimalControlFlow)(
    t0::Real,
    x0,
    p0,
    tf::Real;
    variable = Core.NotProvided,
    variable_costate::Bool = false,
    unsafe::Bool = false,
)
    return F.flow(t0, x0, p0, tf; variable, variable_costate, unsafe)
end

# ── trajectory call — builds a CTModels.Solution ────────────────────────────

function (F::OptimalControlFlow)(
    tspan::Tuple{<:Real,<:Real},
    x0,
    p0;
    variable = Core.NotProvided,
    unsafe::Bool = false,
)
    sol = F.flow(tspan, x0, p0; variable, unsafe)   # HamiltonianVectorFieldTrajectory
    return _build_ocp_solution(F.ocp, sol, variable, integrator(F.flow), F.law)
end

# =============================================================================
# Solution helpers
# =============================================================================

"""
Convert a variable argument into a `Vector{Float64}`.

Returns an empty vector when the variable was not provided (`Core.NotProvided`),
a 1-element vector for scalars, and a copy for vectors.

See also: `_build_ocp_solution`, `_ocp_objective`.
"""
_variable_vector(::Core.NotProvidedType) = Float64[]
_variable_vector(v::Number) = [Float64(v)]
_variable_vector(v::AbstractVector) = Float64.(v)

"""
Reconstruct the control `u(t)` along a trajectory from a control law and the
state/costate projections. Returns `t -> Float64[]` when there is no control law
(control-free OCP), and `t -> law(t, x(t), p(t), v)` otherwise.

See also: `_ocp_objective`, `_build_ocp_solution`.
"""
_control_of(::Nothing, x, p, v) = (_ -> Float64[])
_control_of(law, x, p, v) = (t -> law(t, x(t), p(t), v))

"""
$(TYPEDSIGNATURES)

Compute the objective value (Mayer + Lagrange) of an OCP along a trajectory.

The Mayer term is evaluated at the endpoints `x(t0)` and `x(tf)`. The Lagrange term is
integrated by flowing `ℓ̇(t) = ℓ(t, x(t), u(t), v)` from `t0` to `tf`, where `u(t)` is
reconstructed from the control law (empty for a control-free OCP).

See also: `_build_ocp_solution`, `_control_of`, `_variable_vector`, [`CTFlows.Flows.Flow`](@ref).
"""
function _ocp_objective(ocp, x, p, v, t0, tf, integ, law)
    obj = 0.0
    if CTModels.Components.has_mayer_cost(ocp)
        may = CTModels.Components.mayer(ocp)
        obj += may(x(t0), x(tf), v)
    end
    if CTModels.Components.has_lagrange_cost(ocp)
        lag = CTModels.Components.lagrange(ocp)
        uc = _control_of(law, x, p, v)
        # Integrate ℓ̇(t) = lag(t, x(t), u(t), v) from t0 to tf.
        # Use a 1-element Vector so SciML always has a mutable in-place buffer.
        running = Data.VectorField(
            (t, ℓ_vec) -> [lag(t, x(t), _asvec(uc(t)), v)];
            is_autonomous = false,
            is_variable = false,
        )
        cost_flow = build_flow(Systems.build_system(running), integ)
        ℓ_tf = cost_flow(t0, [0.0], tf)   # returns [ℓ(tf)]
        obj += ℓ_tf[1]
    end
    return obj
end

"""
$(TYPEDSIGNATURES)

Build a `CTModels.Solution` from a `HamiltonianVectorFieldTrajectory`.

Extracts the time grid, state/costate projections, and variable vector from the
trajectory, computes the objective via `_ocp_objective`, and assembles a full
`CTModels.Solution` with empty control (control-free OCP).

See also: [`CTFlows.Flows.OptimalControlFlow`](@ref), `_ocp_objective`, `_variable_vector`, [`CTModels.Solutions.Solution`](@extref).
"""
function _build_ocp_solution(
    ocp,
    sol::Trajectories.HamiltonianVectorFieldTrajectory,
    variable,
    integ,
    law = nothing,
)
    T = collect(Float64, Trajectories.time_grid(sol))
    x = Trajectories.state(sol)    # callable StateProjection: t -> x(t)
    p = Trajectories.costate(sol)  # callable CostateProjection: t -> p(t)
    t0, tf = first(T), last(T)
    v = _variable_vector(variable)
    u = _control_of(law, x, p, v)  # empty for control-free; law(t,x,p,v) otherwise
    obj = _ocp_objective(ocp, x, p, v, t0, tf, integ, law)
    return CTModels.Solutions.build_solution(
        ocp,
        T,
        x,
        u,
        v,
        p;
        objective = obj,
        iterations = -1,
        constraints_violation = -1.0,
        message = "Solution computed by CTFlows OCP flow",
        status = :nostatusmessage,
        successful = true,
        control_interpolation = :linear,
    )
end
