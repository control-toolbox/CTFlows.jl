module TestBuildingFlows

import Test
using OrdinaryDiffEqTsit5
import CTFlows.Data
import CTFlows.Flows
import CTFlows.Systems
import CTFlows.Integrators
import CTFlows.Common

const VERBOSE = isdefined(Main, :TestOptions) ? Main.TestOptions.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestOptions) ? Main.TestOptions.SHOWTIMING : true

# ==============================================================================
# Test function
# ==============================================================================

function test_building_flows()
    Test.@testset "Building Tests" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ====================================================================
        # UNIT TESTS - Flow constructor from VectorField
        # ====================================================================

        Test.@testset "Flow constructor from VectorField" begin
            Test.@testset "default integrator id (:sciml)" begin
                vf = Data.VectorField(x -> -x; autonomous=true, variable=false)
                flow = Flows.Flow(vf)
                
                Test.@test flow isa Flows.Flow
                Test.@test flow isa Flows.AbstractFlow
                Test.@test flow.system isa Systems.VectorFieldSystem
                Test.@test flow.integrator isa Integrators.AbstractIntegrator
            end

            Test.@testset "explicit integrator id (:sciml)" begin
                vf = Data.VectorField(x -> -x; autonomous=true, variable=false)
                flow = Flows.Flow(vf, :sciml)
                
                Test.@test flow isa Flows.Flow
                Test.@test flow.system isa Systems.VectorFieldSystem
                Test.@test flow.integrator isa Integrators.AbstractIntegrator
            end

            Test.@testset "with keyword options" begin
                vf = Data.VectorField(x -> -x; autonomous=true, variable=false)
                flow = Flows.Flow(vf, :sciml)
                
                Test.@test flow isa Flows.Flow
                Test.@test flow.integrator isa Integrators.AbstractIntegrator
            end
        end

        # ====================================================================
        # UNIT TESTS - Trait preservation
        # ====================================================================

        Test.@testset "Trait preservation" begin
            Test.@testset "Autonomous Fixed" begin
                vf = Data.VectorField(x -> x; autonomous=true, variable=false)
                flow = Flows.Flow(vf)
                
                Test.@test Common.time_dependence(flow) === Common.Autonomous
                Test.@test Common.variable_dependence(flow) === Common.Fixed
            end

            Test.@testset "NonAutonomous Fixed" begin
                vf = Data.VectorField((t, x) -> t .* x; autonomous=false, variable=false)
                flow = Flows.Flow(vf)
                
                Test.@test Common.time_dependence(flow) === Common.NonAutonomous
                Test.@test Common.variable_dependence(flow) === Common.Fixed
            end

            Test.@testset "Autonomous NonFixed" begin
                vf = Data.VectorField((x, v) -> x .+ v; autonomous=true, variable=true)
                flow = Flows.Flow(vf)
                
                Test.@test Common.time_dependence(flow) === Common.Autonomous
                Test.@test Common.variable_dependence(flow) === Common.NonFixed
            end

            Test.@testset "NonAutonomous NonFixed" begin
                vf = Data.VectorField((t, x, v) -> t .* x .+ v; autonomous=false, variable=true)
                flow = Flows.Flow(vf)
                
                Test.@test Common.time_dependence(flow) === Common.NonAutonomous
                Test.@test Common.variable_dependence(flow) === Common.NonFixed
            end
        end

        # ====================================================================
        # UNIT TESTS - System and Integrator access
        # ====================================================================

        Test.@testset "System and Integrator access" begin
            vf = Data.VectorField(x -> 2 .* x; autonomous=true, variable=false)
            flow = Flows.Flow(vf)
            
            Test.@testset "system accessor returns correct system" begin
                sys = Flows.system(flow)
                Test.@test sys isa Systems.VectorFieldSystem
            end
            
            Test.@testset "integrator accessor returns correct integrator" begin
                integ = Flows.integrator(flow)
                Test.@test integ isa Integrators.AbstractIntegrator
            end
        end

        # ====================================================================
        # UNIT TESTS - Integration with build_system
        # ====================================================================

        Test.@testset "Integration with build_system" begin
            Test.@testset "build_system is called internally" begin
                vf = Data.VectorField(x -> -x; autonomous=true, variable=false)
                
                # Build system directly
                sys_direct = Systems.build_system(vf)
                
                # Build flow which should use build_system internally
                flow = Flows.Flow(vf)
                sys_from_flow = Flows.system(flow)
                
                # Both should be VectorFieldSystem with same traits
                Test.@test sys_direct isa Systems.VectorFieldSystem
                Test.@test sys_from_flow isa Systems.VectorFieldSystem
                Test.@test Common.time_dependence(sys_direct) === Common.time_dependence(sys_from_flow)
                Test.@test Common.variable_dependence(sys_direct) === Common.variable_dependence(sys_from_flow)
            end
        end

        # ====================================================================
        # UNIT TESTS - Exports Verification
        # ====================================================================

        Test.@testset "Exports Verification" begin
            Test.@testset "Flow constructor is exported" begin
                Test.@test isdefined(Flows, :Flow)
            end
        end
    end
end

end # module

test_building_flows() = TestBuilding.test_building_flows()