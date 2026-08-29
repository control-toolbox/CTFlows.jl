"""
Tests for the CTFlowsMakie extension: `Makie.plot` / `Makie.plot!` on the three CTFlows
trajectory types, dispatched through the backend-free `CTFlows.TrajectoryPlots` case
layer and rendered with the `CTBase.Plotting` Makie backend (loaded here via
`CairoMakie`). The case layer itself (`clean`, `_default_description`, `_panels`, …) and
the rendering engine are tested in `test_plots_extension.jl` and in CTBase.

Freeze granularity is behavioural (`isa Makie.Figure` / no throw), plus the structural
assertion the backend makes checkable: one `Makie.Axis` per figure leaf.
"""
module TestMakieExtension

using Test: Test
using CTFlows: CTFlows
using CTFlows: Integrators
using CTFlows: Trajectories
using CTFlows: TrajectoryPlots
using CTBase: Data
using CTBase: Core
using CTBase: Exceptions
using CTBase: Plotting
using CTModels: CTModels

using CairoMakie: CairoMakie
using CairoMakie: Makie

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

# ==============================================================================
# Fake integration results (module top-level, per the testing convention)
# ==============================================================================

struct FakePlotIntegrationResult{T} <: Integrators.AbstractIntegrationResult
    t::Vector{Float64}
    u::Vector{T}
end
Integrators.times(r::FakePlotIntegrationResult) = r.t
function Integrators.evaluate_at(r::FakePlotIntegrationResult, t::Real)
    idx = findfirst(==(t), r.t)
    return isnothing(idx) ? r.u[1] : r.u[idx]
end
(r::FakePlotIntegrationResult)(t::Real) = Integrators.evaluate_at(r, t)

struct FakeHamiltonianPlotResult <: Integrators.AbstractIntegrationResult
    t::Vector{Float64}
    u::Vector{Vector{Float64}}
end
Integrators.times(r::FakeHamiltonianPlotResult) = r.t
function Integrators.evaluate_at(r::FakeHamiltonianPlotResult, t::Real)
    idx = findfirst(==(t), r.t)
    return isnothing(idx) ? r.u[1] : r.u[idx]
end
(r::FakeHamiltonianPlotResult)(t::Real) = Integrators.evaluate_at(r, t)

# ==============================================================================
# Fixtures (shared with test_plots_extension.jl)
# ==============================================================================

function _vf_traj()
    return Trajectories.VectorFieldTrajectory(
        FakePlotIntegrationResult([0.0, 0.5, 1.0], [[1.0], [0.5], [0.25]])
    )
end
function _vf_traj2()
    return Trajectories.VectorFieldTrajectory(
        FakePlotIntegrationResult([0.0, 1.0], [[1.0, 2.0], [3.0, 4.0]])
    )
end

function _ham_traj()
    return Trajectories.HamiltonianVectorFieldTrajectory(
        1.0,
        FakeHamiltonianPlotResult([0.0, 0.5, 1.0], [[1.0, 5.0], [0.5, 2.5], [0.25, 1.25]]),
    )
end
function _ham_traj2()
    return Trajectories.HamiltonianVectorFieldTrajectory(
        [1.0, 2.0],
        FakeHamiltonianPlotResult([0.0, 1.0], [[1.0, 2.0, 5.0, 6.0], [3.0, 4.0, 7.0, 8.0]]),
    )
end

function _ctrl_traj(; objective=nothing)
    inner = _vf_traj()
    law = Data.ClosedLoop(x -> -2x)
    return Trajectories.StateFlowTrajectory(
        inner, law, Core.NotProvided, objective, only, nothing
    )
end

function _ctrl_traj_multi()
    inner = Trajectories.VectorFieldTrajectory(
        FakePlotIntegrationResult([0.0, 1.0], [[1.0, 2.0, 3.0], [0.5, 1.0, 1.5]])
    )
    law = Data.ClosedLoop(x -> [-x[1], -x[2]])
    return Trajectories.StateFlowTrajectory(
        inner, law, Core.NotProvided, nothing, identity, nothing
    )
end

function _ocp_named()
    pre = CTModels.Building.PreModel()
    CTModels.Building.time_dependence!(pre; autonomous=true)
    CTModels.Building.time!(pre; t0=0.0, tf=1.0)
    CTModels.Building.state!(pre, 2, "x", ["pos", "vel"])
    CTModels.Building.control!(pre, 1, "u", ["thrust"])
    CTModels.Building.dynamics!(pre, (r, t, x, u, v) -> (r[1]=x[2]; r[2]=u; nothing))
    CTModels.Building.objective!(pre, :min; lagrange=(t, x, u, v) -> 0.5 * u^2)
    return CTModels.Building.build(pre)
end

function _ctrl_traj_ocp()
    inner = _vf_traj2()
    law = Data.ClosedLoop(x -> [-x[1]])
    return Trajectories.StateFlowTrajectory(
        inner, law, Core.NotProvided, nothing, identity, _ocp_named()
    )
end

# ==============================================================================
# Helpers
# ==============================================================================

