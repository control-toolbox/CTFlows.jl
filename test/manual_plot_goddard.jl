using CTBase
#using MINPACK
using CTFlows

# Parameters
Cd = 310.
Tmax = 3.5
β = 500.
b = 2.
t0 = 0.
r0 = 1.
v0 = 0.
vmax = 0.1
m0 = 1.
mf = 0.6
x0 = [r0, v0, m0]

# OCP model
ocp = Model()
time!(ocp, :initial, t0) # if not provided, final time is free
state!(ocp, 3, labels=["r", "v", "m"]) # state dim
control!(ocp, 1) # control dim
constraint!(ocp, :initial, x0)
constraint!(ocp, :control, u -> u, 0., 1.)
constraint!(ocp, :mixed, (x, u) -> x[1], r0, Inf, :state_con1)
constraint!(ocp, :mixed, (x, u) -> x[2], 0., vmax, :state_con2)
constraint!(ocp, :mixed, (x, u) -> x[3], m0, mf, :state_con3)
#
objective!(ocp, :mayer,  (t0, x0, tf, xf) -> xf[1], :max)

function F0(x)
    r, v, m = x
    D = Cd * v^2 * exp(-β*(r - 1))
    F = [ v, -D/m - 1/r^2, 0 ]
    return F
end

function F1(x)
    r, v, m = x
    F = [ 0, Tmax/m, -b*Tmax ]
    return F
end

f(x, u) = F0(x) + u*F1(x)

constraint!(ocp, :dynamics, f)

# --------------------------------------------------------
# Indirect

# Bang controls
u0(x, p) = 0.
u1(x, p) = 1.

# Computation of singular control of order 1
H0(x, p) = p' * F0(x)
H1(x, p) = p' * F1(x)
H01 = Poisson(H0, H1)
H001 = Poisson(H0, H01)
H101 = Poisson(H1, H01)
us(x, p) = -H001(x, p) / H101(x, p)

# Computation of boundary control
remove_constraint!(ocp, :state_con1)
remove_constraint!(ocp, :state_con3)
constraint!(ocp, :boundary, (t0, x0, tf, xf) -> xf[3], mf, :final_con) # one value => equality (not boxed inequality)

g(x) = constraint(ocp, :state_con2, :upper)(x, 0) # g(x, u) ≥ 0 (cf. nonnegative multiplier)
ub(x, _) = -Ad(F0, g)(x) / Ad(F1, g)(x)
μb(x, p) = H01(x, p) / Ad(F1, g)(x)

f0 = Flow(ocp, u0)
f1 = Flow(ocp, u1)
fs = Flow(ocp, us)
fb = Flow(ocp, ub, (x, _) -> g(x), μb)

# solution
p0 = [3.94576465875024, 0.1503955962329867, 0.05371271294038511]
t1 = 0.023509684041960622
t2 = 0.05973738090036058
t3 = 0.1015713484234725
tf = 0.20204744057041196

f1sb0 = f1 * (t1, fs) * (t2, fb) * (t3, f0) # concatenation of the Hamiltonian flows
flow_sol = f1sb0((t0, tf), x0, p0)

plot(flow_sol)