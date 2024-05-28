
abstract type AbstractFlow end
abstract type AbstractSystem{X, V} end

function throw_not_implemented(function_name::String, Σ::AbstractSystem)
    str_exception_not_implemented = " must be implemented for system of type: "
	str = function_name * str_exception_not_implemented * string(typeof(Σ))
    throw(NotImplemented(str))
end

#
# API par défaut pour un AbstractSystem 
# ce sont les fonctions à définir si l'on veut redéfinir un système
default_variable(Σ::AbstractSystem) = __variable # throw_not_implemented("default_variable", Σ)
is_variable(Σ::AbstractSystem)      = false #throw_not_implemented("is_variable", Σ)
convert_state(Σ::AbstractSystem)    = x->x #throw_not_implemented("convert_state", Σ)
convert_variable(Σ::AbstractSystem) = x->x #throw_not_implemented("convert_variable", Σ)
convert_ode_sol(Σ::AbstractSystem)  = x->x #throw_not_implemented("convert_ode_sol", Σ)
convert_ode_u(Σ::AbstractSystem)    = x->x #throw_not_implemented("convert_ode_u", Σ)
rhs(Σ::AbstractSystem, args...) 	= Σ.rhs! #throw_not_implemented("rhs", Σ)
is_hamiltonian(Σ::AbstractSystem)   = false;
# Fin API par défaut


# macro _flow_function_fixed(f, _f, __variable)
# 	q1 = :(
# 		function $f(tspan::Tuple{Time,Time}, x0; rhs, kwargs...)
# 			return $_f(tspan, x0, $__variable(); rhs, kwargs...)
# 		end
# 	)
# 	#
# 	q2 = :(
# 		function $f(t0::Time, x0, tf::Time; kwargs...)
# 			return $_f(t0, x0, tf, $__variable(); kwargs...)
# 		end
# 	)
# 	#
# 	code = Expr(:block, q1, q2)
# 	esc(code)
# end

"""
$(TYPEDSIGNATURES)

Construct the flow depending on the traits of the system
"""
function _construct_flow(Σ::AbstractSystem, f, args...)::AbstractFlow

	# second membre: doit être conforme à OrdinaryDiffEq.jl
	rhs! = rhs(Σ, args...) # pour un ocp, il y a u dans args...

	if is_hamiltonian(Σ)
		return HamiltonianFlow(f, rhs!)
	else 
		throw(error("The system must be: Hamiltonian."))
	end

end

"""
$(TYPEDSIGNATURES)

Core of the flow
"""
function _core_flow(tspan, x0, v, rhs, alg, abstol, reltol, saveat; kwargs...)

	# ode
	ode = OrdinaryDiffEq.ODEProblem(rhs, x0, tspan, v)

	# solve
	sol = OrdinaryDiffEq.solve( ode, alg=alg, abstol=abstol, reltol=reltol, saveat=saveat; kwargs...)

	return sol

end

let
	n = 2
	x = ( :(X1), )
	for i=2:n 
		x = (x..., Symbol("X", string(i)))
	end
	e_tuple = Expr(:curly, :(Tuple), x...)
	e_call  = :( g(Σ::$e_tuple, n::Int)::Int )
	e_where = Expr(:where, e_call, x...)
	e_core  = quote 
		return n
	end
	e_fun   = Expr(:function, e_where, e_core)
	eval(e_fun)
	g((1, 2), 3)
end

