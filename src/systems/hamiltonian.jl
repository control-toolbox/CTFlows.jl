"""
Hamiltonian system: the constructor builds the rhs.
"""
struct HamiltonianSystem <: AbstractSystem
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

#
System(H::AbstractHamiltonian) = HamiltonianSystem(H)
function is_variable(H::AbstractHamiltonian{time_dependence, variable_dependence}) where{time_dependence, variable_dependence}
    return variable_dependence==NonFixed
end

#
is_hamiltonian(Σ::HamiltonianSystem) = true;

state_type(Σ::HamiltonianSystem) = Tuple{State, Costate}

variable_type(Σ::HamiltonianSystem) = Variable

default_variable(Σ::HamiltonianSystem) = __variable

is_variable(Σ::HamiltonianSystem) = is_variable(Σ.H)

function convert_state_function(Σ::HamiltonianSystem) 
    convert((x, p)::Tuple{State,Costate}) = [x; p]
    return convert
end

function convert_variable_function(Σ::HamiltonianSystem)
    convert(v::Variable) = v 
    return convert
end

function convert_ode_sol_function(Σ::HamiltonianSystem)
    convert(sol) = sol
    return convert
end

function convert_ode_u_function(Σ::HamiltonianSystem)
    function convert(u)
        n = size(u, 1) ÷ 2
        return (u[rg(1,n)], u[rg(n+1,2n)])
    end 
    return convert
end

rhs(Σ::HamiltonianSystem) = Σ.rhs!