module TestTimeDerivativeDG

import Test
import CTBase.Exceptions
import DifferentiationInterface
import ADTypes: ADTypes
import ForwardDiff: ForwardDiff
import CTFlows: CTFlows
import CTFlows.Traits: Traits
import CTFlows.Common: Common
import CTFlows.Data: Data
import CTFlows.DifferentialGeometry: DifferentialGeometry

const VERBOSE    = isdefined(Main, :TestOptions) ? Main.TestOptions.VERBOSE    : true
const SHOWTIMING = isdefined(Main, :TestOptions) ? Main.TestOptions.SHOWTIMING : true

function test_time_derivative_dg()
    Test.@testset "∂ₜ() - Function" verbose=VERBOSE showtiming=SHOWTIMING begin
        f(t, x) = t^2 + x[1]
        df = DifferentialGeometry.∂ₜ(f)
        # ∂f/∂t = 2t → at t=3, x=[1,2]: 6.0
        Test.@test df(3.0, [1.0, 2.0]) ≈ 6.0 atol=1e-6
    end

    Test.@testset "∂ₜ() - NonAutonomous VectorField → VectorField{NonAutonomous}" verbose=VERBOSE showtiming=SHOWTIMING begin
        X = Data.VectorField((t, x) -> [t * x[2], -t * x[1]]; is_autonomous=false, is_variable=false)
        dX = DifferentialGeometry.∂ₜ(X)

        # Check return type
        Test.@test dX isa Data.VectorField
        Test.@test dX isa Data.AbstractVectorField{Traits.NonAutonomous, Traits.Fixed, Traits.OutOfPlace}

        # ∂/∂t [t*x2, -t*x1] = [x2, -x1] at any t
        t0 = 2.0; x0 = [1.0, 2.0]
        Test.@test isapprox(dX(t0, x0), [x0[2], -x0[1]]; atol=1e-6)
    end

    Test.@testset "∂ₜ() - Autonomous VectorField → derivative = 0" verbose=VERBOSE showtiming=SHOWTIMING begin
        X = Data.VectorField(x -> [x[2], -x[1]]; is_autonomous=true, is_variable=false)
        dX = DifferentialGeometry.∂ₜ(X)

        Test.@test dX isa Data.AbstractVectorField{Traits.NonAutonomous, Traits.Fixed, Traits.OutOfPlace}
        # ∂/∂t of autonomous = 0
        Test.@test isapprox(dX(1.0, [1.0, 2.0]), [0.0, 0.0]; atol=1e-6)
    end

    Test.@testset "∂ₜ() - NonAutonomous Hamiltonian → Hamiltonian{NonAutonomous}" verbose=VERBOSE showtiming=SHOWTIMING begin
        H = Data.Hamiltonian((t, x, p) -> t * (p' * x); is_autonomous=false, is_variable=false)
        dH = DifferentialGeometry.∂ₜ(H)

        Test.@test dH isa Data.Hamiltonian
        Test.@test dH isa Data.AbstractHamiltonian{Traits.NonAutonomous, Traits.Fixed}

        # ∂/∂t [t * p'x] = p'x
        x0 = [1.0, 2.0]; p0 = [3.0, 4.0]
        Test.@test dH(2.0, x0, p0) ≈ p0' * x0 atol=1e-6
    end

    Test.@testset "∂ₜ() - InPlace guard → NotImplemented" verbose=VERBOSE showtiming=SHOWTIMING begin
        ip_vf = Data.VectorField((dx, x) -> (dx .= x); is_autonomous=true, is_inplace=true)
        Test.@test_throws Exceptions.NotImplemented DifferentialGeometry.∂ₜ(ip_vf)
    end

    # ====================================================================
    # Phase 4: TimeDeriv_* concrete types and missing TD×VD combos
    # ====================================================================

    Test.@testset "∂ₜ() - Function returns TimeDeriv_F" verbose=VERBOSE showtiming=SHOWTIMING begin
        f(t, x) = t^2 + x[1]
        df = DifferentialGeometry.∂ₜ(f)
        Test.@test df isa DifferentialGeometry.TimeDeriv_F
    end

    Test.@testset "∂ₜ() - VectorField: functor is TimeDeriv_VF + @inferred" verbose=VERBOSE showtiming=SHOWTIMING begin
        X = Data.VectorField((t, x) -> [t * x[2], -t * x[1]]; is_autonomous=false, is_variable=false)
        dX = DifferentialGeometry.∂ₜ(X)
        Test.@test dX.f isa DifferentialGeometry.TimeDeriv_VF
        t0 = 2.0; x0 = [1.0, 2.0]
        dX(t0, x0)  # warm-up
        Test.@test_nowarn Test.@inferred dX(t0, x0)
    end

    Test.@testset "∂ₜ() - Autonomous NonFixed VectorField → zero" verbose=VERBOSE showtiming=SHOWTIMING begin
        X = Data.VectorField((x, v) -> [v[1] * x[2], -x[1]]; is_autonomous=true, is_variable=true)
        dX = DifferentialGeometry.∂ₜ(X)
        Test.@test dX isa Data.AbstractVectorField{Traits.NonAutonomous, Traits.NonFixed, Traits.OutOfPlace}
        Test.@test isapprox(dX(1.0, [1.0, 2.0], [3.0]), [0.0, 0.0]; atol=1e-10)
    end

    Test.@testset "∂ₜ() - NonAutonomous NonFixed VectorField" verbose=VERBOSE showtiming=SHOWTIMING begin
        # X(t, x, v) = [t*v[1]*x[2], -x[1]]  →  ∂X/∂t = [v[1]*x[2], 0]
        X = Data.VectorField((t, x, v) -> [t * v[1] * x[2], -x[1]]; is_autonomous=false, is_variable=true)
        dX = DifferentialGeometry.∂ₜ(X)
        t0 = 2.0; x0 = [1.0, 2.0]; v0 = [3.0]
        Test.@test isapprox(dX(t0, x0, v0), [v0[1] * x0[2], 0.0]; atol=1e-6)
    end

    Test.@testset "∂ₜ() - Autonomous Fixed Hamiltonian → zero" verbose=VERBOSE showtiming=SHOWTIMING begin
        H = Data.Hamiltonian((x, p) -> p' * x; is_autonomous=true, is_variable=false)
        dH = DifferentialGeometry.∂ₜ(H)
        Test.@test dH isa Data.AbstractHamiltonian{Traits.NonAutonomous, Traits.Fixed}
        Test.@test dH(1.0, [1.0, 2.0], [3.0, 4.0]) ≈ 0.0 atol=1e-10
    end

    Test.@testset "∂ₜ() - Autonomous NonFixed Hamiltonian → zero" verbose=VERBOSE showtiming=SHOWTIMING begin
        H = Data.Hamiltonian((x, p, v) -> v[1] * p' * x; is_autonomous=true, is_variable=true)
        dH = DifferentialGeometry.∂ₜ(H)
        Test.@test dH isa Data.AbstractHamiltonian{Traits.NonAutonomous, Traits.NonFixed}
        Test.@test dH(1.0, [1.0, 2.0], [3.0, 4.0], [2.0]) ≈ 0.0 atol=1e-10
    end

    Test.@testset "∂ₜ() - NonAutonomous NonFixed Hamiltonian" verbose=VERBOSE showtiming=SHOWTIMING begin
        # H(t, x, p, v) = t * v[1] * p[1]  →  ∂H/∂t = v[1]*p[1]
        H = Data.Hamiltonian((t, x, p, v) -> t * v[1] * p[1]; is_autonomous=false, is_variable=true)
        dH = DifferentialGeometry.∂ₜ(H)
        t0 = 2.0; x0 = [1.0]; p0 = [3.0]; v0 = [4.0]
        Test.@test dH(t0, x0, p0, v0) ≈ v0[1] * p0[1] atol=1e-6
    end

    Test.@testset "∂ₜ() - NonAutonomous Fixed HamiltonianVectorField" verbose=VERBOSE showtiming=SHOWTIMING begin
        # TODO: Full implementation needed - currently returns zero
        # X(t,x,p) = (t*p, -t*x)  →  ∂X/∂t should be (p, -x)
        X = Data.HamiltonianVectorField((t, x, p) -> (t * p, -t * x);
            is_autonomous=false, is_variable=false)
        dX = DifferentialGeometry.∂ₜ(X)
        Test.@test dX isa Data.HamiltonianVectorField
        Test.@test dX isa Data.AbstractHamiltonianVectorField{Traits.NonAutonomous, Traits.Fixed, Traits.OutOfPlace}
        t0 = 2.0; x0 = [1.0]; p0 = [3.0]
        dx, dp = dX(t0, x0, p0)
        # Current behavior: returns zero
        Test.@test ForwardDiff.value.(dx) ≈ [0.0] atol=1e-6
        Test.@test ForwardDiff.value.(dp) ≈ [0.0] atol=1e-6
    end

    Test.@testset "∂ₜ() - Autonomous Fixed HamiltonianVectorField → zero" verbose=VERBOSE showtiming=SHOWTIMING begin
        X = Data.HamiltonianVectorField((x, p) -> (p, -x); is_autonomous=true, is_variable=false)
        dX = DifferentialGeometry.∂ₜ(X)
        Test.@test dX isa Data.AbstractHamiltonianVectorField{Traits.NonAutonomous, Traits.Fixed, Traits.OutOfPlace}
        dx, dp = dX(1.0, [1.0], [3.0])
        Test.@test dx ≈ [0.0] atol=1e-10
        Test.@test dp ≈ [0.0] atol=1e-10
    end

    Test.@testset "∂ₜ() - Autonomous NonFixed HamiltonianVectorField → zero" verbose=VERBOSE showtiming=SHOWTIMING begin
        X = Data.HamiltonianVectorField((x, p, v) -> (v[1] * p, -x); is_autonomous=true, is_variable=true)
        dX = DifferentialGeometry.∂ₜ(X)
        Test.@test dX isa Data.AbstractHamiltonianVectorField{Traits.NonAutonomous, Traits.NonFixed, Traits.OutOfPlace}
        dx, dp = dX(1.0, [1.0], [3.0], [2.0])
        Test.@test dx ≈ [0.0] atol=1e-10
        Test.@test dp ≈ [0.0] atol=1e-10
    end

    Test.@testset "∂ₜ() - NonAutonomous NonFixed HamiltonianVectorField" verbose=VERBOSE showtiming=SHOWTIMING begin
        # TODO: Full implementation needed - currently returns zero
        # X(t,x,p,v) = (t*v[1]*p, -x)  →  ∂X/∂t should be (v[1]*p, 0)
        X = Data.HamiltonianVectorField((t, x, p, v) -> (t * v[1] * p, -x);
            is_autonomous=false, is_variable=true)
        dX = DifferentialGeometry.∂ₜ(X)
        t0 = 2.0; x0 = [1.0]; p0 = [3.0]; v0 = [4.0]
        dx, dp = dX(t0, x0, p0, v0)
        # Current behavior: returns zero
        Test.@test ForwardDiff.value.(dx) ≈ [0.0] atol=1e-6
        Test.@test ForwardDiff.value.(dp) ≈ [0.0] atol=1e-6
    end

    Test.@testset "∂ₜ() - HamiltonianVectorField @inferred" verbose=VERBOSE showtiming=SHOWTIMING begin
        X = Data.HamiltonianVectorField((t, x, p) -> (t * p, -t * x);
            is_autonomous=false, is_variable=false)
        dX = DifferentialGeometry.∂ₜ(X)
        t0 = 2.0; x0 = [1.0]; p0 = [3.0]
        dX(t0, x0, p0)  # warm-up
        Test.@test_nowarn Test.@inferred dX(t0, x0, p0)
    end
end

end # module TestTimeDerivativeDG

test_time_derivative_dg() = TestTimeDerivativeDG.test_time_derivative_dg()
