abstract type AbstractSystem{X, V} end

function throw_not_implemented(function_name::String, Σ::AbstractSystem)
    str_exception_not_implemented = " must be implemented for system of type: "
	str = function_name * str_exception_not_implemented * string(typeof(Σ))
    throw(NotImplemented(str))
end

#
# API par défaut pour un AbstractSystem 
# ce sont les fonctions à définir si l'on veut redéfinir un système
default_variable(Σ::AbstractSystem) 		 = __variable   # throw_not_implemented("default_variable", Σ)
is_variable(Σ::AbstractSystem)      		 = false        # throw_not_implemented("is_variable", Σ)
convert_state_function(Σ::AbstractSystem)    = x->x         # throw_not_implemented("convert_state", Σ)
convert_variable_function(Σ::AbstractSystem) = x->x         # throw_not_implemented("convert_variable", Σ)
convert_ode_sol_function(Σ::AbstractSystem)  = x->x         # throw_not_implemented("convert_ode_sol", Σ)
convert_ode_u_function(Σ::AbstractSystem)    = x->x         # throw_not_implemented("convert_ode_u", Σ)
rhs(Σ::AbstractSystem, args...) 			 = Σ.rhs!       # throw_not_implemented("rhs", Σ)
#is_hamiltonian(Σ::AbstractSystem)   		 = false;
#is_vector_field(Σ::AbstractSystem)   		 = false;
# Fin API par défaut