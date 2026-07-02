module TestBuildingFlows

import Test
using OrdinaryDiffEqTsit5
import CTBase.Data
import CTFlows.Flows
import CTFlows.Systems
import CTFlows.Integrators
import CTBase.Traits

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

# ==============================================================================
# Test function
# ==============================================================================

function test_building_flows()
    Test.@testset "Building Tests" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ====================================================================
        # UNIT TESTS - Flow constructor from VectorField
        # ====================================================================

        Test.@testset "Flow constructor from VectorField" begin
            Test.@testset "default constructor" begin
                vf = Data.VectorField(x -> -x; is_autonomous=true, is_variable=false)
                flow = Flows.Flow(vf)

                Test.@test flow isa Flows.StateFlow
                Test.@test flow isa Flows.AbstractFlow
                Test.@test flow.system isa Systems.VectorFieldSystem
                Test.@test flow.integrator isa Integrators.AbstractIntegrator
            end

            Test.@testset "with keyword options" begin
                vf = Data.VectorField(x -> -x; is_autonomous=true, is_variable=false)
                flow = Flows.Flow(vf; reltol=1e-10)

                Test.@test flow isa Flows.StateFlow
                Test.@test flow.integrator isa Integrators.AbstractIntegrator
            end
        end

        # ====================================================================
        # UNIT TESTS - Trait preservation
        # ====================================================================

        Test.@testset "Trait preservation" begin
            Test.@testset "Autonomous Fixed" begin
                vf = Data.VectorField(x -> x; is_autonomous=true, is_variable=false)
                flow = Flows.Flow(vf)
                
                Test.@test Traits.time_dependence(flow) === Traits.Autonomous
                Test.@test Traits.variable_dependence(flow) === Traits.Fixed
            end

            Test.@testset "NonAutonomous Fixed" begin
                vf = Data.VectorField((t, x) -> t .* x; is_autonomous=false, is_variable=false)
                flow = Flows.Flow(vf)
                
                Test.@test Traits.time_dependence(flow) === Traits.NonAutonomous
                Test.@test Traits.variable_dependence(flow) === Traits.Fixed
            end

            Test.@testset "Autonomous NonFixed" begin
                vf = Data.VectorField((x, v) -> x .+ v; is_autonomous=true, is_variable=true)
                flow = Flows.Flow(vf)
                
                Test.@test Traits.time_dependence(flow) === Traits.Autonomous
                Test.@test Traits.variable_dependence(flow) === Traits.NonFixed
            end

            Test.@testset "NonAutonomous NonFixed" begin
                vf = Data.VectorField((t, x, v) -> t .* x .+ v; is_autonomous=false, is_variable=true)
                flow = Flows.Flow(vf)
                
                Test.@test Traits.time_dependence(flow) === Traits.NonAutonomous
                Test.@test Traits.variable_dependence(flow) === Traits.NonFixed
            end
        end

        # ====================================================================
        # UNIT TESTS - System and Integrator access
        # ====================================================================

        Test.@testset "System and Integrator access" begin
            vf = Data.VectorField(x -> 2 .* x; is_autonomous=true, is_variable=false)
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
                vf = Data.VectorField(x -> -x; is_autonomous=true, is_variable=false)
                
                # Build system directly
                sys_direct = Systems.build_system(vf)
                
                # Build flow which should use build_system internally
                flow = Flows.Flow(vf)
                sys_from_flow = Flows.system(flow)
                
                # Both should be VectorFieldSystem with same traits
                Test.@test sys_direct isa Systems.VectorFieldSystem
                Test.@test sys_from_flow isa Systems.VectorFieldSystem
                Test.@test Traits.time_dependence(sys_direct) === Traits.time_dependence(sys_from_flow)
                Test.@test Traits.variable_dependence(sys_direct) === Traits.variable_dependence(sys_from_flow)
            end
        end

        # ====================================================================
        # UNIT TESTS - HamiltonianFlow constructor from HamiltonianVectorField
        # ====================================================================

        Test.@testset "HamiltonianFlow constructor from HamiltonianVectorField" begin
            Test.@testset "default constructor" begin
                hvf = Data.HamiltonianVectorField((x, p) -> (x, -p); is_autonomous=true, is_variable=false)
                flow = Flows.Flow(hvf)

                Test.@test flow isa Flows.HamiltonianFlow
                Test.@test flow isa Flows.AbstractFlow
                Test.@test flow.system isa Systems.HamiltonianVectorFieldSystem
                Test.@test flow.integrator isa Integrators.AbstractIntegrator
            end

            Test.@testset "with keyword options" begin
                hvf = Data.HamiltonianVectorField((x, p) -> (x, -p); is_autonomous=true, is_variable=false)
                flow = Flows.Flow(hvf; reltol=1e-10)

                Test.@test flow isa Flows.HamiltonianFlow
                Test.@test flow.integrator isa Integrators.AbstractIntegrator
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

test_building_flows() = TestBuildingFlows.test_building_flows()