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
import CTModels.OCP

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

            Test.@testset "StatePointConfig is exported" begin
                Test.@test isdefined(Common, :StatePointConfig)
                config = Common.StatePointConfig(0.0, [1.0], 1.0)
                Test.@test config isa Common.StatePointConfig
            end

            Test.@testset "StateTrajectoryConfig is exported" begin
                Test.@test isdefined(Common, :StateTrajectoryConfig)
                config = Common.StateTrajectoryConfig((0.0, 1.0), [1.0])
                Test.@test config isa Common.StateTrajectoryConfig
            end
        end

        # ====================================================================
        # Config Functions
        # ====================================================================

        Test.@testset "Config Functions" begin
            Test.@testset "tspan is exported" begin
                Test.@test isdefined(Common, :tspan)
                config = Common.StatePointConfig(0.0, [1.0], 1.0)
                ts = Common.tspan(config)
                Test.@test ts == (0.0, 1.0)
            end

            Test.@testset "initial_condition is exported" begin
                Test.@test isdefined(Common, :initial_condition)
                config = Common.StatePointConfig(0.0, [1.0], 1.0)
                ic = Common.initial_condition(config)
                Test.@test ic == [1.0]
            end
        end

        # ====================================================================
        # Time-Dependence Trait Types
        # ====================================================================

        Test.@testset "Time-Dependence Trait Types" begin
            Test.@testset "TimeDependence is exported" begin
                Test.@test isdefined(OCP, :TimeDependence)
                Test.@test isabstracttype(Common.TimeDependence)
            end

            Test.@testset "Autonomous is exported" begin
                Test.@test isdefined(OCP, :Autonomous)
                Test.@test Common.Autonomous <: Common.TimeDependence
            end

            Test.@testset "NonAutonomous is exported" begin
                Test.@test isdefined(OCP, :NonAutonomous)
                Test.@test Common.NonAutonomous <: Common.TimeDependence
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
        # ODEParameters Type
        # ====================================================================

        Test.@testset "ODEParameters Type" begin
            Test.@testset "ODEParameters is exported" begin
                Test.@test isdefined(Common, :ODEParameters)
            end

            Test.@testset "constructs with nothing" begin
                params = Common.ODEParameters(nothing)
                Test.@test params isa Common.ODEParameters
                Test.@test params.variable === nothing
            end

            Test.@testset "constructs with value" begin
                params = Common.ODEParameters(0.5)
                Test.@test params isa Common.ODEParameters
                Test.@test params.variable == 0.5
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
                Test.@test Common.StatePointConfig <: Common.AbstractConfig
                Test.@test Common.StateTrajectoryConfig <: Common.AbstractConfig
            end
        end

        # ====================================================================
        # Internal Norm Functions
        # ====================================================================

        Test.@testset "Internal Norm Functions" begin
            Test.@testset "deepvalue is exported" begin
                Test.@test isdefined(Common, :deepvalue)
                Test.@test Common.deepvalue(3.14) === 3.14
            end

            Test.@testset "real_norm is exported" begin
                Test.@test isdefined(Common, :real_norm)
                Test.@test Common.real_norm(3.0, 0.0) === 3.0
            end
        end
    end
end

end # module

test_common_module() = TestCommonModule.test_common_module()
