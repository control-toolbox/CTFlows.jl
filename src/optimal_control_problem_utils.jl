function __is_min(ocp::CTModels.Model)
    return CTModels.criterion(ocp) == :min
end

function __dynamics(ocp::CTModels.Model)
    n = CTModels.state_dimension(ocp)
    dyn = (t, x, u, v) -> (r = zeros(eltype(x), n); CTModels.dynamics(ocp)(r, t, x, u, v); n==1 ? r[1] : r)
    return Dynamics(dyn, NonAutonomous, NonFixed)
end

function __lagrange(ocp::CTModels.Model)
    CTModels.has_lagrange_cost(ocp) || return nothing
    return Lagrange(CTModels.lagrange(ocp), NonAutonomous, NonFixed)
end

function __mayer(ocp::CTModels.Model)
    CTModels.has_mayer_cost(ocp) || return nothing
    return Mayer(CTModels.mayer(ocp), NonFixed)
end

# ---------------------------------------------------------------------------------------------------
function __create_hamiltonian(ocp::CTModels.Model, u::ControlLaw{<:Function,T,V}) where {T,V}
    f, f⁰, p⁰, s = __get_data_for_ocp_flow(ocp) # data
    @assert f ≠ nothing "no dynamics in ocp"
    h = Hamiltonian(f⁰ ≠ nothing ? makeH(f, u, f⁰, p⁰, s) : makeH(f, u), NonAutonomous, NonFixed)
    return h, u
end

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

function __create_hamiltonian(ocp::CTModels.Model, u::Function, g, μ; autonomous::Bool, variable::Bool)
    T, V = @match (autonomous, variable) begin
        (true, false)   => (Autonomous, Fixed)
        (true, true)    => (Autonomous, NonFixed)
        (false, false)  => (NonAutonomous, Fixed)
        _               => (NonAutonomous, NonFixed)
    end
    return __create_hamiltonian(ocp, ControlLaw(u, T, V), g, μ)
end

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

function __create_hamiltonian(
    ocp::CTModels.Model, u::ControlLaw{<:Function,T,V}, g::Function, μ
) where {T,V}
    return __create_hamiltonian(ocp, u, MixedConstraint(g, T, V), μ)
end

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

function __create_hamiltonian(
    ocp::CTModels.Model, u::ControlLaw{<:Function,T,V}, g::MixedConstraint{<:Function,T,V}, μ::Function
) where {T,V}
    return __create_hamiltonian(ocp, u, g, Multiplier(μ, T, V))
end

# ---------------------------------------------------------------------------------------------------
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

Constructs the Hamiltonian: 

H(t, x, p) = p f(t, x, u(t, x, p))
"""
function makeH(f::Dynamics, u::ControlLaw)
    return (t, x, p, v) -> p' * f(t, x, u(t, x, p, v), v)
end

"""
$(TYPEDSIGNATURES)

Constructs the Hamiltonian: 

H(t, x, p) = p ⋅ f(t, x, u(t, x, p)) + s p⁰ f⁰(t, x, u(t, x, p))
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

Constructs the Hamiltonian: 

H(t, x, p) = p ⋅ f(t, x, u(t, x, p)) + μ(t, x, p) ⋅ g(t, x, u(t, x, p))
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

Constructs the Hamiltonian: 

H(t, x, p) = p ⋅ f(t, x, u(t, x, p)) + s p⁰ f⁰(t, x, u(t, x, p)) + μ(t, x, p) ⋅ g(t, x, u(t, x, p))
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
