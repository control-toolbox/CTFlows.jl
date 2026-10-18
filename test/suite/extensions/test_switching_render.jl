"""
End-to-end rendering of multi-phase trajectories with the Plots and Makie backends (issue
#443): the vertical jump, the switching-time lines and the phase labels reach the figure.
"""

module TestSwitchingRender

using Test: Test
using CTBase: Data
using CTFlows: Flows
using CTModels: CTModels
using OrdinaryDiffEqTsit5: Tsit5
using Plots: Plots
using CairoMakie: CairoMakie
using CairoMakie: Makie

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

const τ = 0.5

# ẋ = u on [0, 1], 1-D: a bang-bang controlled flow, then a state jump.
function _ocp()
    pre = CTModels.Building.PreModel()
    CTModels.Building.time_dependence!(pre; autonomous=true)
    CTModels.Building.time!(pre; t0=0.0, tf=1.0)
    CTModels.Building.state!(pre, 1)
    CTModels.Building.control!(pre, 1)
    CTModels.Building.dynamics!(pre, (r, t, x, u, v) -> (r[1] = u; nothing))
    CTModels.Building.objective!(pre, :min; lagrange=(t, x, u, v) -> 0.5 * u^2)
    return CTModels.Building.build(pre)
end

function _traj()
    ocp = _ocp()
    f1 = Flows.Flow(ocp, Data.OpenLoop(t -> 1.0); label="u=+1", alg=Tsit5())
    f2 = Flows.Flow(ocp, Data.OpenLoop(t -> -1.0); label="u=-1", alg=Tsit5())
    return (f1 * (τ, 1.0, f2))((0.0, 1.0), 0.0)   # state jump +1 at τ
end

_axes(f) = [x for x in f.content if x isa Makie.Axis]
_count_plots(axis, ::Type{P}) where {P} = count(p -> p isa P, axis.scene.plots)

function test_switching_render()
    Test.@testset "Rendering multi-phase trajectories" verbose=VERBOSE showtiming=SHOWTIMING begin
        traj = _traj()

        Test.@testset "Plots" begin
            plt = Plots.plot(traj)
            Test.@test plt isa Plots.Plot
            Test.@test length(plt.subplots) == 2   # state over control
            xs = plt.subplots[1].series_list[1][:x]
            ys = plt.subplots[1].series_list[1][:y]
            k = findfirst(==(τ), xs)
            Test.@test xs[k + 1] == τ
            Test.@test ys[k + 1] - ys[k] ≈ 1.0 atol = 1e-8   # the state jump
            Test.@test isempty(plt.subplots[1][:annotations])
            Test.@test sort([a[3].str for a in plt.subplots[2][:annotations]]) ==
                ["u=+1", "u=-1"]
            Test.@test Plots.plot(traj; switching_style=:none, phase_labels=:none) isa
                Plots.Plot
        end

        Test.@testset "Makie" begin
            f = Makie.plot(traj)
            Test.@test f isa Makie.Figure
            axs = _axes(f)
            Test.@test length(axs) == 2
            Test.@test all(ax -> _count_plots(ax, Makie.VLines) == 1, axs)
            Test.@test sum(ax -> _count_plots(ax, Makie.Text), axs) == 2
            g = Makie.plot(traj; phase_labels=:all, switching_style=:none)
            Test.@test all(ax -> _count_plots(ax, Makie.VLines) == 0, _axes(g))
            Test.@test sum(ax -> _count_plots(ax, Makie.Text), _axes(g)) == 4
        end
    end
end

end # module

test_switching_render() = TestSwitchingRender.test_switching_render()
