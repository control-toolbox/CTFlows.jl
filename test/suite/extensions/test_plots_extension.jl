"""
Tests for the CTFlowsPlots extension: the generic `PlotEngine` and the `TrajectoryPlots`
case layer (plotting of the three trajectory types, including `ControlledTrajectory`,
component-name plumbing from the OCP, and the split/group layouts).
"""
module TestPlotsExtension

using Test: Test
import CTFlows: CTFlows
import CTFlows.Integrators: Integrators
import CTFlows.Trajectories: Trajectories
import CTBase.Data: Data
import CTBase.Core: Core
import CTBase.Exceptions: Exceptions
import CTModels: CTModels

using Plots

# Extension and its two sub-modules
const CTFlowsPlots = Base.get_extension(CTFlows, :CTFlowsPlots)
const PlotEngine = CTFlowsPlots.PlotEngine
const TrajectoryPlots = CTFlowsPlots.TrajectoryPlots

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
# Fixtures
# ==============================================================================

# 1-D and 2-D state vector-field trajectories
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

# scalar and 2-D Hamiltonian trajectories (u = [state…; costate…])
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

# controlled trajectory (1-D, no OCP): closed-loop u(t,x,v) = -2x
function _ctrl_traj(; objective=nothing)
    inner = _vf_traj()
    law = Data.ClosedLoop(x -> -2x)                 # autonomous, fixed
    return Trajectories.ControlledTrajectory(
        inner, law, Core.NotProvided, objective, only, nothing
    )
end

# controlled trajectory (3 states, 2 controls, no OCP -> generated names)
function _ctrl_traj_multi()
    inner = Trajectories.VectorFieldTrajectory(
        FakePlotIntegrationResult([0.0, 1.0], [[1.0, 2.0, 3.0], [0.5, 1.0, 1.5]])
    )
    law = Data.ClosedLoop(x -> [-x[1], -x[2]])      # 2-D control
    return Trajectories.ControlledTrajectory(
        inner, law, Core.NotProvided, nothing, identity, nothing
    )
end

# a small OCP with *named* components (2 states "pos"/"vel", 1 control "thrust")
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

# controlled trajectory carrying the named OCP (2-D state, 1-D control)
function _ctrl_traj_ocp()
    inner = _vf_traj2()                               # 2-D state
    law = Data.ClosedLoop(x -> [-x[1]])              # 1-D control
    return Trajectories.ControlledTrajectory(
        inner, law, Core.NotProvided, nothing, identity, _ocp_named()
    )
end

# ==============================================================================
# Test entry
# ==============================================================================

