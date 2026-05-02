"""
# ============================================================================
# Common Module Exports Tests
# ============================================================================
# This file tests the exports from the `Common` module. It verifies that
# the expected types, functions, and constants are properly exported by
# `CTFlows.Common` and readily accessible to the end user.
"""

module TestCommonModule

import Test
import CTFlows.Common

const VERBOSE = isdefined(Main, :TestOptions) ? Main.TestOptions.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestOptions) ? Main.TestOptions.SHOWTIMING : true

const CurrentModule = TestCommonModule

function test_common_module()
    Test.@testset "Common Module Exports" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ====================================================================
        # Tag Types
        # ====================================================================

        Test.@testset "Tag Types" begin
            Test.@testset "AbstractTag is exported" begin
                Test.@test isdefined(Common, :AbstractTag)
                Test.@test isabstracttype(Common.AbstractTag)
            end
        end

        # ====================================================================
        # Config Types
        # ====================================================================

        Test.@testset "Config Types" begin
            Test.@testset "AbstractConfig is exported" begin
                Test.@test isdefined(Common, :AbstractConfig)
                Test.@test isabstracttype(Common.AbstractConfig)
            end

            Test.@testset "PointConfig is exported" begin
                Test.@test isdefined(Common, :PointConfig)
                config = Common.PointConfig(0.0, [1.0], 1.0)
                Test.@test config isa Common.PointConfig
            end

            Test.@testset "TrajectoryConfig is exported" begin
                Test.@test isdefined(Common, :TrajectoryConfig)
                config = Common.TrajectoryConfig((0.0, 1.0), [1.0])
                Test.@test config isa Common.TrajectoryConfig
            end
        end

        # ====================================================================
        # Config Functions
        # ====================================================================

        Test.@testset "Config Functions" begin
            Test.@testset "tspan is exported" begin
                Test.@test isdefined(Common, :tspan)
                config = Common.PointConfig(0.0, [1.0], 1.0)
                ts = Common.tspan(config)
                Test.@test ts == (0.0, 1.0)
            end
        end

        # ====================================================================
        # Time-Dependence Trait Types
        # ====================================================================

        Test.@testset "Time-Dependence Trait Types" begin
            Test.@testset "TimeDependence is exported" begin
                Test.@test isdefined(Common, :TimeDependence)
                Test.@test isabstracttype(Common.TimeDependence)
            end

            Test.@testset "Autonomous is exported" begin
                Test.@test isdefined(Common, :Autonomous)
                Test.@test Common.Autonomous <: Common.TimeDependence
                trait = Common.Autonomous()
                Test.@test trait isa Common.Autonomous
            end

            Test.@testset "NonAutonomous is exported" begin
                Test.@test isdefined(Common, :NonAutonomous)
                Test.@test Common.NonAutonomous <: Common.TimeDependence
                trait = Common.NonAutonomous()
                Test.@test trait isa Common.NonAutonomous
            end
        end

        # ====================================================================
        # Variable-Dependence Trait Types
        # ====================================================================

        Test.@testset "Variable-Dependence Trait Types" begin
            Test.@testset "VariableDependence is exported" begin
                Test.@test isdefined(Common, :VariableDependence)
                Test.@test isabstracttype(Common.VariableDependence)
            end

            Test.@testset "Fixed is exported" begin
                Test.@test isdefined(Common, :Fixed)
                Test.@test Common.Fixed <: Common.VariableDependence
                trait = Common.Fixed()
                Test.@test trait isa Common.Fixed
            end

            Test.@testset "NonFixed is exported" begin
                Test.@test isdefined(Common, :NonFixed)
                Test.@test Common.NonFixed <: Common.VariableDependence
                trait = Common.NonFixed()
                Test.@test trait isa Common.NonFixed
            end
        end

        # ====================================================================
        # Trait Check Functions
        # ====================================================================

        Test.@testset "Trait Check Functions" begin
            Test.@testset "has_time_dependence_trait is exported" begin
                Test.@test isdefined(Common, :has_time_dependence_trait)
            end

            Test.@testset "has_variable_dependence_trait is exported" begin
                Test.@test isdefined(Common, :has_variable_dependence_trait)
            end
        end

        # ====================================================================
        # Trait Query Functions
        # ====================================================================

        Test.@testset "Trait Query Functions" begin
            Test.@testset "time_dependence is exported" begin
                Test.@test isdefined(Common, :time_dependence)
            end

            Test.@testset "variable_dependence is exported" begin
                Test.@test isdefined(Common, :variable_dependence)
            end
        end

        # ====================================================================
        # Trait Accessor Functions
        # ====================================================================

        Test.@testset "Trait Accessor Functions" begin
            Test.@testset "is_autonomous is exported" begin
                Test.@test isdefined(Common, :is_autonomous)
                Test.@test Common.is_autonomous(Common.Autonomous) === true
                Test.@test Common.is_autonomous(Common.NonAutonomous) === false
            end

            Test.@testset "is_nonautonomous is exported" begin
                Test.@test isdefined(Common, :is_nonautonomous)
                Test.@test Common.is_nonautonomous(Common.Autonomous) === false
                Test.@test Common.is_nonautonomous(Common.NonAutonomous) === true
            end

            Test.@testset "is_variable is exported" begin
                Test.@test isdefined(Common, :is_variable)
                Test.@test Common.is_variable(Common.Fixed) === false
                Test.@test Common.is_variable(Common.NonFixed) === true
            end

            Test.@testset "is_nonvariable is exported" begin
                Test.@test isdefined(Common, :is_nonvariable)
                Test.@test Common.is_nonvariable(Common.Fixed) === true
                Test.@test Common.is_nonvariable(Common.NonFixed) === false
            end

            Test.@testset "has_variable is exported" begin
                Test.@test isdefined(Common, :has_variable)
                Test.@test Common.has_variable(Common.Fixed) === false
                Test.@test Common.has_variable(Common.NonFixed) === true
            end
        end

        # ====================================================================
        # Type Hierarchy Verification
        # ====================================================================

        Test.@testset "Type Hierarchy" begin
            Test.@testset "TimeDependence hierarchy" begin
                Test.@test Common.Autonomous <: Common.TimeDependence
                Test.@test Common.NonAutonomous <: Common.TimeDependence
            end

            Test.@testset "VariableDependence hierarchy" begin
                Test.@test Common.Fixed <: Common.VariableDependence
                Test.@test Common.NonFixed <: Common.VariableDependence
            end

            Test.@testset "Config hierarchy" begin
                Test.@test Common.PointConfig <: Common.AbstractConfig
                Test.@test Common.TrajectoryConfig <: Common.AbstractConfig
            end
        end
    end
end

end # module

test_common_module() = TestCommonModule.test_common_module()
