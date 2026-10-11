"""
Unit tests of `Configs.AutomaticGrid` (issue #446), the default output grid of a trajectory
call: construction, defaults, subtyping, and its resolution against the time specification
(it only completes a time span, never a grid of times).
"""

module TestAutomaticGrid

using Test: Test
using CTBase: Exceptions
using CTFlows: Configs

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

function test_automatic_grid()
    Test.@testset "AutomaticGrid" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ── UNIT: construction and defaults ─────────────────────────────────
        Test.@testset "default is AdaptiveGrid(250), uniform share 0.1" begin
            g = Configs.AutomaticGrid()
            Test.@test g isa Configs.AutomaticGrid
            Test.@test g isa Configs.AbstractGrid
            Test.@test g.grid isa Configs.AdaptiveGrid
            Test.@test g.grid.n == 250
            Test.@test g.grid.uniform == 0.1
        end

        Test.@testset "wraps a given adaptive grid" begin
            g = Configs.AutomaticGrid(Configs.AdaptiveGrid(40; uniform=0.5))
            Test.@test g.grid.n == 40
            Test.@test g.grid.uniform == 0.5
        end

        Test.@testset "is exported by Configs" begin
            Test.@test :AutomaticGrid in names(Configs)
        end

        # ── UNIT: _grid_spec passes it through ──────────────────────────────
        Test.@testset "_grid_spec keeps an AutomaticGrid" begin
            g = Configs.AutomaticGrid()
            Test.@test Configs._grid_spec(g) === g
        end

        # ── UNIT: _time_spec completes a time span only ─────────────────────
        Test.@testset "_time_spec: time span → span and AutomaticGrid" begin
            g = Configs.AutomaticGrid()
            span, spec = Configs._time_spec((0, 1), g)
            Test.@test span == (0.0, 1.0)
            Test.@test spec === g
        end

        Test.@testset "_time_spec: grid of times → no generated grid, no error [$kind]" for (
            kind, times
        ) in (
            ("vector", [0.0, 0.5, 1.0]),
            ("tuple of 3", (0.0, 0.5, 1.0)),
            ("range", 0.0:0.25:1.0),
        )
            span, grid = Configs._time_spec(times, Configs.AutomaticGrid())
            Test.@test span == (0.0, 1.0)
            Test.@test grid == collect(Float64, times)
        end

        Test.@testset "_time_spec: an invalid grid of times is still rejected" begin
            Test.@test_throws Exceptions.IncorrectArgument Configs._time_spec(
                [0.0, 0.0, 1.0], Configs.AutomaticGrid()
            )
        end

        # ── UNIT: a trajectory config built with it carries it ──────────────
        Test.@testset "trajectory configs keep the AutomaticGrid on a span" begin
            g = Configs.AutomaticGrid()
            c1 = Configs.StateTrajectoryConfig((0.0, 1.0), [1.0]; grid=g)
            c2 = Configs.HamiltonianTrajectoryConfig((0.0, 1.0), [1.0], [0.0]; grid=g)
            Test.@test Configs.output_grid(c1) === g
            Test.@test Configs.output_grid(c2) === g
        end

        Test.@testset "trajectory configs drop it on a grid of times" begin
            g = Configs.AutomaticGrid()
            c = Configs.StateTrajectoryConfig([0.0, 0.5, 1.0], [1.0]; grid=g)
            Test.@test Configs.output_grid(c) == [0.0, 0.5, 1.0]
        end
    end
end

end # module

test_automatic_grid() = TestAutomaticGrid.test_automatic_grid()
