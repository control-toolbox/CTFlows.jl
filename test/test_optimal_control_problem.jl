function test_optimal_control_problem()
    Flow = CTFlows.Flow
    * = CTFlows.:(*)

    @testset "Double integrator - energy" begin
        t0 = 0
        tf = 1
        x0 = [-1, 0]
        xf = [0, 0]
        A = [
            0 1
            0 0
        ]
        B = [
            0
            1
        ]

        # create the ocp
        pre_ocp = CTModels.PreModel()
        CTModels.time!(pre_ocp; t0=t0, tf=tf)
        CTModels.state!(pre_ocp, 2)
        CTModels.control!(pre_ocp, 1)
        dynamics!(r, t, x, u, v) = r .= [x[2], u[1]]
        CTModels.dynamics!(pre_ocp, dynamics!)
        lagrange(t, x, u, v) = 0.5 * u[1]^2
        CTModels.objective!(pre_ocp, :min; lagrange=lagrange)
        initi_condition(r, x0, xf, v) = r .= x0
        final_condition(r, x0, xf, v) = r .= xf
        CTModels.constraint!(pre_ocp, :boundary; f=initi_condition, lb=x0, ub=x0)
        CTModels.constraint!(pre_ocp, :boundary; f=final_condition, lb=xf, ub=xf)
        definition = quote
            t ∈ [t0, tf], time
            x ∈ R², state
            u ∈ R, control
            x(t0) == [-1, 0], (initial_con)
            x(tf) == [0, 0], (final_con)
            ẋ(t) == A * x(t) + B * u(t)
            ∫(0.5u(t)^2) → min
        end
        CTModels.definition!(pre_ocp, definition)
        CTModels.time_dependence!(pre_ocp; autonomous=true)
        ocp = CTModels.build(pre_ocp)
        # end create the ocp

        f = Flow(ocp, (x, p) -> p[2]; alg=BS5())
        p0 = [12, 6]

        xf_, pf = f(t0, x0, p0, tf)
        Test.@test xf_ ≈ xf atol = 1e-6

        sol = f((t0, tf), x0, p0)
        Test.@test plot(sol) isa Plots.Plot

        # on ne peut pas ajouter une variable pour un problème Fixed
        @test_throws MethodError f(t0, x0, p0, tf, 2)
        @test_throws MethodError f((t0, tf), x0, p0, 2)
    end

    @testset "tf variable: plot" begin
        t0 = 0
        x0 = 0
        xf = 1

        # create the ocp
        pre_ocp = CTModels.PreModel()
        CTModels.variable!(pre_ocp, 1)
        CTModels.time!(pre_ocp; t0=t0, indf=1)
        CTModels.state!(pre_ocp, 1)
        CTModels.control!(pre_ocp, 1)
        dynamics!(r, t, x, u, v) = r .= v[1]*u[1]
        CTModels.dynamics!(pre_ocp, dynamics!)
        lagrange(t, x, u, v) = 0.5 * u[1]^2
        mayer(x0, xf, v) = v[1]
        CTModels.objective!(pre_ocp, :min; lagrange=lagrange, mayer=mayer)
        initi_condition(r, x0, xf, v) = r .= x0
        final_condition(r, x0, xf, v) = r .= xf
        CTModels.constraint!(pre_ocp, :boundary; f=initi_condition, lb=[x0], ub=[x0])
        CTModels.constraint!(pre_ocp, :boundary; f=final_condition, lb=[xf], ub=[xf])
        definition = quote
            tf ∈ R, variable
            t ∈ [t0, tf], time
            x ∈ R, state
            u ∈ R, control
            ẋ(t) == tf * u(t)
            x(t0) == x0
            x(tf) == xf
            tf + 0.5∫(u(t)^2) → min
        end
        CTModels.definition!(pre_ocp, definition)
        CTModels.time_dependence!(pre_ocp; autonomous=true)
        ocp = CTModels.build(pre_ocp)
        # end create the ocp

        # solution
        tf = (3 / 2)^(1 / 4)
        p0 = 2tf / 3

        #
        f = Flow(ocp, (x, p, tf) -> tf * p; alg=Tsit5())
        sol = f((t0, tf), x0, p0, tf; alg=BS5())
        Test.@test plot(sol) isa Plots.Plot
    end

    @testset "objective: mayer" begin
        t0 = 0
        x0 = [-1, 0]
        xf = [0, 0]
        γ = 1
        A = [
            0 1
            0 0
        ]
        B = [
            0
            1
        ]

        # create the ocp
        pre_ocp = CTModels.PreModel()
        CTModels.variable!(pre_ocp, 1)
        CTModels.time!(pre_ocp; t0=t0, indf=1)
        CTModels.state!(pre_ocp, 2)
        CTModels.control!(pre_ocp, 1)
        dynamics!(r, t, x, u, v) = r .= [x[2], u[1]]
        CTModels.dynamics!(pre_ocp, dynamics!)
        mayer(x0, xf, v) = v[1]
        CTModels.objective!(pre_ocp, :min; mayer=mayer)
        initi_condition(r, x0, xf, v) = r .= x0
        final_condition(r, x0, xf, v) = r .= xf
        CTModels.constraint!(pre_ocp, :boundary; f=initi_condition, lb=x0, ub=x0)
        CTModels.constraint!(pre_ocp, :boundary; f=final_condition, lb=xf, ub=xf)
        CTModels.constraint!(pre_ocp, :control; lb=[-γ], ub=[γ])
        definition = quote
            tf ∈ R, variable
            t ∈ [t0, tf], time
            x ∈ R², state
            u ∈ R, control
            x(t0) == x0, (initial_con)
            x(tf) == xf, (final_con)
            -γ ≤ u(t) ≤ γ, (u_con)
            ẋ(t) == A * x(t) + B * u(t)
            tf → min
        end
        CTModels.definition!(pre_ocp, definition)
        CTModels.time_dependence!(pre_ocp; autonomous=true)
        ocp = CTModels.build(pre_ocp)
        # end create the ocp

        # solution
        a = x0[1]
        t1 = sqrt(-a)
        tf = 2 * t1
        α = 1 / t1
        β = 1
        p0 = [α, β]

        #
        fm = Flow(ocp, (x, p, v) -> -γ)
        fp = Flow(ocp, (x, p, v) -> +γ)
        f = fp * (t1, fm)

        sol = f((t0, tf), x0, p0, tf)
        Test.@test CTModels.objective(sol) ≈ tf atol = 1e-6
    end

    @testset "objective: Lagrange" begin
        t0 = 0
        tf = 1
        x0 = [-1, 0]
        xf = [0, 0]
        A = [
            0 1
            0 0
        ]
        B = [
            0
            1
        ]

        # create the ocp
        pre_ocp = CTModels.PreModel()
        CTModels.time!(pre_ocp; t0=t0, tf=tf)
        CTModels.state!(pre_ocp, 2)
        CTModels.control!(pre_ocp, 1)
        dynamics!(r, t, x, u, v) = r .= [x[2], u[1]]
        CTModels.dynamics!(pre_ocp, dynamics!)
        lagrange(t, x, u, v) = 0.5 * u[1]^2
        CTModels.objective!(pre_ocp, :min; lagrange=lagrange)
        initi_condition(r, x0, xf, v) = r .= x0
        final_condition(r, x0, xf, v) = r .= xf
        CTModels.constraint!(pre_ocp, :boundary; f=initi_condition, lb=x0, ub=x0)
        CTModels.constraint!(pre_ocp, :boundary; f=final_condition, lb=xf, ub=xf)
        definition = quote
            t ∈ [t0, tf], time
            x ∈ R², state
            u ∈ R, control
            x(t0) == [-1, 0], (initial_con)
            x(tf) == [0, 0], (final_con)
            ẋ(t) == A * x(t) + B * u(t)
            ∫(0.5u(t)^2) → min
        end
        CTModels.definition!(pre_ocp, definition)
        CTModels.time_dependence!(pre_ocp; autonomous=true)
        ocp = CTModels.build(pre_ocp)
        # end create the ocp

        # solution
        a = x0[1]
        b = x0[2]
        C = [
            -(tf - t0)^3/6 (tf - t0)^2/2
            -(tf - t0)^2/2 (tf-t0)
        ]
        D = [-a - b * (tf - t0), -b] + xf
        p0 = C \ D

        #
        f = Flow(ocp, (x, p) -> p[2])

        # objective value
        α = p0[1]
        β = p0[2]
        x(t) = [
            a + b * (t - t0) + β * (t - t0)^2 / 2.0 - α * (t - t0)^3 / 6.0,
            b + β * (t - t0) - α * (t - t0)^2 / 2.0,
        ]
        p(t) = [α, -α * (t - t0) + β]
        u(t) = p(t)[2]
        obj = 0.5 * (α^2 * (tf - t0)^3 / 3 + β^2 * (tf - t0) - α * β * (tf - t0)^2)

        # test
        sol = f((t0, tf), x0, p0)
        Test.@test CTModels.objective(sol) ≈ obj atol = 1e-6
    end

    @testset "objective: Bolza" begin
        t0 = 0
        tf = 1
        x0 = [0, 0]
        A = [
            0 1
            0 0
        ]
        B = [
            0
            1
        ]

        # create the ocp
        pre_ocp = CTModels.PreModel()
        CTModels.time!(pre_ocp; t0=t0, tf=tf)
        CTModels.state!(pre_ocp, 2)
        CTModels.control!(pre_ocp, 1)
        dynamics!(r, t, x, u, v) = r .= [x[2], u[1]]
        CTModels.dynamics!(pre_ocp, dynamics!)
        mayer(x0, xf, v) = -0.5*xf[1]
        lagrange(t, x, u, v) = 0.5 * u[1]^2
        CTModels.objective!(pre_ocp, :min; mayer=mayer, lagrange=lagrange)
        initi_condition(r, x0, xf, v) = r .= x0
        final_condition(r, x0, xf, v) = r .= xf
        CTModels.constraint!(pre_ocp, :boundary; f=initi_condition, lb=x0, ub=x0)
        definition = quote
            t ∈ [t0, tf], time
            x ∈ R², state
            u ∈ R, control
            x(t0) == x0, (initial_con)
            ẋ(t) == A * x(t) + B * u(t)
            -0.5x₁(tf) + ∫(0.5u(t)^2) → min
        end
        CTModels.definition!(pre_ocp, definition)
        CTModels.time_dependence!(pre_ocp; autonomous=true)
        ocp = CTModels.build(pre_ocp)
        # end create the ocp

        # solution
        a = x0[1]
        b = x0[2]
        α = 0.5
        β = tf / 2
        x(t) = [a + b * t + t^2 / 12 * (3 * tf - t), b + t / 4 * (2 * tf - t)]
        p(t) = [α, -α * t + β]
        u(t) = p(t)[2]
        obj = -0.5 * x(tf)[1] + (1 / 3) * (tf^3 / 8)

        #
        f = Flow(ocp, (x, p) -> p[2])

        # test
        p0 = p(t0)
        sol = f((t0, tf), x0, p0)
        Test.@test CTModels.objective(sol) ≈ obj atol = 1e-6
    end

    @testset "Double integrator energy - x₁ ≤ l" begin
        n = 1
        m = 1
        t0 = 0
        tf = 1
        x0 = -1

        #
        pre_ocp = CTModels.PreModel()
        CTModels.state!(pre_ocp, n)   # dimension of the state
        CTModels.control!(pre_ocp, m) # dimension of the control
        CTModels.time!(pre_ocp; t0=t0, tf=tf)
        initi_condition(r, x0, xf, v) = r .= x0
        CTModels.constraint!(pre_ocp, :boundary; f=initi_condition, lb=x0, ub=x0)
        path_constraint(r, t, x, u, v) = r .= x+u
        CTModels.constraint!(pre_ocp, :path; f=path_constraint, lb=(-Inf), ub=0)
        dynamics!(r, t, x, u, v) = r .= u
        CTModels.dynamics!(pre_ocp, dynamics!)
        lagrange(t, x, u, v) = -u
        CTModels.objective!(pre_ocp, :min; lagrange=lagrange)
        definition = quote end
        CTModels.definition!(pre_ocp, definition)
        CTModels.time_dependence!(pre_ocp; autonomous=true)
        ocp = CTModels.build(pre_ocp)
        # end create the ocp

        # the solution
        x(t) = -exp(-t)
        p(t) = exp(t - 1) - 1
        u(t) = -x(t)

        # Hamiltonian flow
        H(x, p, u, η) = p * u + u + η * (x + u) # pseudo-Hamiltonian
        η(x, p) = -(p + 1) # multiplier associated to the mixed constraint
        u(x, p) = -x
        H(x, p) = H(x, p, u(x, p), η(x, p))
        f = Flow(CTFlows.Hamiltonian(H))
        xf, pf = f(t0, x0, p(t0), tf)
        Test.@test xf ≈ x(tf) atol = 1e-6
        Test.@test pf ≈ p(tf) atol = 1e-6

        # ocp flow
        g(x, u) = x + u
        f = Flow(ocp, u, g, η)
        xf, pf = f(t0, x0, p(t0), tf)
        Test.@test xf ≈ x(tf) atol = 1e-6
        Test.@test pf ≈ p(tf) atol = 1e-6

        # ocp flow with u a ControlLaw, g a MixedConstraint and η a Multiplier
        u = CTFlows.ControlLaw((x, p) -> -x)
        g = CTFlows.MixedConstraint((x, u) -> x + u)
        η = CTFlows.Multiplier((x, p) -> -(p + 1))
        f = Flow(ocp, u, g, η)
        xf, pf = f(t0, x0, p(t0), tf)
        Test.@test xf ≈ x(tf) atol = 1e-6
        Test.@test pf ≈ p(tf) atol = 1e-6

        # # ocp flow with u a FeedbackControl, g a MixedConstraint and η a Function
        # u = CTFlows.FeedbackControl(x -> -x)
        # g = CTFlows.MixedConstraint((x, u) -> x + u)
        # η = (x, p) -> -(p + 1)
        # f = Flow(ocp, u, g, η)
        # xf, pf = f(t0, x0, p(t0), tf)
        # Test.@test xf ≈ x(tf) atol = 1e-6
        # Test.@test pf ≈ p(tf) atol = 1e-6

        # # ocp flow with u a FeedbackControl, g a Function and η a Multiplier
        # u = CTFlows.FeedbackControl(x -> -x)
        # g = (x, u) -> x + u
        # η = CTFlows.Multiplier((x, p) -> -(p + 1))
        # f = Flow(ocp, u, g, η)
        # xf, pf = f(t0, x0, p(t0), tf)
        # Test.@test xf ≈ x(tf) atol = 1e-6
        # Test.@test pf ≈ p(tf) atol = 1e-6
    end

    @testset "State constraint" begin
        # the model
        n = 2
        m = 1
        t0 = 0
        tf = 1
        x0 = [0, 1]
        xf = [0, -1]
        l = 1 / 9

        #
        pre_ocp = CTModels.PreModel()
        CTModels.state!(pre_ocp, n)   # dimension of the state
        CTModels.control!(pre_ocp, m) # dimension of the control
        CTModels.time!(pre_ocp; t0=t0, tf=tf)
        initi_condition(r, x0, xf, v) = r .= x0
        final_condition(r, x0, xf, v) = r .= xf
        CTModels.constraint!(pre_ocp, :boundary; f=initi_condition, lb=x0, ub=x0)
        CTModels.constraint!(pre_ocp, :boundary; f=final_condition, lb=xf, ub=xf)
        CTModels.constraint!(pre_ocp, :state; rg=1, lb=(-Inf), ub=l)
        dynamics!(r, t, x, u, v) = r .= [x[2], u[1]]
        CTModels.dynamics!(pre_ocp, dynamics!)
        lagrange(t, x, u, v) = 0.5u[1]^2
        CTModels.objective!(pre_ocp, :min; lagrange=lagrange)
        definition = quote end
        CTModels.definition!(pre_ocp, definition)
        CTModels.time_dependence!(pre_ocp; autonomous=true)
        ocp = CTModels.build(pre_ocp)
        # end create the ocp

        # the solution (case l ≤ 1/6 because it has 3 arc)
        arc(t) = [0 ≤ t ≤ 3 * l, 3 * l < t ≤ 1 - 3 * l, 1 - 3 * l < t ≤ 1]
        x =
            t -> (
                arc(t)[1] * [l * (1 - (1 - t / (3l))^3), (1 - t / (3l))^2] +
                arc(t)[2] * [l, 0] +
                arc(t)[3] * [l * (1 - (1 - (1 - t) / (3l))^3), -(1 - (1 - t) / (3l))^2]
            )
        u =
            t -> (
                arc(t)[1] * (-2 / (3l) * (1 - t / (3l))) +
                arc(t)[2] * 0 +
                arc(t)[3] * (-2 / (3l) * (1 - (1 - t) / (3l)))
            )
        α = -18
        β = -6
        p =
            t -> (
                arc(t)[1] * [α, -α * t + β] +
                arc(t)[2] * [0, 0] +
                arc(t)[3] * [-α, α * (t - 2 / 3)]
            )

        #
        fs = Flow(ocp, (x, p) -> p[2])
        l = 1 / 9
        u = CTFlows.FeedbackControl(x -> 0)
        g = CTFlows.StateConstraint(x -> x[1] - l)
        μ = CTFlows.Multiplier((x, p) -> 0)
        fc = Flow(ocp, u, g, μ)

        #
        t1 = 1 / 3
        t2 = 2 / 3
        p0 = [-18, -6]
        ν1 = 18
        ν2 = 18
        f = fs * (t1, ν1 * [1, 0], fc) * (t2, ν2 * [1, 0], fs)
        xf, pf = f(t0, x0, p0, tf)
        Test.@test xf ≈ x(tf) atol = 1e-6
        Test.@test pf ≈ p(tf) atol = 1e-6
    end

    @testset "tf variable" begin
        t0 = 0
        x0 = 0
        xf = 1

        # create the ocp
        pre_ocp = CTModels.PreModel()
        CTModels.variable!(pre_ocp, 1)
        CTModels.time!(pre_ocp; t0=t0, indf=1)
        CTModels.state!(pre_ocp, 1)
        CTModels.control!(pre_ocp, 1)
        dynamics!(r, t, x, u, v) = r .= v[1]*u[1]
        CTModels.dynamics!(pre_ocp, dynamics!)
        lagrange(t, x, u, v) = 0.5 * u[1]^2
        mayer(x0, xf, v) = v[1]
        CTModels.objective!(pre_ocp, :min; lagrange=lagrange, mayer=mayer)
        initi_condition(r, x0, xf, v) = r .= x0
        final_condition(r, x0, xf, v) = r .= xf
        CTModels.constraint!(pre_ocp, :boundary; f=initi_condition, lb=[x0], ub=[x0])
        CTModels.constraint!(pre_ocp, :boundary; f=final_condition, lb=[xf], ub=[xf])
        definition = quote
            tf ∈ R, variable
            t ∈ [t0, tf], time
            x ∈ R, state
            u ∈ R, control
            ẋ(t) == tf * u(t)
            x(t0) == x0
            x(tf) == xf
            tf + 0.5∫(u(t)^2) → min
        end
        CTModels.definition!(pre_ocp, definition)
        CTModels.time_dependence!(pre_ocp; autonomous=true)
        ocp = CTModels.build(pre_ocp)
        # end create the ocp

        u = (x, p, tf) -> tf * p
        F = Flow(ocp, u)

        # solution
        tf = (3 / 2)^(1 / 4)
        p0 = 2tf / 3

        # tf is provided twice
        xf_, pf_ = F(t0, x0, p0, tf, tf)
        Test.@test xf ≈ xf_ atol = 1e-6

        # tf is provided once
        xf_, pf_ = F(t0, x0, p0, tf)
        Test.@test xf ≈ xf_ atol = 1e-6
    end

    @testset "t0 variable" begin
        t0 = 0
        x0 = 0
        xf = 1

        # create the ocp
        pre_ocp = CTModels.PreModel()
        CTModels.variable!(pre_ocp, 1)
        CTModels.time!(pre_ocp; ind0=1, tf=t0)
        CTModels.state!(pre_ocp, 1)
        CTModels.control!(pre_ocp, 1)
        dynamics!(r, t, x, u, v) = r .= -v[1]*u[1]
        CTModels.dynamics!(pre_ocp, dynamics!)
        lagrange(t, x, u, v) = -0.5 * u[1]^2
        mayer(x0, xf, v) = v[1]
        CTModels.objective!(pre_ocp, :min; lagrange=lagrange, mayer=mayer)
        initi_condition(r, x0, xf, v) = r .= x0
        final_condition(r, x0, xf, v) = r .= xf
        CTModels.constraint!(pre_ocp, :boundary; f=initi_condition, lb=[xf], ub=[xf])
        CTModels.constraint!(pre_ocp, :boundary; f=final_condition, lb=[x0], ub=[x0])
        definition = quote
            tf ∈ R, variable
            s ∈ [tf, t0], time
            x ∈ R, state
            u ∈ R, control
            ẋ(s) == -tf * u(s)
            x(tf) == xf
            x(t0) == x0
            tf - 0.5∫(u(s)^2) → min
        end
        CTModels.definition!(pre_ocp, definition)
        CTModels.time_dependence!(pre_ocp; autonomous=true)
        ocp = CTModels.build(pre_ocp)
        # end create the ocp

        u = (x, p, tf) -> tf * p
        F = Flow(ocp, u)

        # solution
        tf = (3 / 2)^(1 / 4)
        p0 = -2tf / 3

        # tf is provided twice: it plays the role of the initial time
        x0_, pf_ = F(tf, xf, p0, t0, tf)
        Test.@test x0 ≈ x0_ atol = 1e-6

        # tf is provided once
        x0_, pf_ = F(tf, xf, p0, t0)
        Test.@test x0 ≈ x0_ atol = 1e-6
    end

    @testset "t0 and tf variable" begin
        x0 = 0
        xf = 1

        # create the ocp
        pre_ocp = CTModels.PreModel()
        CTModels.variable!(pre_ocp, 2)
        CTModels.time!(pre_ocp; ind0=1, indf=2)
        CTModels.state!(pre_ocp, 1)
        CTModels.control!(pre_ocp, 1)
        dynamics!(r, t, x, u, v) = r .= v[1] + v[2]*u[1]
        CTModels.dynamics!(pre_ocp, dynamics!)
        lagrange(t, x, u, v) = 0.5 * u[1]^2
        mayer(x0, xf, v) = v[1]^2 + v[2]
        CTModels.objective!(pre_ocp, :min; lagrange=lagrange, mayer=mayer)
        initi_condition(r, x0, xf, v) = r .= x0
        final_condition(r, x0, xf, v) = r .= xf
        CTModels.constraint!(pre_ocp, :boundary; f=initi_condition, lb=[xf], ub=[xf])
        CTModels.constraint!(pre_ocp, :boundary; f=final_condition, lb=[x0], ub=[x0])
        definition = quote
            v = (t0, tf) ∈ R^2, variable
            t ∈ [t0, tf], time
            x ∈ R, state
            u ∈ R, control
            ẋ(t) == tf * u(t) + t0
            x(t0) == x0
            x(tf) == xf
            (t0^2 + tf) + 0.5∫(u(t)^2) → min
        end
        CTModels.definition!(pre_ocp, definition)
        CTModels.time_dependence!(pre_ocp; autonomous=true)
        ocp = CTModels.build(pre_ocp)
        # end create the ocp

        u = (x, p, v) -> v[2] * p
        F = Flow(ocp, u)

        # solution
        t0 = 0
        tf = (3 / 2)^(1 / 4)
        p0 = 2tf / 3

        # t0, tf are provided twice
        xf_, pf_ = F(t0, x0, p0, tf, [t0, tf])
        Test.@test xf ≈ xf_ atol = 1e-6

        # t0, tf are provided once
        xf_, pf_ = F(t0, x0, p0, tf)
        Test.@test xf ≈ xf_ atol = 1e-6
    end

    @testset "Autonomous case" begin
        t0 = 0
        tf = 1
        x0 = [-1, 0]

        ocp = @def begin
            t ∈ [t0, tf], time
            x = (q, v) ∈ R², state
            u ∈ R, control

            x(t0) == x0
            x(tf) == [0, 0]
            ẋ(t) == [v(t), u(t)]

            ∫(0.5u(t)^2) → min
        end

        u = (x, p) -> p[2]
        p0 = [12, 6]

        f = Flow(ocp, u; autonomous=true)
        xf, pf = f(t0, x0, p0, tf)
        Test.@test xf ≈ [0, 0] atol = 1e-6

        f = Flow(ocp, u)
        xf, pf = f(t0, x0, p0, tf)
        Test.@test xf ≈ [0, 0] atol = 1e-6

        u_t = (t, x, p) -> p[2]
        f = Flow(ocp, u_t; autonomous=false)
        xf, pf = f(t0, x0, p0, tf)
        Test.@test xf ≈ [0, 0] atol = 1e-6
    end

    @testset "Non autonomous case" begin
        t0 = 0
        tf = π/4
        x0 = 0
        xf = tan(π/4) - 2log(√(2)/2)

        ocp = @def begin
            t ∈ [t0, tf], time
            x ∈ R, state
            u ∈ R, control

            x(t0) == x0
            x(tf) == xf
            ẋ(t) == u(t) * (1 + tan(t)) # The dynamics depend explicitly on t

            0.5∫(u(t)^2) → min
        end

        u = (t, x, p) -> p * (1 + tan(t))
        p0 = 1

        f = Flow(ocp, u; autonomous=false)
        xf, pf = f(t0, x0, p0, tf)
        Test.@test xf - (tan(π/4) - 2log(√(2)/2)) ≈ 0 atol = 1e-6

        f = Flow(ocp, u)
        xf, pf = f(t0, x0, p0, tf)
        Test.@test xf - (tan(π/4) - 2log(√(2)/2)) ≈ 0 atol = 1e-6
    end
end
