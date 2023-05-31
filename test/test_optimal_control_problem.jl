function test_optimal_control_problem()

    @testset "Double integrator - energy" begin
        # the model
        n=2
        m=1
        t0=0
        tf=1
        x0=[-1, 0]
        xf=[0, 0]
        ocp = Model()
        state!(ocp, n)   # dimension of the state
        control!(ocp, m) # dimension of the control
        time!(ocp, [t0, tf])
        constraint!(ocp, :initial, x0, :initial_constraint)
        constraint!(ocp, :final, xf, :final_constraint)
        dynamics!(ocp, (x, u) -> [x[2], u])
        objective!(ocp, :lagrange, (x, u) -> 0.5u^2) # default is to minimise
        f = Flow(ocp, (x, p) -> p[2])
        p0 = [12, 6]
        xf_, pf = f(t0, x0, p0, tf)
        @test xf_ ≈ xf atol=1e-6
    end

    
#=
# the model
n=1
m=1
t0=0
tf=1
x0=-1
xf=0
ocp = Model()
state!(ocp, n)   # dimension of the state
control!(ocp, m) # dimension of the control
time!(ocp, [t0, tf])
constraint!(ocp, :initial, x0, :initial_constraint)
constraint!(ocp, :final, xf, :final_constraint)
constraint!(ocp, :control, -1, 1, :control_constraint) 
dynamics!(ocp, (x, u) -> -x + u)
objective!(ocp, :lagrange, (x, u) -> abs(u)) # default is to minimise

# Flow(ocp, u)
f0 = Flow(ocp, (x, p) -> 0)
f1 = Flow(ocp, (x, p) -> 1)

p0 = 1/(x0-(xf-1)/exp(-tf))
t1 = -log(p0)

f = f0 * (t1, f1)

sol = f((t0, tf), x0, p0)
@test plot(sol) isa Plots.Plot

xf_, pf = f(t0, x0, p0, tf)
@test xf_ ≈ xf atol=1e-6
=#

end