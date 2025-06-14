"""
$(TYPEDSIGNATURES)

Return `true` if the given model defines a minimization problem, `false` otherwise.
"""
function __is_min(ocp::CTModels.Model)
    return CTModels.criterion(ocp) == :min
end

"""
$(TYPEDSIGNATURES)

Return a `Dynamics` object built from the model's right-hand side function.

The returned function computes the state derivative `dx/dt = f(t, x, u, v)`, 
wrapped to return either a scalar or vector depending on the model's state dimension.
"""
function __dynamics(ocp::CTModels.Model)
    n = CTModels.state_dimension(ocp)
    dyn = (t, x, u, v) -> (r = zeros(eltype(x), n); CTModels.dynamics(ocp)(r, t, x, u, v); n==1 ? r[1] : r)
    return Dynamics(dyn, NonAutonomous, NonFixed)
end

"""
$(TYPEDSIGNATURES)

Return a `Lagrange` object if the model includes an integrand cost; otherwise, return `nothing`.

The resulting function can be used to compute the running cost of the optimal control problem.
"""
function __lagrange(ocp::CTModels.Model)
    CTModels.has_lagrange_cost(ocp) || return nothing
    return Lagrange(CTModels.lagrange(ocp), NonAutonomous, NonFixed)
end

"""
$(TYPEDSIGNATURES)

Return a `Mayer` object if the model includes a terminal cost; otherwise, return `nothing`.

The resulting function can be used to compute the final cost in the objective.
"""
function __mayer(ocp::CTModels.Model)
    CTModels.has_mayer_cost(ocp) || return nothing
    return Mayer(CTModels.mayer(ocp), NonFixed)
end

# ---------------------------------------------------------------------------------------------------
"""
$(TYPEDSIGNATURES)

Construct and return the Hamiltonian for the given model and control law.

The Hamiltonian is built using model dynamics (and possibly a running cost) and returned as a callable function.

Returns a tuple `(H, u)` where `H` is the Hamiltonian function and `u` is the control law.
"""
function __create_hamiltonian(ocp::CTModels.Model, u::ControlLaw{<:Function,T,V}) where {T,V}
    f, f⁰, p⁰, s = __get_data_for_ocp_flow(ocp) # data
    @assert f ≠ nothing "no dynamics in ocp"
    h = Hamiltonian(f⁰ ≠ nothing ? makeH(f, u, f⁰, p⁰, s) : makeH(f, u), NonAutonomous, NonFixed)
    return h, u
end

"""
$(TYPEDSIGNATURES)

Helper method to construct the Hamiltonian when control is given as a plain function.

The function is wrapped in a `ControlLaw`, and the flags `autonomous` and `variable` define its behavior type.
"""
function __create_hamiltonian(ocp::CTModels.Model, u::Function; autonomous::Bool, variable::Bool)
    T, V = @match (autonomous, variable) begin
        (true, false)   => (Autonomous, Fixed)
        (true, true)    => (Autonomous, NonFixed)
        (false, false)  => (NonAutonomous, Fixed)
        _               => (NonAutonomous, NonFixed)
    end
    return __create_hamiltonian(ocp, ControlLaw(u, T, V))
end

