function test_flow_hamiltonian_vector_field()

    @testset "2D autonomous, non variable" begin
        Hv(x, p) = [x[2], p[2]], [0.0, -p[1]]
        z = Flow(HamiltonianVectorField(Hv))
        t0 = 0.0
        tf = 1.0
        x0 = [-1.0, 0.0]
        p0 = [12.0, 6.0]
        xf, pf = z(t0, x0, p0, tf)
        Test.@test xf ≈ [0.0, 0.0] atol = 1e-5
        Test.@test pf ≈ [12.0, -6.0] atol = 1e-5        
    end

    @testset "2D non autonomous, variable" begin
        Hv(t, x, p, l) = [x[2], (2+l)*p[2]], [0.0, -p[1]]
        z = Flow(HamiltonianVectorField(Hv, autonomous=false, variable=true))
        t0 = 0.0
        tf = 1.0
        x0 = [-1.0, 0.0]
        p0 = [12.0, 6.0]
        xf, pf = z(t0, x0, p0, tf, -1.0)
        Test.@test xf ≈ [0.0, 0.0] atol = 1e-5
        Test.@test pf ≈ [12.0, -6.0] atol = 1e-5       
    end

    @testset "1D autonomous, non variable" begin
        H1v(x, p) = 2p, -2x
        z = Flow(HamiltonianVectorField(H1v))
        x0 = 1.0
        p0 = 0.0
        xf, pf = z(0.0, x0, p0, 2π)
        Test.@test xf ≈ x0 atol = 1e-5
        Test.@test pf ≈ p0 atol = 1e-5 
    end

end