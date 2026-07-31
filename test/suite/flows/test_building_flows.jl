module TestBuildingFlows

using Test: Test
using OrdinaryDiffEqTsit5
using CTBase: Data
using CTBase: Exceptions
using CTFlows: Flows
using CTFlows: Systems
using CTFlows: Integrators
using CTBase: Traits

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
                vf = Data.VectorField(
                    (t, x) -> t .* x; is_autonomous=false, is_variable=false
                )
                flow = Flows.Flow(vf)

                Test.@test Traits.time_dependence(flow) === Traits.NonAutonomous
                Test.@test Traits.variable_dependence(flow) === Traits.Fixed
            end

            Test.@testset "Autonomous NonFixed" begin
                vf = Data.VectorField(
                    (x, v) -> x .+ v; is_autonomous=true, is_variable=true
                )
                flow = Flows.Flow(vf)

                Test.@test Traits.time_dependence(flow) === Traits.Autonomous
                Test.@test Traits.variable_dependence(flow) === Traits.NonFixed
            end

            Test.@testset "NonAutonomous NonFixed" begin
                vf = Data.VectorField(
                    (t, x, v) -> t .* x .+ v; is_autonomous=false, is_variable=true
                )
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
                Test.@test Traits.time_dependence(sys_direct) ===
                    Traits.time_dependence(sys_from_flow)
                Test.@test Traits.variable_dependence(sys_direct) ===
                    Traits.variable_dependence(sys_from_flow)
            end
        end

        # ====================================================================
        # UNIT TESTS - HamiltonianFlow constructor from HamiltonianVectorField
        # ====================================================================

        Test.@testset "HamiltonianFlow constructor from HamiltonianVectorField" begin
            Test.@testset "default constructor" begin
                hvf = Data.HamiltonianVectorField(
                    (x, p) -> (x, -p); is_autonomous=true, is_variable=false
                )
                flow = Flows.Flow(hvf)

                Test.@test flow isa Flows.HamiltonianFlow
                Test.@test flow isa Flows.AbstractFlow
                Test.@test flow.system isa Systems.HamiltonianVectorFieldSystem
                Test.@test flow.integrator isa Integrators.AbstractIntegrator
            end

            Test.@testset "with keyword options" begin
                hvf = Data.HamiltonianVectorField(
                    (x, p) -> (x, -p); is_autonomous=true, is_variable=false
                )
                flow = Flows.Flow(hvf; reltol=1e-10)

                Test.@test flow isa Flows.HamiltonianFlow
                Test.@test flow.integrator isa Integrators.AbstractIntegrator
            end
        end

        # ====================================================================
        # UNIT TESTS - HamiltonianFlow constructor from PseudoHamiltonianVectorField + law
        # ====================================================================

        Test.@testset "HamiltonianFlow constructor from PseudoHamiltonianVectorField + law" begin
            Test.@testset "default constructor" begin
                h̃vf = Data.PseudoHamiltonianVectorField(
                    (x, p, u) -> (u, zero(p)); is_autonomous=true, is_variable=false
                )
                law = Data.DynClosedLoop((x, p) -> p)
                flow = Flows.Flow(h̃vf, law)

                Test.@test flow isa Flows.HamiltonianFlow
                Test.@test flow isa Flows.AbstractFlow
                Test.@test flow.system isa Systems.PseudoHamiltonianVectorFieldSystem
                Test.@test flow.integrator isa Integrators.AbstractIntegrator
            end

            Test.@testset "with keyword options" begin
                h̃vf = Data.PseudoHamiltonianVectorField(
                    (x, p, u) -> (u, zero(p)); is_autonomous=true, is_variable=false
                )
                law = Data.DynClosedLoop((x, p) -> p)
                flow = Flows.Flow(h̃vf, law; reltol=1e-10)

                Test.@test flow isa Flows.HamiltonianFlow
                Test.@test flow.integrator isa Integrators.AbstractIntegrator
            end

            Test.@testset "matches analytic solution" begin
                # h̃vf = (u, 0): ẋ = u, ṗ = 0. Feedback u = p (stationary point of
                # H̃ = p·u - 0.5u²) ⟹ ẋ = p, ṗ = 0 ⟹ xf = x0 + p0, pf = p0 at tf = 1.
                # Same example as the Flow(h̃, law) compatibility page, provided here
                # pre-differentiated instead of via AD.
                h̃vf = Data.PseudoHamiltonianVectorField(
                    (x, p, u) -> (u, zero(p)); is_autonomous=true, is_variable=false
                )
                law = Data.DynClosedLoop((x, p) -> p)
                flow = Flows.Flow(h̃vf, law; reltol=1e-8)

                x0, p0 = 1.0, 0.5
                xf, pf = flow(0.0, x0, p0, 1.0)
                Test.@test xf ≈ x0 + p0 atol=1e-6
                Test.@test pf ≈ p0 atol=1e-6
            end

            Test.@testset "OpenLoop law is rejected" begin
                h̃vf = Data.PseudoHamiltonianVectorField(
                    (x, p, u) -> (u, zero(p)); is_autonomous=true, is_variable=false
                )
                law = Data.OpenLoop(t -> 1.0)
                Test.@test_throws Exceptions.PreconditionError Flows.Flow(h̃vf, law)
            end

            Test.@testset "ClosedLoop law is rejected" begin
                h̃vf = Data.PseudoHamiltonianVectorField(
                    (x, p, u) -> (u, zero(p)); is_autonomous=true, is_variable=false
                )
                law = Data.ClosedLoop(x -> -x)
                Test.@test_throws Exceptions.PreconditionError Flows.Flow(h̃vf, law)
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
