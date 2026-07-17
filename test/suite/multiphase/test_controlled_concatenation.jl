"""
Integration tests for the concatenation (`*`) of controlled (state) flows: a multi-phase
`ControlledFlow` must return the SAME type a single-phase controlled flow returns — a
`StateFlowTrajectory` with a PIECEWISE control reconstructed from the per-phase laws
(and, for OCP-built phases, the objective recomputed over the merged trajectory).
"""

module TestControlledConcatenation

using Test: Test
import CTBase.Data: Data
import CTBase.Exceptions: Exceptions
import CTModels: CTModels
import CTFlows.Flows: Flows
import CTFlows.Trajectories: Trajectories
import CTFlows.MultiPhase: MultiPhase
using OrdinaryDiffEqTsit5: Tsit5

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

_opts() = (; alg=Tsit5(), reltol=1e-12, abstol=1e-12)

# ẋ = -x + u, ℓ = 0.5u², :min  (autonomous, fixed, 1-D — scalar convention)
function _build_ocp()
    pre = CTModels.Building.PreModel()
    CTModels.Building.time_dependence!(pre; autonomous=true)
    CTModels.Building.time!(pre; t0=0.0, tf=1.0)
    CTModels.Building.state!(pre, 1)
    CTModels.Building.control!(pre, 1)
    CTModels.Building.dynamics!(pre, (r, t, x, u, v) -> (r[1]=(-x + u); nothing))
    CTModels.Building.objective!(pre, :min; lagrange=(t, x, u, v) -> 0.5 * u^2)
    return CTModels.Building.build(pre)
end

const OCP = _build_ocp()

function test_controlled_concatenation()
    Test.@testset "Controlled flow concatenation" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ── ClosedLoop, two phases from the same OCP ─────────────────────────
        # Phase 1 [0,0.5]: u = -x ⇒ ẋ = -2x ⇒ x = x0 e^{-2t}
        # Phase 2 [0.5,1]: u =  0 ⇒ ẋ = -x  ⇒ x = x(0.5) e^{-(t-0.5)}

        Test.@testset "ClosedLoop OCP: piecewise control + objective" begin
            f1 = Flows.Flow(OCP, Data.ClosedLoop(x -> -x); _opts()...)
            f2 = Flows.Flow(OCP, Data.ClosedLoop(x -> 0.0); _opts()...)
            Test.@test f1 isa Flows.ControlledFlow
            φ = f1 * (0.5, f2)

            x0 = 1.0
            x_half = x0 * exp(-2 * 0.5)

            # point-eval: no costate, returns the final state (exact — no interpolation)
            xf = φ(0.0, x0, 1.0)
            Test.@test xf isa Number
            Test.@test xf ≈ x_half * exp(-(1.0 - 0.5)) atol = 1e-8

            # trajectory: same type as a single-phase controlled flow
            sol = φ((0.0, 1.0), x0)
            Test.@test sol isa Trajectories.StateFlowTrajectory
            x = Trajectories.state(sol)
            u = Trajectories.control(sol)

            # state continuity across the switch (merged trajectory interpolates linearly —
            # the SciML merge builds a `dense=false` solution — hence a loose tolerance)
            Test.@test x(0.25) ≈ x0 * exp(-2 * 0.25) atol = 1e-3
            Test.@test x(0.75) ≈ x_half * exp(-(0.75 - 0.5)) atol = 1e-3

            # piecewise control: phase 1 has u = -x, phase 2 has u ≡ 0
            Test.@test u(0.25) ≈ -x0 * exp(-2 * 0.25) atol = 1e-3
            Test.@test abs(u(0.75)) < 1e-8

            # objective = ∫_0^0.5 0.5 u² dt with u = -x = x0 e^{-2t} (phase 2 contributes 0)
            #           = 0.5 x0² (1 - e^{-2}) / 4
            Test.@test Trajectories.objective(sol) ≈ 0.5 * x0^2 * (1 - exp(-2)) / 4 atol =
                1e-3
        end

        # ── OpenLoop, two phases (piecewise-constant control) ────────────────
        # Phase 1 [0,0.5]: u = 1 ⇒ ẋ = -x + 1
        # Phase 2 [0.5,1]: u = 2 ⇒ ẋ = -x + 2

        Test.@testset "OpenLoop OCP: piecewise-constant control" begin
            f1 = Flows.Flow(OCP, Data.OpenLoop(() -> 1.0); _opts()...)
            f2 = Flows.Flow(OCP, Data.OpenLoop(() -> 2.0); _opts()...)
            φ = f1 * (0.5, f2)
            sol = φ((0.0, 1.0), 0.0)
            Test.@test sol isa Trajectories.StateFlowTrajectory
            u = Trajectories.control(sol)
            Test.@test u(0.25) ≈ 1.0 atol = 1e-8
            Test.@test u(0.75) ≈ 2.0 atol = 1e-8
        end

        # ── state jump between phases (additive on the state) ────────────────
        # A scalar jump keeps the 1-D scalar convention through the point path.

        Test.@testset "ClosedLoop with a state jump" begin
            f1 = Flows.Flow(OCP, Data.ClosedLoop(x -> -x); _opts()...)
            f2 = Flows.Flow(OCP, Data.ClosedLoop(x -> -x); _opts()...)
            x0 = 1.0
            Δ = 0.3
            # point-eval reference with the additive jump applied by hand
            x_half = x0 * exp(-2 * 0.5)
            xf_ref = (x_half + Δ) * exp(-2 * (1.0 - 0.5))
            φ = f1 * (0.5, Δ, f2)
            Test.@test φ(0.0, x0, 1.0) ≈ xf_ref atol = 1e-6
            sol = φ((0.0, 1.0), x0)
            Test.@test sol isa Trajectories.StateFlowTrajectory
        end

        # ── Flow(fc, law) phases: no OCP ⇒ no objective (2-D, vector-safe) ────

        Test.@testset "Flow(fc, law) concatenation: no objective" begin
            fc = Data.ControlledVectorField((x, u) -> -x .+ u)
            f1 = Flows.Flow(fc, Data.ClosedLoop(x -> -x); _opts()...)
            f2 = Flows.Flow(fc, Data.ClosedLoop(x -> zero(x)); _opts()...)
            φ = f1 * (0.5, f2)
            sol = φ((0.0, 1.0), [1.0, 2.0])
            Test.@test sol isa Trajectories.StateFlowTrajectory
            # no OCP ⇒ objective getter errors clearly
            Test.@test_throws Exceptions.PreconditionError Trajectories.objective(sol)
        end

        # ── different OCP objects ⇒ reconstruction rejects ───────────────────

        Test.@testset "Error: phases from different OCPs" begin
            ocp2 = _build_ocp()   # structurally identical, distinct object
            f1 = Flows.Flow(OCP, Data.ClosedLoop(x -> -x); _opts()...)
            f2 = Flows.Flow(ocp2, Data.ClosedLoop(x -> 0.0); _opts()...)
            φ = f1 * (0.5, f2)
            Test.@test_throws Exceptions.IncorrectArgument φ((0.0, 1.0), 1.0)
        end
    end
end

end # module

function test_controlled_concatenation()
    return TestControlledConcatenation.test_controlled_concatenation()
end
