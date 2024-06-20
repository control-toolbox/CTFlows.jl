abstract type AbstractHamiltonianSystem <: AbstractSystem{Tuple{State, Costate}, Variable} end

"""
Hamiltonian system: the constructor builds the rhs.
"""
struct HamiltonianSystem <: AbstractHamiltonianSystem

    H::AbstractHamiltonian
    rhs!::Function    # OrdinaryDiffEq rhs

    function HamiltonianSystem(H::AbstractHamiltonian)
        function rhs!(dz::DCoTangent, z::CoTangent, v::Variable, t::Time)
            n      = size(z, 1) ÷ 2
            foo(z) = H(t, z[rg(1,n)], z[rg(n+1,2n)], v)
            dh     = ctgradient(foo, z)
            dz[1:n]    =  dh[n+1:2n]
            dz[n+1:2n] = -dh[1:n]
        end
        return new(H, rhs!)
    end

end

"""
Hamiltonian system: the constructor builds the rhs.
"""
struct HamiltonianVectorFieldSystem <: AbstractHamiltonianSystem

    Hv::HamiltonianVectorField # il faudrait peut-être avoir un AbstractHamiltonianVectorField
    rhs!::Function    # OrdinaryDiffEq rhs

    function HamiltonianVectorFieldSystem(Hv::HamiltonianVectorField)
        function rhs!(dz::DCoTangent, z::CoTangent, v::Variable, t::Time)
            n = size(z, 1) ÷ 2
            dz[rg(1, n)], dz[rg(n+1, 2n)] = Hv(t, z[rg(1,n)], z[rg(n+1,2n)], v)
        end
        return new(Hv, rhs!)
    end
end

#
System(H::AbstractHamiltonian) = HamiltonianSystem(H)
System(Hv::HamiltonianVectorField) = HamiltonianVectorFieldSystem(Hv)

#
is_variable(Σ::HamiltonianSystem) = is_variable(Σ.H)
is_variable(Σ::HamiltonianVectorFieldSystem) = is_variable(Σ.Hv)

#
#is_hamiltonian(Σ::AbstractHamiltonianSystem) = true;

#
function convert_state_function(Σ::AbstractHamiltonianSystem) 
    convert(x::State, p::Costate) = [x; p]
    return convert
end

function convert_variable_function(Σ::AbstractHamiltonianSystem)
    convert(v::Variable) = v 
    return convert
end

function convert_ode_sol_function(Σ::AbstractHamiltonianSystem)
    convert(sol) = sol
    return convert
end

function convert_ode_u_function(Σ::AbstractHamiltonianSystem)
    function convert(u)
        n = size(u, 1) ÷ 2
        return u[rg(1,n)], u[rg(n+1,2n)]
    end 
    return convert
end