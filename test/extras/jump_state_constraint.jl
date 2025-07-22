using Revise
using Pkg
Pkg.activate("./test/extras/")

#Pkg.develop(url="/Users/ocots/Research/logiciels/dev/control-toolbox/CTFlows")
#Pkg.add("CTParser")
#Pkg.add("CTModels")
#Pkg.add("CTBase")
#Pkg.add("OrdinaryDiffEq")
#Pkg.add("Plots")

using CTBase
using CTModels
import CTParser: CTParser, @def
import CTFlows: CTFlows, Flow, *
using OrdinaryDiffEq
using Plots

t0=0
tf=1
x0=[0, 1]
l = 1/9
@def ocp begin
    t ∈ [ t0, tf ], time
    x ∈ R², state
    u ∈ R, control
    x(t0) == x0
    x(tf) == [0, -1]
    x₁(t) ≤ l,                      (x_con)
    ẋ(t) == [x₂(t), u(t)]
    0.5∫(u(t)^2) → min
end

t1 = 3l
t2 = 1 - 3l
p0 = [-18, -6]

fs = Flow(ocp, 
    (x, p) -> p[2]      # control along regular arc
    )
fc = Flow(ocp, 
    (x, p) -> 0,        # control along boundary arc
    (x, u) -> l-x[1],   # state constraint
    (x, p) -> 0         # Lagrange multiplier
    )

ν = 18  # jump value of p1 at t1 and t2

f = fs * (t1, [ν, 0], fc) * (t2, [ν, 0], fs)

xf, pf = f(t0, x0, p0, tf) # xf should be [0, -1]

flow_sol = f((t0, tf), x0, p0)

plot(flow_sol)