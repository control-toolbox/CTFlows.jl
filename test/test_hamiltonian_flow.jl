function test_hamiltonian_flow()

    # file flows/hamiltonian.jl
    @testset "HamiltonianFlow" begin
        f(x; rhs) = rhs(x)
        rhs(x) = 2x

        HF = HamiltonianFlow(f, rhs)

        @test HF isa HamiltonianFlow
        @test HF(1) == 2
    end

    # 
    @testset "From HamiltonianSystem" begin

        # that's a dummy caller
        f!(dz, z, v, t; rhs) = rhs(dz, z, v, t)

        #
        H(x, p) = p[1] * x[2] + p[2] * p[2] - 0.5 * p[2]^2    
        H = Hamiltonian(H)
        Σ = System(H)

        #
        HF = CTFlows.construct_flow(Σ, f!)
        @test HF isa HamiltonianFlow

        #
        convert_state    = CTFlows.convert_state_function(Σ)
	    convert_variable = CTFlows.convert_variable_function(Σ)
        __variable = CTFlows.default_variable(Σ)

        #
        x0 = [-1.0, 0.0]
        p0 = [12.0, 6.0]
        dz = similar(x0, 4)
        t0 = 0
        v  = __variable()

        #
        HF(dz, convert_state((x0, p0)), convert_variable(v), t0)
        @test dz ≈ [x0[2], p0[2], 0, -p0[1]] atol=1e-12

    end

    @testset "From _Flow" begin

        #
        H = (x, p) -> p[1] * x[2] + p[2] * p[2] - 0.5 * p[2]^2    
        H = Hamiltonian(H)
        Σ = System(H)
        z = CTFlows._Flow(Σ)

        #
        t0 = 0.0
        tf = 1.0
        x0 = [-1.0, 0.0]
        p0 = [12.0, 6.0]

        xf, pf = z(t0, (x0, p0), tf)
        @test xf ≈ [0.0, 0.0] atol = 1e-5
        @test pf ≈ [12.0, -6.0] atol = 1e-5   

    end


    @testset "From Flow" begin

        #
        H = (x, p) -> p[1] * x[2] + p[2] * p[2] - 0.5 * p[2]^2    
        H = Hamiltonian(H)
        z = Flow(H)

        #
        t0 = 0.0
        tf = 1.0
        x0 = [-1.0, 0.0]
        p0 = [12.0, 6.0]

        xf, pf = z(t0, (x0, p0), tf)
        @test xf ≈ [0.0, 0.0] atol = 1e-5
        @test pf ≈ [12.0, -6.0] atol = 1e-5   

    end

end