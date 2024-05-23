
abstract type AbstractFlow end
abstract type AbstractSystem end

function throw_not_implemented(function_name::String, Σ::AbstractSystem)
    str_exception_not_implemented = " must be implemented for system of type: "
	str = function_name * str_exception_not_implemented * string(typeof(Σ))
    throw(NotImplemented(str))
end

state_type(Σ::AbstractSystem)       = throw_not_implemented("state_type", Σ)
variable_type(Σ::AbstractSystem)    = throw_not_implemented("variable_type", Σ)
default_variable(Σ::AbstractSystem) = throw_not_implemented("default_variable", Σ)
is_variable(Σ::AbstractSystem)      = throw_not_implemented("is_variable", Σ)
convert_state(Σ::AbstractSystem)    = throw_not_implemented("convert_state", Σ)
convert_variable(Σ::AbstractSystem) = throw_not_implemented("convert_variable", Σ)
convert_ode_sol(Σ::AbstractSystem)  = throw_not_implemented("convert_ode_sol", Σ)
convert_ode_u(Σ::AbstractSystem)    = throw_not_implemented("convert_ode_u", Σ)
rhs(Σ::AbstractSystem, args...) 	= throw_not_implemented("rhs", Σ)
is_hamiltonian(Σ::AbstractSystem)   = false;

"""
$(TYPEDSIGNATURES)

Return a flow from a system. It mainly constructs the caller for the flow.
"""
function _Flow(Σ::AbstractSystem, args...; alg=__alg(), abstol=__abstol(), 
    reltol=__reltol(), saveat=__saveat(), kwargs_Flow...)::AbstractFlow

    # state and variable types
	XType = state_type(Σ)
	VType = variable_type(Σ)
	
	# default variable from the system
	__variable = default_variable(Σ)
	
	# conversion
	convert_state    = convert_state_function(Σ)
	convert_variable = convert_variable_function(Σ)
	convert_ode_sol  = convert_ode_sol_function(Σ)
	convert_ode_u    = convert_ode_u_function(Σ)

	#
	function _f(tspan::Tuple{Time,Time}, x0, v=__variable(); rhs, kwargs...)

		# check types 
		x0 isa XType || throw(IncorrectArgument("x0 must be of type: " + XType))
		v  isa VType || throw(IncorrectArgument("v must be of type: "  + VType))

		# ode
		ode = OrdinaryDiffEq.ODEProblem(rhs, convert_state(x0), tspan, convert_variable(v))

		# solve
		sol = OrdinaryDiffEq.solve( ode, 
                                    alg=alg, abstol=abstol, reltol=reltol, saveat=saveat, 
                                    kwargs_Flow..., kwargs... )
        #
        return convert_ode_sol(sol)
	end
	#
	function _f(t0::Time, x0, tf::Time, v=__variable(); kwargs...)
		sol = _f((t0, tf), x0, v; kwargs...)
		return convert_ode_u(sol(tf))
	end

	# si le système est Fixed, on ne permet pas de fournir une variable
	if is_variable(Σ)
		return construct_flow(Σ, _f)
	else
		function f(tspan::Tuple{Time,Time}, x0; rhs, kwargs...)
			return _f(tspan, x0, __variable(); rhs, kwargs...)
		end
		function f(t0::Time, x0, tf::Time; kwargs...)
			return _f(t0, x0, tf, __variable(); kwargs...)
		end
		return construct_flow(Σ, f)
	end

end

"""
$(TYPEDSIGNATURES)

Construct the flow depending on the traits of the system
"""
function construct_flow(Σ::AbstractSystem, f, args...)::AbstractFlow

	# second membre: doit être conforme à OrdinaryDiffEq.jl
	rhs! = rhs(Σ, args...) # pour un ocp, il y a u dans args...

	if is_hamiltonian(Σ)
		return HamiltonianFlow(f, rhs!)
	else 
		throw(error("The system must be: Hamiltonian."))
	end

end

# --------------------------------------------------------------------------------------------
# Flow from a Hamiltonian
function Flow(H::AbstractHamiltonian; alg=__alg(), abstol=__abstol(), 
    reltol=__reltol(), saveat=__saveat(), kwargs_Flow...)::AbstractFlow
    #
	return _Flow(System(H); alg=alg, abstol=abstol, reltol=reltol, saveat=saveat, kwargs_Flow...)
end