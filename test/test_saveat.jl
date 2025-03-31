function test_saveat()

    Flow = CTFlows.Flow

    # with OrdinaryDiffEq, simple test
    f(u, p, t) = [u[2], -u[1]]
    u0 = [1, 0]
    tspan = (0, 2π)
    prob = ODEProblem(f, u0, tspan)
    sol = solve(prob, Tsit5(), reltol = 1e-8, abstol = 1e-8)
    @test sol(π/2) ≈ [0, -1] atol=1e-3

    # with OrdinaryDiffEq, test saveat    
    times = [π\4, π/2, π]
    sol = solve(prob, Tsit5(), reltol = 1e-8, abstol = 1e-8, saveat=times)
    for t ∈ [π\4, π/2, π]
        @test sol(t)[1] ≈ cos(t) atol=1e-3
    end

    # with CTFlows, simple test
    V(u) = [u[2], -u[1]]
    φ = Flow(V)
    t0 = 0
    tf = 2π
    u0 = [1, 0]
    sol = φ((t0, tf), u0)
    @test sol(π/2) ≈ [0, -1] atol=1e-3

    # with CTFlows, test saveat
    times = [π\4, π/2, π]
    sol = φ((t0, tf), u0; saveat=times)
    for t ∈ [π\4, π/2, π]
        @test sol(t)[1] ≈ cos(t) atol=1e-3
    end

    #
    t0 = 0
    tf = 1
    x0 = -1
    xf = 0
    α  = 1.5
    ocp = @def begin

        t ∈ [t0, tf], time
        x ∈ R, state
        u ∈ R, control

        x(t0) == x0
        x(tf) == xf

        ẋ(t) == -x(t) + α * x(t)^2 + u(t)

        ∫( 0.5u(t)^2 ) → min
        
    end
    u(x, p) = p
    φu = Flow(ocp, u)
    expo(p0, tf; saveat=[]) = φu((t0, tf), x0, p0; saveat=saveat)
    p0 = 0
    times = range(t0, tf, length=3)
    sol_saveat = expo(p0, tf; saveat=times)
    x_saveat = CTModels.state(sol_saveat)
    p_saveat = CTModels.costate(sol_saveat)
    for t ∈ times
        if (t == t0)
            @test x0 ≈ x_saveat(t) atol=1e-3
            @test p0 ≈ p_saveat(t) atol=1e-3
        else
            sol = expo(t0, t)
            x = CTModels.state(sol)
            p = CTModels.costate(sol)
            @test x(t) ≈ x_saveat(t) atol=1e-3
            @test p(t) ≈ p_saveat(t) atol=1e-3
        end
    end

end
