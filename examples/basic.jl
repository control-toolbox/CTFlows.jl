using CTFlows

t0 = 0.0
tf = 1.0
x0 = [-1.0; 0.0]
p0 = [12.0; 6.0]

u(x, p) = p[2]
H(x, p) = p[1] * x[2] + p[2] * u(x, p) - 0.5 * u(x, p)^2

z = Flow(Hamiltonian(H))

xf, pf = z(t0, x0, p0, tf)