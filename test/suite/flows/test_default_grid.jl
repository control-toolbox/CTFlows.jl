"""
Contract tests of the default output grid (issue #446), with fakes and no solver:

- `Flows.__grid()` and the resolution `Flows._default_grid` (time span vs grid of times,
  `saveat`, explicit `grid`);
- `Trajectories.apply_generated_grid` on an `AutomaticGrid`: regenerated only when the
  trajectory is dense and has fewer than `n` distinct times (threshold 249 / 250 / 251).
"""

module TestDefaultGrid

using Test: Test
using CTBase: Core
using CTFlows: Configs
using CTFlows: Flows
using CTFlows: Integrators
using CTFlows: Trajectories

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

# ── fakes (module top-level) ────────────────────────────────────────────────

struct FakeIntegSaveat <: Integrators.AbstractIntegrator end
Integrators.has_saveat(::FakeIntegSaveat) = true

struct FakeIntegPlain <: Integrators.AbstractIntegrator end

struct FakeFlow{I}
    integ::I
end
Flows.integrator(f::FakeFlow) = f.integ

"""A trajectory on `ts` that records the grid it is regridded on."""
struct FakeTraj
    ts::Vector{Float64}
    dense::Bool
    regridded_on::Union{Nothing,Vector{Float64}}
end
FakeTraj(ts; dense=true) = FakeTraj(collect(Float64, ts), dense, nothing)
Integrators.is_dense(t::FakeTraj) = t.dense
Integrators.times(t::FakeTraj) = t.ts
function Integrators.regrid(t::FakeTraj, grid::AbstractVector)
    return FakeTraj(t.ts, t.dense, collect(grid))
end

_curve(t) = [sin(3t)]
function _apply(traj, spec=Configs.AutomaticGrid())
    return Trajectories.apply_generated_grid(traj, spec, _curve, [0.0, 1.0])
end

