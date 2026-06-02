module TestAdDG

import Test
import CTBase.Exceptions
import DifferentiationInterface
import ADTypes
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
        Test.@test Lf_na(2.0, [1.0, 2.0]) ≈ 8.0 atol = 1e-6
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

    Test.@testset "ad() - Scalar x (Float64)" verbose=VERBOSE showtiming=SHOWTIMING begin
        # Autonomous, scalar x
        X_s(x) = 2.0 * x
        f_s(x) = x^2
        Lf_s = DifferentialGeometry.ad(X_s, f_s)
        # ∇f = 2x, X = 2x, Lf = 2x * 2x = 4x^2
        # x=3 -> 4*9 = 36
        Test.@test Lf_s(3.0) ≈ 36.0 atol = 1e-6

        # NonAutonomous, scalar x
        X_na_s(t, x) = t * x
        f_na_s(t, x) = t + x^2
        Lf_na_s = DifferentialGeometry.ad(X_na_s, f_na_s; is_autonomous=false)
        # ∇x f = 2x, X = t*x, dot = 2x * t*x = 2tx^2
        # t=2, x=3 -> 2*2*9 = 36
        Test.@test Lf_na_s(2.0, 3.0) ≈ 36.0 atol = 1e-6
    end

    Test.@testset "ad() - NonFixed (is_variable=true)" verbose=VERBOSE showtiming=SHOWTIMING begin
        # Autonomous, NonFixed
        X_nf(x, v) = [x[2] * v, -x[1]]
        f_nf(x, v) = x[1]^2 + x[2]^2 + v
        Lf_nf = DifferentialGeometry.ad(X_nf, f_nf; is_variable=true)
        # ∇x f = [2x1, 2x2], X = [x2*v, -x1]
        # dot = 2x1*x2*v + 2x2*(-x1) = 2x1*x2*v - 2x1*x2 = 2x1*x2*(v-1)
        # x=[1,2], v=3 -> 2*1*2*(3-1) = 8
        Test.@test Lf_nf([1.0, 2.0], 3.0) ≈ 8.0 atol = 1e-6

        # NonAutonomous, NonFixed
        X_na_nf(t, x, v) = [t * x[2] * v, -x[1]]
        f_na_nf(t, x, v) = t + x[1]^2 + v
        Lf_na_nf = DifferentialGeometry.ad(X_na_nf, f_na_nf; is_autonomous=false, is_variable=true)
        # ∇x f = [2x1, 0], X = [t*x2*v, -x1]
        # dot = 2x1 * t*x2*v
        # t=2, x=[1,2], v=3 -> 2*1*2*2*3 = 24
        Test.@test Lf_na_nf(2.0, [1.0, 2.0], 3.0) ≈ 24.0 atol = 1e-6
    end

    Test.@testset "ad() - VectorField/VectorField NonAutonomous" verbose=VERBOSE showtiming=SHOWTIMING begin
        X = Data.VectorField((t, x) -> [t * x[2], -x[1]]; is_autonomous=false, is_variable=false)
        Y = Data.VectorField((t, x) -> [x[1], x[2]]; is_autonomous=false, is_variable=false)
        Z = DifferentialGeometry.ad(X, Y)

        Test.@test Z isa Data.VectorField
        Test.@test Z isa Data.AbstractVectorField{Traits.NonAutonomous, Traits.Fixed, Traits.OutOfPlace}

        # Check correctness at t=2, x=[1,2]
        # J_X = [[0, t], [-1, 0]], J_Y = I
        # J_Y*X = [t*x2, -x1] = [4, -1]
        # J_X*Y = [t*x2, -x1] = [4, -1]
        # [X,Y] = [0, 0]
        Test.@test isapprox(Z(2.0, [1.0, 2.0]), [0.0, 0.0]; atol=1e-6)
    end

    Test.@testset "ad() - VectorField/Function NonAutonomous" verbose=VERBOSE showtiming=SHOWTIMING begin
        X = Data.VectorField((t, x) -> [t * x[2], -x[1]]; is_autonomous=false, is_variable=false)
        f(t, x) = t + x[1]^2
        Xf = DifferentialGeometry.ad(X, f)

        Test.@test Xf isa Function

        # ∇x f = [2x1, 0], X = [t*x2, -x1]
        # dot = 2x1 * t*x2
        # t=2, x=[1,2] -> 2*1*2*2 = 8
        Test.@test Xf(2.0, [1.0, 2.0]) ≈ 8.0 atol = 1e-6
    end

    Test.@testset "ad() - VectorField/VectorField NonFixed" verbose=VERBOSE showtiming=SHOWTIMING begin
        X = Data.VectorField((x, v) -> [x[2] * v, -x[1]]; is_autonomous=true, is_variable=true)
        Y = Data.VectorField((x, v) -> [x[1], x[2]]; is_autonomous=true, is_variable=true)
        Z = DifferentialGeometry.ad(X, Y)

        Test.@test Z isa Data.VectorField
        Test.@test Z isa Data.AbstractVectorField{Traits.Autonomous, Traits.NonFixed, Traits.OutOfPlace}

        # Check correctness at x=[1,2], v=3
        # J_X = [[0, v], [-1, 0]], J_Y = I
        # J_Y*X = [x2*v, -x1] = [6, -1]
        # J_X*Y = [x2*v, -x1] = [6, -1]
        # [X,Y] = [0, 0]
        Test.@test isapprox(Z([1.0, 2.0], 3.0), [0.0, 0.0]; atol=1e-6)
    end

    Test.@testset "ad() - VectorField/Function NonFixed" verbose=VERBOSE showtiming=SHOWTIMING begin
        X = Data.VectorField((x, v) -> [x[2] * v, -x[1]]; is_autonomous=true, is_variable=true)
        f(x, v) = x[1]^2 + v
        Xf = DifferentialGeometry.ad(X, f)

        Test.@test Xf isa Function

        # ∇x f = [2x1, 0], X = [x2*v, -x1]
        # dot = 2x1 * x2*v
        # x=[1,2], v=3 -> 2*1*2*3 = 12
        Test.@test Xf([1.0, 2.0], 3.0) ≈ 12.0 atol = 1e-6
    end

    Test.@testset "ad() - Backend: fake ADType" verbose=VERBOSE showtiming=SHOWTIMING begin
        # Use AutoForwardDiff as a concrete ADType
        X(x) = [x[2], -x[1]]
        f(x) = x[1]^2 + x[2]^2

        # With default backend
        Xf1 = DifferentialGeometry.ad(X, f)

        # With explicit fake backend (AutoForwardDiff)
        Xf2 = DifferentialGeometry.ad(X, f; ad_backend=ADTypes.AutoForwardDiff())

        x0 = [1.0, 2.0]
        Test.@test isapprox(Xf1(x0), Xf2(x0); atol=1e-5)
    end
end

end # module TestAdDG

# CRITICAL: Redefine in outer scope for TestRunner
test_ad_dg() = TestAdDG.test_ad_dg()
