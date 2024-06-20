# ---------------------------------------------------------------------------------------------------
function __create_hamiltonian(ocp::OptimalControlModel{T, V}, u::ControlLaw{T, V}) where {T, V}
    f, f⁰, p⁰, s = __get_data_for_ocp_flow(ocp) # data
    @assert f ≠ nothing "no dynamics in ocp"
    h = Hamiltonian(f⁰ ≠ nothing ? makeH(f, u, f⁰, p⁰, s) : makeH(f, u), NonAutonomous, NonFixed)
    return h, u
end

function __create_hamiltonian(ocp::OptimalControlModel{T, V}, u::Function) where {T, V}
    return __create_hamiltonian(ocp, ControlLaw(u, T, V))
end

# ---------------------------------------------------------------------------------------------------
function __create_hamiltonian(ocp::OptimalControlModel{T, V}, u::ControlLaw{T, V}, g::MixedConstraint{T, V}, μ::Multiplier{T, V}) where {T, V}
    f, f⁰, p⁰, s = __get_data_for_ocp_flow(ocp) # data
    @assert f ≠ nothing "no dynamics in ocp"
    h = Hamiltonian(f⁰ ≠ nothing ? makeH(f, u, f⁰, p⁰, s, g, μ) : makeH(f, u, g, μ), NonAutonomous, NonFixed)
    return h, u
end

function __create_hamiltonian(ocp::OptimalControlModel{T, V}, u::Function, g, μ) where {T, V}
    return __create_hamiltonian(ocp, ControlLaw(u, T, V), g, μ)
end

function __create_hamiltonian(ocp::OptimalControlModel{T, V}, u_::FeedbackControl{T, V}, g, μ) where {T, V}
    u = @match (T, V) begin
        (Autonomous, Fixed)       => ControlLaw((x, p) -> u_(x), T, V)
        (Autonomous, NonFixed)    => ControlLaw((x, p, v) -> u_(x, v), T, V)
        (NonAutonomous, Fixed)    => ControlLaw((t, p, x) -> u_(t, x), T, V)
        (NonAutonomous, NonFixed) => ControlLaw((t, x, p, v) -> u_(t, x, v), T, V)
    end
    return __create_hamiltonian(ocp, u, g, μ)
end

function __create_hamiltonian(ocp::OptimalControlModel{T, V}, u::ControlLaw{T, V}, g::Function, μ) where {T, V}
    return __create_hamiltonian(ocp, u, MixedConstraint(g, T, V), μ)
end

function __create_hamiltonian(ocp::OptimalControlModel{T, V}, u::ControlLaw{T, V}, g_::StateConstraint{T, V}, μ) where {T, V}
    g = @match (T, V) begin
        (Autonomous, Fixed)       => MixedConstraint((x, u) -> g_(x), T, V)
        (Autonomous, NonFixed)    => MixedConstraint((x, u, v) -> g_(x, v), T, V)
        (NonAutonomous, Fixed)    => MixedConstraint((t, x, u) -> g_(t, x), T, V)
        (NonAutonomous, NonFixed) => MixedConstraint((t, x, u, v) -> g_(t, x, v), T, V)
    end
    return __create_hamiltonian(ocp, u, g, μ)
end

function __create_hamiltonian(ocp::OptimalControlModel{T, V}, u::ControlLaw{T, V}, g::MixedConstraint{T, V}, μ::Function) where {T, V}
    return __create_hamiltonian(ocp, u, g, Multiplier(μ, T, V))
end

# ---------------------------------------------------------------------------------------------------
function __get_data_for_ocp_flow(ocp::OptimalControlModel)
    f  = ocp.dynamics
    f⁰ = ocp.lagrange
    p⁰ = -1
    s  = is_min(ocp) ? 1.0 : -1.0
    return f, f⁰, p⁰, s
end

# ---------------------------------------------------------------------------------------------------
"""
$(TYPEDSIGNATURES)

Constructs the Hamiltonian: 

H(t, x, p) = p f(t, x, u(t, x, p))
"""
function makeH(f::Dynamics, u::ControlLaw)
    return (t, x, p, v) -> p'*f(t, x, u(t, x, p, v), v)
end

"""
$(TYPEDSIGNATURES)

Constructs the Hamiltonian: 

H(t, x, p) = p ⋅ f(t, x, u(t, x, p)) + s p⁰ f⁰(t, x, u(t, x, p))
"""
function makeH(f::Dynamics, u::ControlLaw, f⁰::Lagrange, p⁰::ctNumber, s::ctNumber)
    function H(t, x, p, v)
        u_ = u(t, x, p, v)
        return p'*f(t, x, u_, v) + s*p⁰*f⁰(t, x, u_, v)
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
        return p'*f(t, x, u_, v) + μ(t, x, p, v)'*g(t, x, u_, v)
    end
    return H
end

"""
$(TYPEDSIGNATURES)

Constructs the Hamiltonian: 

H(t, x, p) = p ⋅ f(t, x, u(t, x, p)) + s p⁰ f⁰(t, x, u(t, x, p)) + μ(t, x, p) ⋅ g(t, x, u(t, x, p))
"""
function makeH(f::Dynamics, u::ControlLaw, f⁰::Lagrange, p⁰::ctNumber, s::ctNumber, g::MixedConstraint, μ::Multiplier)
    function H(t, x, p, v)
        u_ = u(t, x, p, v)
        return p'*f(t, x, u_, v) + s*p⁰*f⁰(t, x, u_, v) + μ(t, x, p, v)'*g(t, x, u_, v)
    end
    return H
end