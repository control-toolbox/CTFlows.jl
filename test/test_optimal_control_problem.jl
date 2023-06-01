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

end