_axes(f::Makie.Figure) = [x for x in f.content if x isa Makie.Axis]
_n_axes(f::Makie.Figure) = length(_axes(f))

# ==============================================================================
# Test entry
# ==============================================================================

function test_makie_extension()
    Test.@testset "Makie Extension" verbose = VERBOSE showtiming = SHOWTIMING begin

        # ======================================================================
        # Contract — the extension activates and the case layer maps onto Makie
        # ======================================================================
        Test.@testset "Extension loading" begin
            ext = Base.get_extension(CTFlows, :CTFlowsMakie)
            Test.@test ext isa Module
            Test.@test TrajectoryPlots isa Module
        end

        Test.@testset "case layer -> Makie axis count" begin
            # one `Makie.Axis` per leaf of the backend-free figure the case layer builds
            for sol in (_vf_traj(), _vf_traj2(), _ham_traj(), _ham_traj2(), _ctrl_traj())
                fig = TrajectoryPlots.build_figure(sol)
                Test.@test fig isa Plotting.Figure
                Test.@test _n_axes(Makie.plot(sol)) == Plotting.n_leaves(fig)
            end
        end

        # ======================================================================
        # Integration — `Makie.plot` / `plot!` render a `Makie.Figure` for the
        # common description / layout / style / overlay combinations
        # ======================================================================
        Test.@testset "VectorFieldTrajectory plotting" begin
            sol = _vf_traj()
            Test.@test Makie.plot(sol) isa Makie.Figure
            Test.@test Makie.plot(sol; layout=:group) isa Makie.Figure
            Test.@test Makie.plot(sol; time=:normalize) isa Makie.Figure
            Test.@test Makie.plot(sol; state_style=(color=:red,)) isa Makie.Figure
            Test.@test Makie.plot(sol; color=:red) isa Makie.Figure          # passthrough
            Test.@test Makie.plot(_vf_traj2(); layout=:split) isa Makie.Figure
            Test.@test_throws Exceptions.IncorrectArgument Makie.plot(
                sol; state_style=:none
            )
        end

        Test.@testset "StateFlowTrajectory plotting" begin
            sol = _ctrl_traj()
            Test.@test Makie.plot(sol) isa Makie.Figure                      # state + control
            Test.@test Makie.plot(sol, :control) isa Makie.Figure
            Test.@test Makie.plot(sol; control=:norm) isa Makie.Figure
            Test.@test Makie.plot(sol; control=:all) isa Makie.Figure
            Test.@test Makie.plot(_ctrl_traj(; objective=2.0)) isa Makie.Figure
            Test.@test Makie.plot(_ctrl_traj_multi()) isa Makie.Figure       # 3 states, 2 controls
            Test.@test Makie.plot(_ctrl_traj_ocp()) isa Makie.Figure         # OCP names
            Test.@test_throws Exceptions.IncorrectArgument Makie.plot(sol; control=:bad)
        end

        Test.@testset "HamiltonianVectorFieldTrajectory plotting" begin
            sol = _ham_traj()
            Test.@test Makie.plot(sol) isa Makie.Figure                      # state | costate
            Test.@test Makie.plot(sol, :state) isa Makie.Figure
            Test.@test Makie.plot(sol; layout=:group) isa Makie.Figure
            Test.@test Makie.plot(_ham_traj2()) isa Makie.Figure             # 2 states | 2 costates
        end

        Test.@testset "overlay onto an existing figure" begin
            sol = _ham_traj()
            f = Makie.plot(sol)
            n = _n_axes(f)
            out = Makie.plot!(f, sol; state_style=(linestyle=:dash,))
            Test.@test out === f
            Test.@test _n_axes(f) == n            # overlay adds no axes
        end

        Test.@testset "plot! onto current and fresh figures" begin
            Makie.plot(_vf_traj())               # sets the current figure
            Test.@test Makie.plot!(_vf_traj()) isa Makie.Figure
            Test.@test Makie.plot!(Makie.Figure(), _vf_traj()) isa Makie.Figure
        end

        Test.@testset "plot(; size) empty canvas (from CTModelsMakie) overlays" begin
            # mirror of `Plots.plot(; size=…)`: a blank figure, then `plot!(f, traj)`.
            # The zero-arg `Makie.plot(; …)` is provided by the CTModelsMakie extension.
            f = Makie.plot(; size=(800, 800))
            Test.@test f isa Makie.Figure
            Test.@test _n_axes(f) == 0
            Test.@test size(f.scene) == (800, 800)
            out = Makie.plot!(f, _vf_traj())
            Test.@test out === f
            Test.@test _n_axes(f) == _n_axes(Makie.plot(_vf_traj()))
        end

        # ======================================================================
        # Error — invalid keywords / nothing to draw throw the right exception
        # ======================================================================
        Test.@testset "error paths" begin
            sol = _vf_traj()
            Test.@test_throws Exceptions.IncorrectArgument Makie.plot(sol; layout=:bad)
            Test.@test_throws Exceptions.IncorrectArgument Makie.plot(sol; time=:bad)
        end
    end
end

end # module

# CRITICAL: Redefine in outer scope for TestRunner
test_makie_extension() = TestMakieExtension.test_makie_extension()
