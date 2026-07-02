module TestConcatenation

import Test
import CTBase.Exceptions
import CTFlows.MultiPhase
import CTFlows.Systems
import CTFlows.Integrators
import CTFlows.Flows
import CTBase.Traits
import CTBase.Strategies
import CTBase.Options

const VERBOSE    = isdefined(Main, :TestData) ? Main.TestData.VERBOSE    : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

# ==============================================================================
# Fake types — module top-level (testing-creation.md §1)
# ==============================================================================

struct FakeStateSystem <: Systems.AbstractStateSystem{Traits.Autonomous, Traits.Fixed}
    tag::Symbol
end

Systems.get_ip_rhs(::FakeStateSystem, _) = (du, u, p, t) -> (du .= u)

struct FakeHamiltonianSystem <: Systems.AbstractHamiltonianSystem{Traits.Autonomous, Traits.Fixed}
    tag::Symbol
end

Systems.get_ip_rhs(::FakeHamiltonianSystem, _) = (dz, z, p, t) -> (dz .= z)

struct FakeIntegrator <: Integrators.AbstractIntegrator end

Strategies.id(::Type{FakeIntegrator})       = :fake
Strategies.metadata(::Type{FakeIntegrator}) = Strategies.StrategyMetadata()
Strategies.options(::FakeIntegrator)        = Options.StrategyOptions()

# ==============================================================================
# Helpers
# ==============================================================================

_state_flow(tag=:s) = Flows.StateFlow(FakeStateSystem(tag), FakeIntegrator())
_ham_flow(tag=:h)   = Flows.HamiltonianFlow(FakeHamiltonianSystem(tag), FakeIntegrator())

# Build a MultiPhaseStateFlow with n phases (switching times 1.0, 2.0, …)
function _mpstate(n)
    f = _state_flow(Symbol(:s, 1))
    for i in 2:n
        f = f * (Float64(i - 1), _state_flow(Symbol(:s, i)))
    end
    return f
end

# Build a MultiPhaseHamiltonianFlow with n phases
function _mpham(n)
    f = _ham_flow(Symbol(:h, 1))
    for i in 2:n
        f = f * (Float64(i - 1), _ham_flow(Symbol(:h, i)))
    end
    return f
end

# ==============================================================================
# Test function
# ==============================================================================

