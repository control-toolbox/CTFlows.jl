function test_concatenation()

    t0 = 0
    tf = 1
    a = -1
    b = 0
    c = 12
    d = 6
    x0 = [a, b]
    p0 = [c, d]

    n = length(x0)

    #
    control(_, p) = p[2]
    H1(x, p) = p[1] * x[2] + p[2] * control(x, p) - 0.5 * control(x, p)^2
    H2(x, p) = -H1(x, p)
    H3(t, x, p) = H1(x, p)
    #
    dx(x, p) = [x[2], control(x, p)]
    dp(x, p) = [0.0, -p[1]]
    #   
    Hv1(x, p) = dx(x, p), dp(x, p)
    Hv2(x, p) = -dx(x, p), -dp(x, p)
    Hv3(t, x, p) = Hv1(x, p)
    #
    V1(z) = vcat(dx(z[1:n], z[n+1:2n]), dp(z[1:n], z[n+1:2n]))
    V2(z) = -V1(z)
    V3(t, z) = V1(z)
    #
    # solution
    x1_sol(t) = a + b * t + 0.5 * d * t^2 - c * t^3 / 6
    x2_sol(t) = b + d * t - 0.5 * c * t^2
    p1_sol(t) = c
    p2_sol(t) = d - c * t
    z_sol(t) = [x1_sol(t), x2_sol(t), p1_sol(t), p2_sol(t)]

    @testset "Hamiltonian" begin

        #
        f1 = Flow(Hamiltonian(H1))
        f2 = Flow(Hamiltonian(H2))
        f3 = Flow(Hamiltonian(H3, autonomous = false))

        # one flow is used because t1 > tf
        f = f1 * (2tf, f2)
        xf, pf = f(t0, x0, p0, tf)
        Test.@test xf ≈ [x1_sol(tf), x2_sol(tf)] atol = 1e-5
        Test.@test pf ≈ [p1_sol(tf), p2_sol(tf)] atol = 1e-5

        # two flows: going back
        f = f1 * ((t0 + tf) / 2, f2)
        xf, pf = f(t0, x0, p0, tf)
        Test.@test xf ≈ x0 atol = 1e-5
        Test.@test pf ≈ p0 atol = 1e-5

        # three flows: go forward
        f = f1 * ((t0 + tf) / 4, f2) * ((t0 + tf) / 2, f1)
        xf, pf = f(t0, x0, p0, tf + (t0 + tf) / 2)
        Test.@test xf ≈ [x1_sol(tf), x2_sol(tf)] atol = 1e-5
        Test.@test pf ≈ [p1_sol(tf), p2_sol(tf)] atol = 1e-5

        # autonomous and nonautonomous
        f = f1 * ((t0 + tf) / 4, f2) * ((t0 + tf) / 2, f3)
        xf, pf = f(t0, x0, p0, tf + (t0 + tf) / 2)
        Test.@test xf ≈ [x1_sol(tf), x2_sol(tf)] atol = 1e-5
        Test.@test pf ≈ [p1_sol(tf), p2_sol(tf)] atol = 1e-5

        # on a grid
        f = f1 * ((t0 + tf) / 4, f1) * ((t0 + tf) / 2, f1)
        N = 100
        saveat = range(t0, tf, N)
        sol = f((t0, tf), x0, p0, saveat = saveat)
        xf = sol.u[end][1:n]
        pf = sol.u[end][n+1:2n]
        Test.@test xf ≈ [x1_sol(tf), x2_sol(tf)] atol = 1e-5
        Test.@test pf ≈ [p1_sol(tf), p2_sol(tf)] atol = 1e-5
        zspan = sol.u
        zspan_sol = z_sol.(sol.t)
        Test.@test zspan ≈ zspan_sol atol = 1e-5
    end

    @testset "Hamiltonian vector field" begin

        #
        f1 = Flow(HamiltonianVectorField(Hv1))
        f2 = Flow(HamiltonianVectorField(Hv2))
        f3 = Flow(HamiltonianVectorField(Hv3, autonomous = false))

        # one flow is used because t1 > tf
        f = f1 * (2tf, f2)
        xf, pf = f(t0, x0, p0, tf)
        Test.@test xf ≈ [x1_sol(tf), x2_sol(tf)] atol = 1e-5
        Test.@test pf ≈ [p1_sol(tf), p2_sol(tf)] atol = 1e-5

        # two flows: going back
        f = f1 * ((t0 + tf) / 2, f2)
        xf, pf = f(t0, x0, p0, tf)
        Test.@test xf ≈ x0 atol = 1e-5
        Test.@test pf ≈ p0 atol = 1e-5

        # three flows: go forward
        f = f1 * ((t0 + tf) / 4, f2) * ((t0 + tf) / 2, f1)
        xf, pf = f(t0, x0, p0, tf + (t0 + tf) / 2)
        Test.@test xf ≈ [x1_sol(tf), x2_sol(tf)] atol = 1e-5
        Test.@test pf ≈ [p1_sol(tf), p2_sol(tf)] atol = 1e-5

        # autonomous and nonautonomous
        f = f1 * ((t0 + tf) / 4, f2) * ((t0 + tf) / 2, f3)
        xf, pf = f(t0, x0, p0, tf + (t0 + tf) / 2)
        Test.@test xf ≈ [x1_sol(tf), x2_sol(tf)] atol = 1e-5
        Test.@test pf ≈ [p1_sol(tf), p2_sol(tf)] atol = 1e-5

        # on a grid
        f = f1 * ((t0 + tf) / 4, f1) * ((t0 + tf) / 2, f1)
        N = 100
        saveat = range(t0, tf, N)
        sol = f((t0, tf), x0, p0, saveat = saveat)
        xf = sol.u[end][1:n]
        pf = sol.u[end][n+1:2n]
        Test.@test xf ≈ [x1_sol(tf), x2_sol(tf)] atol = 1e-5
        Test.@test pf ≈ [p1_sol(tf), p2_sol(tf)] atol = 1e-5
        zspan = sol.u
        zspan_sol = z_sol.(sol.t)
        Test.@test zspan ≈ zspan_sol atol = 1e-5
    end

    @testset "Vector field" begin

        #
        f1 = Flow(VectorField(V1))
        f2 = Flow(VectorField(V2))
        f3 = Flow(VectorField(V3, autonomous = false))

        # one flow is used because t1 > tf
        f = f1 * (2tf, f2)
        zf = f(t0, [x0; p0], tf)
        Test.@test zf ≈ [x1_sol(tf), x2_sol(tf), p1_sol(tf), p2_sol(tf)] atol = 1e-5

        # two flows: going back
        f = f1 * ((t0 + tf) / 2, f2)
        zf = f(t0, [x0; p0], tf)
        Test.@test zf ≈ [x0; p0] atol = 1e-5

        # three flows: go forward
        f = f1 * ((t0 + tf) / 4, f2) * ((t0 + tf) / 2, f1)
        zf = f(t0, [x0; p0], tf + (t0 + tf) / 2)
        Test.@test zf ≈ [x1_sol(tf), x2_sol(tf), p1_sol(tf), p2_sol(tf)] atol = 1e-5

        # autonomous and nonautonomous
        f = f1 * ((t0 + tf) / 4, f2) * ((t0 + tf) / 2, f3)
        zf = f(t0, [x0; p0], tf + (t0 + tf) / 2)
        Test.@test zf ≈ [x1_sol(tf), x2_sol(tf), p1_sol(tf), p2_sol(tf)] atol = 1e-5

        # on a grid
        f = f1 * ((t0 + tf) / 4, f1) * ((t0 + tf) / 2, f1)
        N = 100
        saveat = range(t0, tf, N)
        sol = f((t0, tf), [x0; p0], saveat = saveat)
        xf = sol.u[end][1:n]
        pf = sol.u[end][n+1:2n]
        Test.@test xf ≈ [x1_sol(tf), x2_sol(tf)] atol = 1e-5
        Test.@test pf ≈ [p1_sol(tf), p2_sol(tf)] atol = 1e-5
        zspan = sol.u
        zspan_sol = z_sol.(sol.t)
        Test.@test zspan ≈ zspan_sol atol = 1e-5

    end

    @testset "Function" begin

        #
        f1 = Flow(V1)
        f2 = Flow(V2)
        f3 = Flow(V3, autonomous = false)

        # one flow is used because t1 > tf
        f = f1 * (2tf, f2)
        zf = f(t0, [x0; p0], tf)
        Test.@test zf ≈ [x1_sol(tf), x2_sol(tf), p1_sol(tf), p2_sol(tf)] atol = 1e-5

        # two flows: going back
        f = f1 * ((t0 + tf) / 2, f2)
        zf = f(t0, [x0; p0], tf)
        Test.@test zf ≈ [x0; p0] atol = 1e-5

        # three flows: go forward
        f = f1 * ((t0 + tf) / 4, f2) * ((t0 + tf) / 2, f1)
        zf = f(t0, [x0; p0], tf + (t0 + tf) / 2)
        Test.@test zf ≈ [x1_sol(tf), x2_sol(tf), p1_sol(tf), p2_sol(tf)] atol = 1e-5

        # autonomous and nonautonomous
        f = f1 * ((t0 + tf) / 4, f2) * ((t0 + tf) / 2, f3)
        zf = f(t0, [x0; p0], tf + (t0 + tf) / 2)
        Test.@test zf ≈ [x1_sol(tf), x2_sol(tf), p1_sol(tf), p2_sol(tf)] atol = 1e-5

        # on a grid
        f = f1 * ((t0 + tf) / 4, f1) * ((t0 + tf) / 2, f1)
        N = 100
        saveat = range(t0, tf, N)
        sol = f((t0, tf), [x0; p0], saveat = saveat)
        xf = sol.u[end][1:n]
        pf = sol.u[end][n+1:2n]
        Test.@test xf ≈ [x1_sol(tf), x2_sol(tf)] atol = 1e-5
        Test.@test pf ≈ [p1_sol(tf), p2_sol(tf)] atol = 1e-5
        zspan = sol.u
        zspan_sol = z_sol.(sol.t)
        Test.@test zspan ≈ zspan_sol atol = 1e-5

    end

    @testset "Jump is 0" begin

        # Hamiltonien
        f1 = Flow(Hamiltonian(H1))
        f2 = Flow(Hamiltonian(H2))
        f3 = Flow(Hamiltonian(H3, autonomous = false))
        f = f1 * ((t0 + tf) / 4, [0, 0], f2) * ((t0 + tf) / 2, f3)
        xf, pf = f(t0, x0, p0, tf + (t0 + tf) / 2)
        Test.@test xf ≈ [x1_sol(tf), x2_sol(tf)] atol = 1e-5
        Test.@test pf ≈ [p1_sol(tf), p2_sol(tf)] atol = 1e-5

        # vector field
        f1 = Flow(VectorField(V1))
        f2 = Flow(VectorField(V2))
        f3 = Flow(VectorField(V3, autonomous = false))
        f = f1 * ((t0 + tf) / 4, [0, 0, 0, 0], f2) * ((t0 + tf) / 2, f3)
        zf = f(t0, [x0; p0], tf + (t0 + tf) / 2)
        Test.@test zf ≈ [x1_sol(tf), x2_sol(tf), p1_sol(tf), p2_sol(tf)] atol = 1e-5

    end

    @testset "Bounce" begin

        # example from https://docs.sciml.ai/DiffEqDocs/stable/features/callback_functions/#DiscreteCallback-Examples
        function dyn(du, u, p, t)
            du[1] = -u[1]
        end
        u0 = [10.0]
        prob = ODEProblem(dyn, u0, (0.0, 10.0))
        dosetimes = [4.0, 8.0]
        condition(u, t, integrator) = t ∈ dosetimes
        affect!(integrator) = integrator.u[1] += 10
        cb = DiscreteCallback(condition, affect!)
        sol = solve(prob, Tsit5(), callback = cb, tstops = dosetimes)

        #
        x0 = 10

        # vector field
        V = x -> -x
        f = Flow(VectorField(V))
        fc = f * (4, 10, f) * (8, 10, f)
        sol2 = fc((0, 10), x0)

        # vector field
        f = Flow(V)
        fc = f * (4, 10, f) * (6, f) * (8, 10, f) * (9, f)
        sol3 = fc((0, 10), x0)

        # test
        N = 100
        tspan = range(0, 10, N)
        Test.@test norm([sol(t)[1] - sol2(t) for t ∈ tspan]) / N ≈ 0 atol = 1e-3
        Test.@test norm([sol(t)[1] - sol3(t) for t ∈ tspan]) / N ≈ 0 atol = 1e-3

        # -------
        f = Flow(Hamiltonian((x, p) -> 0.5p^2))
        fc =
            f *
            (1, 1, f) *
            (1.5, f) *
            (2, 1, f) *
            (2.5, f) *
            (3, 1, f) *
            (3.5, f) *
            (4, 1, f)
        xf, pf = fc(0, 0, 0, 5)
        Test.@test xf ≈ 10 atol = 1e-6
        Test.@test pf ≈ 4 atol = 1e-6

        # -------
        f = Flow(HamiltonianVectorField((x, p) -> ([p[1], 0], [0, 0])))
        fc =
            f *
            (1, [1, 0], f) *
            (1.5, f) *
            (2, [1, 0], f) *
            (2.5, f) *
            (3, [1, 0], f) *
            (3.5, f) *
            (4, [1, 0], f)
        xf, pf = fc(0, [0, 0], [0, 0], 5)
        Test.@test xf[1] ≈ 10 atol = 1e-6
        Test.@test pf[1] ≈ 4 atol = 1e-6

    end

    @testset "Bounce OCP" begin
        ocp = Model()
        state!(ocp, 2)
        control!(ocp, 2)
        time!(ocp, t0 = 0, tf = 5)
        constraint!(ocp, :initial, lb = [0, 0], ub = [0, 0])
        dynamics!(ocp, (x, u) -> u)
        objective!(ocp, :mayer, (x0, xf) -> xf)
        f = Flow(ocp, (x, p) -> [p[1] / 2, 0])
        fc =
            f *
            (1, [1, 0], f) *
            (1.5, f) *
            (2, [1, 0], f) *
            (2.5, f) *
            (3, [1, 0], f) *
            (3.5, f) *
            (4, [1, 0], f)
        xf, pf = fc(0, [0, 0], [0, 0], 5)
        Test.@test xf[1] ≈ 10 atol = 1e-6
        Test.@test pf[1] ≈ 4 atol = 1e-6
    end

    @testset "Concat OCP" begin
        ocp = Model()
        state!(ocp, 1)
        control!(ocp, 1)
        time!(ocp, t0 = 0, tf = 1)
        constraint!(ocp, :initial, lb = -1, ub = -1, label = :initial_constraint)
        constraint!(ocp, :final, lb = 0, ub = 0, label = :final_constraint)
        constraint!(ocp, :control, lb = -1, ub = 1, label = :control_constraint)
        dynamics!(ocp, (x, u) -> -x + u)
        objective!(ocp, :lagrange, (x, u) -> abs(u))
        f0 = Flow(ocp, ControlLaw((x, p) -> 0))
        f1 = Flow(ocp, (x, p) -> 1)
        p0 = 1 / (-1 - (0 - 1) / exp(-1))
        t1 = -log(p0)
        f = f0 * (t1, f1)
        xf_, pf = f(0, -1, p0, 1)
        Test.@test xf_ ≈ 0 atol = 1e-6
    end

end
