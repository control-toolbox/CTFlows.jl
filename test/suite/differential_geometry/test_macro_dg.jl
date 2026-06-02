module TestMacroDG

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

function test_macro_dg()
    Test.@testset "@Lie [X, Y] — Lie bracket" verbose=VERBOSE showtiming=SHOWTIMING begin
        X(x) = [x[2], 0.0]
        Y(x) = [0.0, x[1]]
        XY = DifferentialGeometry.@Lie [X, Y]
        # [X,Y] = [-x1, x2]
        x0 = [1.0, 2.0]
        Test.@test isapprox(XY(x0), [-1.0, 2.0]; atol=1e-6)
    end

    Test.@testset "@Lie [X, [Y, Z]] — nested bracket" verbose=VERBOSE showtiming=SHOWTIMING begin
        X(x) = [x[2], 0.0]
        Y(x) = [0.0, x[1]]
        Z(x) = [x[1], x[2]]
        # @Lie [X, [Y, Z]] should expand to ad(X, ad(Y, Z))
        inner = DifferentialGeometry.@Lie [Y, Z]
        outer_ref = DifferentialGeometry.@Lie [X, inner]
        nested = DifferentialGeometry.@Lie [X, [Y, Z]]
        x0 = [1.0, 2.0]
        Test.@test isapprox(nested(x0), outer_ref(x0); atol=1e-6)
    end

    Test.@testset "@Lie {H, G} — Poisson bracket" verbose=VERBOSE showtiming=SHOWTIMING begin
        H(x, p) = p[1]^2 / 2
        G(x, p) = x[1]
        PB = DifferentialGeometry.@Lie {H, G}
        x0 = [1.0, 2.0]; p0 = [0.5, 1.0]
        # {H,G} = ∇pH · ∇xG - ∇xH · ∇pG = [p1,0]·[1,0] - [0,0]·[1,0] = p1
        Test.@test PB(x0, p0) ≈ p0[1] atol=1e-6
    end

    Test.@testset "@Lie is_autonomous=false" verbose=VERBOSE showtiming=SHOWTIMING begin
        X(t, x) = [t * x[2], 0.0]
        Y(t, x) = [0.0, t * x[1]]
        XY = DifferentialGeometry.@Lie [X, Y] is_autonomous=false
        t0 = 1.0; x0 = [1.0, 2.0]
        # Check callable
        val = XY(t0, x0)
        Test.@test val isa AbstractVector
    end

    Test.@testset "diffgeo_prefix! — prefix system" verbose=VERBOSE showtiming=SHOWTIMING begin
        original = DifferentialGeometry.diffgeo_prefix()
        Test.@test original isa Symbol

        DifferentialGeometry.diffgeo_prefix!(:MyPrefix)
        Test.@test DifferentialGeometry.diffgeo_prefix() == :MyPrefix

        # Restore
        DifferentialGeometry.diffgeo_prefix!(original)
        Test.@test DifferentialGeometry.diffgeo_prefix() == original
    end
end

end # module TestMacroDG

test_macro_dg() = TestMacroDG.test_macro_dg()
