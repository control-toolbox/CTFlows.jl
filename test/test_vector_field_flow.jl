function test_vector_field_flow()

    @testset "VectorFieldFlow" begin
        f(x; rhs) = rhs(x)
        rhs(x) = 2x

        VF = VectorFieldFlow(f, rhs)

        @test VF isa VectorFieldFlow
        @test VF(1) == 2
    end

    # 
    @testset "From VectorFieldSystem" begin

        # that's a dummy caller
        f!(dx, x, v, t; rhs) = rhs(dx, x, v, t)

        #
        V(z) = [z[2], z[2+2], 0.0, -z[2+1]]
        Σ = System(VectorField(V))

        #
        VF = CTFlows._construct_flow(Σ, f!)
        @test VF isa VectorFieldFlow

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
        VF(dz, convert_state([x0; p0]), convert_variable(v), t0)
        @test dz ≈ [x0[2], p0[2], 0, -p0[1]] atol=1e-12

    end

    @testset "From Flow of System" begin

        V(z) = [z[2], z[2+2], 0.0, -z[2+1]]
        z = Flow(System(VectorField(V)))

        t0 = 0.0
        tf = 1.0
        x0 = [-1.0, 0.0]
        p0 = [12.0, 6.0]

        zf = z(t0, [x0; p0], tf)
        @test zf ≈ [0.0, 0.0, 12.0, -6.0] atol=1e-5 
    end

    @testset "From Flow of vector field: 4D autonomous, non variable" begin

        V(z) = [z[2], z[2+2], 0.0, -z[2+1]]
        z = Flow(VectorField(V))

        t0 = 0.0
        tf = 1.0
        x0 = [-1.0, 0.0]
        p0 = [12.0, 6.0]

        zf = z(t0, [x0; p0], tf)
        @test zf ≈ [0.0, 0.0, 12.0, -6.0] atol=1e-5 

    end

    @testset "From Flow of vector field: 4D non autonomous, variable" begin

        V(t, z, l) = [z[2], (2+l)*z[2+2], 0.0, -z[2+1]]
        z = Flow(VectorField(V, autonomous=false, variable=true))

        t0 = 0.0
        tf = 1.0
        x0 = [-1.0, 0.0]
        p0 = [12.0, 6.0]

        zf = z(t0, [x0; p0], tf, -1.0)
        @test zf ≈ [0.0, 0.0, 12.0, -6.0] atol=1e-5

    end

    @testset "From Flow of  vector field: 2D autonomous, non variable" begin

        V(z) = [2z[2], -2z[1]]
        z = Flow(VectorField(V))

        x0 = 1.0
        p0 = 0.0

        zf = z(0.0, [x0; p0], 2π)
        @test zf ≈ [x0; p0] atol = 1e-5

    end

    @testset "From Flow of  vector field: 1D autonomous, non variable" begin

        V(x) = 2x
        z = Flow(VectorField(V))

        x0 = 1.0

        xf = z(0.0, x0, 2π)
        @test xf ≈ x0*exp(4π) atol = 1e-5

    end

    # From a function
    @testset "From Flow of Function: 4D autonomous, non variable" begin

        V(z) = [z[2], z[2+2], 0.0, -z[2+1]]
        z = Flow(V)

        t0 = 0.0
        tf = 1.0
        x0 = [-1.0, 0.0]
        p0 = [12.0, 6.0]

        zf = z(t0, [x0; p0], tf)
        @test zf ≈ [0.0, 0.0, 12.0, -6.0] atol=1e-5 

    end

    @testset "From Flow of Function: 4D non autonomous, variable" begin

        V(t, z, l) = [z[2], (2+l)*z[2+2], 0.0, -z[2+1]]
        z = Flow(V, autonomous=false, variable=true)

        t0 = 0.0
        tf = 1.0
        x0 = [-1.0, 0.0]
        p0 = [12.0, 6.0]

        zf = z(t0, [x0; p0], tf, -1.0)
        @test zf ≈ [0.0, 0.0, 12.0, -6.0] atol=1e-5

    end

    @testset "From Flow of Function: 2D autonomous, non variable" begin

        V(z) = [2z[2], -2z[1]]
        z = Flow(V)

        x0 = 1.0
        p0 = 0.0

        zf = z(0.0, [x0; p0], 2π)
        @test zf ≈ [x0; p0] atol = 1e-5

    end

    @testset "From Flow of Function: 1D autonomous, non variable" begin

        V(x) = 2x
        z = Flow(V)

        x0 = 1.0

        xf = z(0.0, x0, 2π)
        @test xf ≈ x0*exp(4π) atol = 1e-5

    end

    @testset "From Flow of Function with types: 4D non autonomous, variable" begin

        V(t, z, l) = [z[2], (2+l)*z[2+2], 0.0, -z[2+1]]
        z = Flow(V, autonomous=false, variable=true, XType=Vector{<:Real}, VType=Real)

        t0 = 0.0
        tf = 1.0
        x0 = [-1.0, 0.0]
        p0 = [12.0, 6.0]

        zf = z(t0, [x0; p0], tf, -1.0)
        @test zf ≈ [0.0, 0.0, 12.0, -6.0] atol=1e-5

        @test_throws MethodError z(t0, [x0; p0], tf, [-1.0, 0.0])
        @test_throws MethodError z(t0, 1.0, tf, [-1.0, 0.0])

    end

    @testset "Ricatti" begin
        #
        t0 = 0
        tf = 5
        x0 = [0, 1]
        Q  = I
        R  = I
        Rm1 = I
        A = [0 1 ; -1 0]
        B = [0 ; 1]

        # computing S
        ricatti(S) = -S*B*Rm1*B'*S - (-Q+A'*S+S*A)
        #
        S = solve(ODEProblem((S, _, _) -> ricatti(S), zeros(size(A)), (tf, t0)), Tsit5(), reltol=1e-12, abstol=1e-12)
        #
        f = Flow(ricatti, autonomous=true, variable=false)
        SS = f((tf, t0), zeros(size(A)))
        #
        @test S.u[end] ≈ SS.u[end] atol=1e-5

        # computing x
        dyn(t, x) = A*x + B*Rm1*B'*S(t)*x
        #
        x = solve(ODEProblem((x, _, t) -> dyn(t, x), x0, (t0, tf)), Tsit5(), reltol=1e-8, abstol=1e-8)
        #
        f = Flow(dyn, autonomous=false, variable=false)
        xx = f((t0, tf), x0)
        #
        @test x.u[end] ≈ xx.u[end] atol=1e-5

        # computing u
        u(t) = Rm1*B'*S(t)*x(t) 
        
        # computing p
        ϕ(t, p) = [p[2]+x(t)[1], x(t)[2]-p[1]]
        #
        p = solve(ODEProblem((p, _, t) -> ϕ(t, p), zeros(2), (tf, t0)), Tsit5(), reltol=1e-8, abstol=1e-8)
        #
        f = Flow(ϕ, autonomous=false, variable=false)
        pp = f((tf, t0), zeros(2))
        #
        @test p.u[end] ≈ pp.u[end] atol=1e-5

        # computing objective
        ψ(t) = 0.5*(x(t)[1]^2 + x(t)[2]^2 + u(t)^2)
        #
        o = solve(ODEProblem((_, _, t) -> ψ(t), 0, (t0, tf)), Tsit5(), reltol=1e-8, abstol=1e-8)
        #
        f = Flow((t, _) -> ψ(t), autonomous=false, variable=false)
        oo = f((t0, tf), 0)
        #
        @test o.u[end] ≈ oo.u[end] atol=1e-5

    end

end