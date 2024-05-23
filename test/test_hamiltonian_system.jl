function test_hamiltonian_system()

    H(x, p) = p[1] * x[2] + p[2] * p[2] - 0.5 * p[2]^2    
    H = Hamiltonian(H)
    Σ = System(H)

    #
    @test Σ isa HamiltonianSystem
    @test !CTFlows.is_variable(Σ)
    @test CTFlows.state_type(Σ) == Tuple{State, Costate}
    @test CTFlows.variable_type(Σ) == Variable

    #
    __variable = CTFlows.default_variable(Σ)
    @test __variable() isa Vector{Real}

	# conversion
	convert_state    = CTFlows.convert_state_function(Σ)
	convert_variable = CTFlows.convert_variable_function(Σ)
	#convert_ode_sol  = CTFlows.convert_ode_sol_function(Σ)
	#convert_ode_u    = CTFlows.convert_ode_u_function(Σ)

    #
    x0 = [-1.0, 0.0]
    p0 = [12.0, 6.0]
    @test convert_state((x0, p0)) == [x0; p0]

    v = [1]
    @test convert_variable(v) == v

    # rhs
    rhs! = CTFlows.rhs(Σ)
    dz = similar(x0, 4)
    t0 = 0
    v  = __variable()
    rhs!(dz, convert_state((x0, p0)), convert_variable(v), t0)
    @test dz ≈ [x0[2], p0[2], 0, -p0[1]] atol=1e-12

end