using CTFlows
using Plots
using OrdinaryDiffEq
using CTBase

#f  = Flow(Hamiltonian((x, p) -> 0.5p^2))
#fc = f * (1, 1, f) * (1.5, f) * (2, 1, f) * (2.5, f) * (3, 1, f) * (3.5, f) * (4, 1, f)
#sol = fc((0, 5), 0, 0)
#plot(sol)

f  = Flow(HamiltonianVectorField((x, p) -> [p[1], 0, 0, 0]))
fc = f * (1, [1, 0], f) * (1.5, f) * (2, [1, 0], f) * (2.5, f) * (3, [1, 0], f) * (3.5, f) * (4, [1, 0], f)
sol = fc((0, 5), [0, 0], [0, 0])
plot(sol)

#=

ocp = Model()
state!(ocp, 2)
control!(ocp, 2)
time!(ocp, [0, 5])
constraint!(ocp, :initial, [0, 0])
dynamics!(ocp, (x, u) -> u)
objective!(ocp, :mayer, (x0, xf) -> xf)
f = Flow(ocp, (x, p) -> [p[1]/2, 0])
fc = f * (1, [1, 0], f) * (1.5, f) * (2, [1, 0], f) * (2.5, f) * (3, [1, 0], f) * (3.5, f) * (4, [1, 0], f)
sol = fc((0, 5), [0, 0], [0, 0])
plot(sol)
=#

#=    
function dyn(du, u, p, t)
    du[1] = -u[1]
end
u0 = [10.0]
prob = ODEProblem(dyn, u0, (0, 10))
dosetimes = [4, 8]
condition(u, t, integrator) = t ∈ dosetimes
affect!(integrator) = integrator.u[1] += 10
cb = DiscreteCallback(condition, affect!)
sol = solve(prob, Tsit5(), callback=cb, tstops=dosetimes)
pp = plot(sol)

V = x -> -x
f = Flow(VectorField(V))
fc = f * (4, 10, f) * (8, 10, f)
x0 = 10
sol2 = fc((0, 10), x0)
plot!(pp, sol2)

println("gap = ", sol.u[end][1]-sol2.u[end])

# solution
x1 = x0*exp(-(4-0))+10
x2 = x1*exp(-(8-4))+10
x(t) = (0 ≤ t < 4 )*(x0*exp(-(t-0))) +
    (4 ≤ t < 8 )*(x1*exp(-(t-4))) +
    (8 ≤ t ≤ 10)*(x2*exp(-(t-8)))
N = 1000 
tspan = vcat(range(0, 4, N), range(4, 8, N), range(8, 10, N))
plot!(pp, tspan, x)

println("x(10) -  sol(10) = ", x(10)-sol(10)[1])
println("x(10) - sol2(10) = ", x(10)-sol2(10))
=#