function test_flow_function()
    @testset "4D autonomous, non variable" begin
        V(z) = [z[2], z[2 + 2], 0.0, -z[2 + 1]]
        z = Flow(V)
        t0 = 0.0
        tf = 1.0
        x0 = [-1.0, 0.0]
        p0 = [12.0, 6.0]
        zf = z(t0, [x0; p0], tf)
        Test.@test zf ≈ [0.0, 0.0, 12.0, -6.0] atol = 1e-5
    end

    @testset "4D non autonomous, variable" begin
        V(t, z, l) = [z[2], (2 + l) * z[2 + 2], 0.0, -z[2 + 1]]
        z = Flow(V; autonomous=false, variable=true)
        t0 = 0.0
        tf = 1.0
        x0 = [-1.0, 0.0]
        p0 = [12.0, 6.0]
        zf = z(t0, [x0; p0], tf, -1.0)
        Test.@test zf ≈ [0.0, 0.0, 12.0, -6.0] atol = 1e-5
    end

    @testset "1D autonomous, non variable" begin
        V(x) = 2x
        z = Flow(V)
        x0 = 1.0
        xf = z(0.0, x0, 2π)
        Test.@test xf ≈ x0 * exp(4π) atol = 1e-5
    end

    @testset "Ricatti" begin
        #
        t0 = 0
        tf = 5
        x0 = [0, 1]
        Q = I
        R = I
        Rm1 = I
        A = [0 1; -1 0]
        B = [0; 1]

        # computing S
        ricatti(S) = -S * B * Rm1 * B' * S - (-Q + A' * S + S * A)
        #
        S = solve(
            ODEProblem((S, _, _) -> ricatti(S), zeros(size(A)), (tf, t0)),
            Tsit5();
            reltol=1e-12,
            abstol=1e-12,
        )
        #
        f = Flow(ricatti; autonomous=true, variable=false)
        SS = f((tf, t0), zeros(size(A)))
        #
        Test.@test S.u[end] ≈ SS.u[end] atol = 1e-5

        # computing x
        dyn(t, x) = A * x + B * Rm1 * B' * S(t) * x
        #
        x = solve(
            ODEProblem((x, _, t) -> dyn(t, x), x0, (t0, tf)),
            Tsit5();
            reltol=1e-8,
            abstol=1e-8,
        )
        #
        f = Flow(dyn; autonomous=false, variable=false)
        xx = f((t0, tf), x0)
        #
        Test.@test x.u[end] ≈ xx.u[end] atol = 1e-5

        # computing u
        u(t) = Rm1 * B' * S(t) * x(t)

        # computing p
        ϕ(t, p) = [p[2] + x(t)[1], x(t)[2] - p[1]]
        #
        p = solve(
            ODEProblem((p, _, t) -> ϕ(t, p), zeros(2), (tf, t0)),
            Tsit5();
            reltol=1e-8,
            abstol=1e-8,
        )
        #
        f = Flow(ϕ; autonomous=false, variable=false)
        pp = f((tf, t0), zeros(2))
        #
        Test.@test p.u[end] ≈ pp.u[end] atol = 1e-5

        # computing objective
        ψ(t) = 0.5 * (x(t)[1]^2 + x(t)[2]^2 + u(t)^2)
        #
        o = solve(
            ODEProblem((_, _, t) -> ψ(t), 0, (t0, tf)), Tsit5(); reltol=1e-8, abstol=1e-8
        )
        #
        f = Flow((t, _) -> ψ(t); autonomous=false, variable=false)
        oo = f((t0, tf), 0)
        #
        Test.@test o.u[end] ≈ oo.u[end] atol = 1e-5
    end
end
