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

        # Scalar case
        H_scalar(x, p) = 0.5 * (p^2 + x^2)
        G_scalar(x, p) = x
        # {H, G} = ∂H/∂p * ∂G/∂x - ∂H/∂x * ∂G/∂p
        # ∂H/∂p = p, ∂G/∂x = 1 -> p*1 = p
        # ∂H/∂x = x, ∂G/∂p = 0 -> x*0 = 0
        # {H, G} = p
        PB_scalar = CTFlows.Poisson(H_scalar, G_scalar)
        @test PB_scalar(1.0, 3.0) ≈ 3.0 atol = 1e-6
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

    @testset "Backend parameter" begin
        using DifferentiationInterface
        # Test that Poisson accepts backend parameter
        H(x, p) = 0.5 * (p[1]^2 + p[2]^2)
        G(x, p) = x[1]
        backend = AutoForwardDiff()
        PB = CTFlows.Poisson(H, G; backend=backend)
        @test PB([1.0, 2.0], [3.0, 4.0]) ≈ 3.0 atol = 1e-6

        # Test that ad accepts backend parameter
        X(x) = [x[2], -x[1]]
        f(x) = x[1]^2 + x[2]^2
        Lf = CTFlows.ad(X, f; backend=backend)
        @test Lf([1.0, 2.0]) ≈ 0.0 atol = 1e-6
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

    # ============================================================================
    # PRIORITY 1: Type-Based API Tests
    # ============================================================================

    @testset "Type-Based API - ad()" begin
        # Test that explicit type dispatch works correctly
        X(x) = [x[2], -x[1]]
        f(x) = x[1]^2 + x[2]^2

        # Autonomous, Fixed
        Lf_typed = CTFlows.ad(X, f, CTFlows.Autonomous, CTFlows.Fixed)
        Lf_kwargs = CTFlows.ad(X, f; autonomous=true, variable=false)
        @test Lf_typed([1.0, 2.0]) ≈ Lf_kwargs([1.0, 2.0]) atol = 1e-6

        # NonAutonomous, Fixed
        X_na(t, x) = [t * x[2], -x[1]]
        f_na(t, x) = t + x[1]^2
        Lf_na_typed = CTFlows.ad(X_na, f_na, CTFlows.NonAutonomous, CTFlows.Fixed)
        Lf_na_kwargs = CTFlows.ad(X_na, f_na; autonomous=false, variable=false)
        @test Lf_na_typed(2.0, [1.0, 2.0]) ≈ Lf_na_kwargs(2.0, [1.0, 2.0]) atol = 1e-6

        # Autonomous, NonFixed (with variable)
        X_v(x, v) = [v[1] * x[2], -x[1]]
        f_v(x, v) = v[1] * x[1]^2 + x[2]^2
        Lf_v_typed = CTFlows.ad(X_v, f_v, CTFlows.Autonomous, CTFlows.NonFixed)
        Lf_v_kwargs = CTFlows.ad(X_v, f_v; autonomous=true, variable=true)
        @test Lf_v_typed([1.0, 2.0], [2.0]) ≈ Lf_v_kwargs([1.0, 2.0], [2.0]) atol = 1e-6

        # NonAutonomous, NonFixed
        X_nav(t, x, v) = [t * v[1] * x[2], -x[1]]
        f_nav(t, x, v) = t + v[1] * x[1]^2
        Lf_nav_typed = CTFlows.ad(X_nav, f_nav, CTFlows.NonAutonomous, CTFlows.NonFixed)
        Lf_nav_kwargs = CTFlows.ad(X_nav, f_nav; autonomous=false, variable=true)
        @test Lf_nav_typed(2.0, [1.0, 2.0], [2.0]) ≈ Lf_nav_kwargs(2.0, [1.0, 2.0], [2.0]) atol = 1e-6
    end

    @testset "Type-Based API - Lift()" begin
        # Autonomous, Fixed
        f(x) = [x[1]^2, x[2]]
        H_typed = CTFlows.Lift(f, CTFlows.Autonomous, CTFlows.Fixed)
        H_kwargs = CTFlows.Lift(f; autonomous=true, variable=false)
        @test H_typed([1.0, 2.0], [3.0, 4.0]) ≈ H_kwargs([1.0, 2.0], [3.0, 4.0]) atol = 1e-6

        # NonAutonomous, Fixed
        g(t, x) = [t * x[1], x[2]]
        Hg_typed = CTFlows.Lift(g, CTFlows.NonAutonomous, CTFlows.Fixed)
        Hg_kwargs = CTFlows.Lift(g; autonomous=false, variable=false)
        @test Hg_typed(2.0, [1.0, 2.0], [3.0, 4.0]) ≈ Hg_kwargs(2.0, [1.0, 2.0], [3.0, 4.0]) atol = 1e-6

        # Autonomous, NonFixed
        h(x, v) = [v[1] * x[1], x[2]]
        Hh_typed = CTFlows.Lift(h, CTFlows.Autonomous, CTFlows.NonFixed)
        Hh_kwargs = CTFlows.Lift(h; autonomous=true, variable=true)
        @test Hh_typed([1.0, 2.0], [3.0, 4.0], [2.0]) ≈ Hh_kwargs([1.0, 2.0], [3.0, 4.0], [2.0]) atol = 1e-6
    end

    @testset "Type-Based API - Poisson()" begin
        # Autonomous, Fixed
        H(x, p) = 0.5 * (p[1]^2 + p[2]^2)
        G(x, p) = x[1]
        PB_typed = CTFlows.Poisson(H, G, CTFlows.Autonomous, CTFlows.Fixed)
        PB_kwargs = CTFlows.Poisson(H, G; autonomous=true, variable=false)
        @test PB_typed([1.0, 2.0], [3.0, 4.0]) ≈ PB_kwargs([1.0, 2.0], [3.0, 4.0]) atol = 1e-6

        # NonAutonomous, Fixed
        H_na(t, x, p) = t + 0.5 * (p[1]^2 + p[2]^2)
        G_na(t, x, p) = x[1]
        PB_na_typed = CTFlows.Poisson(H_na, G_na, CTFlows.NonAutonomous, CTFlows.Fixed)
        PB_na_kwargs = CTFlows.Poisson(H_na, G_na; autonomous=false, variable=false)
        @test PB_na_typed(1.0, [1.0, 2.0], [3.0, 4.0]) ≈ PB_na_kwargs(1.0, [1.0, 2.0], [3.0, 4.0]) atol = 1e-6
    end

    # ============================================================================
    # PRIORITY 2: Edge Cases Tests
    # ============================================================================

    @testset "Edge Cases - 1D (Scalar)" begin
        # ad() with scalars
        X_1d(x) = -x
        f_1d(x) = x^2
        Lf_1d = CTFlows.ad(X_1d, f_1d)
        # L_X(f) = df/dx * X = 2x * (-x) = -2x^2
        # At x=3: -2*9 = -18
        @test Lf_1d(3.0) ≈ -18.0 atol = 1e-6

        # Poisson() with scalars (already tested above, but explicit)
        H_1d(x, p) = 0.5 * (p^2 + x^2)
        G_1d(x, p) = x
        PB_1d = CTFlows.Poisson(H_1d, G_1d)
        @test PB_1d(1.0, 3.0) ≈ 3.0 atol = 1e-6

        # Lift() with scalar
        f_1d_vec(x) = -2 * x  # returns scalar (treated as 1D vector)
        H_1d = CTFlows.Lift(f_1d_vec)
        @test H_1d(2.0, 3.0) ≈ -12.0 atol = 1e-6
    end

    @testset "Edge Cases - High Dimensional (3D, 4D)" begin
        # 3D Lie bracket
        X_3d(x) = [0, x[3], -x[2]]
        Y_3d(x) = [-x[3], 0, x[1]]
        XY_3d = CTFlows.ad(X_3d, Y_3d)
        # Known result for rotational vector fields
        @test length(XY_3d([1.0, 2.0, 3.0])) == 3

        # 4D Poisson bracket
        H_4d(x, p) = sum(p .^ 2) + sum(x .^ 2)
        G_4d(x, p) = x[1] * p[1]
        PB_4d = CTFlows.Poisson(H_4d, G_4d)
        result_4d = PB_4d([1.0, 0.0, 0.0, 0.0], [1.0, 0.0, 0.0, 0.0])
        @test result_4d isa Number  # Just check it computes
    end

    @testset "Edge Cases - Trivial Cases" begin
        # Zero vector field
        X_zero(x) = [0.0, 0.0]
        f(x) = x[1]^2 + x[2]^2
        Lf_zero = CTFlows.ad(X_zero, f)
        @test Lf_zero([1.0, 2.0]) ≈ 0.0 atol = 1e-10

        # Constant function (gradient = 0)
        X(x) = [x[2], -x[1]]
        f_const(x) = 42.0
        Lf_const = CTFlows.ad(X, f_const)
        @test Lf_const([1.0, 2.0]) ≈ 0.0 atol = 1e-10

        # Zero Hamiltonian
        H_zero(x, p) = 0.0
        G(x, p) = x[1]
        PB_zero = CTFlows.Poisson(H_zero, G)
        @test PB_zero([1.0, 2.0], [3.0, 4.0]) ≈ 0.0 atol = 1e-10
    end

    @testset "Edge Cases - Commuting Vector Fields" begin
        # [X, Y] = 0 for commuting fields
        X(x) = [1.0, 0.0]  # Constant field in x direction
        Y(x) = [0.0, 1.0]  # Constant field in y direction
        XY = CTFlows.ad(X, Y)
        # Commuting vector fields should have zero Lie bracket
        @test isapprox_vec(XY([1.0, 2.0]), [0.0, 0.0])
    end

    # ============================================================================
    # PACKAGE 1: Mathematical Properties (from backup analysis)
    # ============================================================================

    @testset "Poisson - Mathematical Properties" begin
        # Setup test functions
        f(x, p) = x[2]^2 + 2x[1]^2 + p[1]^2
        g(x, p) = 3x[2]^2 + -x[1]^2 + p[2]^2 + p[1]
        h(x, p) = x[2]^2 + -2x[1]^2 + p[1]^2 - 2p[2]^2
        f_plus_g(x, p) = f(x, p) + g(x, p)
        f_times_g(x, p) = f(x, p) * g(x, p)
        const_42(x, p) = 42.0

        x_test = [1, 2]
        p_test = [2, 1]

        # Property 1: Constant function has zero Poisson bracket
        @test CTFlows.Poisson(f, const_42)(x_test, p_test) ≈ 0.0 atol = 1e-10

        # Property 2: Anticommutativity - {F, G} = -{G, F}
        PB_fg = CTFlows.Poisson(f, g)(x_test, p_test)
        PB_gf = CTFlows.Poisson(g, f)(x_test, p_test)
        @test PB_fg ≈ -PB_gf atol = 1e-10

        # Property 3: Bilinearity (left) - {F+G, H} = {F, H} + {G, H}
        PB_fpg_h = CTFlows.Poisson(f_plus_g, h)(x_test, p_test)
        PB_f_h = CTFlows.Poisson(f, h)(x_test, p_test)
        PB_g_h = CTFlows.Poisson(g, h)(x_test, p_test)
        @test PB_fpg_h ≈ PB_f_h + PB_g_h atol = 1e-10

        # Property 4: Bilinearity (right) - {H, F+G} = {H, F} + {H, G}
        PB_h_fpg = CTFlows.Poisson(h, f_plus_g)(x_test, p_test)
        PB_h_f = CTFlows.Poisson(h, f)(x_test, p_test)
        PB_h_g = CTFlows.Poisson(h, g)(x_test, p_test)
        @test PB_h_fpg ≈ PB_h_f + PB_h_g atol = 1e-10

        # Property 5: Leibniz's rule - {FG, H} = {F, H}·G + F·{G, H}
        PB_ftg_h = CTFlows.Poisson(f_times_g, h)(x_test, p_test)
        leibniz_rhs = PB_f_h * g(x_test, p_test) + f(x_test, p_test) * PB_g_h
        @test PB_ftg_h ≈ leibniz_rhs atol = 1e-10

        # Property 6: Jacobi identity - {F, {G, H}} + {G, {H, F}} + {H, {F, G}} = 0
        PB_gh = CTFlows.Poisson(g, h)
        PB_hf = CTFlows.Poisson(h, f)
        PB_fg_func = CTFlows.Poisson(f, g)

        PB_f_gh = CTFlows.Poisson(f, PB_gh)(x_test, p_test)
        PB_g_hf = CTFlows.Poisson(g, PB_hf)(x_test, p_test)
        PB_h_fg = CTFlows.Poisson(h, PB_fg_func)(x_test, p_test)

        jacobi_sum = PB_f_gh + PB_g_hf + PB_h_fg
        @test abs(jacobi_sum) < 1e-10
    end

    @testset "Poisson of Lifts - Composition" begin
        # Test that Poisson(Lift(f), Lift(g)) gives correct results
        f(x) = [x[1] + x[2]^2, x[1], 0]
        g(x) = [0, x[2], x[1]^2 + 4 * x[2]]

        # Create Lifts
        F = CTFlows.Lift(f)
        G = CTFlows.Lift(g)

        # Explicit Hamiltonians
        F_explicit(x, p) = p' * f(x)
        G_explicit(x, p) = p' * g(x)

        x_test = [1.0, 2.0, 3.0]
        p_test = [4.0, 0.0, 4.0]

        # Poisson of Lifts should equal Poisson of explicit Hamiltonians
        @test CTFlows.Poisson(F, G)(x_test, p_test) ≈
              CTFlows.Poisson(F_explicit, G_explicit)(x_test, p_test) atol = 1e-6

        # Mixed case: Lift + explicit
        @test CTFlows.Poisson(F, G_explicit)(x_test, p_test) ≈
              CTFlows.Poisson(F_explicit, G)(x_test, p_test) atol = 1e-6

        # Non-autonomous case
        f_na(t, x) = [t * x[1] + x[2]^2, x[1], 0]
        g_na(t, x) = [0, x[2], t * x[1]^2 + 4 * x[2]]

        F_na = CTFlows.Lift(f_na; autonomous=false)
        G_na = CTFlows.Lift(g_na; autonomous=false)
        F_na_explicit(t, x, p) = p' * f_na(t, x)
        G_na_explicit(t, x, p) = p' * g_na(t, x)

        t_test = 2.0
        @test CTFlows.Poisson(F_na, G_na; autonomous=false)(t_test, x_test, p_test) ≈
              CTFlows.Poisson(F_na_explicit, G_na_explicit; autonomous=false)(t_test, x_test, p_test) atol = 1e-6
    end

    # ============================================================================
    # PACKAGE 2: Physical Examples & Theoretical Validation
    # ============================================================================

    @testset "MRI Example - Bloch Equations" begin
        # Physical constants for magnetic resonance imaging
        Γ = 2.0  # Relaxation rate
        γ = 1.0  # Gyromagnetic ratio
        δ = γ - Γ

        # Bloch equation vector fields
        F0(x) = [-Γ * x[1], -Γ * x[2], γ * (1 - x[3])]
        F1(x) = [0.0, -x[3], x[2]]
        F2(x) = [x[3], 0.0, -x[1]]

        # Compute Lie brackets
        F01 = CTFlows.ad(F0, F1)
        F02 = CTFlows.ad(F0, F2)
        F12 = CTFlows.ad(F1, F2)

        x = [1.0, 2.0, 3.0]

        # Verify known analytical results for Bloch equations
        # WHY: These are well-known results in MRI physics
        @test F01(x) ≈ -[0.0, γ - δ * x[3], -δ * x[2]] atol = 1e-6
        @test F02(x) ≈ -[-γ + δ * x[3], 0.0, δ * x[1]] atol = 1e-6
        @test F12(x) ≈ -[-x[2], x[1], 0.0] atol = 1e-6
    end

    @testset "Lie Bracket - Intrinsic Definition" begin
        # Verify intrinsic definition: [X, Y]·f = X·(Y·f) - Y·(X·f)
        # WHY: This is the fundamental commutator property of Lie brackets

        X(x) = [x[2]^2, -2x[1] * x[2]]
        Y(x) = [x[1] * (1 + x[2]), 3x[2]^3]
        f(x) = x[1]^4 + 2x[2]^3

        x_test = [1.0, 2.0]

        # Method 1: Direct computation of [X,Y]·f
        XY = CTFlows.ad(X, Y)
        XY_dot_f = CTFlows.ad(XY, f)
        result_direct = XY_dot_f(x_test)

        # Method 2: Commutator of directional derivatives X·(Y·f) - Y·(X·f)
        Y_dot_f = CTFlows.ad(Y, f)
        X_dot_f = CTFlows.ad(X, f)
        X_dot_Yf = CTFlows.ad(X, Y_dot_f)
        Y_dot_Xf = CTFlows.ad(Y, X_dot_f)
        result_commutator = X_dot_Yf(x_test) - Y_dot_Xf(x_test)

        # Both methods should give the same result
        @test result_direct ≈ result_commutator atol = 1e-6
    end

end