# ---------------------------------------------------------------------------------------------------
"""
$(TYPEDSIGNATURES)

Construct the Hamiltonian for a constrained optimal control problem.

This function supports multiple input types for the control law (`u`), path constraints (`g`), and multipliers (`μ`), 
automatically adapting to autonomous/non-autonomous systems and fixed/non-fixed parameters.

# Supported input types

- `u` can be:
  - a raw function,
  - a `ControlLaw` object,
  - or a `FeedbackControl` object.

- `g` can be:
  - a plain constraint function,
  - a `MixedConstraint`,
  - or a `StateConstraint`.

- `μ` can be:
  - a function,
  - or a `Multiplier` object.

The function normalizes these inputs to the appropriate types internally using multiple dispatch and pattern matching.

# Arguments
- `ocp::CTModels.Model`: The continuous-time optimal control problem.
- `u`: Control law, flexible input type as described.
- `g`: Path constraint, flexible input type as described.
- `μ`: Multiplier associated with the constraints.
- `autonomous::Bool` (optional keyword): Specifies if the system is autonomous.
- `variable::Bool` (optional keyword): Specifies if the system parameters are variable.

# Returns
- `(H, u)`: Tuple containing the Hamiltonian object `H` and the processed control law `u`.

# Examples
```julia-repl
# Using a raw function control law with autonomous system and fixed parameters
H, u_processed = __create_hamiltonian(ocp, u_function, g_function, μ_function; autonomous=true, variable=false)

# Using a FeedbackControl control law
H, u_processed = __create_hamiltonian(ocp, feedback_control, g_constraint, μ_multiplier)
```
"""
function __create_hamiltonian(
    ocp::CTModels.Model,
    u::ControlLaw{<:Function,T,V},
    g::MixedConstraint{<:Function,T,V},
    μ::Multiplier{<:Function,T,V},
) where {T,V}
    f, f⁰, p⁰, s = __get_data_for_ocp_flow(ocp) # data
    @assert f ≠ nothing "no dynamics in ocp"
    h = Hamiltonian(
        f⁰ ≠ nothing ? makeH(f, u, f⁰, p⁰, s, g, μ) : makeH(f, u, g, μ),
        NonAutonomous,
        NonFixed,
    )
    return h, u
end

"""
$(TYPEDSIGNATURES)

Overload for control law as a raw function with autonomous and variable flags.
"""
function __create_hamiltonian(ocp::CTModels.Model, u::Function, g, μ; autonomous::Bool, variable::Bool)
    T, V = @match (autonomous, variable) begin
        (true, false)   => (Autonomous, Fixed)
        (true, true)    => (Autonomous, NonFixed)
        (false, false)  => (NonAutonomous, Fixed)
        _               => (NonAutonomous, NonFixed)
    end
    return __create_hamiltonian(ocp, ControlLaw(u, T, V), g, μ)
end

"""
$(TYPEDSIGNATURES)

Overload for feedback control laws that adapts the signature based on autonomy and variability.
"""
function __create_hamiltonian(
    ocp::CTModels.Model, u_::FeedbackControl{<:Function,T,V}, g, μ
) where {T,V}
    u = @match (T, V) begin
        (Autonomous, Fixed) => ControlLaw((x, p) -> u_(x), T, V)
        (Autonomous, NonFixed) => ControlLaw((x, p, v) -> u_(x, v), T, V)
        (NonAutonomous, Fixed) => ControlLaw((t, p, x) -> u_(t, x), T, V)
        (NonAutonomous, NonFixed) => ControlLaw((t, x, p, v) -> u_(t, x, v), T, V)
    end
    return __create_hamiltonian(ocp, u, g, μ)
end

"""
$(TYPEDSIGNATURES)

Overload that wraps plain constraint functions into MixedConstraint objects.
"""
function __create_hamiltonian(
    ocp::CTModels.Model, u::ControlLaw{<:Function,T,V}, g::Function, μ
) where {T,V}
    return __create_hamiltonian(ocp, u, MixedConstraint(g, T, V), μ)
end

"""
$(TYPEDSIGNATURES)

Overload that converts StateConstraint objects into MixedConstraint with appropriate signature adaptation.
"""
function __create_hamiltonian(
    ocp::CTModels.Model, u::ControlLaw{<:Function,T,V}, g_::StateConstraint{<:Function,T,V}, μ
) where {T,V}
    g = @match (T, V) begin
        (Autonomous, Fixed) => MixedConstraint((x, u) -> g_(x), T, V)
        (Autonomous, NonFixed) => MixedConstraint((x, u, v) -> g_(x, v), T, V)
        (NonAutonomous, Fixed) => MixedConstraint((t, x, u) -> g_(t, x), T, V)
        (NonAutonomous, NonFixed) => MixedConstraint((t, x, u, v) -> g_(t, x, v), T, V)
    end
    return __create_hamiltonian(ocp, u, g, μ)
