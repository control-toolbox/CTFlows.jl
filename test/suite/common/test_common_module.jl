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
import CTFlows.Traits
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
        # Trait Types (now in Traits module)
        # ====================================================================

        Test.@testset "Trait Types (Traits module)" begin
            Test.@testset "TimeDependence is exported from Traits" begin
                Test.@test isdefined(Traits, :TimeDependence)
                Test.@test isabstracttype(Traits.TimeDependence)
            end

            Test.@testset "Autonomous is exported from Traits" begin
                Test.@test isdefined(OCP, :Autonomous)
                Test.@test Traits.Autonomous <: Traits.TimeDependence
            end

            Test.@testset "NonAutonomous is exported from Traits" begin
                Test.@test isdefined(OCP, :NonAutonomous)
                Test.@test Traits.NonAutonomous <: Traits.TimeDependence
            end
        end

        Test.@testset "Variable-Dependence Trait Types (Traits module)" begin
            Test.@testset "VariableDependence is exported from Traits" begin
                Test.@test isdefined(Traits, :VariableDependence)
                Test.@test isabstracttype(Traits.VariableDependence)
            end

            Test.@testset "Fixed is exported from Traits" begin
                Test.@test isdefined(Traits, :Fixed)
                Test.@test Traits.Fixed <: Traits.VariableDependence
                trait = Traits.Fixed()
                Test.@test trait isa Traits.Fixed
            end

            Test.@testset "NonFixed is exported from Traits" begin
                Test.@test isdefined(Traits, :NonFixed)
                Test.@test Traits.NonFixed <: Traits.VariableDependence
                trait = Traits.NonFixed()
                Test.@test trait isa Traits.NonFixed
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
                Test.@test Common.variable(params) === nothing
            end

            Test.@testset "constructs with value" begin
                params = Common.ODEParameters(0.5)
                Test.@test params isa Common.ODEParameters
                Test.@test Common.variable(params) == 0.5
            end
        end

        # ====================================================================
        # Trait Check Functions (now in Traits module)
        # ====================================================================

        Test.@testset "Trait Check Functions (Traits module)" begin
            Test.@testset "has_time_dependence_trait is exported from Traits" begin
                Test.@test isdefined(Traits, :has_time_dependence_trait)
            end

            Test.@testset "has_variable_dependence_trait is exported from Traits" begin
                Test.@test isdefined(Traits, :has_variable_dependence_trait)
            end
        end

        # ====================================================================
        # Trait Query Functions (now in Traits module)
        # ====================================================================

        Test.@testset "Trait Query Functions (Traits module)" begin
            Test.@testset "time_dependence is exported from Traits" begin
                Test.@test isdefined(Traits, :time_dependence)
            end

            Test.@testset "variable_dependence is exported from Traits" begin
                Test.@test isdefined(Traits, :variable_dependence)
            end
        end

        # ====================================================================
        # Trait Accessor Functions (now in Traits module)
        # ====================================================================

        Test.@testset "Trait Accessor Functions (Traits module)" begin
            Test.@testset "is_autonomous is exported from Traits" begin
                Test.@test isdefined(Traits, :is_autonomous)
            end

            Test.@testset "is_nonautonomous is exported from Traits" begin
                Test.@test isdefined(Traits, :is_nonautonomous)
            end

            Test.@testset "is_variable is exported from Traits" begin
                Test.@test isdefined(Traits, :is_variable)
            end

            Test.@testset "is_nonvariable is exported from Traits" begin
                Test.@test isdefined(Traits, :is_nonvariable)
            end

            Test.@testset "has_variable is exported from Traits" begin
                Test.@test isdefined(Traits, :has_variable)
            end
        end

        # ====================================================================
        # Type Hierarchy Verification (Traits module)
        # ====================================================================

        Test.@testset "Type Hierarchy (Traits module)" begin
            Test.@testset "TimeDependence hierarchy" begin
                Test.@test Traits.Autonomous <: Traits.TimeDependence
                Test.@test Traits.NonAutonomous <: Traits.TimeDependence
            end

            Test.@testset "VariableDependence hierarchy" begin
                Test.@test Traits.Fixed <: Traits.VariableDependence
                Test.@test Traits.NonFixed <: Traits.VariableDependence
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