function test_plots_extension()
    Test.@testset "Plots Extension" verbose = VERBOSE showtiming = SHOWTIMING begin

        # ----------------------------------------------------------------------
        Test.@testset "Extension loading" begin
            Test.@test CTFlowsPlots isa Module
            Test.@test PlotEngine isa Module
            Test.@test TrajectoryPlots isa Module
        end

        # ----------------------------------------------------------------------
        # PlotEngine — generic, domain-free
        # ----------------------------------------------------------------------
        Test.@testset "PlotEngine" begin
            Test.@testset "time axis" begin
                Test.@test PlotEngine._time_axis([0.0, 1.0, 2.0], :default) ==
                    [0.0, 1.0, 2.0]
                Test.@test PlotEngine._time_axis([0.0, 1.0, 2.0], :normalize) ==
                    [0.0, 0.5, 1.0]
                Test.@test_throws Exceptions.IncorrectArgument PlotEngine._time_axis(
                    [0.0, 1.0], :bad
                )
            end

            Test.@testset "cells and grid" begin
                state = PlotEngine.Panel(
                    "state", ["x₁", "x₂"], [1.0 2.0; 3.0 4.0], NamedTuple()
                )
                costate = PlotEngine.Panel(
                    "costate", ["", ""], [5.0 6.0; 7.0 8.0], NamedTuple()
                )
                control = PlotEngine.Panel(
                    "control", ["u"], reshape([9.0, 10.0], 2, 1), NamedTuple()
                )

                # stacked: one column of every component
                cells, grid = PlotEngine._cells_and_grid([state, control], :stacked)
                Test.@test grid == (3, 1)
                Test.@test length(cells) == 3

                # paired: state | costate side by side, (2, 2) grid
                cells2, grid2 = PlotEngine._cells_and_grid([state, costate], :paired)
                Test.@test grid2 == (2, 2)
                Test.@test length(cells2) == 4

                # paired fallback to stacked when heights differ
                _, gridf = PlotEngine._cells_and_grid([state, control], :paired)
                Test.@test gridf == (3, 1)
            end

            Test.@testset "render / render!" begin
                times = [0.0, 0.5, 1.0]
                ps = [
                    PlotEngine.Panel(
                        "state", ["x"], reshape([1.0, 0.5, 0.25], 3, 1), NamedTuple()
                    ),
                ]
                p = PlotEngine.render(times, ps)
                Test.@test p isa Plots.Plot
                Test.@test PlotEngine.render(times, ps; layout=:group) isa Plots.Plot
                Test.@test_nowarn PlotEngine.render!(p, times, ps)
                Test.@test_throws Exceptions.IncorrectArgument PlotEngine.render(
                    times, PlotEngine.Panel[]
                )
                Test.@test_throws Exceptions.IncorrectArgument PlotEngine.render(
                    times, ps; layout=:bad
                )
            end
        end

        # ----------------------------------------------------------------------
        # TrajectoryPlots — case layer
        # ----------------------------------------------------------------------
        Test.@testset "TrajectoryPlots" begin
            Test.@testset "clean" begin
                Test.@test Set(TrajectoryPlots.clean((:states, :controls, :state))) ==
                    Set([:state, :control])
            end

            Test.@testset "default description contract" begin
                Test.@test TrajectoryPlots._default_description(_vf_traj()) == (:state,)
                Test.@test TrajectoryPlots._default_description(_ctrl_traj()) ==
                    (:state, :control)
                Test.@test TrajectoryPlots._default_description(_ham_traj()) ==
                    (:state, :costate)
            end

            Test.@testset "names: generated vs from OCP" begin
                # generated defaults
                Test.@test TrajectoryPlots._state_names(_vf_traj2(), 2) == ["x₁", "x₂"]
                Test.@test TrajectoryPlots._time_name(_vf_traj2()) == "t"
                # from the OCP the ControlledTrajectory carries
                sol = _ctrl_traj_ocp()
                Test.@test TrajectoryPlots._state_names(sol, 2) == ["pos", "vel"]
                Test.@test TrajectoryPlots._control_names(sol, 1) == ["thrust"]
            end

            Test.@testset "panels & placement" begin
                # OCP names flow into the panels
                _, panels, placement = TrajectoryPlots._panels(
                    _ctrl_traj_ocp(),
                    (:state, :control);
                    control=:components,
                    state_style=NamedTuple(),
                    costate_style=NamedTuple(),
                    control_style=NamedTuple(),
                )
                Test.@test placement == :stacked
                Test.@test panels[1].labels == ["pos", "vel"]
                Test.@test panels[2].labels == ["thrust"]
                # state + costate -> paired
                _, _, placement2 = TrajectoryPlots._panels(
                    _ham_traj(),
                    (:state, :costate);
                    control=:components,
                    state_style=NamedTuple(),
                    costate_style=NamedTuple(),
                    control_style=NamedTuple(),
                )
                Test.@test placement2 == :paired
            end
        end

        # ----------------------------------------------------------------------
        Test.@testset "VectorFieldTrajectory plotting" begin
            sol = _vf_traj()
            Test.@test Plots.plot(sol) isa Plots.Plot
            Test.@test Plots.plot(sol; layout=:group) isa Plots.Plot
            Test.@test Plots.plot(sol; time=:normalize) isa Plots.Plot
            Test.@test Plots.plot(sol; state_style=(color=:red,)) isa Plots.Plot
            Test.@test Plots.plot(sol; color=:red, linewidth=2) isa Plots.Plot  # passthrough
            Test.@test Plots.plot(_vf_traj2(); layout=:split) isa Plots.Plot
            p = Plots.plot(sol)
            Test.@test_nowarn Plots.plot!(p, sol)
            Test.@test_throws Exceptions.IncorrectArgument Plots.plot(
                sol; state_style=:none
            )
        end

        # ----------------------------------------------------------------------
        Test.@testset "ControlledTrajectory plotting" begin
            sol = _ctrl_traj()
            Test.@test Plots.plot(sol) isa Plots.Plot                     # state + control
            Test.@test Plots.plot(sol, :control) isa Plots.Plot
            Test.@test Plots.plot(sol; control=:norm) isa Plots.Plot
            Test.@test Plots.plot(sol; control=:all) isa Plots.Plot
            Test.@test Plots.plot(_ctrl_traj(; objective=2.0)) isa Plots.Plot
            Test.@test Plots.plot(_ctrl_traj_multi()) isa Plots.Plot      # 3 states, 2 controls
            Test.@test Plots.plot(_ctrl_traj_ocp()) isa Plots.Plot        # OCP names
            Test.@test_throws Exceptions.IncorrectArgument Plots.plot(sol; control=:bad)
        end

        # ----------------------------------------------------------------------
        Test.@testset "HamiltonianVectorFieldTrajectory plotting" begin
            sol = _ham_traj()
            Test.@test Plots.plot(sol) isa Plots.Plot                     # state | costate
            Test.@test Plots.plot(sol, :state) isa Plots.Plot
            Test.@test Plots.plot(sol; layout=:group) isa Plots.Plot
            Test.@test Plots.plot(_ham_traj2()) isa Plots.Plot            # 2 states | 2 costates
            p = Plots.plot(sol)
            Test.@test_nowarn Plots.plot!(p, sol)
        end

        # ----------------------------------------------------------------------
        Test.@testset "error paths" begin
            sol = _vf_traj()
            Test.@test_throws Exceptions.IncorrectArgument Plots.plot(sol; layout=:bad)
            Test.@test_throws Exceptions.IncorrectArgument Plots.plot(sol; time=:bad)
        end
    end
end

end # module

test_plots_extension() = TestPlotsExtension.test_plots_extension()
