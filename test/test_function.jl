#
t0 = 0.0
tf = 1.0
x0 = [-1.0; 0.0]
p0 = [12.0; 6.0]

# from a function: should be as a Hamiltonian
H(t, x, p, l) = p[1] * x[2] + p[2] * control(x, p) + 0.5 * l * control(x, p)^2
z = flow(H, (:nonautonomous,))
xf, pf = z(t0, x0, p0, tf, -1.0)
@test xf ≈ [0.0; 0.0] atol = 1e-5
@test pf ≈ [12.0; -6.0] atol = 1e-5