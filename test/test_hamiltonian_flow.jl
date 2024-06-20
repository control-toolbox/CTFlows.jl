function test_hamiltonian_flow()

    # g = CTFlows.myfun()
    # println(g(1))

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
        Σ = System(Hamiltonian(H))

        #
        HF = CTFlows._construct_flow(Σ, f!)
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
        HF(dz, convert_state(x0, p0), convert_variable(v), t0)
        @test dz ≈ [x0[2], p0[2], 0, -p0[1]] atol=1e-12

    end

    @testset "From Flow of System" begin

        #
        H(x, p) = p[1] * x[2] + p[2] * p[2] - 0.5 * p[2]^2    
        z = CTFlows.Flow(System(Hamiltonian(H)))

        #
        t0 = 0.0
        tf = 1.0
        x0 = [-1.0, 0.0]
        p0 = [12.0, 6.0]

        xf, pf = z(t0, x0, p0, tf)
        @test xf ≈ [0.0, 0.0] atol = 1e-5
        @test pf ≈ [12.0, -6.0] atol = 1e-5   

    end

    @testset "From Flow of a Hamiltonian: 2D autonomous, non variable" begin

        #
        H(x, p) = p[1] * x[2] + p[2] * p[2] - 0.5 * p[2]^2    
        z = Flow(Hamiltonian(H))

        #
        t0 = 0.0
        tf = 1.0
        x0 = [-1.0, 0.0]
        p0 = [12.0, 6.0]

        xf, pf = z(t0, x0, p0, tf)
        @test xf ≈ [0.0, 0.0] atol = 1e-5
        @test pf ≈ [12.0, -6.0] atol = 1e-5   

    end

    @testset "From Flow of a Hamiltonian: 2D non autonomous, variable" begin

        H(t, x, p, l) = p[1] * x[2] + p[2] * p[2] + 0.5 * l * p[2]^2
        z = Flow(Hamiltonian(H, autonomous=false, variable=true))

        t0 = 0.0
        tf = 1.0
        x0 = [-1.0, 0.0]
        p0 = [12.0, 6.0]

        xf, pf = z(t0, x0, p0, tf, -1.0)
        @test xf ≈ [0.0, 0.0] atol = 1e-5
        @test pf ≈ [12.0, -6.0] atol = 1e-5       

    end
 
    @testset "From Flow of a Hamiltonian: 1D autonomous, non variable" begin

        H1(x, p) = x^2 + p^2
        z = Flow(Hamiltonian(H1))

        x0 = 1.0
        p0 = 0.0

        xf, pf = z(0.0, x0, p0, 2π)
        @test xf ≈ x0 atol = 1e-5
        @test pf ≈ p0 atol = 1e-5

    end

    @testset "From Flow of a Hamiltonian vector field: 2D autonomous, non variable" begin

        #
        Hv(x, p) = [x[2], p[2]], [0.0, -p[1]]
        z = Flow(HamiltonianVectorField(Hv))

        #
        t0 = 0.0
        tf = 1.0
        x0 = [-1.0, 0.0]
        p0 = [12.0, 6.0]

        xf, pf = z(t0, x0, p0, tf)
        @test xf ≈ [0.0, 0.0] atol = 1e-5
        @test pf ≈ [12.0, -6.0] atol = 1e-5   

    end

    @testset "From Flow of a Hamiltonian vector field: 2D non autonomous, variable" begin

        Hv(t, x, p, l) = [x[2], (2+l)*p[2]], [0.0, -p[1]]
        z = Flow(HamiltonianVectorField(Hv, autonomous=false, variable=true))

        t0 = 0.0
        tf = 1.0
        x0 = [-1.0, 0.0]
        p0 = [12.0, 6.0]

        xf, pf = z(t0, x0, p0, tf, -1.0)
        @test xf ≈ [0.0, 0.0] atol = 1e-5
        @test pf ≈ [12.0, -6.0] atol = 1e-5       

    end
 
    @testset "From Flow of a Hamiltonian vector field: 1D autonomous, non variable" begin

        H1v(x, p) = 2p, -2x
        z = Flow(HamiltonianVectorField(H1v))

        x0 = 1.0
        p0 = 0.0

        xf, pf = z(0.0, x0, p0, 2π)
        @test xf ≈ x0 atol = 1e-5
        @test pf ≈ p0 atol = 1e-5
        
    end

end