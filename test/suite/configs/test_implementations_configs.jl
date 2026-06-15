module TestImplementationsConfigs

import Test
import CTBase.Exceptions
import CTFlows.Configs
import CTFlows.Traits

const VERBOSE = isdefined(Main, :TestOptions) ? Main.TestOptions.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestOptions) ? Main.TestOptions.SHOWTIMING : true

function test_implementations_configs()
    Test.@testset "Implementations Configs Tests" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ====================================================================
        # UNIT TESTS - tspan Implementations
        # ====================================================================

        Test.@testset "UNIT TESTS - tspan Implementations" begin
            Test.@testset "AbstractEndPointConfig tspan returns tuple" begin
                config = Configs.StateEndPointConfig(0.0, [1.0, 0.0], 1.0)
                ts = Configs.tspan(config)
                Test.@test ts isa Tuple{Real, Real}
                Test.@test ts == (0.0, 1.0)
            end

            Test.@testset "AbstractTrajectoryConfig tspan returns tuple" begin
                config = Configs.StateTrajectoryConfig((0.0, 1.0), [1.0, 0.0])
                ts = Configs.tspan(config)
                Test.@test ts isa Tuple{Real, Real}
                Test.@test ts == (0.0, 1.0)
            end
        end

        # ====================================================================
        # UNIT TESTS - initial_time Implementations
        # ====================================================================

        Test.@testset "UNIT TESTS - initial_time Implementations" begin
            Test.@testset "AbstractEndPointConfig initial_time returns t0" begin
                config = Configs.StateEndPointConfig(0.5, [1.0], 1.0)
                Test.@test Configs.initial_time(config) == 0.5
            end

            Test.@testset "AbstractTrajectoryConfig initial_time returns tspan[1]" begin
                config = Configs.StateTrajectoryConfig((0.5, 2.5), [1.0])
                Test.@test Configs.initial_time(config) == 0.5
            end
        end

        # ====================================================================
        # UNIT TESTS - final_time Implementations
        # ====================================================================

        Test.@testset "UNIT TESTS - final_time Implementations" begin
            Test.@testset "AbstractEndPointConfig final_time returns tf" begin
                config = Configs.StateEndPointConfig(0.0, [1.0], 2.5)
                Test.@test Configs.final_time(config) == 2.5
            end

            Test.@testset "AbstractTrajectoryConfig final_time returns tspan[2]" begin
                config = Configs.StateTrajectoryConfig((0.0, 2.5), [1.0])
                Test.@test Configs.final_time(config) == 2.5
            end
        end

        # ====================================================================
        # UNIT TESTS - initial_condition Implementations
        # ====================================================================

        Test.@testset "UNIT TESTS - initial_condition Implementations" begin
            Test.@testset "AbstractStateConfig with scalar X0 wraps in vector" begin
                config = Configs.StateEndPointConfig(0.0, 1.0, 1.0)
                ic = Configs.initial_condition(config)
                Test.@test ic isa AbstractVector
                Test.@test ic == [1.0]
            end

            Test.@testset "AbstractStateConfig with vector X0 returns vector" begin
                config = Configs.StateEndPointConfig(0.0, [1.0, 0.0], 1.0)
                ic = Configs.initial_condition(config)
                Test.@test ic isa AbstractVector
                Test.@test ic == [1.0, 0.0]
            end

            Test.@testset "AbstractHamiltonianConfig returns vcat(x0, p0)" begin
                config = Configs.HamiltonianEndPointConfig(0.0, [1.0, 0.0], [0.5, 0.3], 1.0)
                ic = Configs.initial_condition(config)
                Test.@test ic == [1.0, 0.0, 0.5, 0.3]
            end
        end

        # ====================================================================
        # UNIT TESTS - initial_state Implementation
        # ====================================================================

        Test.@testset "UNIT TESTS - initial_state Implementation" begin
            Test.@testset "initial_state returns x0 field" begin
                config = Configs.StateEndPointConfig(0.0, [1.0, 0.0], 1.0)
                Test.@test Configs.initial_state(config) == [1.0, 0.0]
            end

            Test.@testset "initial_state for HamiltonianEndPointConfig" begin
                config = Configs.HamiltonianEndPointConfig(0.0, [1.0, 0.0], [0.5, 0.3], 1.0)
                Test.@test Configs.initial_state(config) == [1.0, 0.0]
            end

            Test.@testset "initial_state for StateTrajectoryConfig" begin
                config = Configs.StateTrajectoryConfig((0.0, 1.0), [1.0, 0.0])
                Test.@test Configs.initial_state(config) == [1.0, 0.0]
            end

            Test.@testset "initial_state for HamiltonianTrajectoryConfig" begin
                config = Configs.HamiltonianTrajectoryConfig((0.0, 1.0), [1.0, 0.0], [0.5, 0.3])
                Test.@test Configs.initial_state(config) == [1.0, 0.0]
            end
        end

        # ====================================================================
        # ERROR TESTS - initial_costate Implementations
        # ====================================================================

        Test.@testset "ERROR TESTS - initial_costate Implementations" begin
            Test.@testset "initial_costate throws PreconditionError for state configs" begin
                config = Configs.StateEndPointConfig(0.0, [1.0], 1.0)
                Test.@test_throws Exceptions.PreconditionError Configs.initial_costate(config)
            end

            Test.@testset "PreconditionError message quality" begin
                config = Configs.StateEndPointConfig(0.0, [1.0], 1.0)
                e = try
                    Configs.initial_costate(config)
                catch err
                    err
                end
                Test.@test e isa Exceptions.PreconditionError
                Test.@test occursin("Hamiltonian", string(e))
                Test.@test occursin("costate", string(e))
            end

            Test.@testset "initial_costate returns p0 for Hamiltonian configs" begin
                config = Configs.HamiltonianEndPointConfig(0.0, [1.0, 0.0], [0.5, 0.3], 1.0)
                Test.@test Configs.initial_costate(config) == [0.5, 0.3]
            end

            Test.@testset "initial_costate for HamiltonianTrajectoryConfig" begin
                config = Configs.HamiltonianTrajectoryConfig((0.0, 1.0), [1.0, 0.0], [0.5, 0.3])
                Test.@test Configs.initial_costate(config) == [0.5, 0.3]
            end
        end
    end
end

end # module

test_implementations_configs() = TestImplementationsConfigs.test_implementations_configs()