end

"""
$(TYPEDSIGNATURES)

Overload that wraps multiplier functions into Multiplier objects.
"""
function __create_hamiltonian(
    ocp::CTModels.Model, u::ControlLaw{<:Function,T,V}, g::MixedConstraint{<:Function,T,V}, μ::Function
) where {T,V}
    return __create_hamiltonian(ocp, u, g, Multiplier(μ, T, V))
end

# ---------------------------------------------------------------------------------------------------
"""
$(TYPEDSIGNATURES)

Return internal components needed to construct the OCP Hamiltonian.

Returns a tuple `(f, f⁰, p⁰, s)` where:
- `f`  : system dynamics (`Dynamics`)
- `f⁰` : optional Lagrange integrand (`Lagrange` or `nothing`)
- `p⁰` : constant multiplier for cost (typically `-1`)
- `s`  : sign for minimization/maximization (`+1` or `-1`)
"""
function __get_data_for_ocp_flow(ocp::CTModels.Model)
    f = __dynamics(ocp)
    f⁰ = __lagrange(ocp)
    p⁰ = -1
    s = __is_min(ocp) ? 1.0 : -1.0
    return f, f⁰, p⁰, s
end

# ---------------------------------------------------------------------------------------------------
"""
$(TYPEDSIGNATURES)

Construct the Hamiltonian:

H(t, x, p) = p ⋅ f(t, x, u(t, x, p))

The function returns a callable `H(t, x, p, v)` where `v` is an optional additional parameter.
"""
function makeH(f::Dynamics, u::ControlLaw)
    return (t, x, p, v) -> p' * f(t, x, u(t, x, p, v), v)
end

"""
$(TYPEDSIGNATURES)

Construct the Hamiltonian:

H(t, x, p) = p ⋅ f(t, x, u(t, x, p)) + s p⁰ f⁰(t, x, u(t, x, p))

Includes a Lagrange integrand scaled by `p⁰` and sign `s`.
"""
function makeH(f::Dynamics, u::ControlLaw, f⁰::Lagrange, p⁰::ctNumber, s::ctNumber)
    function H(t, x, p, v)
        u_ = u(t, x, p, v)
        return p' * f(t, x, u_, v) + s * p⁰ * f⁰(t, x, u_, v)
    end
    return H
end

"""
$(TYPEDSIGNATURES)

Construct the Hamiltonian:

H(t, x, p) = p ⋅ f(t, x, u(t, x, p)) + μ(t, x, p) ⋅ g(t, x, u(t, x, p))

Includes state-control constraints and associated multipliers.
"""
function makeH(f::Dynamics, u::ControlLaw, g::MixedConstraint, μ::Multiplier)
    function H(t, x, p, v)
        u_ = u(t, x, p, v)
        return p' * f(t, x, u_, v) + μ(t, x, p, v)' * g(t, x, u_, v)
    end
    return H
end

"""
$(TYPEDSIGNATURES)

Construct the Hamiltonian:

H(t, x, p) = p ⋅ f(t, x, u(t, x, p)) 
           + s p⁰ f⁰(t, x, u(t, x, p)) 
           + μ(t, x, p) ⋅ g(t, x, u(t, x, p))

Combines integrand cost and path constraints.
"""
function makeH(
    f::Dynamics,
    u::ControlLaw,
    f⁰::Lagrange,
    p⁰::ctNumber,
    s::ctNumber,
    g::MixedConstraint,
    μ::Multiplier,
)
    function H(t, x, p, v)
        u_ = u(t, x, p, v)
        return p' * f(t, x, u_, v) +
               s * p⁰ * f⁰(t, x, u_, v) +
               μ(t, x, p, v)' * g(t, x, u_, v)
    end
    return H
end
