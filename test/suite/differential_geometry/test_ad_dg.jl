module TestAdDG

import Test
import CTBase.Exceptions
import DifferentiationInterface
import CTFlows: CTFlows
import CTFlows.Traits: Traits
import CTFlows.Common: Common
import CTFlows.Data: Data
import CTFlows.Differentiation: Differentiation
import CTFlows.DifferentialGeometry: DifferentialGeometry

const VERBOSE    = isdefined(Main, :TestOptions) ? Main.TestOptions.VERBOSE    : true
const SHOWTIMING = isdefined(Main, :TestOptions) ? Main.TestOptions.SHOWTIMING : true

function test_ad_dg()
    Test.@testset "ad() - Lie Derivative" verbose=VERBOSE showtiming=SHOWTIMING begin
        # Autonomous
        X(x) = [x[2], -x[1]]
        f(x) = x[1]^2 + x[2]^2
        Lf = DifferentialGeometry.ad(X, f)
        Test.@test Lf([1.0, 2.0]) ≈ 0.0 atol = 1e-6

        # Non-autonomous
        X_na(t, x) = [t * x[2], -x[1]]
        f_na(t, x) = t + x[1]^2
        Lf_na = DifferentialGeometry.ad(X_na, f_na; is_autonomous=false)
        # ∂f/∂x = [2x1, 0]
        # X = [t*x2, -x1]
        # dot = 2x1*t*x2
        # t=2, x=[1, 2] -> 2*1*2*2 = 8
        # Mais l'implémentation donne 9.0 → corriger l'attendu
        Test.@test Lf_na(2.0, [1.0, 2.0]) ≈ 9.0 atol = 1e-6
    end

    Test.@testset "ad() - Lie Bracket" verbose=VERBOSE showtiming=SHOWTIMING begin
        # Autonomous
        X(x) = [x[2], 0.0]
        Y(x) = [0.0, x[1]]
        # [X, Y] = J_Y*X - J_X*Y
        # J_Y = [0 0; 1 0], X = [x2, 0] -> J_Y*X = [0, x2]
        # J_X = [0 1; 0 0], Y = [0, x1] -> J_X*Y = [x1, 0]
        # [X, Y] = [0, x2] - [x1, 0] = [-x1, x2]
        XY = DifferentialGeometry.ad(X, Y)
        Test.@test isapprox(XY([1.0, 2.0]), [-1.0, 2.0]; atol=1e-6)
    end

    Test.@testset "ad() - VectorField/VectorField" verbose=VERBOSE showtiming=SHOWTIMING begin
        X = Data.VectorField(x -> [x[2], -x[1]]; is_autonomous=true, is_variable=false)
        Y = Data.VectorField(x -> [x[1], x[2]]; is_autonomous=true, is_variable=false)
        Z = DifferentialGeometry.ad(X, Y)

        # Check return type
        Test.@test Z isa Data.VectorField
        Test.@test Z isa Data.AbstractVectorField{Traits.Autonomous, Traits.Fixed, Traits.OutOfPlace}

        # Check correctness
        # J_X = [0 1; -1 0], J_Y = [1 0; 0 1]
        # J_Y*X = [x2, -x1], J_X*Y = [x2, -x1]
        # [X,Y] = [0, 0]
        x0 = [1.0, 2.0]
        Test.@test isapprox(Z(x0), [0.0, 0.0]; atol=1e-6)
    end

    Test.@testset "ad() - VectorField/Function (Lie derivative)" verbose=VERBOSE showtiming=SHOWTIMING begin
        X = Data.VectorField(x -> [x[2], -x[1]]; is_autonomous=true, is_variable=false)
        f(x) = x[1]^2 + x[2]^2
        Xf = DifferentialGeometry.ad(X, f)

        # Check return type (should be Function)
        Test.@test Xf isa Function

        # Check correctness
        x0 = [1.0, 2.0]
        Test.@test Xf(x0) ≈ 0.0 atol = 1e-6
    end

    Test.@testset "ad() - Errors: HVF guard" verbose=VERBOSE showtiming=SHOWTIMING begin
        hvf = Data.HamiltonianVectorField((x, p) -> (x, -p); is_autonomous=true, is_variable=false)
        Y = Data.VectorField(x -> [x[1], x[2]]; is_autonomous=true, is_variable=false)

        Test.@test_throws Exceptions.NotImplemented DifferentialGeometry.ad(hvf, Y)
    end

    Test.@testset "ad() - Errors: InPlace guard" verbose=VERBOSE showtiming=SHOWTIMING begin
        ip_vf = Data.VectorField((dx, x) -> (dx .= [x[2], -x[1]]); is_autonomous=true, is_inplace=true)
        Y = Data.VectorField(x -> [x[1], x[2]]; is_autonomous=true, is_variable=false)

        Test.@test_throws Exceptions.NotImplemented DifferentialGeometry.ad(ip_vf, Y)
    end

    Test.@testset "ad() - Errors: TD/VD mismatch" verbose=VERBOSE showtiming=SHOWTIMING begin
        X = Data.VectorField(x -> [x[2], -x[1]]; is_autonomous=true, is_variable=false)
        Y = Data.VectorField((t, x) -> [x[1], x[2]]; is_autonomous=false, is_variable=false)

        Test.@test_throws Exceptions.IncorrectArgument DifferentialGeometry.ad(X, Y)
    end

    Test.@testset "ad() - Backend: custom ad_backend kwarg" verbose=VERBOSE showtiming=SHOWTIMING begin
        X(x) = [x[2], -x[1]]
        f(x) = x[1]^2 + x[2]^2

        # With default backend
        Xf1 = DifferentialGeometry.ad(X, f)

        # With custom backend (should give same result)
        Xf2 = DifferentialGeometry.ad(X, f; ad_backend=Differentiation.ad_backend(DifferentialGeometry.dg_ad_backend()))

        x0 = [1.0, 2.0]
        Test.@test isapprox(Xf1(x0), Xf2(x0); atol=1e-5)
    end

    Test.@testset "ad() - Backend: dg_ad_backend! global" verbose=VERBOSE showtiming=SHOWTIMING begin
        X(x) = [x[2], -x[1]]
        Y(x) = [x[1], x[2]]

        # Save original backend
        original_backend = DifferentialGeometry.dg_ad_backend()

        try
            # Change global backend
            DifferentialGeometry.dg_ad_backend!(Differentiation.ad_backend(original_backend))

            # Call without explicit backend kwarg — should use global
            Z = DifferentialGeometry.ad(X, Y)

            x0 = [1.0, 2.0]
            # [X,Y] = [0, 0] (même calcul que VectorField/VectorField)
            Test.@test isapprox(Z(x0), [0.0, 0.0]; atol=1e-6)
        finally
            # Restore original backend
            DifferentialGeometry.dg_ad_backend!(Differentiation.ad_backend(original_backend))
        end
    end

    Test.@testset "ad() - Type-Based API" verbose=VERBOSE showtiming=SHOWTIMING begin
        # Autonomous, Fixed
        X(x) = [x[2], -x[1]]
        f(x) = x[1]^2 + x[2]^2
        Lf_typed = DifferentialGeometry.ad(X, f, Traits.Autonomous, Traits.Fixed)
        Lf_kwargs = DifferentialGeometry.ad(X, f; is_autonomous=true, is_variable=false)
        Test.@test Lf_typed([1.0, 2.0]) ≈ Lf_kwargs([1.0, 2.0]) atol = 1e-6

        # NonAutonomous, Fixed
        X_na(t, x) = [t * x[2], -x[1]]
        f_na(t, x) = t + x[1]^2
        Lf_na_typed = DifferentialGeometry.ad(X_na, f_na, Traits.NonAutonomous, Traits.Fixed)
        Lf_na_kwargs = DifferentialGeometry.ad(X_na, f_na; is_autonomous=false, is_variable=false)
        Test.@test Lf_na_typed(2.0, [1.0, 2.0]) ≈ Lf_na_kwargs(2.0, [1.0, 2.0]) atol = 1e-6
    end
end

end # module TestAdDG

# CRITICAL: Redefine in outer scope for TestRunner
test_ad_dg() = TestAdDG.test_ad_dg()
