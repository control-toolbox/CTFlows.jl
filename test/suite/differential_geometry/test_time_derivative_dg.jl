module TestTimeDerivativeDG

import Test
import CTBase.Exceptions
import DifferentiationInterface
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
end

end # module TestTimeDerivativeDG

test_time_derivative_dg() = TestTimeDerivativeDG.test_time_derivative_dg()