"""
$(TYPEDSIGNATURES)

Return a flow from a system. It mainly constructs the caller for the flow.
"""
function Flow(Σ::AbstractSystem{Tuple{X1, X2}, V}, args...; alg=__alg(), abstol=__abstol(), reltol=__reltol(), 
	saveat=__saveat(), kwargs_Flow...)::AbstractFlow where {X1, X2, V}
	
	# default variable from the system
	__variable = default_variable(Σ)
	
	# conversion
	convert_state    = convert_state_function(Σ)
	convert_variable = convert_variable_function(Σ)
	convert_ode_sol  = convert_ode_sol_function(Σ)
	convert_ode_u    = convert_ode_u_function(Σ)

	# 
	if is_variable(Σ)

		function f_variable(tspan::Tuple{Time,Time}, x01::X1, x02::X2, v::V=__variable(); rhs, kwargs...)
			sol = _core_flow(tspan, convert_state(x01, x02), convert_variable(v), 
				rhs, alg, abstol, reltol, saveat; kwargs_Flow..., kwargs...)
			return convert_ode_sol(sol)
		end

		function f_variable(t0::Time, x01::X1, x02::X2, tf::Time, v::V=__variable(); rhs, kwargs...)
			sol = _core_flow((t0, tf), convert_state(x01, x02), convert_variable(v), 
				rhs, alg, abstol, reltol, saveat; kwargs_Flow..., kwargs...)
			return convert_ode_u(sol(tf))
		end

	 	return _construct_flow(Σ, f_variable)

	else # si le système est Fixed, on ne permet pas de fournir une variable
	
		function f_fixed(tspan::Tuple{Time,Time}, x01::X1, x02::X2; rhs, kwargs...)
			sol = _core_flow(tspan, convert_state(x01, x02), convert_variable(__variable()), 
				rhs, alg, abstol, reltol, saveat; kwargs_Flow..., kwargs...)
			return convert_ode_sol(sol)
		end

		function f_fixed(t0::Time, x01::X1, x02::X2, tf::Time; rhs, kwargs...)
			sol = _core_flow((t0, tf), convert_state(x01, x02), convert_variable(__variable()), 
				rhs, alg, abstol, reltol, saveat; kwargs_Flow..., kwargs...)
			return convert_ode_u(sol(tf))
		end

		return _construct_flow(Σ, f_fixed)

	end

end

"""
$(TYPEDSIGNATURES)

Return a flow from a system. It mainly constructs the caller for the flow.
"""
function Flow(Σ::AbstractSystem{X, V}, args...; alg=__alg(), abstol=__abstol(), reltol=__reltol(), 
		saveat=__saveat(), kwargs_Flow...)::AbstractFlow where {X, V}
	
	# default variable from the system
	__variable = default_variable(Σ)
	
	# conversion
	convert_state    = convert_state_function(Σ)
	convert_variable = convert_variable_function(Σ)
	convert_ode_sol  = convert_ode_sol_function(Σ)
	convert_ode_u    = convert_ode_u_function(Σ)

	# 
	if is_variable(Σ)

		function f_variable(tspan::Tuple{Time,Time}, x0::X, v::V=__variable(); rhs, kwargs...)
			sol = _core_flow(tspan, convert_state(x0), convert_variable(v), 
				rhs, alg, abstol, reltol, saveat; kwargs_Flow..., kwargs...)
			return convert_ode_sol(sol)
		end

		function f_variable(t0::Time, x0::X, tf::Time, v::V=__variable(); rhs, kwargs...)
			sol = _core_flow((t0, tf), convert_state(x0), convert_variable(v), 
				rhs, alg, abstol, reltol, saveat; kwargs_Flow..., kwargs...)
			return convert_ode_u(sol(tf))
		end

	 	return _construct_flow(Σ, f_variable)

	else # si le système est Fixed, on ne permet pas de fournir une variable
	
		function f_fixed(tspan::Tuple{Time,Time}, x0::X; rhs, kwargs...)
			sol = _core_flow(tspan, convert_state(x0), convert_variable(__variable()), 
				rhs, alg, abstol, reltol, saveat; kwargs_Flow..., kwargs...)
			return convert_ode_sol(sol)
		end

		function f_fixed(t0::Time, x0::X, tf::Time; rhs, kwargs...)
			sol = _core_flow((t0, tf), convert_state(x0), convert_variable(__variable()), 
				rhs, alg, abstol, reltol, saveat; kwargs_Flow..., kwargs...)
			return convert_ode_u(sol(tf))
		end

		return _construct_flow(Σ, f_fixed)

	end

end

# --------------------------------------------------------------------------------------------
# Flow from a Hamiltonian
function Flow(H::AbstractHamiltonian; alg=__alg(), abstol=__abstol(), 
    	reltol=__reltol(), saveat=__saveat(), kwargs_Flow...)::HamiltonianFlow
	return Flow(System(H); alg=alg, abstol=abstol, reltol=reltol, saveat=saveat, kwargs_Flow...)
end