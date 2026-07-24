module TestPseudoHamiltonianVectorFieldSystem

using Test: Test
import CTBase.Exceptions
import CTBase.Data: Data
import CTBase.Traits: Traits
import CTFlows.Systems: Systems
import CTFlows.Configs: Configs

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

function test_pseudo_hamiltonian_vector_field_system()
    Test.@testset "Pseudo-Hamiltonian Vector Field System Tests" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ====================================================================
        # UNIT TESTS - Construction
        # ====================================================================

        Test.@testset "Construction" begin
            h̃vf = Data.PseudoHamiltonianVectorField(
                (x, p, u) -> (u, -p); is_autonomous=true, is_variable=false
            )
            law = Data.DynClosedLoop((x, p) -> x)
            sys = Systems.PseudoHamiltonianVectorFieldSystem(h̃vf, law)
            Test.@test sys isa Systems.PseudoHamiltonianVectorFieldSystem
            Test.@test sys isa Systems.AbstractHamiltonianSystem

            # Hierarchy check: supertype (2-param alias, AD via ad_trait)
            Test.@test sys isa
                Systems.AbstractHamiltonianSystem{Traits.Autonomous,Traits.Fixed}
        end

        Test.@testset "ad_trait" begin
            h̃vf = Data.PseudoHamiltonianVectorField(
                (x, p, u) -> (u, -p); is_autonomous=true, is_variable=false
            )
            law = Data.DynClosedLoop((x, p) -> x)
            sys = Systems.PseudoHamiltonianVectorFieldSystem(h̃vf, law)

            Test.@test Traits.ad_trait(sys) === Traits.WithoutAD
            Test.@test Test.@inferred Traits.ad_trait(sys) === Traits.WithoutAD
        end

        # ====================================================================
        # UNIT TESTS - build_system
        # ====================================================================

        Test.@testset "build_system" begin
            h̃vf = Data.PseudoHamiltonianVectorField(
                (x, p, u) -> (u, -p); is_autonomous=true, is_variable=false
            )
            law = Data.DynClosedLoop((x, p) -> x)

            sys = Systems.build_system(h̃vf, law)
            Test.@test sys isa Systems.PseudoHamiltonianVectorFieldSystem
        end

        # ====================================================================
        # UNIT TESTS - get_ip_rhs (lazy in-place)
        # ====================================================================

        Test.@testset "get_ip_rhs" begin
            h̃vf = Data.PseudoHamiltonianVectorField(
                (x, p, u) -> (u, -p); is_autonomous=true, is_variable=false
            )
            law = Data.DynClosedLoop((x, p) -> x)
            sys = Systems.PseudoHamiltonianVectorFieldSystem(h̃vf, law)

            x0 = [1.0, 2.0]
            p0 = [3.0, 4.0]
            config = Configs.HamiltonianEndPointConfig(0.0, x0, p0, 1.0)
            rhs = Systems.get_ip_rhs(sys, config)
            Test.@test rhs isa Systems.AbstractIPPseudoHVFRHS

            u = [1.0, 2.0, 3.0, 4.0]  # x = [1, 2], p = [3, 4]
            du = zeros(4)
            p = Systems.ODEParameters(nothing)
            rhs(du, u, p, 0.0)

            # law: u_ = x = [1, 2]; h̃vf: dx = u_, dp = -p
            Test.@test du[1:2] == [1.0, 2.0]
            Test.@test du[3:4] == [-3.0, -4.0]

            # Matrix (batch) form
            x0_mat = [1.0 2.0; 3.0 4.0]
            p0_mat = [5.0 6.0; 7.0 8.0]
            config_mat = Configs.HamiltonianEndPointConfig(0.0, x0_mat, p0_mat, 1.0)
            rhs_mat = Systems.get_ip_rhs(sys, config_mat)
            u_mat = [1.0 2.0; 3.0 4.0; 5.0 6.0; 7.0 8.0]  # x = [1 2; 3 4], p = [5 6; 7 8]
            du_mat = zeros(4, 2)
            rhs_mat(du_mat, u_mat, p, 0.0)
            Test.@test du_mat ≈ [1.0 2.0; 3.0 4.0; -5.0 -6.0; -7.0 -8.0] atol=1e-10
        end

        # ====================================================================
        # UNIT TESTS - get_oop_rhs (lazy out-of-place)
        # ====================================================================

        Test.@testset "get_oop_rhs" begin
            h̃vf = Data.PseudoHamiltonianVectorField(
                (x, p, u) -> (u, -p); is_autonomous=true, is_variable=false
            )
            law = Data.DynClosedLoop((x, p) -> x)
            sys = Systems.PseudoHamiltonianVectorFieldSystem(h̃vf, law)

            x0 = [1.0, 2.0]
            p0 = [3.0, 4.0]
            config = Configs.HamiltonianEndPointConfig(0.0, x0, p0, 1.0)
            rhs_oop = Systems.get_oop_rhs(sys, config)
            Test.@test rhs_oop isa Systems.AbstractOoPPseudoHVFRHS

            u = [1.0, 2.0, 3.0, 4.0]
            p = Systems.ODEParameters(nothing)
            du = rhs_oop(u, p, 0.0)

            Test.@test du[1:2] == [1.0, 2.0]
            Test.@test du[3:4] == [-3.0, -4.0]
        end

        # ====================================================================
        # UNIT TESTS - Complex numbers
        # ====================================================================

        Test.@testset "Complex numbers" begin
            h̃vf = Data.PseudoHamiltonianVectorField(
                (x, p, u) -> (u, -p); is_autonomous=true, is_variable=false
            )
            law = Data.DynClosedLoop((x, p) -> x)
            sys = Systems.PseudoHamiltonianVectorFieldSystem(h̃vf, law)
            p_param = Systems.ODEParameters(nothing)

            x0 = [1.0 + 2.0im]
            p0 = [3.0 + 4.0im]
            config = Configs.HamiltonianEndPointConfig(0.0, x0, p0, 1.0)
            rhs = Systems.get_ip_rhs(sys, config)
            u = [1.0 + 2.0im, 3.0 + 4.0im]
            du = zeros(ComplexF64, 2)
            rhs(du, u, p_param, 0.0)
            Test.@test du ≈ [1.0 + 2.0im, -3.0 - 4.0im] atol=1e-10

            rhs_oop = Systems.get_oop_rhs(sys, config)
            du_oop = rhs_oop(u, p_param, 0.0)
            Test.@test du_oop ≈ [1.0 + 2.0im, -3.0 - 4.0im] atol=1e-10
        end

        # ====================================================================
        # UNIT TESTS - variable_costate_trait
        # ====================================================================

        Test.@testset "variable_costate_trait" begin
            # Fixed system -> NoVariableCostate
            h̃vf_fixed = Data.PseudoHamiltonianVectorField(
                (x, p, u) -> (u, -p); is_autonomous=true, is_variable=false
            )
            law_fixed = Data.DynClosedLoop((x, p) -> x)
            sys_fixed = Systems.PseudoHamiltonianVectorFieldSystem(h̃vf_fixed, law_fixed)
            Test.@test Traits.variable_costate_trait(sys_fixed) === Traits.NoVariableCostate

            # NonFixed system -> SupportsVariableCostate
            h̃vf_nonfixed = Data.PseudoHamiltonianVectorField(
                (x, p, u, v) -> (u ./ sum(v), -p); is_autonomous=true, is_variable=true
            )
            law_nonfixed = Data.DynClosedLoop((x, p, v) -> x; is_variable=true)
            sys_nonfixed = Systems.PseudoHamiltonianVectorFieldSystem(
                h̃vf_nonfixed, law_nonfixed
            )
            Test.@test Traits.variable_costate_trait(sys_nonfixed) ===
                Traits.SupportsVariableCostate
        end

        # ====================================================================
        # UNIT TESTS - get_ip_rhs_augmented (just verify it builds without error)
        # ====================================================================

        Test.@testset "get_ip_rhs_augmented" begin
            h̃vf = Data.PseudoHamiltonianVectorField(
                (x, p, u, v; variable_costate::Bool=false) ->
                    variable_costate ? (u, -p, zeros(1)) : (u, -p);
                is_autonomous=true,
                is_variable=true,
            )
            law = Data.DynClosedLoop((x, p, v) -> x; is_variable=true)
            sys = Systems.PseudoHamiltonianVectorFieldSystem(h̃vf, law)

            Test.@testset "OOP builds" begin
                x0, p0 = [1.0, 2.0], [3.0, 4.0]
                pv0 = [0.5]
                config = Configs.AugmentedHamiltonianEndPointConfig(0.0, x0, p0, pv0, 1.0)
                rhs_aug = Systems.get_ip_rhs_augmented(sys, config)
                Test.@test rhs_aug isa Systems.AbstractIPPseudoHVFRHS
            end

            Test.@testset "IP builds" begin
                h̃vf_ip = Data.PseudoHamiltonianVectorField(
                    (dx, dp, x, p, u, v; dpv=nothing, variable_costate::Bool=false) ->
                        nothing;
                    is_autonomous=true,
                    is_variable=true,
                    is_inplace=true,
                )
                sys_ip = Systems.PseudoHamiltonianVectorFieldSystem(h̃vf_ip, law)
                x0, p0 = [1.0, 2.0], [3.0, 4.0]
                pv0 = [0.5]
                config = Configs.AugmentedHamiltonianEndPointConfig(0.0, x0, p0, pv0, 1.0)
                rhs_aug_ip = Systems.get_ip_rhs_augmented(sys_ip, config)
                Test.@test rhs_aug_ip isa Systems.AbstractIPPseudoHVFRHS
            end
        end

        # ====================================================================
        # UNIT TESTS - Base.show
        # ====================================================================

        Test.@testset "Base.show" begin
            h̃vf = Data.PseudoHamiltonianVectorField(
                (x, p, u) -> (u, -p); is_autonomous=true, is_variable=false
            )
            law = Data.DynClosedLoop((x, p) -> x)
            sys = Systems.PseudoHamiltonianVectorFieldSystem(h̃vf, law)

            str = sprint(show, sys)
            Test.@test occursin("PseudoHamiltonianVectorFieldSystem", str)
            Test.@test_nowarn sprint(show, MIME("text/plain"), sys)
        end
    end
end

end # module

# CRITICAL: Redefine in outer scope for TestRunner
function test_pseudo_hamiltonian_vector_field_system()
    return TestPseudoHamiltonianVectorFieldSystem.test_pseudo_hamiltonian_vector_field_system()
end
