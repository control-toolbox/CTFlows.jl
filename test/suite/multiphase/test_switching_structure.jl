"""
Switching structure of multi-phase flows (issue #443): phase labels given at construction
and kept through concatenation, left and right limits at the switching times (state,
costate, control), the switching structure of the `CTModels.Solution`, and the plot data
(vertical jumps, switching-time lines, phase labels).
"""

module TestSwitchingStructure

using Test: Test
using CTBase: Data
using CTBase: Exceptions
using CTBase: Plotting
using CTBase: Strategies
using CTBase: Traits
using CTModels: CTModels
using CTFlows: Flows
using CTFlows: MultiPhase
using CTFlows: Trajectories
using CTFlows: TrajectoryPlots
using CTFlows: Integrators
using OrdinaryDiffEqTsit5: Tsit5
using ForwardDiff: ForwardDiff  # triggers the DI ForwardDiff extension (AutoForwardDiff)

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

# A flow type that holds no label (TST3: fakes at module top level).
struct FakeFlow <: Flows.AbstractFlow{Traits.Autonomous,Traits.Fixed,Traits.StateDynamics} end

_opts() = (; alg=Tsit5(), reltol=1e-12, abstol=1e-12)
_val(a) = a isa Number ? a : a[1]

# ẋ = -x + u, ℓ = u²/2 (1-D, for Hamiltonian flows with a law u = ±p).
function _lqr()
    pre = CTModels.Building.PreModel()
    CTModels.Building.time_dependence!(pre; autonomous=true)
    CTModels.Building.time!(pre; t0=0.0, tf=1.0)
    CTModels.Building.state!(pre, 1)
    CTModels.Building.control!(pre, 1)
    CTModels.Building.dynamics!(pre, (r, t, x, u, v) -> (r[1] = (-x + u); nothing))
    CTModels.Building.objective!(pre, :min; lagrange=(t, x, u, v) -> 0.5 * u^2)
    return CTModels.Building.build(pre)
end

# ẋ = u, ℓ = u²/2 (1-D, for controlled state flows with open-loop laws).
function _integrator()
    pre = CTModels.Building.PreModel()
    CTModels.Building.time_dependence!(pre; autonomous=true)
    CTModels.Building.time!(pre; t0=0.0, tf=1.0)
    CTModels.Building.state!(pre, 1)
    CTModels.Building.control!(pre, 1)
    CTModels.Building.dynamics!(pre, (r, t, x, u, v) -> (r[1] = u; nothing))
    CTModels.Building.objective!(pre, :min; lagrange=(t, x, u, v) -> 0.5 * u^2)
    return CTModels.Building.build(pre)
end

const LQR = _lqr()
const INT = _integrator()
const τ = 0.5

_plus(; label="") = Flows.Flow(
    LQR, Data.DynClosedLoop((x, p) -> p); hamiltonian_type=:total, label=label, _opts()...
)
_minus(; label="") = Flows.Flow(
    LQR, Data.DynClosedLoop((x, p) -> -p); hamiltonian_type=:total, label=label, _opts()...
)
_bang(u; label="") = Flows.Flow(INT, Data.OpenLoop(t -> u); label=label, _opts()...)
_decay(; label="") = Flows.Flow(Data.VectorField(x -> -x); label=label, _opts()...)
_harmonic(; label="") =
    Flows.Flow(Data.HamiltonianVectorField((x, p) -> (p, -x)); label=label, _opts()...)

_leaves(fig) = Plotting.leaves(fig.root)
_cell(fig, title) = only(l for l in _leaves(fig) if l.axes.title == title)
_texts(fig) = reduce(
    vcat,
    (filter(d -> d isa Plotting.Annotation, l.axes.decorations) for l in _leaves(fig));
    init=Plotting.Annotation[],
)
_vlines(cell) = [d.value for d in cell.axes.decorations if d isa Plotting.VLine]

