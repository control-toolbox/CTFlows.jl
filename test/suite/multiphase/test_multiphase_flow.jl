module TestMultiPhaseFlow

import Test
import CTFlows.MultiPhase
import CTFlows.Systems
import CTFlows.Integrators
import CTFlows.Flows
import CTFlows.Common

const VERBOSE = isdefined(Main, :TestOptions) ? Main.TestOptions.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestOptions) ? Main.TestOptions.SHOWTIMING : true

# ==============================================================================
# Fake types for testing
# ==============================================================================

struct FakeStateSystem <: Systems.AbstractStateSystem{Common.Autonomous, Common.Fixed}
    data::Vector{Float64}
end

function Systems.rhs(sys::FakeStateSystem)
    return (du, u, p, t) -> du .= sys.data .* u
end

struct FakeIntegrator <: Integrators.AbstractIntegrator
    result::Any
end

import CTSolvers.Strategies
import CTSolvers.Options

Strategies.id(::Type{FakeIntegrator}) = :fake_integrator
Strategies.metadata(::Type{FakeIntegrator}) = Strategies.StrategyMetadata()
Strategies.options(integ::FakeIntegrator) = Options.StrategyOptions()

# ==============================================================================
# Test function
# ==============================================================================

function test_multiphase_flow()
    Test.@testset "MultiPhaseFlow Tests" verbose=VERBOSE showtiming=SHOWTIMING begin

        Test.@testset "MultiPhaseStateFlow" begin
            sys = FakeStateSystem([1.0, 2.0])
            integ = FakeIntegrator(:fake_result)
            flow1 = Flows.StateFlow(sys, integ)
            flow2 = Flows.StateFlow(sys, integ)
            mpsf = MultiPhase.MultiPhaseStateFlow([flow1, flow2], [0.5], [nothing])

            Test.@testset "stores flows" begin
                Test.@test length(mpsf.flows) == 2
                Test.@test mpsf.flows[1] === flow1
                Test.@test mpsf.flows[2] === flow2
            end

            Test.@testset "stores switching times" begin
                Test.@test mpsf.switching_times == [0.5]
            end

            Test.@testset "stores jumps" begin
                Test.@test mpsf.jumps == [nothing]
            end

            Test.@testset "system returns Vector of systems" begin
                sys_result = Flows.system(mpsf)
                Test.@test sys_result isa Vector
                Test.@test eltype(sys_result) <: Systems.AbstractSystem
                Test.@test length(sys_result) == 2
            end

            Test.@testset "Display Methods" begin
                Test.@testset "tree-style display works" begin
                    io = IOBuffer()
                    show(io, MIME("text/plain"), mpsf)
                    output = String(take!(io))
                    Test.@test occursin("MultiPhaseStateFlow", output)
                    Test.@test occursin("phases: 2", output)
                    Test.@test occursin("systems: FakeStateSystem", output)
                    Test.@test occursin("integrators: FakeIntegrator", output)
                    Test.@test occursin("switching_times: [0.5]", output)
                end

                Test.@testset "compact display works" begin
                    io = IOBuffer()
                    show(io, mpsf)
                    output = String(take!(io))
                    Test.@test occursin("MultiPhaseStateFlow(phases=2", output)
                    Test.@test occursin("switching_times=[0.5])", output)
                end
            end

            Test.@testset "Getter Methods" begin
                Test.@testset "n_phases returns number of phases" begin
                    Test.@test MultiPhase.n_phases(mpsf) == 2
                end

                Test.@testset "get_flow returns correct flow" begin
                    Test.@test MultiPhase.get_flow(mpsf, 1) === flow1
                    Test.@test MultiPhase.get_flow(mpsf, 2) === flow2
                end

                Test.@testset "get_switching_time returns correct time" begin
                    Test.@test MultiPhase.get_switching_time(mpsf, 1) == 0.5
                end

                Test.@testset "get_jump returns correct jump" begin
                    Test.@test MultiPhase.get_jump(mpsf, 1) === nothing
                end
            end
        end

        Test.@testset "MultiPhaseHamiltonianFlow" begin
            # TODO: Add HamiltonianSystem fake when implemented
            Test.@testset "type exists" begin
                Test.@test isdefined(MultiPhase, :MultiPhaseHamiltonianFlow)
            end
        end

        Test.@testset "Helper Methods — AbstractFlow (single-phase)" begin
            sys = FakeStateSystem([1.0, 2.0])
            integ = FakeIntegrator(:fake_result)
            flow = Flows.StateFlow(sys, integ)

            Test.@testset "get_flows returns single-element vector" begin
                result = MultiPhase.get_flows(flow)
                Test.@test result isa Vector
                Test.@test length(result) == 1
                Test.@test result[1] === flow
                Test.@test Test.@inferred(MultiPhase.get_flows(flow)) isa Vector
            end

            Test.@testset "get_switching_times returns empty Real vector" begin
                result = MultiPhase.get_switching_times(flow)
                Test.@test result isa Vector{Real}
                Test.@test length(result) == 0
                Test.@test Test.@inferred(MultiPhase.get_switching_times(flow)) isa Vector{Real}
            end

            Test.@testset "get_jumps returns empty Any vector" begin
                result = MultiPhase.get_jumps(flow)
                Test.@test result isa Vector{Any}
                Test.@test length(result) == 0
                Test.@test Test.@inferred(MultiPhase.get_jumps(flow)) isa Vector{Any}
            end
        end

        Test.@testset "Helper Methods — AnyMultiPhaseFlow (multi-phase)" begin
            sys = FakeStateSystem([1.0, 2.0])
            integ = FakeIntegrator(:fake_result)
            flow1 = Flows.StateFlow(sys, integ)
            flow2 = Flows.StateFlow(sys, integ)
            mpf = MultiPhase.MultiPhaseStateFlow([flow1, flow2], [0.5], [nothing])

            Test.@testset "get_flows delegates to mpf.flows" begin
                result = MultiPhase.get_flows(mpf)
                Test.@test result === mpf.flows
            end

            Test.@testset "get_switching_times delegates to mpf.switching_times" begin
                result = MultiPhase.get_switching_times(mpf)
                Test.@test result === mpf.switching_times
            end

            Test.@testset "get_jumps delegates to mpf.jumps" begin
                result = MultiPhase.get_jumps(mpf)
                Test.@test result === mpf.jumps
            end
        end

        Test.@testset "Exports" begin
            Test.@testset "helper methods are exported" begin
                Test.@test isdefined(MultiPhase, :get_flows)
                Test.@test isdefined(MultiPhase, :get_switching_times)
                Test.@test isdefined(MultiPhase, :get_jumps)
            end
        end
    end
end

end # module

test_multiphase_flow() = TestMultiPhaseFlow.test_multiphase_flow()
