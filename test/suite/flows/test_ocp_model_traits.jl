"""
Unit and contract tests for CTFlows.Flows trait methods on CTModels.Models.Model.

Tests that time_dependence / variable_dependence dispatch correctly for all
combinations of autonomous/non-autonomous and Fixed/NonFixed OCPs.
No extensions required — pure type-level dispatch.
"""

module TestOCPModelTraits

import Test
import CTModels
import CTBase.Traits: Traits

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

# =============================================================================
# OCP fixtures at module top-level
# =============================================================================

function _build_ocp_auton_fixed()
    pre = CTModels.Building.PreModel()
    CTModels.Building.time_dependence!(pre; autonomous=true)
    CTModels.Building.time!(pre; t0=0.0, tf=1.0)
    CTModels.Building.state!(pre, 1)
    CTModels.Building.dynamics!(pre, (r, t, x, u, v) -> (r[1] = x[1]; nothing))
    CTModels.Building.objective!(pre, :min; mayer=(x0, xf, v) -> xf[1])
    return CTModels.Building.build(pre)
end

function _build_ocp_auton_nonfixed()
    pre = CTModels.Building.PreModel()
    CTModels.Building.time_dependence!(pre; autonomous=true)
    CTModels.Building.time!(pre; t0=0.0, tf=1.0)
    CTModels.Building.state!(pre, 1)
    CTModels.Building.variable!(pre, 1)
    CTModels.Building.dynamics!(pre, (r, t, x, u, v) -> (r[1] = v[1]*x[1]; nothing))
    CTModels.Building.objective!(pre, :min; mayer=(x0, xf, v) -> xf[1])
    return CTModels.Building.build(pre)
end

function _build_ocp_nonauton_nonfixed()
    pre = CTModels.Building.PreModel()
    CTModels.Building.time_dependence!(pre; autonomous=false)
    CTModels.Building.time!(pre; t0=0.0, tf=1.0)
    CTModels.Building.state!(pre, 1)
    CTModels.Building.variable!(pre, 1)
    CTModels.Building.dynamics!(pre, (r, t, x, u, v) -> (r[1] = t*v[1]*x[1]; nothing))
    CTModels.Building.objective!(pre, :min; mayer=(x0, xf, v) -> xf[1])
    return CTModels.Building.build(pre)
end

function _build_ocp_nonauton_fixed()
    pre = CTModels.Building.PreModel()
    CTModels.Building.time_dependence!(pre; autonomous=false)
    CTModels.Building.time!(pre; t0=0.0, tf=1.0)
    CTModels.Building.state!(pre, 1)
    CTModels.Building.dynamics!(pre, (r, t, x, u, v) -> (r[1] = t*x[1]; nothing))
    CTModels.Building.objective!(pre, :min; mayer=(x0, xf, v) -> xf[1])
    return CTModels.Building.build(pre)
end

const OCP_AUTON_FIXED       = _build_ocp_auton_fixed()
const OCP_AUTON_NONFIXED    = _build_ocp_auton_nonfixed()
const OCP_NONAUTON_NONFIXED = _build_ocp_nonauton_nonfixed()
const OCP_NONAUTON_FIXED    = _build_ocp_nonauton_fixed()

# =============================================================================

function test_ocp_model_traits()
    Test.@testset "OCP Model Traits" verbose=VERBOSE showtiming=SHOWTIMING begin

        Test.@testset "Unit: time_dependence" begin
            Test.@test Traits.time_dependence(OCP_AUTON_FIXED)       === CTModels.Components.Autonomous
            Test.@test Traits.time_dependence(OCP_AUTON_NONFIXED)    === CTModels.Components.Autonomous
            Test.@test Traits.time_dependence(OCP_NONAUTON_NONFIXED) === CTModels.Components.NonAutonomous
            Test.@test Traits.time_dependence(OCP_NONAUTON_FIXED)    === CTModels.Components.NonAutonomous
        end

        Test.@testset "Unit: variable_dependence" begin
            Test.@test Traits.variable_dependence(OCP_AUTON_FIXED)       === Traits.Fixed
            Test.@test Traits.variable_dependence(OCP_AUTON_NONFIXED)    === Traits.NonFixed
            Test.@test Traits.variable_dependence(OCP_NONAUTON_NONFIXED) === Traits.NonFixed
            Test.@test Traits.variable_dependence(OCP_NONAUTON_FIXED)    === Traits.Fixed
        end

        Test.@testset "Contract: has_time_dependence_trait returns true for all OCP" begin
            Test.@test Traits.has_time_dependence_trait(OCP_AUTON_FIXED)       === true
            Test.@test Traits.has_time_dependence_trait(OCP_AUTON_NONFIXED)    === true
            Test.@test Traits.has_time_dependence_trait(OCP_NONAUTON_NONFIXED) === true
            Test.@test Traits.has_time_dependence_trait(OCP_NONAUTON_FIXED)    === true
        end

        Test.@testset "Contract: has_variable_dependence_trait returns true for all OCP" begin
            Test.@test Traits.has_variable_dependence_trait(OCP_AUTON_FIXED)       === true
            Test.@test Traits.has_variable_dependence_trait(OCP_AUTON_NONFIXED)    === true
            Test.@test Traits.has_variable_dependence_trait(OCP_NONAUTON_NONFIXED) === true
            Test.@test Traits.has_variable_dependence_trait(OCP_NONAUTON_FIXED)    === true
        end

        Test.@testset "Contract: OCP isa CTModels.Models.Model" begin
            Test.@test OCP_AUTON_FIXED    isa CTModels.Models.Model
            Test.@test OCP_AUTON_NONFIXED isa CTModels.Models.Model
        end

        Test.@testset "Unit: EmptyVariableModel ↔ Fixed, VariableModel ↔ NonFixed" begin
            Test.@test CTModels.Models.variable_dimension(OCP_AUTON_FIXED)    == 0
            Test.@test CTModels.Models.variable_dimension(OCP_AUTON_NONFIXED) == 1
        end

    end
end

end # module

test_ocp_model_traits() = TestOCPModelTraits.test_ocp_model_traits()