function test_switching_structure()
    Test.@testset "Switching structure" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ====================================================================
        # UNIT TESTS - labels given at construction
        # ====================================================================

        Test.@testset "labels: default, stored, every flow type" begin
            Test.@test Flows.label(Flows.Flow(Data.VectorField(x -> -x))) == ""
            Test.@test Flows.label(_decay(; label="decay")) == "decay"
            Test.@test Flows.label(_harmonic(; label="h")) == "h"
            ocf = _plus(; label="plus")
            Test.@test ocf isa Flows.OptimalControlFlow
            Test.@test Flows.label(ocf) == "plus"
            cf = _bang(1.0; label="bang+")
            Test.@test cf isa Flows.ControlledFlow
            Test.@test Flows.label(cf) == "bang+"
            # a flow type that holds no label has none
            Test.@test Flows.label(FakeFlow()) == ""
        end

        Test.@testset "labels: not passed to the integrator, flows still integrate" begin
            f = _decay(; label="decay")
            Test.@test _val(f(0.0, 1.0, 1.0)) ≈ exp(-1.0) atol = 1e-10
            Test.@test Flows.label(Flows.with_label(f, "")) == "decay"   # empty: unchanged
            Test.@test Flows.label(Flows.with_label(f, "other")) == "other"
            Test.@test Flows.label(Flows.with_label(_plus(), "p")) == "p"
            Test.@test Flows.label(Flows.with_label(_bang(1.0), "b")) == "b"
        end

        Test.@testset "labels: an action option of every constructor" begin
            # routed as an action option, never as a strategy option
            routed = Flows._route_flow_options(Traits.WithoutAD, (; label="a", reltol=1e-8))
            Test.@test Flows._routed_label(routed) == "a"
            Test.@test !haskey(routed.strategies.integrator, :label)
            Test.@test haskey(routed.strategies.integrator, :reltol)
            Test.@test Flows._routed_label(Flows._route_flow_options(Traits.WithAD, (;))) == ""
            # with the action options of the control flows
            routed = Flows._route_flow_options(
                Traits.WithAD,
                (; label="b", hamiltonian_type=:partial);
                action_defs=Flows._flow_action_defs(),
            )
            Test.@test Flows._routed_label(routed) == "b"
            # the AD-free integrator builder returns the label with the integrator
            built = Flows._build_integrator((; label="c", reltol=1e-8))
            Test.@test built.label == "c"
            Test.@test built.integrator isa Integrators.AbstractIntegrator
            Test.@test Flows._build_integrator((;)).label == ""
            # every constructor accepts it
            h = Data.Hamiltonian((x, p) -> (x^2 + p^2) / 2)
            Test.@test Flows.label(Flows.Flow(h; label="h", _opts()...)) == "h"
            hvf = Data.PseudoHamiltonianVectorField((x, p, u) -> (u, -x))
            law = Data.DynClosedLoop((x, p) -> p)
            Test.@test Flows.label(Flows.Flow(hvf, law; label="phvf", _opts()...)) == "phvf"
            ph = Data.PseudoHamiltonian((x, p, u) -> p * u - u^2 / 2)
            for ht in (:total, :partial)
                f = Flows.Flow(ph, law; hamiltonian_type=ht, label="ph", _opts()...)
                Test.@test Flows.label(f) == "ph"
            end
            fc = Data.ControlledVectorField((x, u) -> -x + u)
            cf = Flows.Flow(fc, Data.OpenLoop(t -> 1.0); label="fc", _opts()...)
            Test.@test cf isa Flows.ControlledFlow
            Test.@test Flows.label(cf) == "fc"
            Test.@test Flows.label(Flows.Flow(LQR, (x, p) -> p; label="u", _opts()...)) == "u"
            # a value of the wrong type is rejected by the orchestration
            Test.@test_throws Exceptions.IncorrectArgument Flows.Flow(
                Data.VectorField(x -> -x); label=:decay
            )
            Test.@test_throws Exceptions.IncorrectArgument Flows.Flow(
                LQR, Data.DynClosedLoop((x, p) -> p); label=1
            )
            # route_to sends it to a strategy, which has no such option
            Test.@test_throws Exceptions.IncorrectArgument Flows.Flow(
                Data.VectorField(x -> -x); label=Strategies.route_to(sciml="x")
            )
            # display: a label row when there is a label
            s = sprint(show, MIME"text/plain"(), _decay(; label="decay"))
            Test.@test occursin("label: decay", s)
            Test.@test !occursin("label", sprint(show, MIME"text/plain"(), _decay()))
            Test.@test occursin("label=\"bang\"", sprint(show, _bang(1.0; label="bang")))
            Test.@test !occursin("label", sprint(show, _bang(1.0)))
        end

        Test.@testset "labels: concatenation keeps them in order" begin
            Test.@test MultiPhase.get_labels(_decay(; label="a")) == ["a"]
            mp = _decay(; label="a") * (0.3, _decay()) * (0.6, _decay(; label="c"))
            Test.@test MultiPhase.get_labels(mp) == ["a", "", "c"]
            # nested multi-phase flows
            left = _decay(; label="a") * (0.2, _decay(; label="b"))
            right = _decay(; label="c") * (0.8, _decay(; label="d"))
            Test.@test MultiPhase.get_labels(left * (0.5, right)) == ["a", "b", "c", "d"]
            # display: a labels row, an unlabelled phase as ·
            s = sprint(show, MIME"text/plain"(), mp)
            Test.@test occursin("labels: a → · → c", s)
            s0 = sprint(show, MIME"text/plain"(), _decay() * (0.5, _decay()))
            Test.@test !occursin("labels", s0)
        end

        # ====================================================================
        # UNIT TESTS - left and right limits of raw trajectories
        # ====================================================================

        Test.@testset "state flow: state jump" begin
            mp = _decay(; label="decay") * (τ, 1.0, _decay())
            traj = mp((0.0, 1.0), 1.0; grid=nothing)
            Test.@test traj isa Trajectories.VectorFieldTrajectory
            Test.@test Trajectories.switching_times(traj) == [τ]
            Test.@test Trajectories.phase_labels(traj) == ["decay", ""]
            Test.@test count(==(τ), Integrators.times(traj)) == 1
            Test.@test Trajectories.left_limit(traj, :state, 1) ≈ exp(-τ) atol = 1e-8
            Test.@test Trajectories.right_limit(traj, :state, 1) ≈ exp(-τ) + 1 atol = 1e-8
            Test.@test traj(τ) ≈ exp(-τ) atol = 1e-8                     # left-continuous
            Test.@test Trajectories.right_limit(traj, :state, 1) isa Float64   # DIM1
        end

        Test.@testset "Hamiltonian flow: jumps of the state and of the costate" begin
            # ẋ = p, ṗ = -x from (1, 0): x = cos t, p = -sin t; jump (Δx, Δp) = (1, 2)
            mp = _harmonic(; label="h1") * (τ, 1.0, 2.0, _harmonic(; label="h2"))
            traj = mp((0.0, 1.0), 1.0, 0.0; grid=nothing)
            Test.@test traj isa Trajectories.HamiltonianVectorFieldTrajectory
            Test.@test Trajectories.phase_labels(traj) == ["h1", "h2"]
            Test.@test Trajectories.left_limit(traj, :state, 1) ≈ cos(τ) atol = 1e-8
            Test.@test Trajectories.right_limit(traj, :state, 1) ≈ cos(τ) + 1 atol = 1e-8
            Test.@test Trajectories.left_limit(traj, :costate, 1) ≈ -sin(τ) atol = 1e-8
            Test.@test Trajectories.right_limit(traj, :costate, 1) ≈ -sin(τ) + 2 atol = 1e-8
            # costate only
            mpp = _harmonic() * (τ, nothing, 2.0, _harmonic())
            tp = mpp((0.0, 1.0), 1.0, 0.0; grid=nothing)
            Test.@test Trajectories.right_limit(tp, :state, 1) ≈ cos(τ) atol = 1e-8
            Test.@test Trajectories.right_limit(tp, :costate, 1) ≈ -sin(τ) + 2 atol = 1e-8
            Test.@test isempty(Trajectories.phase_labels(tp))   # no label at all
        end

        Test.@testset "controlled flow: bang-bang, no jump of the state" begin
            mp = _bang(1.0; label="u=+1") * (τ, _bang(-1.0; label="u=-1"))
            traj = mp((0.0, 1.0), 0.0; grid=nothing)
            Test.@test traj isa Trajectories.StateFlowTrajectory
            Test.@test Trajectories.phase_labels(traj) == ["u=+1", "u=-1"]
            Test.@test Trajectories.left_limit(traj, :state, 1) ≈ τ atol = 1e-8
            Test.@test Trajectories.right_limit(traj, :state, 1) ≈ τ atol = 1e-8
            # the control at τ is the left limit: the law of the phase that ends there
            Test.@test Trajectories.control(traj)(τ) ≈ 1.0
            Test.@test Trajectories.left_limit(traj, :control, 1) ≈ 1.0
            Test.@test Trajectories.right_limit(traj, :control, 1) ≈ -1.0
            Test.@test Trajectories.control(traj)(τ + 1e-9) ≈ -1.0
        end

        Test.@testset "single-phase trajectories" begin
            traj = _decay(; label="decay")((0.0, 1.0), 1.0)
            Test.@test isempty(Trajectories.switching_times(traj))
            Test.@test Trajectories.phase_labels(traj) == ["decay"]
            Test.@test isempty(Trajectories.phase_labels(_decay()((0.0, 1.0), 1.0)))
            st = _bang(1.0; label="bang")((0.0, 1.0), 0.0)
            Test.@test Trajectories.phase_labels(st) == ["bang"]
        end

        Test.@testset "display: switching times and phase sequence" begin
            _plain(x) = sprint(show, MIME"text/plain"(), x)
            _compact(x) = sprint(show, x)
            Test.@test Trajectories._phase_sequence(["a", "", "c"]) == "a → · → c"
            Test.@test Trajectories._phase_sequence(["a"]) == "a"
            # state flow, labelled phases
            vt = (_decay(; label="a") * (τ, _decay(; label="b")))((0.0, 1.0), 1.0)
            Test.@test occursin("switching times: [0.5]", _plain(vt))
            Test.@test occursin("phases: a → b", _plain(vt))
            Test.@test occursin("switching_times=[0.5]", _compact(vt))
            Test.@test occursin("phases=a → b", _compact(vt))
            # Hamiltonian flow, one unlabelled phase: written ·
            ht = (_harmonic(; label="h") * (τ, _harmonic()))((0.0, 1.0), 1.0, 0.0)
            Test.@test occursin("phases: h → ·", _plain(ht))
            Test.@test occursin("switching times: [0.5]", _plain(ht))
            # controlled flow
            ct = (_bang(1.0; label="u=+1") * (τ, _bang(-1.0; label="u=-1")))((0.0, 1.0), 0.0)
            Test.@test occursin("phases: u=+1 → u=-1", _plain(ct))
            Test.@test occursin("switching_times=[0.5]", _compact(ct))
            # no label: the switching times only, no phases row
            nt = (_decay() * (τ, _decay()))((0.0, 1.0), 1.0)
            Test.@test occursin("switching times: [0.5]", _plain(nt))
            Test.@test !occursin("phases", _plain(nt))
            Test.@test !occursin("phases", _compact(nt))
            # a labelled single phase: its label, no switching time
            st = _decay(; label="decay")((0.0, 1.0), 1.0)
            Test.@test occursin("phases: decay", _plain(st))
            Test.@test !occursin("switching", _plain(st))
            # an unlabelled single phase: nothing
            s0 = _plain(_decay()((0.0, 1.0), 1.0))
            Test.@test !occursin("switching", s0)
            Test.@test !occursin("phases", s0)
        end

        # ====================================================================
        # UNIT TESTS - switching structure of the Solution of OCP flows
        # ====================================================================

        Test.@testset "Solution: costate jump and change of law" begin
            x0, p0, Δp = 1.0, 0.5, 0.4
            mp = _plus(; label="u = p") * (τ, nothing, Δp, _minus(; label="u = -p"))
            sol = mp((0.0, 1.0), x0, p0; grid=nothing)
            Test.@test sol isa CTModels.Solution
            Test.@test CTModels.switching_times(sol) == [τ]
            Test.@test CTModels.phase_labels(sol) == ["u = p", "u = -p"]
            pl = p0 * exp(τ)
            Test.@test CTModels.left_limit(sol, :costate, 1) ≈ pl atol = 1e-8
            Test.@test CTModels.right_limit(sol, :costate, 1) ≈ pl + Δp atol = 1e-8
            Test.@test CTModels.left_limit(sol, :control, 1) ≈ pl atol = 1e-8        # u = p
            Test.@test CTModels.right_limit(sol, :control, 1) ≈ -(pl + Δp) atol = 1e-8 # u = -p
            Test.@test CTModels.left_limit(sol, :state, 1) ≈
                CTModels.right_limit(sol, :state, 1) atol = 1e-10
            Test.@test CTModels.control(sol)(τ) ≈ pl atol = 1e-8                     # left
            Test.@test count(==(τ), CTModels.time_grid(sol)) == 1
            s = sprint(show, MIME"text/plain"(), sol)
            Test.@test occursin("Switching times : [0.5]", s)
            Test.@test occursin("Phases : u = p → u = -p", s)
        end

        Test.@testset "Solution: unlabelled phases, labelled single phase" begin
            sol = (_plus() * (τ, _plus()))((0.0, 1.0), 1.0, 0.5)
            Test.@test CTModels.switching_times(sol) == [τ]
            Test.@test CTModels.phase_labels(sol) == ["", ""]
            one = _plus(; label="u = p")((0.0, 1.0), 1.0, 0.5)
            Test.@test isempty(CTModels.switching_times(one))
            Test.@test CTModels.phase_labels(one) == ["u = p"]
            plain = _plus()((0.0, 1.0), 1.0, 0.5)
            Test.@test CTModels.Solutions.switching_model(plain) isa
                CTModels.Solutions.EmptySwitchingModel
        end

        Test.@testset "output grids hold each switching time once" begin
            mp = _plus() * (τ, nothing, 0.4, _minus())
            for kw in ((; grid=21), (; grid=nothing), (;))
                sol = mp((0.0, 1.0), 1.0, 0.5; kw...)
                T = CTModels.time_grid(sol)
                Test.@test count(==(τ), T) == 1
                Test.@test issorted(T; lt=(<=))
            end
            Test.@test length(CTModels.time_grid(mp((0.0, 1.0), 1.0, 0.5; grid=21))) == 21
            # a grid of times is returned exactly; the limits are still known
            sol = mp([0.0, 0.25, 0.75, 1.0], 1.0, 0.5)
            Test.@test CTModels.time_grid(sol) == [0.0, 0.25, 0.75, 1.0]
            Test.@test CTModels.switching_times(sol) == [τ]
            Test.@test CTModels.right_limit(sol, :costate, 1) ≈ 0.5 * exp(τ) + 0.4 atol = 1e-8
        end

        # ====================================================================
        # UNIT TESTS - plot data (backend-free)
        # ====================================================================

        Test.@testset "plot: vertical jumps in the panels" begin
            mp = _harmonic(; label="h1") * (τ, 1.0, 2.0, _harmonic(; label="h2"))
            fig = TrajectoryPlots.build_figure(mp((0.0, 1.0), 1.0, 0.0))
            for (title, left, right) in
                (("state", cos(τ), cos(τ) + 1), ("costate", -sin(τ), -sin(τ) + 2))
                s = _cell(fig, title).axes.series[1]
                k = findfirst(==(τ), s.x)
                Test.@test s.x[k + 1] == τ
                Test.@test s.y[k] ≈ left atol = 1e-8
                Test.@test s.y[k + 1] ≈ right atol = 1e-8
            end
            st = (_bang(1.0) * (τ, _bang(-1.0)))((0.0, 1.0), 0.0)
            figc = TrajectoryPlots.build_figure(st; control=:all)
            ctrl = [l for l in _leaves(figc) if !isempty(l.axes.series)][end]   # the norm
            s = ctrl.axes.series[1]
            k = findfirst(==(τ), s.x)
            Test.@test (s.y[k], s.y[k + 1]) == (1.0, 1.0)
            u = _cell(figc, "control").axes.series[1]
            k = findfirst(==(τ), u.x)
            Test.@test (u.y[k], u.y[k + 1]) == (1.0, -1.0)
        end

        Test.@testset "plot: jumps=:none breaks the curves" begin
            x0, p0 = 1.0, 0.0
            ht = (_harmonic() * (τ, 1.0, 0.5, _harmonic()))((0.0, 1.0), x0, p0)
            fig = TrajectoryPlots.build_figure(ht; jumps=:none)
            ys = [s.y for l in _leaves(fig) for s in l.axes.series]
            Test.@test all(y -> count(isnan, y) == 1, ys)
            ct = (_bang(1.0) * (τ, _bang(-1.0)))((0.0, 1.0), 0.0)
            u = _cell(TrajectoryPlots.build_figure(ct; jumps=:none), "control").axes.series[1]
            k = findfirst(==(τ), u.x)
            Test.@test u.x[k:(k + 2)] == [τ, τ, τ]
            Test.@test isnan(u.y[k + 1])
            Test.@test (u.y[k], u.y[k + 2]) == (1.0, -1.0)
            # default: the vertical segment
            v = _cell(TrajectoryPlots.build_figure(ct), "control").axes.series[1]
            Test.@test !any(isnan, v.y)
            Test.@test_throws Exceptions.IncorrectArgument TrajectoryPlots.build_figure(
                ct; jumps=:dotted
            )
        end

        Test.@testset "plot: switching lines and phase labels" begin
            mp = _bang(1.0; label="u=+1") * (τ, _bang(-1.0; label="u=-1"))
            st = mp((0.0, 1.0), 0.0)
            fig = TrajectoryPlots.build_figure(st)
            Test.@test _vlines(_cell(fig, "state")) == [τ]
            Test.@test _vlines(_cell(fig, "control")) == [τ]
            texts = filter(d -> d isa Plotting.Annotation, _cell(fig, "control").axes.decorations)
            Test.@test [a.text for a in texts] == ["u=+1", "u=-1"]
            Test.@test [a.x for a in texts] ≈ [0.25, 0.75]
            Test.@test length(_texts(fig)) == 2
            # default style: dashed black lines; user style merged on top
            v = only(d for d in _cell(fig, "state").axes.decorations if d isa Plotting.VLine)
            Test.@test v.style.linestyle === :dash
            fig2 = TrajectoryPlots.build_figure(st; switching_style=(color=:red,))
            v2 = only(d for d in _cell(fig2, "state").axes.decorations if d isa Plotting.VLine)
            Test.@test v2.style.color === :red && v2.style.linestyle === :dash
            # :none, :all, style, normalised time
            Test.@test isempty(_vlines(_cell(
                TrajectoryPlots.build_figure(st; switching_style=:none), "state"
            )))
            Test.@test length(_texts(TrajectoryPlots.build_figure(st; phase_labels=:all))) == 4
            Test.@test isempty(_texts(TrajectoryPlots.build_figure(st; phase_labels=:none)))
            a = first(_texts(TrajectoryPlots.build_figure(st; phase_labels_style=(color=:red,))))
            Test.@test a.style.color === :red
            fign = TrajectoryPlots.build_figure(st; time=:normalize)
            Test.@test _vlines(_cell(fign, "state")) == [0.5]
            # fallback: no control drawn → the first panel
            figs = TrajectoryPlots.build_figure(st, :state)
            Test.@test length(_texts(figs)) == 2
            # the keywords reach build_figure, not the backend
            build, render = TrajectoryPlots.split_plot_kwargs((
                switching_style=:none, phase_labels=:all, phase_labels_style=(;), color=:red
            ))
            Test.@test keys(build) == (:switching_style, :phase_labels, :phase_labels_style)
            Test.@test keys(render) == (:color,)
        end

        Test.@testset "plot: a single-phase trajectory is unchanged" begin
            traj = _decay()((0.0, 1.0), 1.0)
            fig = TrajectoryPlots.build_figure(traj)
            Test.@test only(_leaves(fig)).axes.series[1].x == Integrators.times(traj)
            Test.@test isempty(_vlines(only(_leaves(fig))))
            Test.@test isempty(_texts(fig))
        end

        # ====================================================================
        # ERROR TESTS
        # ====================================================================

        Test.@testset "errors" begin
            traj = (_decay() * (τ, _decay()))((0.0, 1.0), 1.0)
            Test.@test_throws Exceptions.IncorrectArgument Trajectories.right_limit(
                traj, :state, 2
            )
            Test.@test_throws Exceptions.IncorrectArgument Trajectories.left_limit(
                traj, :state, 0
            )
            Test.@test_throws Exceptions.IncorrectArgument Trajectories.right_limit(
                traj, :costate, 1
            )
            single = _decay()((0.0, 1.0), 1.0)
            Test.@test_throws Exceptions.IncorrectArgument Trajectories.right_limit(
                single, :state, 1
            )
            ham = (_harmonic() * (τ, _harmonic()))((0.0, 1.0), 1.0, 0.0)
            Test.@test_throws Exceptions.IncorrectArgument Trajectories.right_limit(
                ham, :control, 1
            )
            st = (_bang(1.0) * (τ, _bang(-1.0)))((0.0, 1.0), 0.0)
            Test.@test_throws Exceptions.IncorrectArgument Trajectories.left_limit(
                st, :costate, 1
            )
            # a flow type that holds no label cannot be given one
            Test.@test_throws Exceptions.PreconditionError Flows.with_label(FakeFlow(), "x")
            Test.@test Flows.with_label(FakeFlow(), "") isa FakeFlow
            # invalid phase_labels
            Test.@test_throws Exceptions.IncorrectArgument TrajectoryPlots.build_figure(
                st; phase_labels=:everywhere
            )
            # one label per phase
            Test.@test_throws Exceptions.IncorrectArgument Trajectories.with_labels(
                traj, ["a"]
            )
            Test.@test_throws Exceptions.IncorrectArgument Trajectories.with_labels(
                ham, ["a", "b", "c"]
            )
            Test.@test isempty(Trajectories.phase_labels(Trajectories.with_labels(traj, [""])))
        end

        # ====================================================================
        # UNIT TESTS - helpers
        # ====================================================================

        Test.@testset "helpers" begin
            # with_label keeps the concrete type of the flow
            f = _decay()
            Test.@test typeof(Flows.with_label(f, "a")) === typeof(f)
            # limits stacked as rows: scalars and vectors
            Test.@test Flows._limit_rows([1.0, 2.0]) == reshape([1.0, 2.0], 2, 1)
            Test.@test Flows._limit_rows([[1.0, 2.0], [3.0, 4.0]]) == [1.0 2.0; 3.0 4.0]
            Test.@test Flows._limit_rows([1, 2]) isa Matrix{Float64}
            Test.@test size(Flows._limit_rows(Float64[])) == (0, 0)
            # panels receiving the phase labels
            Test.@test TrajectoryPlots._phase_label_panels(:all, 3, true) == [true, true, true]
            Test.@test TrajectoryPlots._phase_label_panels(:none, 2, true) == [false, false]
            Test.@test TrajectoryPlots._phase_label_panels(:control, 3, true) ==
                [false, false, true]
            Test.@test TrajectoryPlots._phase_label_panels(:control, 2, false) == [true, false]
            # the limits of a trajectory as the matrices of Plotting.splice_jumps
            ham = (_harmonic() * (τ, 1.0, 0.5, _harmonic()))((0.0, 1.0), 1.0, 0.0)
            left, right = TrajectoryPlots._limits(ham, :costate)
            Test.@test size(left) == (1, 1)
            Test.@test right[1, 1] - left[1, 1] ≈ 0.5 atol = 1e-10
        end

        # ====================================================================
        # TYPE STABILITY
        # ====================================================================

        Test.@testset "type stability" begin
            traj = (_decay(; label="a") * (τ, 1.0, _decay()))((0.0, 1.0), 1.0)
            Test.@test_nowarn Test.@inferred Trajectories.switching_times(traj)
            Test.@test_nowarn Test.@inferred Trajectories.phase_labels(traj)
            Test.@test_nowarn Test.@inferred Flows.label(_decay(; label="a"))
        end
    end
end

end # module

test_switching_structure() = TestSwitchingStructure.test_switching_structure()
