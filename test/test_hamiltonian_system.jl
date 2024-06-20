function test_hamiltonian_system()

    # From Hamiltonian

    @testset "From Hamiltonian: 2D autonomous, non variable" begin

        H(x, p) = p[1] * x[2] + p[2] * p[2] - 0.5 * p[2]^2    
        Σ = System(Hamiltonian(H))

        #
        @test Σ isa HamiltonianSystem
        @test !CTFlows.is_variable(Σ)
        #@test CTFlows.is_hamiltonian(Σ)

        #
        __variable = CTFlows.default_variable(Σ)
        @test __variable() isa Vector{Real}

        # conversion
        convert_state    = CTFlows.convert_state_function(Σ)
        convert_variable = CTFlows.convert_variable_function(Σ)

        #
        x0 = [-1.0, 0.0]
        p0 = [12.0, 6.0]
        @test convert_state(x0, p0) == [x0; p0]

        v = [1]
        @test convert_variable(v) == v

        # rhs
        rhs! = CTFlows.rhs(Σ)
        dz = similar(x0, 4)
        t0 = 0
        v  = __variable()
        rhs!(dz, convert_state(x0, p0), convert_variable(v), t0)
        @test dz ≈ [x0[2], p0[2], 0, -p0[1]] atol=1e-12

    end

    @testset "From Hamiltonian: 2D non autonomous, variable" begin

        H(t, x, p, v) = -(t+v) * x[1] + p[1] * x[2] + p[2] * p[2] - 0.5 * p[2]^2
        Σ = System(Hamiltonian(H, autonomous=false, variable=true))

        #
        @test Σ isa HamiltonianSystem
        @test CTFlows.is_variable(Σ)
        #@test CTFlows.is_hamiltonian(Σ)

        # conversion
        convert_state    = CTFlows.convert_state_function(Σ)
        convert_variable = CTFlows.convert_variable_function(Σ)

        # rhs
        x0 = [-1.0, 0.0]
        p0 = [12.0, 6.0]
        rhs! = CTFlows.rhs(Σ)
        dz = similar(x0, 4)
        t0 = 1
        v  = 2
        rhs!(dz, convert_state(x0, p0), convert_variable(v), t0)
        @test dz ≈ [x0[2], p0[2], t0+v, -p0[1]] atol=1e-12 

    end

    @testset "From Hamiltonian: 1D autonomous, non variable" begin

        H(x, p, v) = x^2 + p^2 + x*v
        Σ = System(Hamiltonian(H, autonomous=true, variable=true))
        __variable = CTFlows.default_variable(Σ)

        #
        @test Σ isa HamiltonianSystem
        @test CTFlows.is_variable(Σ)
        #@test CTFlows.is_hamiltonian(Σ)

        # conversion
        convert_state    = CTFlows.convert_state_function(Σ)
        convert_variable = CTFlows.convert_variable_function(Σ)

        # rhs
        x0 = 1
        p0 = 2
        rhs! = CTFlows.rhs(Σ)
        dz = similar([x0], 2)
        t0 = 0
        v  = 1
        rhs!(dz, convert_state(x0, p0), convert_variable(v), t0)
        @test dz ≈ [2p0, -2x0-v] atol=1e-12 

    end

    # From Hamiltonian vector field

    @testset "From Hamiltonian vector field: 2D autonomous, non variable" begin

        #H(x, p) = p[1] * x[2] + p[2] * p[2] - 0.5 * p[2]^2    
        Hv(x, p) = [x[2], p[2]], [0, -p[1]]
        Σ = System(HamiltonianVectorField(Hv))

        #
        @test Σ isa HamiltonianVectorFieldSystem
        @test !CTFlows.is_variable(Σ)
        #@test CTFlows.is_hamiltonian(Σ)

        #
        __variable = CTFlows.default_variable(Σ)
        @test __variable() isa Vector{Real}

        # conversion
        convert_state    = CTFlows.convert_state_function(Σ)
        convert_variable = CTFlows.convert_variable_function(Σ)

        #
        x0 = [-1.0, 0.0]
        p0 = [12.0, 6.0]
        @test convert_state(x0, p0) == [x0; p0]

        v = [1]
        @test convert_variable(v) == v

        # rhs
        rhs! = CTFlows.rhs(Σ)
        dz = similar(x0, 4)
        t0 = 0
        v  = __variable()
        rhs!(dz, convert_state(x0, p0), convert_variable(v), t0)
        @test dz ≈ [x0[2], p0[2], 0, -p0[1]] atol=1e-12

    end

    @testset "From Hamiltonian vector field: 2D non autonomous, variable" begin

        #H(t, x, p, v) = -(t+v) * x[1] + p[1] * x[2] + p[2] * p[2] - 0.5 * p[2]^2
        Hv(t, x, p, v) = [x[2], p[2]], [t+v, -p[1]]
        Σ = System(HamiltonianVectorField(Hv, autonomous=false, variable=true))

        #
        @test Σ isa HamiltonianVectorFieldSystem
        @test CTFlows.is_variable(Σ)
        #@test CTFlows.is_hamiltonian(Σ)

        # conversion
        convert_state    = CTFlows.convert_state_function(Σ)
        convert_variable = CTFlows.convert_variable_function(Σ)

        # rhs
        x0 = [-1.0, 0.0]
        p0 = [12.0, 6.0]
        rhs! = CTFlows.rhs(Σ)
        dz = similar(x0, 4)
        t0 = 1
        v  = 2
        rhs!(dz, convert_state(x0, p0), convert_variable(v), t0)
        @test dz ≈ [x0[2], p0[2], t0+v, -p0[1]] atol=1e-12 

    end

    @testset "From Hamiltonian vector field: 1D autonomous, non variable" begin

        #H(x, p, v) = x^2 + p^2 + x*v
        Hv(x, p, v) = 2p, -2x-v
        Σ = System(HamiltonianVectorField(Hv, autonomous=true, variable=true))
        __variable = CTFlows.default_variable(Σ)

        #
        @test Σ isa HamiltonianVectorFieldSystem
        @test CTFlows.is_variable(Σ)
        #@test CTFlows.is_hamiltonian(Σ)

        # conversion
        convert_state    = CTFlows.convert_state_function(Σ)
        convert_variable = CTFlows.convert_variable_function(Σ)

        # rhs
        x0 = 1
        p0 = 2
        rhs! = CTFlows.rhs(Σ)
        dz = similar([x0], 2)
        t0 = 0
        v  = 1
        rhs!(dz, convert_state(x0, p0), convert_variable(v), t0)
        @test dz ≈ [2p0, -2x0-v] atol=1e-12 

    end


end