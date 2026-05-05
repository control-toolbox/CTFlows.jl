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
                    Test.@test occursin("systems: Vector", output)
                    Test.@test occursin("integrators: Vector", output)
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
        end

        Test.@testset "MultiPhaseHamiltonianFlow" begin
            # TODO: Add HamiltonianSystem fake when implemented
            Test.@testset "type exists" begin
                Test.@test isdefined(MultiPhase, :MultiPhaseHamiltonianFlow)
            end
        end
    end
end

end # module

test_multiphase_flow() = TestMultiPhaseFlow.test_multiphase_flow()
