t0 = 0.0
tf = 1.0

a = -1.0
b =  0.0
c = 12.0
d =  6.0

x0 = [a, b]
p0 = [c, d]

n = length(x0)

#
control(_, p) = p[2]
H1(x, p) = p[1] * x[2] + p[2] * control(x, p) - 0.5 * control(x, p)^2
H2(x, p) = -H1(x, p)
H3(t, x, p) = H1(x,p)
#   
Hv1(x, p) = [x[2], control(x, p), 0.0, -p[1]]
Hv2(x, p) = -Hv1(x, p)
Hv3(t, x, p) = Hv1(x,p)
#
V1(z) = Hv1(z[1:n], z[n+1:2n])
V2(z) = -V1(z)
V3(t, z) = V1(z)
#
# solution
x1_sol(t) = a + b*t + 0.5*d*t^2 - c*t^3/6
x2_sol(t) = b + d*t - 0.5*c*t^2
p1_sol(t) = c
p2_sol(t) = d -c*t
z_sol(t) = [x1_sol(t), x2_sol(t), p1_sol(t), p2_sol(t)]

@testset "Function" begin
    
    #
    f1 = Flow(H1)
    f2 = Flow(H2)
    f3 = Flow(H3, :nonautonomous)
    
    # one flow is used because t1 > tf
    f = f1 * (2.0*tf, f2)
    xf, pf = f(t0, x0, p0, tf)
    @test xf ≈ [x1_sol(tf), x2_sol(tf)] atol = 1e-5
    @test pf ≈ [p1_sol(tf), p2_sol(tf)] atol = 1e-5
    
    # two flows: going back
    f = f1 * ((t0+tf)/2, f2)
    xf, pf = f(t0, x0, p0, tf)
    @test xf ≈ x0 atol = 1e-5
    @test pf ≈ p0 atol = 1e-5
    
    # three flows: go forward
    f = f1 * ((t0+tf)/4, f2) * ((t0+tf)/2, f1)
    xf, pf = f(t0, x0, p0, tf+(t0+tf)/2)
    @test xf ≈ [x1_sol(tf), x2_sol(tf)] atol = 1e-5
    @test pf ≈ [p1_sol(tf), p2_sol(tf)] atol = 1e-5

    # autonomous and nonautonomous
    f = f1 * ((t0+tf)/4, f2) * ((t0+tf)/2, f3)
    xf, pf = f(t0, x0, p0, tf+(t0+tf)/2)
    @test xf ≈ [x1_sol(tf), x2_sol(tf)] atol = 1e-5
    @test pf ≈ [p1_sol(tf), p2_sol(tf)] atol = 1e-5

    # on a grid
    f = f1 * ((t0+tf)/4, f1) * ((t0+tf)/2, f1)
    N = 100; saveat = range(t0, tf, N)
    sol = f((t0, tf), x0, p0, saveat=saveat)
    xf = sol.u[end][1:n]
    pf = sol.u[end][n+1:2n]
    @test xf ≈ [x1_sol(tf), x2_sol(tf)] atol = 1e-5
    @test pf ≈ [p1_sol(tf), p2_sol(tf)] atol = 1e-5
    zspan = sol.u
    zspan_sol = z_sol.(sol.t)
    @test zspan ≈ zspan_sol atol = 1e-5

end

@testset "Hamiltonian" begin
    
    #
    f1 = Flow(Hamiltonian(H1))
    f2 = Flow(Hamiltonian(H2))
    f3 = Flow(Hamiltonian{:nonautonomous}(H3))
    
    # one flow is used because t1 > tf
    f = f1 * (2.0*tf, f2)
    xf, pf = f(t0, x0, p0, tf)
    @test xf ≈ [x1_sol(tf), x2_sol(tf)] atol = 1e-5
    @test pf ≈ [p1_sol(tf), p2_sol(tf)] atol = 1e-5
    
    # two flows: going back
    f = f1 * ((t0+tf)/2, f2)
    xf, pf = f(t0, x0, p0, tf)
    @test xf ≈ x0 atol = 1e-5
    @test pf ≈ p0 atol = 1e-5
    
    # three flows: go forward
    f = f1 * ((t0+tf)/4, f2) * ((t0+tf)/2, f1)
    xf, pf = f(t0, x0, p0, tf+(t0+tf)/2)
    @test xf ≈ [x1_sol(tf), x2_sol(tf)] atol = 1e-5
    @test pf ≈ [p1_sol(tf), p2_sol(tf)] atol = 1e-5

    # autonomous and nonautonomous
    f = f1 * ((t0+tf)/4, f2) * ((t0+tf)/2, f3)
    xf, pf = f(t0, x0, p0, tf+(t0+tf)/2)
    @test xf ≈ [x1_sol(tf), x2_sol(tf)] atol = 1e-5
    @test pf ≈ [p1_sol(tf), p2_sol(tf)] atol = 1e-5

    # on a grid
    f = f1 * ((t0+tf)/4, f1) * ((t0+tf)/2, f1)
    N = 100; saveat = range(t0, tf, N)
    sol = f((t0, tf), x0, p0, saveat=saveat)
    xf = sol.u[end][1:n]
    pf = sol.u[end][n+1:2n]
    @test xf ≈ [x1_sol(tf), x2_sol(tf)] atol = 1e-5
    @test pf ≈ [p1_sol(tf), p2_sol(tf)] atol = 1e-5
    zspan = sol.u
    zspan_sol = z_sol.(sol.t)
    @test zspan ≈ zspan_sol atol = 1e-5
