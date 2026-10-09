module TestConcreteConfigs

using Test: Test
using CTFlows: Configs
using CTBase: Traits
using CTBase: Exceptions

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

function test_concrete_configs()
    Test.@testset "Concrete Configs Tests" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ====================================================================
        # UNIT TESTS - Concrete Type Construction
        # ====================================================================

        Test.@testset "UNIT TESTS - Output grid at the call (issue #434)" begin
            Test.@testset "time span: no grid" begin
                c = Configs.StateTrajectoryConfig((0, 1), [1.0])
                Test.@test Configs.tspan(c) === (0.0, 1.0)
                Test.@test Configs.output_grid(c) === nothing
                Test.@test Configs.output_grid(Configs.StateEndPointConfig(0.0, [1.0], 1.0)) ===
                    nothing
            end

            Test.@testset "vector, range and tuple grids" begin
                for times in ([0, 0.25, 1], range(0, 1, 3), (0, 0.5, 1))
                    c = Configs.StateTrajectoryConfig(times, [1.0])
                    Test.@test Configs.tspan(c) == (0.0, 1.0)
                    Test.@test Configs.output_grid(c) == collect(Float64, times)
                    Test.@test eltype(Configs.output_grid(c)) == Float64
                end
                h = Configs.HamiltonianTrajectoryConfig([0.0, 0.5, 1.0], [1.0], [0.5])
                Test.@test Configs.tspan(h) == (0.0, 1.0)
                Test.@test Configs.output_grid(h) == [0.0, 0.5, 1.0]
            end

            Test.@testset "backward grid" begin
                c = Configs.StateTrajectoryConfig([1.0, 0.5, 0.0], [1.0])
                Test.@test Configs.tspan(c) == (1.0, 0.0)
                Test.@test Configs.initial_time(c) == 1.0
                Test.@test Configs.final_time(c) == 0.0
            end

            Test.@testset "two-element vector is a grid" begin
                c = Configs.StateTrajectoryConfig([0.0, 1.0], [1.0])
                Test.@test Configs.output_grid(c) == [0.0, 1.0]
            end

            Test.@testset "generated grid keyword" begin
                c = Configs.StateTrajectoryConfig((0, 1), [1.0]; grid=20)
                Test.@test Configs.tspan(c) == (0.0, 1.0)
                Test.@test Configs.output_grid(c) == Configs.UniformGrid(20)
                spec = Configs.AdaptiveGrid(30; uniform=0.2)
                h = Configs.HamiltonianTrajectoryConfig((0.0, 1.0), [1.0], [0.5]; grid=spec)
                Test.@test Configs.output_grid(h) === spec
                Test.@test Configs.output_grid(
                    Configs.StateTrajectoryConfig((0.0, 1.0), [1.0]; grid=nothing)
                ) === nothing
                Test.@test_throws Exceptions.IncorrectArgument Configs.StateTrajectoryConfig(
                    [0.0, 0.5, 1.0], [1.0]; grid=10
                )
                Test.@test_throws Exceptions.IncorrectArgument Configs.StateTrajectoryConfig(
                    (0.0, 1.0), [1.0]; grid=1
                )
            end

            Test.@testset "Error: invalid grids" begin
                for bad in ([0.0], Float64[], [0.0, 0.5, 0.5, 1.0], [0.0, 0.7, 0.5], (0.0,))
                    Test.@test_throws Exceptions.IncorrectArgument Configs.StateTrajectoryConfig(
                        bad, [1.0]
                    )
                end
                Test.@test_throws Exceptions.IncorrectArgument Configs.HamiltonianTrajectoryConfig(
                    [1.0, 1.0], [1.0], [0.5]
                )
            end
        end

        Test.@testset "UNIT TESTS - Concrete Type Construction" begin
            Test.@testset "StateEndPointConfig construction" begin
                config = Configs.StateEndPointConfig(0.0, [1.0, 0.0], 1.0)
                Test.@test config isa Configs.StateEndPointConfig
                Test.@test config.t0 === 0.0
                Test.@test config.x0 == [1.0, 0.0]
                Test.@test config.tf === 1.0
            end

            Test.@testset "StateTrajectoryConfig construction" begin
                config = Configs.StateTrajectoryConfig((0.0, 1.0), [1.0, 0.0])
                Test.@test config isa Configs.StateTrajectoryConfig
                Test.@test config.tspan == (0.0, 1.0)
                Test.@test config.x0 == [1.0, 0.0]
            end

            Test.@testset "HamiltonianEndPointConfig construction" begin
                config = Configs.HamiltonianEndPointConfig(0.0, [1.0, 0.0], [0.5, 0.3], 1.0)
                Test.@test config isa Configs.HamiltonianEndPointConfig
                Test.@test config.t0 === 0.0
                Test.@test config.x0 == [1.0, 0.0]
                Test.@test config.p0 == [0.5, 0.3]
                Test.@test config.tf === 1.0
            end

            Test.@testset "HamiltonianTrajectoryConfig construction" begin
                config = Configs.HamiltonianTrajectoryConfig(
                    (0.0, 1.0), [1.0, 0.0], [0.5, 0.3]
                )
                Test.@test config isa Configs.HamiltonianTrajectoryConfig
                Test.@test config.tspan == (0.0, 1.0)
                Test.@test config.x0 == [1.0, 0.0]
                Test.@test config.p0 == [0.5, 0.3]
            end

            Test.@testset "AugmentedHamiltonianEndPointConfig construction" begin
                config = Configs.AugmentedHamiltonianEndPointConfig(
                    0.0, [1.0, 0.0], [0.5, 0.3], [0.0, 0.0], 1.0
                )
                Test.@test config isa Configs.AugmentedHamiltonianEndPointConfig
                Test.@test config.t0 === 0.0
                Test.@test config.x0 == [1.0, 0.0]
                Test.@test config.p0 == [0.5, 0.3]
                Test.@test config.pv0 == [0.0, 0.0]
                Test.@test config.tf === 1.0
            end
        end

        # ====================================================================
        # UNIT TESTS - Concrete Type Subtype Relationships
        # ====================================================================

        Test.@testset "UNIT TESTS - Concrete Type Subtype Relationships" begin
            Test.@testset "StateEndPointConfig subtypes" begin
                config = Configs.StateEndPointConfig(0.0, [1.0], 1.0)
                Test.@test config isa Configs.AbstractConfig
                Test.@test config isa Configs.AbstractEndPointConfig
                Test.@test config isa Configs.AbstractStateConfig
                Test.@test Configs.StateEndPointConfig <: Configs.AbstractConfig
                Test.@test Configs.StateEndPointConfig <: Configs.AbstractEndPointConfig
                Test.@test Configs.StateEndPointConfig <: Configs.AbstractStateConfig
            end

            Test.@testset "StateTrajectoryConfig subtypes" begin
                config = Configs.StateTrajectoryConfig((0.0, 1.0), [1.0])
                Test.@test config isa Configs.AbstractConfig
                Test.@test config isa Configs.AbstractTrajectoryConfig
                Test.@test config isa Configs.AbstractStateConfig
                Test.@test Configs.StateTrajectoryConfig <: Configs.AbstractConfig
                Test.@test Configs.StateTrajectoryConfig <: Configs.AbstractTrajectoryConfig
                Test.@test Configs.StateTrajectoryConfig <: Configs.AbstractStateConfig
            end

            Test.@testset "HamiltonianEndPointConfig subtypes" begin
                config = Configs.HamiltonianEndPointConfig(0.0, [1.0], [0.5], 1.0)
                Test.@test config isa Configs.AbstractConfig
                Test.@test config isa Configs.AbstractEndPointConfig
                Test.@test config isa Configs.AbstractHamiltonianConfig
                Test.@test Configs.HamiltonianEndPointConfig <: Configs.AbstractConfig
                Test.@test Configs.HamiltonianEndPointConfig <:
                    Configs.AbstractEndPointConfig
                Test.@test Configs.HamiltonianEndPointConfig <:
                    Configs.AbstractHamiltonianConfig
            end

            Test.@testset "HamiltonianTrajectoryConfig subtypes" begin
                config = Configs.HamiltonianTrajectoryConfig((0.0, 1.0), [1.0], [0.5])
                Test.@test config isa Configs.AbstractConfig
                Test.@test config isa Configs.AbstractTrajectoryConfig
                Test.@test config isa Configs.AbstractHamiltonianConfig
                Test.@test Configs.HamiltonianTrajectoryConfig <: Configs.AbstractConfig
                Test.@test Configs.HamiltonianTrajectoryConfig <:
                    Configs.AbstractTrajectoryConfig
                Test.@test Configs.HamiltonianTrajectoryConfig <:
                    Configs.AbstractHamiltonianConfig
            end

            Test.@testset "AugmentedHamiltonianEndPointConfig subtypes" begin
                config = Configs.AugmentedHamiltonianEndPointConfig(
                    0.0, [1.0], [0.5], [0.0], 1.0
                )
                Test.@test config isa Configs.AbstractAugmentedHamiltonianConfig
                Test.@test config isa Configs.AbstractEndPointConfig
                Test.@test Configs.AugmentedHamiltonianEndPointConfig <:
                    Configs.AbstractAugmentedHamiltonianConfig
                Test.@test Configs.AugmentedHamiltonianEndPointConfig <:
                    Configs.AbstractEndPointConfig
            end
        end

        # ====================================================================
        # UNIT TESTS - AugmentedHamiltonianEndPointConfig Specific Methods
        # ====================================================================

        Test.@testset "UNIT TESTS - AugmentedHamiltonianEndPointConfig Specific Methods" begin
            Test.@testset "AugmentedHamiltonianEndPointConfig initial_condition" begin
                config = Configs.AugmentedHamiltonianEndPointConfig(
                    0.0, [1.0, 0.0], [0.5, 0.3], [0.0, 0.0], 1.0
                )
                ic = Configs.initial_condition(config)
                Test.@test ic == [1.0, 0.0, 0.5, 0.3, 0.0, 0.0]
            end

            Test.@testset "AugmentedHamiltonianEndPointConfig initial_state" begin
                config = Configs.AugmentedHamiltonianEndPointConfig(
                    0.0, [1.0, 0.0], [0.5, 0.3], [0.0, 0.0], 1.0
                )
                Test.@test Configs.initial_state(config) == [1.0, 0.0]
            end

            Test.@testset "AugmentedHamiltonianEndPointConfig initial_costate" begin
                config = Configs.AugmentedHamiltonianEndPointConfig(
                    0.0, [1.0, 0.0], [0.5, 0.3], [0.0, 0.0], 1.0
                )
                Test.@test Configs.initial_costate(config) == [0.5, 0.3]
            end

            Test.@testset "AugmentedHamiltonianEndPointConfig initial_variable_costate" begin
                config = Configs.AugmentedHamiltonianEndPointConfig(
                    0.0, [1.0, 0.0], [0.5, 0.3], [0.0, 0.0], 1.0
                )
                Test.@test Configs.initial_variable_costate(config) == [0.0, 0.0]
            end

            Test.@testset "AugmentedHamiltonianEndPointConfig tspan" begin
                config = Configs.AugmentedHamiltonianEndPointConfig(
                    0.0, [1.0, 0.0], [0.5, 0.3], [0.0, 0.0], 1.0
                )
                Test.@test Configs.tspan(config) == (0.0, 1.0)
            end
        end

        # ====================================================================
        # TYPE STABILITY TESTS
        # ====================================================================

        Test.@testset "TYPE STABILITY TESTS" begin
            Test.@testset "Type Stability: AugmentedHamiltonianEndPointConfig getters" begin
                config = Configs.AugmentedHamiltonianEndPointConfig(
                    0.0, [1.0, 0.0], [0.5, 0.3], [0.0, 0.0], 1.0
                )
                Test.@test_nowarn Test.@inferred(Configs.initial_condition(config)) ==
                    [1.0, 0.0, 0.5, 0.3, 0.0, 0.0]
                Test.@test_nowarn Test.@inferred(Configs.initial_state(config)) ==
                    [1.0, 0.0]
                Test.@test_nowarn Test.@inferred(Configs.initial_costate(config)) ==
                    [0.5, 0.3]
                Test.@test_nowarn Test.@inferred(
                    Configs.initial_variable_costate(config)
                ) == [0.0, 0.0]
                Test.@test_nowarn Test.@inferred(Configs.tspan(config)) == (0.0, 1.0)
            end
        end
    end
end

end # module

test_concrete_configs() = TestConcreteConfigs.test_concrete_configs()
