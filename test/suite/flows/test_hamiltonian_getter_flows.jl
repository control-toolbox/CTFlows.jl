module TestHamiltonianGetterFlows

using Test: Test
using ADTypes: ADTypes
using DifferentiationInterface: DifferentiationInterface
using ForwardDiff: ForwardDiff  # triggers DifferentiationInterfaceForwardDiff (provides PushforwardFast)
import CTBase.Traits
import CTBase.Data
import CTFlows.Systems
import CTBase.Differentiation
import CTFlows.Flows
import CTFlows.Integrators

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

# ==============================================================================
# Fake integrator for testing (avoid ExtensionError from SciML)
# ==============================================================================

struct MockIntegrator <: Integrators.AbstractIntegrator end

# ==============================================================================
# Test function
# ==============================================================================

function test_hamiltonian_getter_flows()
    Test.@testset "Hamiltonian Getter Flows Tests" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ====================================================================
        # UNIT TESTS - Trait preservation
        # ====================================================================

        Test.@testset "UNIT TESTS - Trait preservation" begin
            Test.@testset "Autonomous/Fixed preserves traits" begin
                h = Data.Hamiltonian(
                    (x, p) -> 0.5 * sum(x .^ 2) + 0.5 * sum(p .^ 2);
                    is_autonomous=true,
                    is_variable=false,
                )
                backend = Differentiation.DifferentiationInterface(;
                    ad_backend=ADTypes.AutoForwardDiff()
                )
                sys = Systems.HamiltonianSystem(h, backend)
                integrator = MockIntegrator()
                flow = Flows.HamiltonianFlow(sys, integrator)

                hvf = Systems.hamiltonian_vector_field(flow; inplace=false)
                Test.@test Traits.time_dependence(hvf) == Traits.Autonomous
                Test.@test Traits.variable_dependence(hvf) == Traits.Fixed
                Test.@test Traits.mutability(hvf) == Traits.OutOfPlace
            end

            Test.@testset "InPlace preserves mutability trait" begin
                h = Data.Hamiltonian(
                    (x, p) -> 0.5 * sum(x .^ 2) + 0.5 * sum(p .^ 2);
                    is_autonomous=true,
                    is_variable=false,
                )
                backend = Differentiation.DifferentiationInterface(;
                    ad_backend=ADTypes.AutoForwardDiff()
                )
                sys = Systems.HamiltonianSystem(h, backend)
                integrator = MockIntegrator()
                flow = Flows.HamiltonianFlow(sys, integrator)

                hvf_ip = Systems.hamiltonian_vector_field(flow; inplace=true)
                hvf_oop = Systems.hamiltonian_vector_field(flow; inplace=false)
                Test.@test Traits.mutability(hvf_ip) == Traits.InPlace
                Test.@test Traits.mutability(hvf_oop) == Traits.OutOfPlace
            end
        end

        # ====================================================================
        # INTEGRATION TESTS - Flow delegation by trait combination
        # ====================================================================

        Test.@testset "INTEGRATION TESTS - Flow delegation" begin
            Test.@testset "Autonomous/Fixed — HamiltonianSystem" begin
                h = Data.Hamiltonian(
                    (x, p) -> 0.5 * sum(x .^ 2) + 0.5 * sum(p .^ 2);
                    is_autonomous=true,
                    is_variable=false,
                )
                backend = Differentiation.DifferentiationInterface(;
                    ad_backend=ADTypes.AutoForwardDiff()
                )
                sys = Systems.HamiltonianSystem(h, backend)
                integrator = MockIntegrator()
                flow = Flows.HamiltonianFlow(sys, integrator)

                # OOP via Systems
                hvf_from_flow_systems = Systems.hamiltonian_vector_field(
                    flow; inplace=false
                )
                hvf_from_sys = Systems.hamiltonian_vector_field(sys; inplace=false)

                Test.@test hvf_from_flow_systems isa Data.HamiltonianVectorField
                Test.@test hvf_from_sys isa Data.HamiltonianVectorField

                x = [1.0, 2.0]
                p = [0.5, 1.5]
                result_flow_systems = hvf_from_flow_systems.f(x, p)
                result_sys = hvf_from_sys.f(x, p)

                Test.@test result_flow_systems[1] ≈ result_sys[1]
                Test.@test result_flow_systems[2] ≈ result_sys[2]
                Test.@test result_flow_systems[1] ≈ p
                Test.@test result_flow_systems[2] ≈ -x

                # OOP via Flows (re-export)
                hvf_from_flow_flows = Flows.hamiltonian_vector_field(flow; inplace=false)
                Test.@test hvf_from_flow_flows isa Data.HamiltonianVectorField
                result_flow_flows = hvf_from_flow_flows.f(x, p)
                Test.@test result_flow_flows[1] ≈ result_sys[1]
                Test.@test result_flow_flows[2] ≈ result_sys[2]

                # IP via Systems
                hvf_ip = Systems.hamiltonian_vector_field(flow; inplace=true)
                Test.@test Traits.mutability(hvf_ip) == Traits.InPlace
                dx = similar(x)
                dp = similar(p)
                result_ip = hvf_ip.f(dx, dp, x, p)
                Test.@test result_ip === nothing
                Test.@test dx ≈ p
                Test.@test dp ≈ -x
            end

            Test.@testset "NonAutonomous/Fixed — HamiltonianSystem" begin
                h = Data.Hamiltonian(
                    (t, x, p) -> 0.5 * sum(x .^ 2) + 0.5 * sum(p .^ 2);
                    is_autonomous=false,
                    is_variable=false,
                )
                backend = Differentiation.DifferentiationInterface(;
                    ad_backend=ADTypes.AutoForwardDiff()
                )
                sys = Systems.HamiltonianSystem(h, backend)
                integrator = MockIntegrator()
                flow = Flows.HamiltonianFlow(sys, integrator)

                hvf = Systems.hamiltonian_vector_field(flow; inplace=false)
                Test.@test Traits.time_dependence(hvf) == Traits.NonAutonomous

                t = 0.5
                x = [1.0, 2.0]
                p = [0.5, 1.5]
                result = hvf.f(t, x, p)
                Test.@test result[1] ≈ p
                Test.@test result[2] ≈ -x
            end

            Test.@testset "Autonomous/NonFixed — HamiltonianSystem" begin
                h = Data.Hamiltonian(
                    (x, p, v) -> 0.5 * sum(x .^ 2) + 0.5 * sum(p .^ 2) + 0.5 * sum(v .^ 2);
                    is_autonomous=true,
                    is_variable=true,
                )
                backend = Differentiation.DifferentiationInterface(;
                    ad_backend=ADTypes.AutoForwardDiff()
                )
                sys = Systems.HamiltonianSystem(h, backend)
                integrator = MockIntegrator()
                flow = Flows.HamiltonianFlow(sys, integrator)

                hvf = Systems.hamiltonian_vector_field(flow; inplace=false)
                Test.@test Traits.variable_dependence(hvf) == Traits.NonFixed

                x = [1.0, 2.0]
                p = [0.5, 1.5]
                v = [0.1, 0.2]

                # Without variable_costate
                result = hvf.f(x, p, v)
                Test.@test result[1] ≈ p
                Test.@test result[2] ≈ -x

                # With variable_costate
                result_vc = hvf.f(x, p, v; variable_costate=true)
                Test.@test result_vc[1] ≈ p
                Test.@test result_vc[2] ≈ -x
                Test.@test result_vc[3] ≈ -v
            end

            Test.@testset "NonAutonomous/NonFixed — HamiltonianSystem" begin
                h = Data.Hamiltonian(
                    (t, x, p, v) ->
                        0.5 * sum(x .^ 2) + 0.5 * sum(p .^ 2) + 0.5 * sum(v .^ 2);
                    is_autonomous=false,
                    is_variable=true,
                )
                backend = Differentiation.DifferentiationInterface(;
                    ad_backend=ADTypes.AutoForwardDiff()
                )
                sys = Systems.HamiltonianSystem(h, backend)
                integrator = MockIntegrator()
                flow = Flows.HamiltonianFlow(sys, integrator)

                hvf = Systems.hamiltonian_vector_field(flow; inplace=false)
                Test.@test Traits.time_dependence(hvf) == Traits.NonAutonomous
                Test.@test Traits.variable_dependence(hvf) == Traits.NonFixed

                t = 0.5
                x = [1.0, 2.0]
                p = [0.5, 1.5]
                v = [0.1, 0.2]

                # Without variable_costate
                result = hvf.f(t, x, p, v)
                Test.@test result[1] ≈ p
                Test.@test result[2] ≈ -x

                # With variable_costate
                result_vc = hvf.f(t, x, p, v; variable_costate=true)
                Test.@test result_vc[1] ≈ p
                Test.@test result_vc[2] ≈ -x
                Test.@test result_vc[3] ≈ -v
            end
        end

        # ====================================================================
        # CONTRACT TESTS - HamiltonianVectorFieldSystem delegation
        # ====================================================================

        Test.@testset "CONTRACT TESTS - HamiltonianVectorFieldSystem" begin
            Test.@testset "Identity delegation for all trait combinations" begin
                # Autonomous/Fixed
                f1 = (x, p) -> (p, -x)
                hvf1 = Data.HamiltonianVectorField(
                    f1; is_autonomous=true, is_variable=false
                )
                sys1 = Systems.HamiltonianVectorFieldSystem(hvf1)
                flow1 = Flows.HamiltonianFlow(sys1, MockIntegrator())
                Test.@test Systems.hamiltonian_vector_field(flow1) === hvf1
                Test.@test Traits.time_dependence(
                    Systems.hamiltonian_vector_field(flow1)
                ) == Traits.Autonomous
                Test.@test Traits.variable_dependence(
                    Systems.hamiltonian_vector_field(flow1)
                ) == Traits.Fixed

                # NonAutonomous/Fixed
                f2 = (t, x, p) -> (p, -x)
                hvf2 = Data.HamiltonianVectorField(
                    f2; is_autonomous=false, is_variable=false
                )
                sys2 = Systems.HamiltonianVectorFieldSystem(hvf2)
                flow2 = Flows.HamiltonianFlow(sys2, MockIntegrator())
                Test.@test Systems.hamiltonian_vector_field(flow2) === hvf2
                Test.@test Traits.time_dependence(
                    Systems.hamiltonian_vector_field(flow2)
                ) == Traits.NonAutonomous

                # Autonomous/NonFixed
                f3 = (x, p, v) -> (p, -x)
                hvf3 = Data.HamiltonianVectorField(f3; is_autonomous=true, is_variable=true)
                sys3 = Systems.HamiltonianVectorFieldSystem(hvf3)
                flow3 = Flows.HamiltonianFlow(sys3, MockIntegrator())
                Test.@test Systems.hamiltonian_vector_field(flow3) === hvf3
                Test.@test Traits.variable_dependence(
                    Systems.hamiltonian_vector_field(flow3)
                ) == Traits.NonFixed

                # NonAutonomous/NonFixed
                f4 = (t, x, p, v) -> (p, -x)
                hvf4 = Data.HamiltonianVectorField(
                    f4; is_autonomous=false, is_variable=true
                )
                sys4 = Systems.HamiltonianVectorFieldSystem(hvf4)
                flow4 = Flows.HamiltonianFlow(sys4, MockIntegrator())
                Test.@test Systems.hamiltonian_vector_field(flow4) === hvf4
                Test.@test Traits.time_dependence(
                    Systems.hamiltonian_vector_field(flow4)
                ) == Traits.NonAutonomous
                Test.@test Traits.variable_dependence(
                    Systems.hamiltonian_vector_field(flow4)
                ) == Traits.NonFixed
            end
        end

        # ====================================================================
        # vector_field getter (polymorphic: Hamiltonian → X_H, state → the VF)
        # ====================================================================

        Test.@testset "vector_field getter" begin
            Test.@testset "Hamiltonian flow → X_H (same as hamiltonian_vector_field)" begin
                h = Data.Hamiltonian(
                    (x, p) -> 0.5 * sum(x .^ 2) + 0.5 * sum(p .^ 2);
                    is_autonomous=true,
                    is_variable=false,
                )
                backend = Differentiation.DifferentiationInterface(;
                    ad_backend=ADTypes.AutoForwardDiff()
                )
                flow = Flows.HamiltonianFlow(
                    Systems.HamiltonianSystem(h, backend), MockIntegrator()
                )
                xv = Systems.vector_field(flow)
                hv = Systems.hamiltonian_vector_field(flow)
                Test.@test xv isa Data.HamiltonianVectorField
                x = [1.0, 2.0]
                p = [0.5, 1.5]
                Test.@test xv.f(x, p) == hv.f(x, p)
            end

            Test.@testset "state flow → the underlying vector field" begin
                vf = Data.VectorField(x -> -x; is_autonomous=true, is_variable=false)
                sflow = Flows.StateFlow(Systems.VectorFieldSystem(vf), MockIntegrator())
                Test.@test Systems.vector_field(sflow) === vf
                Test.@test Flows.vector_field(sflow) === vf   # re-export
            end
        end

        # ====================================================================
        # EXPORTS
        # ====================================================================

        Test.@testset "EXPORTS" begin
            Test.@testset "hamiltonian_vector_field is accessible via Systems" begin
                Test.@test isdefined(Systems, :hamiltonian_vector_field)
            end

            Test.@testset "hamiltonian_vector_field is re-exported from Flows" begin
                Test.@test isdefined(Flows, :hamiltonian_vector_field)
            end

            Test.@testset "vector_field is accessible via Systems and re-exported from Flows" begin
                Test.@test isdefined(Systems, :vector_field)
                Test.@test isdefined(Flows, :vector_field)
            end
        end
    end
end

end # module

test_hamiltonian_getter_flows() = TestHamiltonianGetterFlows.test_hamiltonian_getter_flows()