function test_default_grid()
    Test.@testset "Default output grid" verbose = VERBOSE showtiming = SHOWTIMING begin

        # ── UNIT: the keyword default ───────────────────────────────────────
        Test.@testset "__grid() is NotProvided" begin
            Test.@test Flows.__grid() isa Core.NotProvidedType
        end

        # ── CONTRACT: _default_grid ─────────────────────────────────────────
        Test.@testset "_default_grid: explicit grids are returned as given" begin
            f = FakeFlow(FakeIntegPlain())
            for grid in (nothing, 5, Configs.UniformGrid(7), Configs.AdaptiveGrid(9))
                Test.@test Flows._default_grid(grid, (0.0, 1.0), f) === grid
            end
        end

        Test.@testset "_default_grid: NotProvided + time span → AutomaticGrid" begin
            f = FakeFlow(FakeIntegPlain())
            g = Flows._default_grid(Core.NotProvided, (0.0, 1.0), f)
            Test.@test g isa Configs.AutomaticGrid
            Test.@test g.grid.n == 250
            # integer endpoints are a span too
            Test.@test Flows._default_grid(Core.NotProvided, (0, 1), f) isa
                Configs.AutomaticGrid
        end

        Test.@testset "_default_grid: NotProvided + grid of times → nothing [$kind]" for (
            kind, times
        ) in (
            ("vector", [0.0, 0.5, 1.0]),
            ("tuple of 3", (0.0, 0.5, 1.0)),
            ("range", 0.0:0.5:1.0),
        )
            f = FakeFlow(FakeIntegPlain())
            Test.@test Flows._default_grid(Core.NotProvided, times, f) === nothing
        end

        Test.@testset "_default_grid: NotProvided + saveat on the integrator → nothing" begin
            Test.@test Flows._default_grid(
                Core.NotProvided, (0.0, 1.0), FakeFlow(FakeIntegSaveat())
            ) === nothing
        end

        Test.@testset "_default_grid: any phase with saveat disables it" begin
            plain, saveat = FakeFlow(FakeIntegPlain()), FakeFlow(FakeIntegSaveat())
            Test.@test Flows._default_grid(Core.NotProvided, (0.0, 1.0), plain, plain) isa
                Configs.AutomaticGrid
            Test.@test Flows._default_grid(Core.NotProvided, (0.0, 1.0), plain, saveat) ===
                nothing
            Test.@test Flows._default_grid(Core.NotProvided, (0.0, 1.0), saveat, plain) ===
                nothing
        end

        # ── CONTRACT: apply_generated_grid on an AutomaticGrid ──────────────
        Test.@testset "regenerated below the threshold [n=$n]" for n in (2, 5, 100, 249)
            out = _apply(FakeTraj(range(0, 1, n)))
            Test.@test out.regridded_on !== nothing
            Test.@test length(out.regridded_on) == 250
            Test.@test allunique(out.regridded_on)
            Test.@test first(out.regridded_on) == 0.0 && last(out.regridded_on) == 1.0
        end

        Test.@testset "kept at or above the threshold [n=$n]" for n in (250, 251, 1000)
            traj = FakeTraj(range(0, 1, n))
            Test.@test _apply(traj) === traj
        end

        Test.@testset "duplicate times count once (a switching time is not two steps)" begin
            ts = vcat(collect(range(0, 0.5, 125)), collect(range(0.5, 1, 126)))
            Test.@test length(ts) == 251 && length(unique(ts)) == 250
            traj = FakeTraj(ts)
            Test.@test _apply(traj) === traj      # 250 distinct times: kept
            ts = vcat(collect(range(0, 0.5, 124)), collect(range(0.5, 1, 126)))
            Test.@test length(unique(ts)) == 249
            Test.@test _apply(FakeTraj(ts)).regridded_on !== nothing   # 249 distinct: regenerated
        end

        Test.@testset "kept without dense output" begin
            traj = FakeTraj(range(0, 1, 5); dense=false)
            Test.@test _apply(traj) === traj
        end

        Test.@testset "a custom size is honoured" begin
            spec = Configs.AutomaticGrid(Configs.AdaptiveGrid(20))
            Test.@test length(_apply(FakeTraj(range(0, 1, 5)), spec).regridded_on) == 20
            traj = FakeTraj(range(0, 1, 30))
            Test.@test _apply(traj, spec) === traj
        end

        Test.@testset "other specs and no spec are not conditional" begin
            traj = FakeTraj(range(0, 1, 400))
            # an explicit generated grid always regenerates, whatever the solver returned
            out = _apply(traj, Configs.AdaptiveGrid(30))
            Test.@test length(out.regridded_on) == 30
            Test.@test _apply(traj, nothing) === traj
            Test.@test _apply(traj, [0.0, 1.0]) === traj
        end

        # ── UNIT: _effective_bounds (issue #524) ────────────────────────────
        Test.@testset "_effective_bounds: the solver reached the end → same bounds" begin
            for (b, s) in (
                ([0.0, 1.0], [0.0, 0.5, 1.0]),
                ([1.0, 0.0], [1.0, 0.5, 0.0]),
                ([0.0, 0.5, 1.0], [0.0, 0.5, 1.0]),
                ([0.0, 0.5, 1.0], [0.0, 0.5, 1.0 + 1e-12]),
            )
                Test.@test Trajectories._effective_bounds(b, s) === b
            end
        end

        Test.@testset "_effective_bounds: early stop [$(b)] → $(expected)" for (
            b, s, expected
        ) in (
            ([0.0, 1.0], [0.0, 0.2, 0.37], [0.0, 0.37]),
            ([1.0, 0.0], [1.0, 0.7, 0.42], [1.0, 0.42]),
            ([0.0, 0.5, 1.0], [0.0, 0.3, 0.65], [0.0, 0.5, 0.65]),
            ([0.0, 0.5, 1.0], [0.0, 0.3], [0.0, 0.3]),
            ([0.0, 0.5, 1.0], [0.0, 0.5], [0.0, 0.5]),
            ([1.0, 0.5, 0.0], [1.0, 0.7, 0.3], [1.0, 0.5, 0.3]),
            ([0, 1], [0.0, 0.25], [0, 0.25]),
        )
            Test.@test Trajectories._effective_bounds(b, s) == expected
            Test.@test Trajectories._effective_bounds(b, s) !== b
        end

        Test.@testset "_effective_bounds: does not mutate its input and is inferred" begin
            b = [0.0, 0.5, 1.0]
            Test.@inferred Trajectories._effective_bounds(b, [0.0, 0.3, 0.65])
            Trajectories._effective_bounds(b, [0.0, 0.3, 0.65])
            Test.@test b == [0.0, 0.5, 1.0]
        end

        # ── CONTRACT: apply_generated_grid stops at the integrated end time ──
        Test.@testset "early termination: the generated grid stops at the stop time" begin
            out = _apply(FakeTraj(range(0, 0.37, 10)))
            Test.@test first(out.regridded_on) == 0.0
            Test.@test last(out.regridded_on) == 0.37
            Test.@test length(out.regridded_on) == 250

            out = Trajectories.apply_generated_grid(
                FakeTraj(range(1.0, 0.42, 10)),
                Configs.AutomaticGrid(),
                _curve,
                [1.0, 0.0],
            )
            Test.@test first(out.regridded_on) == 1.0
            Test.@test last(out.regridded_on) == 0.42
            Test.@test issorted(out.regridded_on; rev=true)
        end

        Test.@testset "early termination: the switching time before the stop is kept" begin
            out = Trajectories.apply_generated_grid(
                FakeTraj(range(0.0, 0.65, 10)),
                Configs.AdaptiveGrid(20),
                _curve,
                [0.0, 0.5, 1.0],
            )
            Test.@test length(out.regridded_on) == 20
            Test.@test first(out.regridded_on) == 0.0
            Test.@test last(out.regridded_on) == 0.65
            Test.@test 0.5 in out.regridded_on
        end

        Test.@testset "early termination: stop before the switching time" begin
            out = Trajectories.apply_generated_grid(
                FakeTraj(range(0.0, 0.3, 10)),
                Configs.AdaptiveGrid(20),
                _curve,
                [0.0, 0.5, 1.0],
            )
            Test.@test length(out.regridded_on) == 20
            Test.@test last(out.regridded_on) == 0.3
            Test.@test all(<=(0.3), out.regridded_on)
        end

        Test.@testset "a trajectory with a single time is returned unchanged" begin
            traj = FakeTraj([0.0])
            for spec in (Configs.AutomaticGrid(), Configs.AdaptiveGrid(20), Configs.UniformGrid(20))
                Test.@test _apply(traj, spec) === traj
            end
            twice = FakeTraj([0.0, 0.0])   # one distinct time
            Test.@test _apply(twice, Configs.AdaptiveGrid(20)) === twice
        end
    end
end

end # module

test_default_grid() = TestDefaultGrid.test_default_grid()