end

@testset "Hamiltonian vector field" begin
    
    #
    f1 = Flow(HamiltonianVectorField(Hv1))
    f2 = Flow(HamiltonianVectorField(Hv2))
    f3 = Flow(HamiltonianVectorField{:nonautonomous}(Hv3))
    
    # one flow is used because t1 > tf
    f = f1 * (2.0*tf, f2)
    xf, pf = f(t0, x0, p0, tf)
    @test xf ≈ [x1_sol(tf), x2_sol(tf)] atol = 1e-5
    @test pf ≈ [p1_sol(tf), p2_sol(tf)] atol = 1e-5
    
    # two flows: going back
    f = f1 * ((t0+tf)/2, f2)
    xf, pf = f(t0, x0, p0, tf)
    @test xf ≈ x0 atol = 1e-5
    @test pf ≈ p0 atol = 1e-5
    
    # three flows: go forward
    f = f1 * ((t0+tf)/4, f2) * ((t0+tf)/2, f1)
    xf, pf = f(t0, x0, p0, tf+(t0+tf)/2)
    @test xf ≈ [x1_sol(tf), x2_sol(tf)] atol = 1e-5
    @test pf ≈ [p1_sol(tf), p2_sol(tf)] atol = 1e-5

    # autonomous and nonautonomous
    f = f1 * ((t0+tf)/4, f2) * ((t0+tf)/2, f3)
    xf, pf = f(t0, x0, p0, tf+(t0+tf)/2)
    @test xf ≈ [x1_sol(tf), x2_sol(tf)] atol = 1e-5
    @test pf ≈ [p1_sol(tf), p2_sol(tf)] atol = 1e-5

    # on a grid
    f = f1 * ((t0+tf)/4, f1) * ((t0+tf)/2, f1)
    N = 100; saveat = range(t0, tf, N)
    sol = f((t0, tf), x0, p0, saveat=saveat)
    xf = sol.u[end][1:n]
    pf = sol.u[end][n+1:2n]
    @test xf ≈ [x1_sol(tf), x2_sol(tf)] atol = 1e-5
    @test pf ≈ [p1_sol(tf), p2_sol(tf)] atol = 1e-5
    zspan = sol.u
    zspan_sol = z_sol.(sol.t)
    @test zspan ≈ zspan_sol atol = 1e-5
end

@testset "Vector field" begin
        
    #
    f1 = Flow(VectorField(V1))
    f2 = Flow(VectorField(V2))
    f3 = Flow(VectorField{:nonautonomous}(V3))

    # one flow is used because t1 > tf
    f = f1 * (2.0*tf, f2)
    zf = f(t0, [x0; p0], tf)
    @test zf ≈ [x1_sol(tf), x2_sol(tf), p1_sol(tf), p2_sol(tf)] atol = 1e-5
    
    # two flows: going back
    f = f1 * ((t0+tf)/2, f2)
    zf = f(t0, [x0; p0], tf)
    @test zf ≈ [x0; p0] atol = 1e-5
    
    # three flows: go forward
    f = f1 * ((t0+tf)/4, f2) * ((t0+tf)/2, f1)
    zf = f(t0, [x0; p0], tf+(t0+tf)/2)
    @test zf ≈ [x1_sol(tf), x2_sol(tf), p1_sol(tf), p2_sol(tf)] atol = 1e-5

    # autonomous and nonautonomous
    f = f1 * ((t0+tf)/4, f2) * ((t0+tf)/2, f3)
    zf = f(t0, [x0; p0], tf+(t0+tf)/2)
    @test zf ≈ [x1_sol(tf), x2_sol(tf), p1_sol(tf), p2_sol(tf)] atol = 1e-5

    # on a grid
    f = f1 * ((t0+tf)/4, f1) * ((t0+tf)/2, f1)
    N = 100; saveat = range(t0, tf, N)
    sol = f((t0, tf), [x0; p0], saveat=saveat)
    xf = sol.u[end][1:n]
    pf = sol.u[end][n+1:2n]
    @test xf ≈ [x1_sol(tf), x2_sol(tf)] atol = 1e-5
    @test pf ≈ [p1_sol(tf), p2_sol(tf)] atol = 1e-5
    zspan = sol.u
    zspan_sol = z_sol.(sol.t)
    @test zspan ≈ zspan_sol atol = 1e-5
end