function test_concatenation()
    Test.@testset "Concatenation Tests" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ======================================================================
        # 1. Helpers on AbstractFlow (single-phase dispatch)
        # ======================================================================
        Test.@testset "Helpers — single-phase (AbstractFlow)" begin
            sf = _state_flow()
            hf = _ham_flow()

            Test.@testset "get_flows" begin
                Test.@test MultiPhase.get_flows(sf) == (sf,)
                Test.@test length(MultiPhase.get_flows(sf)) == 1
                Test.@test MultiPhase.get_flows(hf) == (hf,)
                Test.@test length(MultiPhase.get_flows(hf)) == 1
                # type stability
                Test.@inferred MultiPhase.get_flows(sf)
                Test.@inferred MultiPhase.get_flows(hf)
            end

            Test.@testset "get_switching_times" begin
                Test.@test MultiPhase.get_switching_times(sf) == Real[]
                Test.@test isempty(MultiPhase.get_switching_times(sf))
                Test.@test MultiPhase.get_switching_times(hf) == Real[]
                Test.@inferred MultiPhase.get_switching_times(sf)
                Test.@inferred MultiPhase.get_switching_times(hf)
            end

            Test.@testset "get_jumps" begin
                Test.@test MultiPhase.get_jumps(sf) == Any[]
                Test.@test isempty(MultiPhase.get_jumps(sf))
                Test.@test MultiPhase.get_jumps(hf) == Any[]
                Test.@inferred MultiPhase.get_jumps(sf)
                Test.@inferred MultiPhase.get_jumps(hf)
            end
        end

        # ======================================================================
        # 2. Helpers on AnyMultiPhaseFlow (multi-phase dispatch)
        # ======================================================================
        Test.@testset "Helpers — multi-phase (AnyMultiPhaseFlow)" begin
            mpstate = _mpstate(3)   # 3 phases, switches [1.0, 2.0], jumps [nothing, nothing]
            mpham   = _mpham(3)

            Test.@testset "get_flows" begin
                Test.@test length(MultiPhase.get_flows(mpstate)) == 3
                Test.@test MultiPhase.get_flows(mpstate) === mpstate.flows
                Test.@test length(MultiPhase.get_flows(mpham)) == 3
                Test.@test MultiPhase.get_flows(mpham) === mpham.flows
                Test.@inferred MultiPhase.get_flows(mpstate)
                Test.@inferred MultiPhase.get_flows(mpham)
            end

            Test.@testset "get_switching_times" begin
                Test.@test MultiPhase.get_switching_times(mpstate) == [1.0, 2.0]
                Test.@test MultiPhase.get_switching_times(mpstate) === mpstate.switching_times
                Test.@inferred MultiPhase.get_switching_times(mpstate)
            end

            Test.@testset "get_jumps" begin
                Test.@test MultiPhase.get_jumps(mpstate) == [nothing, nothing]
                Test.@test MultiPhase.get_jumps(mpstate) === mpstate.jumps
                Test.@inferred MultiPhase.get_jumps(mpstate)
            end
        end

        # ======================================================================
        # 3. StateFlow concatenation — all combinations
        # ======================================================================
        Test.@testset "StateFlow concatenation" begin
            jump = x -> 2 .* x

            # ------------------------------------------------------------------
            # 3a. 1 × 1
            # ------------------------------------------------------------------
            Test.@testset "1 × 1 — no jump" begin
                f1, f2 = _state_flow(:a), _state_flow(:b)
                mpf = f1 * (0.5, f2)
                Test.@test mpf isa MultiPhase.MultiPhaseStateFlow
                Test.@test length(mpf.flows)          == 2
                Test.@test mpf.switching_times        == [0.5]
                Test.@test mpf.jumps                  == [nothing]
                Test.@inferred f1 * (0.5, f2)
            end

            Test.@testset "1 × 1 — with jump" begin
                f1, f2 = _state_flow(:a), _state_flow(:b)
                mpf = f1 * (0.5, jump, f2)
                Test.@test mpf isa MultiPhase.MultiPhaseStateFlow
                Test.@test length(mpf.flows)          == 2
                Test.@test mpf.switching_times        == [0.5]
                Test.@test mpf.jumps                  == [jump]
                Test.@inferred f1 * (0.5, jump, f2)
            end

            # ------------------------------------------------------------------
            # 3b. n × 1  (regression: existing MultiPhase × SinglePhase)
            # ------------------------------------------------------------------
            Test.@testset "n × 1 — no jump" begin
                mpf1 = _mpstate(2)   # phases: [s1, s2], switches: [1.0], jumps: [nothing]
                f3   = _state_flow(:s3)
                mpf  = mpf1 * (2.0, f3)
                Test.@test mpf isa MultiPhase.MultiPhaseStateFlow
                Test.@test length(mpf.flows)          == 3
                Test.@test mpf.switching_times        == [1.0, 2.0]
                Test.@test mpf.jumps                  == [nothing, nothing]
            end

            Test.@testset "n × 1 — with jump" begin
                mpf1 = _mpstate(2)
                f3   = _state_flow(:s3)
                mpf  = mpf1 * (2.0, jump, f3)
                Test.@test length(mpf.flows)          == 3
                Test.@test mpf.switching_times        == [1.0, 2.0]
                Test.@test mpf.jumps[1]               === nothing
                Test.@test mpf.jumps[2]               === jump
            end

            # ------------------------------------------------------------------
            # 3c. 1 × n  (new case)
            # ------------------------------------------------------------------
            Test.@testset "1 × n — no jump" begin
                f1   = _state_flow(:s0)
                mpf2 = _mpstate(2)   # phases: [s1, s2], switches: [1.0], jumps: [nothing]
                mpf  = f1 * (0.5, mpf2)
                Test.@test mpf isa MultiPhase.MultiPhaseStateFlow
                Test.@test length(mpf.flows)          == 3
                Test.@test mpf.switching_times        == [0.5, 1.0]
                Test.@test mpf.jumps                  == [nothing, nothing]
            end

            Test.@testset "1 × n — with jump" begin
                f1   = _state_flow(:s0)
                mpf2 = _mpstate(2)
                mpf  = f1 * (0.5, jump, mpf2)
                Test.@test length(mpf.flows)          == 3
                Test.@test mpf.switching_times        == [0.5, 1.0]
                Test.@test mpf.jumps[1]               === jump
                Test.@test mpf.jumps[2]               === nothing
            end

            # ------------------------------------------------------------------
            # 3d. n × m  (new case)
            # ------------------------------------------------------------------
            Test.@testset "n × m — no jump" begin
                f1 = _state_flow(:s1)
                f2 = _state_flow(:s2)
                f3 = _state_flow(:s3)
                f4 = _state_flow(:s4)
                f5 = _state_flow(:s5)
                mpf1 = f1 * (1.0, f2) * (2.0, f3)  # switches: [1.0, 2.0]
                mpf2 = f4 * (5.0, f5)  # switches: [5.0]
                mpf  = mpf1 * (3.0, mpf2)  # switches: [1.0, 2.0, 3.0, 5.0]
                Test.@test mpf isa MultiPhase.MultiPhaseStateFlow
                Test.@test length(mpf.flows)          == 5
                Test.@test mpf.switching_times        == [1.0, 2.0, 3.0, 5.0]
                Test.@test all(==(nothing), mpf.jumps)
                Test.@test length(mpf.jumps)          == 4
            end

            Test.@testset "n × m — with jump" begin
                f1 = _state_flow(:s1)
                f2 = _state_flow(:s2)
                f3 = _state_flow(:s3)
                f4 = _state_flow(:s4)
                f5 = _state_flow(:s5)
                mpf1 = f1 * (1.0, f2) * (2.0, f3)  # switches: [1.0, 2.0], jumps: [nothing, nothing]
                mpf2 = f4 * (5.0, f5)  # switches: [5.0], jumps: [nothing]
                mpf  = mpf1 * (3.0, jump, mpf2)  # switches: [1.0, 2.0, 3.0, 5.0], jumps: [nothing, nothing, jump, nothing]
                Test.@test length(mpf.flows)          == 5
                Test.@test mpf.switching_times        == [1.0, 2.0, 3.0, 5.0]
                Test.@test mpf.jumps[1]               === nothing   # from mpf1
                Test.@test mpf.jumps[2]               === nothing   # from mpf1
                Test.@test mpf.jumps[3]               === jump     # new junction
                Test.@test mpf.jumps[4]               === nothing   # from mpf2
            end

            # ------------------------------------------------------------------
            # 3e. Merge invariant: explicit formula check
            # ------------------------------------------------------------------
            Test.@testset "Merge invariant" begin
                f1   = _state_flow(:a)
                mpf2 = _mpstate(2)   # switches: [1.0], jumps: [nothing]
                t_s  = 0.5
                mpf  = f1 * (t_s, mpf2)

                expected_flows   = [MultiPhase.get_flows(f1)...,            MultiPhase.get_flows(mpf2)...]
                expected_times   = [MultiPhase.get_switching_times(f1)...,  t_s, MultiPhase.get_switching_times(mpf2)...]
                expected_jumps   = [MultiPhase.get_jumps(f1)...,            nothing, MultiPhase.get_jumps(mpf2)...]

                Test.@test length(mpf.flows)          == length(expected_flows)
                Test.@test mpf.switching_times        == expected_times
                Test.@test mpf.jumps                  == expected_jumps
            end
        end

        # ======================================================================
        # 4. HamiltonianFlow concatenation — all combinations
        # ======================================================================
        Test.@testset "HamiltonianFlow concatenation" begin
            jump    = z -> 2 .* z
            jump_x  = x -> x .+ 1
            jump_p  = p -> p .* 2

            # ------------------------------------------------------------------
            # 4a. 1 × 1
            # ------------------------------------------------------------------
            Test.@testset "1 × 1 — no jump" begin
                f1, f2 = _ham_flow(:a), _ham_flow(:b)
                mpf = f1 * (0.5, f2)
                Test.@test mpf isa MultiPhase.MultiPhaseHamiltonianFlow
                Test.@test length(mpf.flows)          == 2
                Test.@test mpf.switching_times        == [0.5]
                Test.@test mpf.jumps                  == [nothing]
                Test.@inferred f1 * (0.5, f2)
            end

            Test.@testset "1 × 1 — with jump" begin
                f1, f2 = _ham_flow(:a), _ham_flow(:b)
                mpf = f1 * (0.5, jump, f2)
                Test.@test mpf isa MultiPhase.MultiPhaseHamiltonianFlow
                Test.@test mpf.jumps                  == [jump]
                Test.@inferred f1 * (0.5, jump, f2)
            end

            Test.@testset "1 × 1 — with (jump_x, jump_p)" begin
                f1, f2 = _ham_flow(:a), _ham_flow(:b)
                mpf = f1 * (0.5, jump_x, jump_p, f2)
                Test.@test mpf isa MultiPhase.MultiPhaseHamiltonianFlow
                Test.@test length(mpf.flows)          == 2
                Test.@test mpf.switching_times        == [0.5]
                Test.@test mpf.jumps                  == [(jump_x, jump_p)]
                j = mpf.jumps[1]
                Test.@test j isa Tuple
                Test.@test j[1] === jump_x
                Test.@test j[2] === jump_p
                Test.@inferred f1 * (0.5, jump_x, jump_p, f2)
            end

            # ------------------------------------------------------------------
            # 4b. n × 1
            # ------------------------------------------------------------------
            Test.@testset "n × 1 — no jump" begin
                mpf1 = _mpham(2)
                f3   = _ham_flow(:h3)
                mpf  = mpf1 * (2.0, f3)
                Test.@test length(mpf.flows)          == 3
                Test.@test mpf.switching_times        == [1.0, 2.0]
                Test.@test mpf.jumps                  == [nothing, nothing]
            end

            Test.@testset "n × 1 — with jump" begin
                mpf1 = _mpham(2)
                f3   = _ham_flow(:h3)
                mpf  = mpf1 * (2.0, jump, f3)
                Test.@test length(mpf.flows)          == 3
                Test.@test mpf.jumps[1]               === nothing
                Test.@test mpf.jumps[2]               === jump
            end

            # ------------------------------------------------------------------
            # 4c. 1 × n
            # ------------------------------------------------------------------
            Test.@testset "1 × n — no jump" begin
                f1   = _ham_flow(:h0)
                mpf2 = _mpham(2)
                mpf  = f1 * (0.5, mpf2)
                Test.@test mpf isa MultiPhase.MultiPhaseHamiltonianFlow
                Test.@test length(mpf.flows)          == 3
                Test.@test mpf.switching_times        == [0.5, 1.0]
                Test.@test mpf.jumps                  == [nothing, nothing]
            end

            Test.@testset "1 × n — with jump" begin
                f1   = _ham_flow(:h0)
                mpf2 = _mpham(2)
                mpf  = f1 * (0.5, jump, mpf2)
                Test.@test length(mpf.flows)          == 3
                Test.@test mpf.jumps[1]               === jump
                Test.@test mpf.jumps[2]               === nothing
            end

            Test.@testset "1 × n — with (jump_x, jump_p)" begin
                f1   = _ham_flow(:h0)
                mpf2 = _mpham(2)
                mpf  = f1 * (0.5, jump_x, jump_p, mpf2)
                Test.@test length(mpf.flows)          == 3
                Test.@test mpf.jumps[1]               == (jump_x, jump_p)
                Test.@test mpf.jumps[2]               === nothing
            end

            # ------------------------------------------------------------------
            # 4d. n × m
            # ------------------------------------------------------------------
            Test.@testset "n × m — no jump" begin
                f1 = _ham_flow(:h1)
                f2 = _ham_flow(:h2)
                f3 = _ham_flow(:h3)
                f4 = _ham_flow(:h4)
                f5 = _ham_flow(:h5)
                mpf1 = f1 * (1.0, f2) * (2.0, f3)  # switches: [1.0, 2.0]
                mpf2 = f4 * (5.0, f5)  # switches: [5.0]
                mpf  = mpf1 * (3.0, mpf2)  # switches: [1.0, 2.0, 3.0, 5.0]
                Test.@test mpf isa MultiPhase.MultiPhaseHamiltonianFlow
                Test.@test length(mpf.flows)          == 5
                Test.@test mpf.switching_times        == [1.0, 2.0, 3.0, 5.0]
                Test.@test all(==(nothing), mpf.jumps)
            end

            Test.@testset "n × m — with jump" begin
                f1 = _ham_flow(:h1)
                f2 = _ham_flow(:h2)
                f3 = _ham_flow(:h3)
                f4 = _ham_flow(:h4)
                f5 = _ham_flow(:h5)
                mpf1 = f1 * (1.0, f2) * (2.0, f3)  # switches: [1.0, 2.0], jumps: [nothing, nothing]
                mpf2 = f4 * (5.0, f5)  # switches: [5.0], jumps: [nothing]
                mpf  = mpf1 * (3.0, jump, mpf2)  # switches: [1.0, 2.0, 3.0, 5.0], jumps: [nothing, nothing, jump, nothing]
                Test.@test length(mpf.flows)          == 5
                Test.@test mpf.jumps[1]               === nothing
                Test.@test mpf.jumps[2]               === nothing
                Test.@test mpf.jumps[3]               === jump
                Test.@test mpf.jumps[4]               === nothing
            end

            Test.@testset "n × m — with (jump_x, jump_p)" begin
                f1 = _ham_flow(:h1)
                f2 = _ham_flow(:h2)
                f3 = _ham_flow(:h3)
                f4 = _ham_flow(:h4)
                f5 = _ham_flow(:h5)
                mpf1 = f1 * (1.0, f2) * (2.0, f3)  # switches: [1.0, 2.0], jumps: [nothing, nothing]
                mpf2 = f4 * (5.0, f5)  # switches: [5.0], jumps: [nothing]
                mpf  = mpf1 * (3.0, jump_x, jump_p, mpf2)  # switches: [1.0, 2.0, 3.0, 5.0], jumps: [nothing, nothing, (jump_x, jump_p), nothing]
                Test.@test mpf.jumps[3]               == (jump_x, jump_p)
            end

            # ------------------------------------------------------------------
            # 4e. Merge invariant
            # ------------------------------------------------------------------
            Test.@testset "Merge invariant" begin
                f1   = _ham_flow(:h0)
                mpf2 = _mpham(2)
                t_s  = 0.5
                mpf  = f1 * (t_s, mpf2)

                expected_flows = [MultiPhase.get_flows(f1)...,           MultiPhase.get_flows(mpf2)...]
                expected_times = [MultiPhase.get_switching_times(f1)..., t_s, MultiPhase.get_switching_times(mpf2)...]
                expected_jumps = [MultiPhase.get_jumps(f1)...,           nothing, MultiPhase.get_jumps(mpf2)...]

                Test.@test length(mpf.flows)    == length(expected_flows)
                Test.@test mpf.switching_times  == expected_times
                Test.@test mpf.jumps            == expected_jumps
            end
        end

        # ======================================================================
        # 5. Long chains (3+ operands via chaining)
        # ======================================================================
        Test.@testset "Long chains" begin
            Test.@testset "StateFlow — 4 phases chained" begin
                f1, f2, f3, f4 = (_state_flow(Symbol(:s, i)) for i in 1:4)
                mpf = f1 * (1.0, f2) * (2.0, f3) * (3.0, f4)
                Test.@test mpf isa MultiPhase.MultiPhaseStateFlow
                Test.@test length(mpf.flows)     == 4
                Test.@test mpf.switching_times   == [1.0, 2.0, 3.0]
                Test.@test length(mpf.jumps)     == 3
            end

            Test.@testset "HamiltonianFlow — 4 phases chained" begin
                f1, f2, f3, f4 = (_ham_flow(Symbol(:h, i)) for i in 1:4)
                mpf = f1 * (1.0, f2) * (2.0, f3) * (3.0, f4)
                Test.@test mpf isa MultiPhase.MultiPhaseHamiltonianFlow
                Test.@test length(mpf.flows)     == 4
                Test.@test mpf.switching_times   == [1.0, 2.0, 3.0]
            end

            Test.@testset "Mixed single/multi — 5 phases" begin
                f1   = _state_flow(:s1)
                f2   = _state_flow(:s2)
                f3   = _state_flow(:s3)
                f4   = _state_flow(:s4)
                f5   = _state_flow(:s5)
                mpf2 = f2 * (2.0, f3)  # switches: [2.0]
                mpf3 = f4 * (5.0, f5)  # switches: [5.0]
                mpf = f1 * (1.0, mpf2) * (3.0, mpf3)  # switches: [1.0, 2.0, 3.0, 5.0]
                Test.@test length(mpf.flows)     == 5
                Test.@test mpf.switching_times   == [1.0, 2.0, 3.0, 5.0]
                Test.@test length(mpf.jumps)     == 4
            end
        end

        # ======================================================================
        # 6. Switching times validation
        # ======================================================================
        Test.@testset "Switching times validation" begin
            Test.@testset "Valid switching times — no error" begin
                f1, f2 = _state_flow(:a), _state_flow(:b)
                mpf = f1 * (1.0, f2)
                Test.@test mpf isa MultiPhase.MultiPhaseStateFlow
            end

            Test.@testset "Invalid switching times — t_switch not greater than f1 times" begin
                mpf1 = _mpstate(2)   # switches: [1.0]
                f3   = _state_flow(:s3)
                Test.@test_throws Exceptions.PreconditionError mpf1 * (0.5, f3)  # 0.5 < 1.0
            end

            Test.@testset "Invalid switching times — t_switch not less than f2 times" begin
                f1   = _state_flow(:s0)
                mpf2 = _mpstate(2)   # switches: [1.0]
                Test.@test_throws Exceptions.PreconditionError f1 * (2.0, mpf2)  # 2.0 > 1.0
            end

            Test.@testset "Invalid switching times — HamiltonianFlow" begin
                mpf1 = _mpham(2)   # switches: [1.0]
                f3   = _ham_flow(:h3)
                Test.@test_throws Exceptions.PreconditionError mpf1 * (0.5, f3)
            end

            Test.@testset "PreconditionError message quality" begin
                mpf1 = _mpstate(2)   # switches: [1.0]
                f3   = _state_flow(:s3)
                try
                    mpf1 * (0.5, f3)
                    Test.@test false  # Should have thrown
                catch e
                    Test.@test e isa Exceptions.PreconditionError
                    Test.@test occursin("strictly increasing", e.msg)
                    Test.@test occursin("flow concatenation", e.context)
                end
            end
        end

        # ======================================================================
        # 7. Exports
        # ======================================================================
        Test.@testset "Exports" begin
            for sym in (:MultiPhaseStateFlow, :MultiPhaseHamiltonianFlow,
                        :n_phases, :get_flow, :get_switching_time, :get_jump,
                        :get_flows, :get_switching_times, :get_jumps)
                Test.@test sym in names(MultiPhase)
            end
        end

    end # top-level testset
end

end # module

test_concatenation() = TestConcatenation.test_concatenation()