#
t0 = 0.0
tf = 1.0
x0 = [-1.0, 0.0]
p0 = [12.0, 6.0]

control(x, p) = p[2]

#
H(x, p) = p[1] * x[2] + p[2] * control(x, p) - 0.5 * control(x, p)^2
z = Flow(H)
xf, pf = z(t0, x0, p0, tf)
@test xf ≈ [0.0, 0.0] atol = 1e-5
@test pf ≈ [12.0, -6.0] atol = 1e-5

#
H(t, x, p, l) = p[1] * x[2] + p[2] * control(x, p) + 0.5 * l * control(x, p)^2
z = Flow(H, :nonautonomous, abstol=1e-12)
xf, pf = z(t0, x0, p0, tf, -1.0)
@test xf ≈ [0.0, 0.0] atol = 1e-5
@test pf ≈ [12.0, -6.0] atol = 1e-5