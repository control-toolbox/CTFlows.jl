"""
Unit tests of the generated output grids (issue #435): `Trajectories.generate_grid` on
plain curves — size, distinctness, monotonicity, bounds, phases, adaptivity, degenerate
cases.
"""

module TestGenerateGrid

using Test: Test
using CTBase: Exceptions
using CTFlows: Configs
using CTFlows: Trajectories

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

const STEPS = collect(range(0, 1, 11))   # stand-in solver steps
_sharp(t) = [tanh(40 * (t - 0.6))]
_gen(spec, curve; steps=STEPS, bounds=[0.0, 1.0]) =
    Trajectories.generate_grid(spec, curve, steps, bounds)

# the generic properties every generated grid must have
function _check_props(g, n, bounds)
    Test.@test length(g) == n
    Test.@test allunique(g)
    forward = last(bounds) > first(bounds)
    Test.@test issorted(forward ? g : reverse(g); lt=<)
    Test.@test first(g) == first(bounds) && last(g) == last(bounds)
    for b in bounds
        Test.@test count(==(b), g) == 1
    end
end

function test_generate_grid()
    Test.@testset "generate_grid" verbose=VERBOSE showtiming=SHOWTIMING begin
        Test.@testset "uniform, one phase" begin
            g = _gen(Configs.UniformGrid(11), _sharp)
            _check_props(g, 11, [0.0, 1.0])
            Test.@test g ≈ collect(range(0, 1, 11)) atol = 1e-14
        end

        Test.@testset "adaptive, one phase [n=$n, uniform=$u]" for n in (2, 3, 20, 101),
            u in (0.0, 0.1, 1.0)

            g = _gen(Configs.AdaptiveGrid(n; uniform=u), _sharp)
            _check_props(g, n, [0.0, 1.0])
        end

        Test.@testset "adaptive is denser where the curve bends" begin
            n = 30
            ga = _gen(Configs.AdaptiveGrid(n), _sharp; steps=collect(range(0, 1, 101)))
            gu = _gen(Configs.UniformGrid(n), _sharp)
            inside(g) = count(t -> 0.5 <= t <= 0.7, g)
            Test.@test inside(ga) > 2 * inside(gu)
        end

        Test.@testset "uniform=1 is the uniform grid" begin
            g = _gen(Configs.AdaptiveGrid(11; uniform=1.0), _sharp)
            Test.@test g ≈ collect(range(0, 1, 11)) atol = 1e-12
        end

        Test.@testset "straight or constant curve → uniform" begin
            for curve in (t -> [2t + 1], t -> [3.0], t -> Float64[])
                g = _gen(Configs.AdaptiveGrid(11), curve)
                Test.@test g ≈ collect(range(0, 1, 11)) atol = 1e-12
            end
        end

        Test.@testset "a constant component is ignored (rounding noise)" begin
            noisy = t -> [12.0 + 1e-15 * sin(1000t); _sharp(t)]
            Test.@test _gen(Configs.AdaptiveGrid(25), noisy) ≈ _gen(Configs.AdaptiveGrid(25), _sharp)
        end

        Test.@testset "multi-phase [$label]" for (label, spec) in (
            ("uniform", Configs.UniformGrid(21)), ("adaptive", Configs.AdaptiveGrid(21))
        )
            bounds = [0.0, 0.3, 1.0]
            g = _gen(spec, _sharp; bounds=bounds)
            _check_props(g, 21, bounds)
            Test.@test count(t -> t < 0.3, g) >= 1 && count(t -> t > 0.3, g) >= 1
        end

        Test.@testset "uniform multi-phase shares intervals by duration" begin
            g = _gen(Configs.UniformGrid(11), _sharp; bounds=[0.0, 0.3, 1.0])
            Test.@test g ≈ collect(range(0, 1, 11)) atol = 1e-14   # 0.3 is a grid point
        end

        Test.@testset "minimal size: one interval per phase" begin
            g = _gen(Configs.AdaptiveGrid(4), _sharp; bounds=[0.0, 0.2, 0.7, 1.0])
            Test.@test g == [0.0, 0.2, 0.7, 1.0]
        end

        Test.@testset "backward" begin
            for spec in (Configs.UniformGrid(9), Configs.AdaptiveGrid(9))
                g = _gen(spec, _sharp; steps=reverse(STEPS), bounds=[1.0, 0.0])
                _check_props(g, 9, [1.0, 0.0])
            end
            g = _gen(Configs.AdaptiveGrid(9), _sharp; steps=reverse(STEPS), bounds=[1.0, 0.5, 0.0])
            _check_props(g, 9, [1.0, 0.5, 0.0])
        end

        Test.@testset "Error: too few times for the phases" begin
            Test.@test_throws Exceptions.IncorrectArgument _gen(
                Configs.UniformGrid(3), _sharp; bounds=[0.0, 0.2, 0.7, 1.0]
            )
        end

        Test.@testset "Error: invalid specs" begin
            for bad in (() -> Configs.UniformGrid(1), () -> Configs.UniformGrid(0),
                        () -> Configs.UniformGrid(-3), () -> Configs.AdaptiveGrid(1),
                        () -> Configs.AdaptiveGrid(10; uniform=-0.1),
                        () -> Configs.AdaptiveGrid(10; uniform=1.1),
                        () -> Configs._grid_spec(2.5), () -> Configs._grid_spec([0.0, 1.0]),
                        () -> Configs._grid_spec(:fine))
                Test.@test_throws Exceptions.IncorrectArgument bad()
            end
            Test.@test Configs._grid_spec(7) == Configs.UniformGrid(7)
            Test.@test Configs._grid_spec(nothing) === nothing
            Test.@test Configs.AdaptiveGrid(10).uniform == 0.1
        end
    end
end

end # module

test_generate_grid() = TestGenerateGrid.test_generate_grid()
