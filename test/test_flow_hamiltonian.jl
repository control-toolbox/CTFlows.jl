function test_flow_hamiltonian()

    @testset "2D autonomous, non variable" begin
        H(x, p) = p[1] * x[2] + p[2] * p[2] - 0.5 * p[2]^2
        z = Flow(Hamiltonian(H))
        t0 = 0.0
        tf = 1.0
        x0 = [-1.0, 0.0]
        p0 = [12.0, 6.0]
        xf, pf = z(t0, x0, p0, tf)
        Test.@test xf ≈ [0.0, 0.0] atol = 1e-5
        Test.@test pf ≈ [12.0, -6.0] atol = 1e-5        
    end

    @testset "2D non autonomous, variable" begin
        H(t, x, p, l) = p[1] * x[2] + p[2] * p[2] + 0.5 * l * p[2]^2
        z = Flow(Hamiltonian(H, autonomous=false, variable=true))
        t0 = 0.0
        tf = 1.0
        x0 = [-1.0, 0.0]
        p0 = [12.0, 6.0]
        xf, pf = z(t0, x0, p0, tf, -1.0)
        Test.@test xf ≈ [0.0, 0.0] atol = 1e-5
        Test.@test pf ≈ [12.0, -6.0] atol = 1e-5       
    end
 
    @testset "1D autonomous, non variable" begin
        H1(x, p) = x^2 + p^2
        z = Flow(Hamiltonian(H1))
        x0 = 1.0
        p0 = 0.0
        xf, pf = z(0.0, x0, p0, 2π)
        Test.@test xf ≈ x0 atol = 1e-5
        Test.@test pf ≈ p0 atol = 1e-5 
    end

end