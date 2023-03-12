#
t0 = 0.0
tf = 1.0
x0 = [-1.0, 0.0]
p0 = [12.0, 6.0]

control(x, p) = p[2]

#
Hv(x, p) = [x[2], control(x, p), 0.0, -p[1]]
z = Flow(HamiltonianVectorField(Hv))
xf, pf = z(t0, x0, p0, tf)
@test xf ≈ [0.0, 0.0] atol = 1e-5
@test pf ≈ [12.0, -6.0] atol = 1e-5

#
Hv(t, x, p, l) = [x[2], control(x, p), 0.0, -p[1]]
z = Flow(HamiltonianVectorField{:nonautonomous}(Hv), abstol=1e-12)
xf, pf = z(t0, x0, p0, tf, 0.0)
@test xf ≈ [0.0, 0.0] atol = 1e-5
@test pf ≈ [12.0, -6.0] atol = 1e-5