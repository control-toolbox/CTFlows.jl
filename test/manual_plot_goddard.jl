using CTBase
using CTFlows
using DifferentialEquations
using Plots

# Parameters
Cd = 310
Tmax = 3.5
β = 500
b = 2
t0 = 0
r0 = 1
v0 = 0
vmax = 0.1
m0 = 1
mf = 0.6
x0 = [r0, v0, m0]

# OCP model
ocp = Model(variable=true)
variable!(ocp, 1)
time!(ocp, t0=t0, indf=1) # if not provided, final time is free
state!(ocp, 3, "x", ["r", "v", "m"]) # state dim
control!(ocp, 1) # control dim
constraint!(ocp, :initial, lb=x0, ub=x0)
constraint!(ocp, :control, f=(u, v) -> u,  lb=0,  ub=1)
constraint!(ocp, :state, f=(x, v) -> x[1], lb=r0, ub=Inf,  label=:state_con1)
constraint!(ocp, :state, f=(x, v) -> x[2], lb=0,  ub=vmax, label=:state_con2)
constraint!(ocp, :state, f=(x, v) -> x[3], lb=m0, ub=mf,   label=:state_con3)
objective!(ocp, :mayer,  (x0, xf, v) -> xf[1], :max)
function F0(x)
    r, v, m = x
    D = Cd * v^2 * exp(-β*(r - 1))
    return [ v, -D/m - 1/r^2, 0 ]
end
function F1(x)
    r, v, m = x
    return [ 0, Tmax/m, -b*Tmax ]
end
dynamics!(ocp, (x, u, v) -> F0(x) + u*F1(x))

# --------------------------------------------------------
# Indirect

# bang controls
u0 = 0
u1 = 1

# singular control
H0 = Lift(F0)
H1 = Lift(F1)
H01  = @Lie {H0, H1}
H001 = @Lie {H0, H01}
H101 = @Lie {H1, H01}
us(x, p) = -H001(x, p) / H101(x, p)

# boundary control
g(x)    = vmax-x[2] # g(x) ≥ 0
ub(x)   = -Lie(F0, g)(x) / Lie(F1, g)(x)
μ(x, p) = H01(x, p) / Lie(F1, g)(x)

# flows
f0 = Flow(ocp, (x, p, v) -> u0)
f1 = Flow(ocp, (x, p, v) -> u1)
fs = Flow(ocp, (x, p, v) -> us(x, p))
fb = Flow(ocp, (x, p, v) -> ub(x), (x, u, v) -> g(x), (x, p, v) -> μ(x, p))

# solution
p0 = [3.94576465875024, 0.1503955962329867, 0.05371271294038511]
t1 = 0.023509684041960622
t2 = 0.05973738090036058
t3 = 0.1015713484234725
tf = 0.20204744057041196

f1sb0 = f1 * (t1, fs) * (t2, fb) * (t3, f0) # concatenation of the Hamiltonian flows
flow_sol = f1sb0((t0, tf), x0, p0)

pp = plot(flow_sol, size=(900, 600))

# Abstract model
f(x, u, v) = F0(x) + u*F1(x)

@def ocp begin
    tf ∈ R, variable
    t ∈ [ t0, tf ], time
    x ∈ R³, state
    u ∈ R, control
    x(t0) == x0,                (initial_con)
    r = x₁
    v = x₂
    m = x₃
    m(tf) == mf,                (final_con)
    0 ≤ u(t) ≤ 1,               (u_con)
    r0 ≤ r(t) ≤ Inf,            (x_con_r)
    0 ≤ v(t) ≤ vmax,            (x_con_v)
    ẋ(t) == f(x(t), u(t), tf)
    r(tf) → max
end

# flows
f0 = Flow(ocp, (x, p, v) -> u0)
f1 = Flow(ocp, (x, p, v) -> u1)
fs = Flow(ocp, (x, p, v) -> us(x, p))
fb = Flow(ocp, (x, p, v) -> ub(x), (x, u, v) -> g(x), (x, p, v) -> μ(x, p))

#
f1sb0 = f1 * (t1, fs) * (t2, fb) * (t3, f0) # concatenation of the Hamiltonian flows
flow_sol = f1sb0((t0, tf), x0, p0)

#
plot!(pp, flow_sol)