using CTProblems
using CTFlows

prob = Problem(:integrator, :dim2, :energy)
ocp = prob.model
sol = prob.solution

times = sol.times
t0 = times[1]
tf = times[end]
x  = sol.state
p  = sol.Costate
x0 = x(t0)
p0 = p(t0)

if isnonautonomous(ocp)
    error("should be autonomous")
end

u(x, p) = p[2] # must be consistent with the model

f = Flow(ocp, u)

xf, pf  = f(t0, x0, p0, tf)

sol = f((t0, tf), x0, p0; saveat=range(t0, tf, 101))

plot(sol, size=(900, 600))

#nothing