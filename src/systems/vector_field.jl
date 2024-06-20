abstract type AbstractVectorFieldSystem{X, V} <: AbstractSystem{X, V} end

"""
Vector field system: the constructor builds the rhs.
"""
struct VectorFieldSystem{X, V} <: AbstractVectorFieldSystem{X, V}

    V::VectorField  # soit on passe un VectorField de CTBase
    rhs!::Function  # OrdinaryDiffEq rhs

    function VectorFieldSystem(V::VectorField)
        function rhs!(dx::DState, x::State, v::Variable, t::Time)
            dx[:]  = V(t, x, v)
        end
        return new{State, Variable}(V, rhs!)
    end
end

"""
Vector field system: the constructor builds the rhs.
"""
struct GeneralVectorFieldSystem{X, V} <: AbstractVectorFieldSystem{X, V}

    G::GeneralVectorField   # soit on passe une CTFunction
    rhs!::Function          # OrdinaryDiffEq rhs

    function GeneralVectorFieldSystem(G::GeneralVectorField{TD, VD, XT, VT}) where {TD, VD, XT, VT}
        rhs! = @match (TD==NonAutonomous, VD==NonFixed) begin
            (true,  true ) => ((dx, x, v, t::Time) -> dx .= G(t, x, v))
            (true,  false) => ((dx, x, v, t::Time) -> dx .= G(t, x))
            (false, true ) => ((dx, x, v, t::Time) -> dx .= G(x, v))
            (false, false) => ((dx, x, v, t::Time) -> dx .= G(x))
        end
        return new{XT, VT}(G, rhs!)
    end

end

#
System(V::VectorField) = VectorFieldSystem(V)
System(G::GeneralVectorField) = GeneralVectorFieldSystem(G)

#
is_variable(Σ::VectorFieldSystem) = is_variable(Σ.V)
is_variable(Σ::GeneralVectorFieldSystem) = is_variable(Σ.G)

#
#is_vector_field(Σ::VectorFieldSystem) = true

#
function convert_state_function(Σ::AbstractVectorFieldSystem{X, V}) where {X, V} 
    convert(x::X) = x
    #convert(x::ctNumber) = [x]
    return convert
end

function convert_variable_function(Σ::AbstractVectorFieldSystem{X, V}) where {X, V}
    convert(v::V) = v 
    return convert
end

function convert_ode_sol_function(Σ::AbstractVectorFieldSystem)
    convert(sol) = sol
    return convert
end

function convert_ode_u_function(Σ::AbstractVectorFieldSystem)
    convert(u::Any) = u
    convert(u::Vector{<:ctNumber}) = ( length(u) == 1 ? u[1] : u )
    return convert
end