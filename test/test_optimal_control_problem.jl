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
        sol = f((t0, tf), x0, p0)
        @test plot(sol) isa Plots.Plot
    end

    @testset "Double integrator energy - x₁ ≤ l" begin
        n=1
        m=1
        t0=0
        tf=1
        x0=-1
        ocp = Model()
        state!(ocp, n)   # dimension of the state
        control!(ocp, m) # dimension of the control
        time!(ocp, [t0, tf])
        constraint!(ocp, :initial, x0)
        constraint!(ocp, :mixed, (x,u) -> x + u, -Inf, 0)
        dynamics!(ocp, (x, u) -> u)
        objective!(ocp, :lagrange, (x, u) -> -u)
    
        # the solution
        x(t) = -exp(-t)
        p(t) = 1-exp(t-1)
        u(t) = -x(t)

        # Hamiltonian flow
        H(x, p, u, η) = p*u - u + η*(x + u) # pseudo-Hamiltonian
        η(x, p) = -(p + 1) # multiplier associated to the mixed constraint
        u(x, p) = -x
        H(x, p) = H(x, p, u(x, p), η(x, p))
        f = Flow(Hamiltonian(H))
        xf, pf = f(t0, x0, p(t0), tf)
        @test xf ≈ x(tf) atol=1e-6
        @test pf ≈ p(tf) atol=1e-6

        # ocp flow
        g(x, u) = x+u
        f = Flow(ocp, u, g, η)
        xf, pf = f(t0, x0, p(t0), tf)
        @test xf ≈ x(tf) atol=1e-6
        @test pf ≈ p(tf) atol=1e-6

        # ocp flow with u a ControlLaw, g a MixedConstraint and η a Multiplier
        u = ControlLaw((x, p) -> -x)
        g = MixedConstraint((x, u) -> x+u)
        η = Multiplier((x, p) -> -(p+1))
        f = Flow(ocp, u, g, η)
        xf, pf = f(t0, x0, p(t0), tf)
        @test xf ≈ x(tf) atol=1e-6
        @test pf ≈ p(tf) atol=1e-6

        # ocp flow with u a FeedbackControl, g a MixedConstraint and η a Function
        u = FeedbackControl(x -> -x)
        g = MixedConstraint((x, u) -> x+u)
        η = (x, p) -> -(p+1)
        f = Flow(ocp, u, g, η)
        xf, pf = f(t0, x0, p(t0), tf)
        @test xf ≈ x(tf) atol=1e-6
        @test pf ≈ p(tf) atol=1e-6

        # ocp flow with u a FeedbackControl, g a Function and η a Multiplier
        u = FeedbackControl(x -> -x)
        g = (x, u) -> x+u
        η = Multiplier((x, p) -> -(p+1))
        f = Flow(ocp, u, g, η)
        xf, pf = f(t0, x0, p(t0), tf)
        @test xf ≈ x(tf) atol=1e-6
        @test pf ≈ p(tf) atol=1e-6

    end

    @testset "State constraint" begin
        # the model
        n=2
        m=1
        t0=0
        tf=1
        x0=[0, 1]
        xf=[0, -1]
        l = 1/9
        ocp = Model()
        state!(ocp, n)   # dimension of the state
        control!(ocp, m) # dimension of the control
        time!(ocp, [t0, tf])
        constraint!(ocp, :initial, x0)
        constraint!(ocp, :final,   xf)
        constraint!(ocp, :state, Index(1), -Inf, l)
        A = [ 0 1
            0 0 ]
        B = [ 0
            1 ]
        dynamics!(ocp, (x, u) -> A*x + B*u)
        objective!(ocp, :lagrange, (x, u) -> 0.5u^2) # default is to minimise
    
        # the solution (case l ≤ 1/6 because it has 3 arc)
        arc(t) = [0 ≤ t ≤ 3*l, 3*l < t ≤ 1 - 3*l, 1 - 3*l < t ≤ 1]
        x = t -> (arc(t)[1]*[l*(1-(1-t/(3l))^3), (1-t/(3l))^2] + 
                  arc(t)[2]*[l, 0] + 
                  arc(t)[3]*[l*(1-(1-(1-t)/(3l))^3), -(1-(1-t)/(3l))^2])
        u = t -> (arc(t)[1]*(-2/(3l)*(1-t/(3l))) + arc(t)[2]*0 + arc(t)[3]*(-2/(3l)*(1-(1-t)/(3l))))
        α = -18
        β = -6
        p = t -> (arc(t)[1]*[α, -α*t+β] + arc(t)[2]*[0, 0] + arc(t)[3]*[-α, α*(t-2/3)])

        #
        fs = Flow(ocp, (x, p) -> p[2])
        l = 1/9
        u = FeedbackControl(x -> 0)
        g = StateConstraint(x -> x[1]-l)
        μ = Multiplier((x, p) -> 0)
        fc = Flow(ocp, u, g, μ)
        
        #
        t1 = 1/3
        t2 = 2/3
        p0 = [-18, -6]
        ν1 = 18
        ν2 = 18
        f = fs * (t1, ν1*[1, 0], fc) * (t2, ν2*[1, 0], fs)
        xf, pf = f(t0, x0, p0, tf)
        @test xf ≈ x(tf) atol=1e-6
        @test pf ≈ p(tf) atol=1e-6

    end

end