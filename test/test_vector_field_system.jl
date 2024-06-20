function test_vector_field_system()

    # From VectorField
    @testset "From VectorField: 4D autonomous, non variable" begin

        V(z) = [z[2], z[2+2], 0.0, -z[2+1]]
        Σ = System(VectorField(V))

        #
        @test Σ isa VectorFieldSystem
        @test !CTFlows.is_variable(Σ)
        #@test !CTFlows.is_hamiltonian(Σ)

        #
        __variable = CTFlows.default_variable(Σ)
        @test __variable() isa Vector{Real}

        #
        t0 = 0.0
        tf = 1.0
        x0 = [-1.0, 0.0]
        p0 = [12.0, 6.0]
        v  = -1

        # conversion
        convert_state    = CTFlows.convert_state_function(Σ)
        convert_variable = CTFlows.convert_variable_function(Σ)

        #
        @test convert_state([x0; p0]) == [x0; p0]
        @test convert_variable(v) == v

        #
        rhs! = CTFlows.rhs(Σ)
        dz = similar([x0; p0], 4)

        rhs!(dz, convert_state([x0; p0]), convert_variable(v), t0)
        @test dz ≈ [x0[2], p0[2], 0, -p0[1]] atol=1e-12

    end

    @testset "From VectorField: 4D non autonomous, variable" begin

        V(t, z, l) = [z[2], (2+l)*z[2+2], 0.0, -z[2+1]]
        Σ = System(VectorField(V, autonomous=false, variable=true))

        #
        @test Σ isa VectorFieldSystem
        @test CTFlows.is_variable(Σ)
        #@test !CTFlows.is_hamiltonian(Σ)

        #
        __variable = CTFlows.default_variable(Σ)
        @test __variable() isa Vector{Real}

        #
        t0 = 0.0
        tf = 1.0
        x0 = [-1.0, 0.0]
        p0 = [12.0, 6.0]
        v  = -1

        # conversion
        convert_state    = CTFlows.convert_state_function(Σ)
        convert_variable = CTFlows.convert_variable_function(Σ)

        #
        @test convert_state([x0; p0]) == [x0; p0]
        @test convert_variable(v) == v

        #
        rhs! = CTFlows.rhs(Σ)
        dz = similar([x0; p0], 4)

        rhs!(dz, convert_state([x0; p0]), convert_variable(v), t0)
        @test dz ≈ [x0[2], p0[2], 0, -p0[1]] atol=1e-12
        
    end

    @testset "From VectorField: 2D autonomous, non variable" begin

        V(z) = [2z[2], -2z[1]]
        Σ = System(VectorField(V, autonomous=true, variable=false))

        #
        @test Σ isa VectorFieldSystem
        @test !CTFlows.is_variable(Σ)
        #@test !CTFlows.is_hamiltonian(Σ)

        #
        __variable = CTFlows.default_variable(Σ)
        @test __variable() isa Vector{Real}

        #
        t0 = 0
        tf = 1
        x0 = 1
        p0 = 2
        v  = -1

        # conversion
        convert_state    = CTFlows.convert_state_function(Σ)
        convert_variable = CTFlows.convert_variable_function(Σ)

        #
        @test convert_state([x0; p0]) == [x0; p0]
        @test convert_variable(v) == v

        #
        rhs! = CTFlows.rhs(Σ)
        dz = similar([x0; p0], 2)

        rhs!(dz, convert_state([x0; p0]), convert_variable(v), t0)
        @test dz ≈ [2p0, -2x0] atol=1e-12

    end

    @testset "From VectorField: 1D autonomous, non variable" begin

        V(x) = 2x
        Σ = System(VectorField(V, autonomous=true, variable=false))

        #
        @test Σ isa VectorFieldSystem
        @test !CTFlows.is_variable(Σ)
        #@test !CTFlows.is_hamiltonian(Σ)

        #
        __variable = CTFlows.default_variable(Σ)
        @test __variable() isa Vector{Real}

        #
        t0 = 0
        tf = 1
        x0 = 1
        v  = -1

        # conversion
        convert_state    = CTFlows.convert_state_function(Σ)
        convert_variable = CTFlows.convert_variable_function(Σ)

        #
        @test convert_state(x0) == [x0]
        @test convert_variable(v) == v

        #
        rhs! = CTFlows.rhs(Σ)
        dz = similar([x0], 1)

        rhs!(dz, convert_state(x0), convert_variable(v), t0)
        @test dz ≈ [2x0] atol=1e-12

    end

    # From GeneralVectorField
    
    @testset "From GeneralVectorField: 4D autonomous, non variable" begin

        V(z) = [z[2], z[2+2], 0.0, -z[2+1]]
        Σ = System(GeneralVectorField(V))

        #
        @test Σ isa GeneralVectorFieldSystem
        @test !CTFlows.is_variable(Σ)
        #@test !CTFlows.is_hamiltonian(Σ)

        #
        __variable = CTFlows.default_variable(Σ)
        @test __variable() isa Vector{Real}

        #
        t0 = 0.0
        tf = 1.0
        x0 = [-1.0, 0.0]
        p0 = [12.0, 6.0]
        v  = -1

        # conversion
        convert_state    = CTFlows.convert_state_function(Σ)
        convert_variable = CTFlows.convert_variable_function(Σ)

        #
        @test convert_state([x0; p0]) == [x0; p0]
        @test convert_variable(v) == v

        #
        rhs! = CTFlows.rhs(Σ)
        dz = similar([x0; p0], 4)

        rhs!(dz, convert_state([x0; p0]), convert_variable(v), t0)
        @test dz ≈ [x0[2], p0[2], 0, -p0[1]] atol=1e-12

    end

    @testset "From GeneralVectorField: 4D nonautonomous, variable" begin

        V(t, z, v) = [t+z[2], z[2+2], 0.0, -z[2+1]+v]
        Σ = System(GeneralVectorField(V, 
        autonomous=false,
        variable=true,
        XType=Vector{<:Real},
        VType=Real))

        #
        @test Σ isa GeneralVectorFieldSystem
        @test CTFlows.is_variable(Σ)
        #@test !CTFlows.is_hamiltonian(Σ)

        #
        __variable = CTFlows.default_variable(Σ)
        @test __variable() isa Vector{Real}

        #
        t0 = 1.0
        tf = 2.0
        x0 = [-1.0, 0.0]
        p0 = [12.0, 6.0]
        v  = -1

        # conversion
        convert_state    = CTFlows.convert_state_function(Σ)
        convert_variable = CTFlows.convert_variable_function(Σ)

        #
        @test convert_state([x0; p0]) == [x0; p0]
        @test convert_variable(v) == v

        #
        rhs! = CTFlows.rhs(Σ)
        dz = similar([x0; p0], 4)

        rhs!(dz, convert_state([x0; p0]), convert_variable(v), t0)
        @test dz ≈ [t0+x0[2], p0[2], 0, -p0[1]+v] atol=1e-12

    end

    @testset "From GeneralVectorField: 1D autonomous, non variable" begin

        V(x) = 2x
        Σ = System(GeneralVectorField(V, 
        autonomous=true,
        variable=false,
        XType=Real,
        VType=Real))

        #
        @test Σ isa GeneralVectorFieldSystem
        @test !CTFlows.is_variable(Σ)
        #@test !CTFlows.is_hamiltonian(Σ)

        #
        __variable = CTFlows.default_variable(Σ)
        @test __variable() isa Vector{Real}

        #
        x0 = 1.0

        # conversion
        convert_state    = CTFlows.convert_state_function(Σ)
        convert_variable = CTFlows.convert_variable_function(Σ)

        #
        @test convert_state(x0) == [x0]

        #
        rhs! = CTFlows.rhs(Σ)
        dx = similar([x0], 1)

        rhs!(dx, convert_state(x0), convert_variable(-1), 0)
        @test dx ≈ [2x0] atol=1e-12

    end

end