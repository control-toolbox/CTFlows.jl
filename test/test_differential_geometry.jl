using CTFlows
using Test
using LinearAlgebra

# Helper for testing
function isapprox_vec(a, b; atol=1e-6)
    return norm(a - b) < atol
end

@testset "Differential Geometry V3" begin

    @testset "ad() - Lie Derivative" begin
        # Autonomous
        X(x) = [x[2], -x[1]]
        f(x) = x[1]^2 + x[2]^2
        Lf = CTFlows.ad(X, f)
        @test Lf([1.0, 2.0]) ≈ 0.0 atol = 1e-6

        # Non-autonomous
        X_na(t, x) = [t * x[2], -x[1]]
        f_na(t, x) = t + x[1]^2
        Lf_na = CTFlows.ad(X_na, f_na; autonomous=false)
        # Lf(t, x) = ∂f/∂x * X + ∂f/∂t (Wait, Lie derivative usually only space derivative?)
        # Standard definition L_X f = ∇f · X. Time derivative is separate usually.
        # Implementation check:
        # ad uses derivative(g, ...). g(s) = foo(t, x + s*X)
        # d/ds g(0) = ∇x foo · X. Correct.

        # ∂f/∂x = [2x1, 0]
        # X = [t*x2, -x1]
        # dot = 2x1*t*x2
        # t=2, x=[1, 2] -> 2*1*2*2 = 8
        @test Lf_na(2.0, [1.0, 2.0]) ≈ 8.0 atol = 1e-6
    end

    @testset "ad() - Lie Bracket" begin
        # Autonomous
        X(x) = [x[2], 0.0]
        Y(x) = [0.0, x[1]]
        # [X, Y] = J_Y*X - J_X*Y
        # J_Y = [0 0; 1 0], X = [x2, 0] -> J_Y*X = [0, x2]
        # J_X = [0 1; 0 0], Y = [0, x1] -> J_X*Y = [x1, 0]
        # [X, Y] = [0, x2] - [x1, 0] = [-x1, x2]
        XY = CTFlows.ad(X, Y)
        @test isapprox_vec(XY([1.0, 2.0]), [-1.0, 2.0])

        # Macro check
        XY_macro = CTFlows.@Lie [X, Y]
        @test isapprox_vec(XY_macro([1.0, 2.0]), [-1.0, 2.0])
    end

    @testset "Lift()" begin
        f(x) = [x[1], x[2]]
        H = CTFlows.Lift(f)
        # H(x, p) = p' * f(x) = p1*x1 + p2*x2
        @test H([1.0, 2.0], [3.0, 4.0]) ≈ 1.0 * 3.0 + 2.0 * 4.0 atol = 1e-6

        # Non-autonomous
        g(t, x) = [t * x[1], x[2]]
        Hg = CTFlows.Lift(g; autonomous=false)
        @test Hg(2.0, [1.0, 2.0], [3.0, 4.0]) ≈ 3.0 * (2.0 * 1.0) + 4.0 * 2.0 atol = 1e-6
    end

    @testset "Poisson()" begin
        H(x, p) = 0.5 * (p[1]^2 + p[2]^2)
        G(x, p) = x[1]
        # {H, G} = ∂H/∂p * ∂G/∂x - ∂H/∂x * ∂G/∂p
        # ∂H/∂p = [p1, p2], ∂G/∂x = [1, 0] -> dot = p1
        # ∂H/∂x = [0, 0] -> term 2 is 0
        PB = CTFlows.Poisson(H, G)
        @test PB([1.0, 2.0], [3.0, 4.0]) ≈ 3.0 atol = 1e-6

        # Macro check
        PB_macro = CTFlows.@Lie {H, G}
        @test PB_macro([1.0, 2.0], [3.0, 4.0]) ≈ 3.0 atol = 1e-6
    end

    @testset "Variable dependence" begin
        # H(x, p, v)
        H(x, p, v) = v[1] * p[1] * x[1]
        G(x, p, v) = x[1]
        # {H, G} -> ∂H/∂p * ∂G/∂x ...
        # ∂H/∂p = [v*x1, 0], ∂G/∂x = [1, 0] -> v*x1
        PB = CTFlows.Poisson(H, G; variable=true)
        # v=2, x=[3, 4], p=[5, 6] -> 2*3 = 6
        @test PB([3.0, 4.0], [5.0, 6.0], [2.0]) ≈ 6.0 atol = 1e-6

        # Macro with options
        PB_macro = CTFlows.@Lie {H, G} variable = true
        @test PB_macro([3.0, 4.0], [5.0, 6.0], [2.0]) ≈ 6.0 atol = 1e-6
    end

    @testset "Nested Brackets (Jacobi Identity check)" begin
        # [X, [Y, Z]] + [Y, [Z, X]] + [Z, [X, Y]] = 0
        X(x) = [0, x[3], -x[2]]
        Y(x) = [-x[3], 0, x[1]]
        Z(x) = [x[2], -x[1], 0]

        # We need to compose functions for nested brackets
        # Let's verify expansion
        XYZ = CTFlows.@Lie [X, [Y, Z]]
        YZX = CTFlows.@Lie [Y, [Z, X]]
        ZXY = CTFlows.@Lie [Z, [X, Y]]

        x0 = [1.0, 2.0, 3.0]
        sum_jacobi = XYZ(x0) + YZX(x0) + ZXY(x0)
        @test isapprox_vec(sum_jacobi, [0.0, 0.0, 0.0])
    end

    @testset "Prefix System" begin
        # Save current prefix
        old_prefix = CTFlows.diffgeo_prefix()

        # Change prefix
        CTFlows.diffgeo_prefix!(:MyModule)
        @test CTFlows.diffgeo_prefix() == :MyModule

        # Check macro expansion uses new prefix (conceptually)
        # We can't easily test macro expansion result availability unless MyModule exists
        # But we tested the set/get mechanism

        # Restore prefix
        CTFlows.diffgeo_prefix!(old_prefix)
        @test CTFlows.diffgeo_prefix() == :CTFlows
    end

    @testset "∂ₜ time derivative" begin
        f(t, x) = t^2 * x[1]
        df = CTFlows.∂ₜ(f)
        # ∂f/∂t = 2t * x1
        @test df(3.0, [2.0]) ≈ 2 * 3.0 * 2.0 atol = 1e-6
    end

end
