"""
Characterization tests for the value a multi-phase trajectory returns AT a switching time
`ts` when a jump is applied there (issue #434).

Convention: the trajectory is left-continuous at a switching time — evaluating at `ts`
returns the end value of the phase that finishes at `ts` (before the jump); any time
strictly after `ts` belongs to the next phase (after the jump). The time grid keeps `ts`
twice (end of one phase, start of the next).
"""

module TestSwitchTimeConvention

using Test: Test
using CTBase: Data
using CTModels: CTModels
using CTFlows: Flows
using CTFlows: Systems
using CTFlows: Integrators
using OrdinaryDiffEqTsit5: Tsit5
using ForwardDiff: ForwardDiff  # triggers the DI ForwardDiff extension (AutoForwardDiff)

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

_opts() = (; alg=Tsit5(), reltol=1e-12, abstol=1e-12)

# scalar helper (values may come back as a Number or a 1-vector)
_val(a) = a isa Number ? a : a[1]

# LQR: ẋ = -x + u, ℓ = 0.5u², :min (1-D). With DynClosedLoop u(x,p) = p the maximized flow
# is p(t) = p0 eᵗ and x(t) = (x0 - p0/2)e⁻ᵗ + (p0/2)eᵗ.
function _build_lqr()
    pre = CTModels.Building.PreModel()
    CTModels.Building.time_dependence!(pre; autonomous=true)
    CTModels.Building.time!(pre; t0=0.0, tf=1.0)
    CTModels.Building.state!(pre, 1)
    CTModels.Building.control!(pre, 1)
    CTModels.Building.dynamics!(pre, (r, t, x, u, v) -> (r[1]=(-x + u); nothing))
    CTModels.Building.objective!(pre, :min; lagrange=(t, x, u, v) -> 0.5 * u^2)
    return CTModels.Building.build(pre)
end

const OCP = _build_lqr()

function test_switch_time_convention()
    Test.@testset "Switch-time convention" verbose=VERBOSE showtiming=SHOWTIMING begin
        ts = 0.5

        Test.@testset "state flow, state jump" begin
            sys = Systems.VectorFieldSystem(Data.VectorField(u -> -u))
            f = Flows.StateFlow(sys, Integrators.SciML(; _opts()...))
            Δx = 10.0
            traj = (f * (ts, Δx, f))((0.0, 1.0), [1.0]; grid=nothing)
            left, right = exp(-ts), exp(-ts) + Δx

            Test.@test count(==(ts), Integrators.times(traj)) == 2
            Test.@test _val(traj(ts)) ≈ left atol = 1e-8
            Test.@test _val(traj(ts + 1e-9)) ≈ right atol = 1e-6
            Test.@test _val(traj(ts - 1e-9)) ≈ left atol = 1e-6
        end

        Test.@testset "OCP flow, costate jump" begin
            g = Flows.Flow(
                OCP, Data.DynClosedLoop((x, p) -> p); hamiltonian_type=:total, _opts()...
            )
            x0, p0, Δp = 1.0, 0.5, 0.4
            sol = (g * (ts, Δp, g))((0.0, 1.0), x0, p0; grid=nothing)
            p, u = CTModels.costate(sol), CTModels.control(sol)
            left = p0 * exp(ts)

            Test.@test count(==(ts), CTModels.time_grid(sol)) == 2
            Test.@test _val(p(ts)) ≈ left atol = 1e-8
            Test.@test _val(u(ts)) ≈ left atol = 1e-8   # u = p, phase-1 law
            Test.@test _val(p(ts + 1e-9)) ≈ left + Δp atol = 1e-6
        end
    end
end

end # module

test_switch_time_convention() = TestSwitchTimeConvention.test_switch_time_convention()
