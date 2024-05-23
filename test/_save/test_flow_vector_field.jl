function test_flow_vector_field()

    @testset "4D autonomous, non variable" begin
        V(z) = [z[2], z[2+2], 0.0, -z[2+1]]
        z = Flow(VectorField(V))
        t0 = 0.0
        tf = 1.0
        x0 = [-1.0, 0.0]
        p0 = [12.0, 6.0]
        zf = z(t0, [x0; p0], tf)
        @test zf ≈ [0.0, 0.0, 12.0, -6.0] atol=1e-5 
    end

    @testset "4D non autonomous, variable" begin
        V(t, z, l) = [z[2], (2+l)*z[2+2], 0.0, -z[2+1]]
        z = Flow(VectorField(V, autonomous=false, variable=true))
        t0 = 0.0
        tf = 1.0
        x0 = [-1.0, 0.0]
        p0 = [12.0, 6.0]
        zf = z(t0, [x0; p0], tf, -1.0)
        @test zf ≈ [0.0, 0.0, 12.0, -6.0] atol=1e-5
    end

    @testset "2D autonomous, non variable" begin
        V(z) = [2z[2], -2z[1]]
        z = Flow(VectorField(V))
        x0 = 1.0
        p0 = 0.0
        zf = z(0.0, [x0; p0], 2π)
        @test zf ≈ [x0; p0] atol = 1e-5
    end

    @testset "1D autonomous, non variable" begin
        V(x) = 2x
        z = Flow(VectorField(V))
        x0 = 1.0
        xf = z(0.0, x0, 2π)
        @test xf ≈ x0*exp(4π) atol = 1e-5
    end

end