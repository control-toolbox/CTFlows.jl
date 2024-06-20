abstract type AbstractFlow end

"""
$(TYPEDSIGNATURES)

Construct the flow depending on the traits of the system
"""
function _construct_flow(Σ::AbstractVectorFieldSystem, f, args...)::VectorFieldFlow
	return VectorFieldFlow(f, rhs(Σ, args...))
end

"""
$(TYPEDSIGNATURES)

Construct the flow depending on the traits of the system
"""
function _construct_flow(Σ::AbstractHamiltonianSystem, f, args...)::HamiltonianFlow
	return HamiltonianFlow(f, rhs(Σ, args...))
end

"""
$(TYPEDSIGNATURES)

Core of the flow
"""
function _core_flow(tspan, x0, v, rhs, alg, abstol, reltol, saveat; kwargs...)

	ode = OrdinaryDiffEq.ODEProblem(rhs, x0, tspan, v)
	sol = OrdinaryDiffEq.solve(ode, alg=alg, abstol=abstol, reltol=reltol, saveat=saveat; kwargs...)
	return sol

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

	 	return _construct_flow(Σ, f_variable, args...)

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

		return _construct_flow(Σ, f_fixed, args...)

	end

end

let

	for n ∈ 2:4

		# tuple {X1, X2, ...}
		x = ( Symbol("X", string(i)) for i ∈ 1:n )
		flow_tuple = Expr(:curly, :(Tuple), x...)

		# signature of Flow
		flow_call =  :( 
			Flow(Σ::AbstractSystem{$flow_tuple, V}, args...; alg=__alg(), abstol=__abstol(), reltol=__reltol(), 
			saveat=__saveat(), kwargs_Flow...)::AbstractFlow
		)

		# definition of the function Flow with "where" keyword	
		flow_where = Expr(:where, flow_call, x..., :(V))

		# first part of the core of the function Flow
		flow_core_1  = quote 
			# default variable from the system
			__variable = default_variable(Σ)
			
			# conversion
			convert_state    = convert_state_function(Σ)
			convert_variable = convert_variable_function(Σ)
			convert_ode_sol  = convert_ode_sol_function(Σ)
			convert_ode_u    = convert_ode_u_function(Σ)
		end

		#
		X_args_f = ( Expr(:(::), Symbol(:(x0), string(i)), Symbol(:(X), string(i))) for i ∈ 1:n)
		X_args_c =  ( Symbol(:(x0), string(i)) for i ∈ 1:n)

		# f_variable 1/2
		f_variable_call = Expr(:call, :(f_variable), 
					Expr(:parameters, :(rhs), :(kwargs...)),
					:(tspan::Tuple{Time,Time}), X_args_f...,
					Expr(:kw, :(v::V), :(__variable())))

		f_variable_convert_state = Expr(:call, :(convert_state), X_args_c...)
		f_variable_core = quote 
			sol = _core_flow(tspan, $f_variable_convert_state, convert_variable(v), 
					rhs, alg, abstol, reltol, saveat; kwargs_Flow..., kwargs...)
			return convert_ode_sol(sol)
		end
		f_variable_fun_1 = Expr(:function, f_variable_call, f_variable_core)

		# f_variable 2/2
		f_variable_call = Expr(:call, :(f_variable), 
					Expr(:parameters, :(rhs), :(kwargs...)),
					:(t0::Time), X_args_f..., :(tf::Time),
					Expr(:kw, :(v::V), :(__variable())))

		f_variable_convert_state = Expr(:call, :(convert_state), X_args_c...)
		f_variable_core = quote 
			sol = _core_flow((t0, tf), $f_variable_convert_state, convert_variable(v), 
					rhs, alg, abstol, reltol, saveat; kwargs_Flow..., kwargs...)
			return convert_ode_u(sol(tf))
		end
		f_variable_fun_2 = Expr(:function, f_variable_call, f_variable_core)

		# f_fixed 1/2
		f_fixed_call = Expr(:call, :(f_fixed), 
					Expr(:parameters, :(rhs), :(kwargs...)),
					:(tspan::Tuple{Time,Time}), X_args_f...)

		f_fixed_convert_state = Expr(:call, :(convert_state), X_args_c...)
		f_fixed_core = quote 
			sol = _core_flow(tspan, $f_fixed_convert_state, convert_variable(__variable()), 
					rhs, alg, abstol, reltol, saveat; kwargs_Flow..., kwargs...)
			return convert_ode_sol(sol)
		end
		f_fixed_fun_1 = Expr(:function, f_fixed_call, f_fixed_core)

		# f_fixed 2/2
		f_fixed_call = Expr(:call, :(f_fixed), 
					Expr(:parameters, :(rhs), :(kwargs...)),
					:(t0::Time), X_args_f..., :(tf::Time),)

		f_fixed_convert_state = Expr(:call, :(convert_state), X_args_c...)
		f_fixed_core = quote 
			sol = _core_flow((t0, tf), $f_fixed_convert_state, convert_variable(__variable()), 
					rhs, alg, abstol, reltol, saveat; kwargs_Flow..., kwargs...)
			return convert_ode_u(sol(tf))
		end
		f_fixed_fun_2 = Expr(:function, f_fixed_call, f_fixed_core)

		# flow core 2
		flow_core_2 = quote
			if is_variable(Σ)

				$f_variable_fun_1
		
				$f_variable_fun_2
		
				return _construct_flow(Σ, f_variable, args...)
		
			else # si le système est Fixed, on ne permet pas de fournir une variable
			
				$f_fixed_fun_1
		
				$f_fixed_fun_2
		
				return _construct_flow(Σ, f_fixed, args...)
		
			end
		end

		# Core of the Flow function
		flow_core = Expr(:block, flow_core_1, flow_core_2)

		# Flow function
		flow_fun  = Expr(:function, flow_where, flow_core)

		#
		eval(flow_fun)

	end # end for
end # end let

# --------------------------------------------------------------------------------------------
# Flow from a Hamiltonian, Hamiltonian vector field, vector field
function Flow(S::Union{AbstractHamiltonian, HamiltonianVectorField, VectorField}; 
	alg=__alg(), 
	abstol=__abstol(), 
    reltol=__reltol(), 
	saveat=__saveat(), 
	kwargs_Flow...)::AbstractFlow
	return Flow(System(S); alg=alg, abstol=abstol, reltol=reltol, saveat=saveat, kwargs_Flow...)
end

# --------------------------------------------------------------------------------------------
# Flow from a Function
function Flow(f::Function;
	autonomous::Bool=true, 
	variable::Bool=false, 
	XType::Type=Any, 
	VType::Type=Any,
	alg=__alg(), 
	abstol=__abstol(), 
    reltol=__reltol(), 
	saveat=__saveat(), 
	kwargs_Flow...)::AbstractFlow
	G = GeneralVectorField(f; autonomous=autonomous, variable=variable, XType=XType, VType=VType)
	return Flow(System(G); alg=alg, abstol=abstol, reltol=reltol, saveat=saveat, kwargs_Flow...)
end
