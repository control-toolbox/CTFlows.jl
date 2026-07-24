module TestPseudoHVFRHSFunctors

using Test: Test
import CTBase.Data: Data
import CTFlows.Systems: Systems
import CTBase.Traits: Traits
import StaticArrays: SA, SVector

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

# =============================================================================
# Fake functions and control laws for testing (top-level)
# =============================================================================

const FakePHVFOoP = (x, p, u) -> (u, -p)
const FakePHVFIP = (dx, dp, x, p, u) -> (dx.=u; dp.=(-p))

const FakePHVFAug = (x, p, u, v; variable_costate::Bool=false) -> (u, -p, zeros(1))
const FakePHVFAugIP =
    (dx, dp, x, p, u, v; dpv=nothing, variable_costate::Bool=false) -> begin
        dx .= u
        dp .= -p
        if dpv !== nothing
            dpv .= zeros(1)
        end
        nothing
    end

const FakePHVFAugNA = (t, x, p, u, v; variable_costate::Bool=false) -> (u, -p, zeros(1))
const FakePHVFAugIPNA =
    (dx, dp, t, x, p, u, v; dpv=nothing, variable_costate::Bool=false) -> begin
        dx .= u
        dp .= -p
        if dpv !== nothing
            dpv .= zeros(1)
        end
        nothing
    end

# Uniform-call control laws: u(t, x, p, v). u_ = x (identity feedback).
const _law_fixed = Data.DynClosedLoop((x, p) -> x)
const _law_nonfixed = Data.DynClosedLoop((x, p, v) -> x; is_variable=true)

function test_pseudo_hvf_rhs_functors()
    Test.@testset "PseudoHVF RHS Functors Tests" verbose=VERBOSE showtiming=SHOWTIMING begin

        # =============================================================================
        # Test hierarchy
        # =============================================================================

        Test.@testset "Abstract types" begin
            phvf_oop = Data.PseudoHamiltonianVectorField(
                FakePHVFOoP; is_autonomous=true, is_variable=false
            )
            ip_oop = Systems.IPPseudoHVFOoPRHS(phvf_oop, _law_fixed, 2, identity, identity)
            oop_oop = Systems.OoPPseudoHVFOoPRHS(
                phvf_oop, _law_fixed, 2, identity, identity
            )

            Test.@test ip_oop isa Systems.AbstractIPPseudoHVFRHS
            Test.@test ip_oop isa Systems.AbstractRHS{Traits.InPlace}
            Test.@test oop_oop isa Systems.AbstractOoPPseudoHVFRHS
            Test.@test oop_oop isa Systems.AbstractRHS{Traits.OutOfPlace}

            phvf_ip = Data.PseudoHamiltonianVectorField(
                FakePHVFIP; is_autonomous=true, is_variable=false, is_inplace=true
            )
            ip_ip = Systems.IPPseudoHVFIpRHS(phvf_ip, _law_fixed, 2, identity, identity)
            oop_ip = Systems.OoPPseudoHVFIpRHS(phvf_ip, _law_fixed, 2, identity, identity)
            oop_finalize = Systems.OoPPseudoHVFIpFinalizeRHS(
                phvf_ip, _law_fixed, 2, identity, identity
            )

            Test.@test ip_ip isa Systems.AbstractIPPseudoHVFRHS
            Test.@test ip_ip isa Systems.AbstractRHS{Traits.InPlace}
            Test.@test oop_ip isa Systems.AbstractOoPPseudoHVFRHS
            Test.@test oop_ip isa Systems.AbstractRHS{Traits.OutOfPlace}
            Test.@test oop_finalize isa Systems.AbstractOoPPseudoHVFRHS
            Test.@test oop_finalize isa Systems.AbstractRHS{Traits.OutOfPlace}
        end

        # =============================================================================
        # Test IPPseudoHVFOoPRHS
        # =============================================================================

        Test.@testset "IPPseudoHVFOoPRHS — call" begin
            phvf = Data.PseudoHamiltonianVectorField(
                FakePHVFOoP; is_autonomous=true, is_variable=false
            )
            r = Systems.IPPseudoHVFOoPRHS(phvf, _law_fixed, 2, identity, identity)

            du = zeros(4)
            u = [1.0, 2.0, 3.0, 4.0]
            λ = Systems.ODEParameters(nothing)
            t = 0.0

            r(du, u, λ, t)
            # law: u_ = x = [1, 2]; h̃vf: dx = u_, dp = -p
            Test.@test du[1:2] == [1.0, 2.0]
            Test.@test du[3:4] == [-3.0, -4.0]
        end

        # =============================================================================
        # Test IPPseudoHVFIpRHS
        # =============================================================================

        Test.@testset "IPPseudoHVFIpRHS — call" begin
            phvf = Data.PseudoHamiltonianVectorField(
                FakePHVFIP; is_autonomous=true, is_variable=false, is_inplace=true
            )
            r = Systems.IPPseudoHVFIpRHS(phvf, _law_fixed, 2, identity, identity)

            du = zeros(4)
            u = [1.0, 2.0, 3.0, 4.0]
            λ = Systems.ODEParameters(nothing)
            t = 0.0

            r(du, u, λ, t)
            Test.@test du[1:2] == [1.0, 2.0]
            Test.@test du[3:4] == [-3.0, -4.0]
        end

        # =============================================================================
        # Test OoPPseudoHVFOoPRHS
        # =============================================================================

        Test.@testset "OoPPseudoHVFOoPRHS — call" begin
            phvf = Data.PseudoHamiltonianVectorField(
                FakePHVFOoP; is_autonomous=true, is_variable=false
            )
            r = Systems.OoPPseudoHVFOoPRHS(phvf, _law_fixed, 2, identity, identity)

            u = [1.0, 2.0, 3.0, 4.0]
            λ = Systems.ODEParameters(nothing)
            t = 0.0

            result = r(u, λ, t)
            Test.@test result[1:2] == [1.0, 2.0]
            Test.@test result[3:4] == [-3.0, -4.0]
        end

        # =============================================================================
        # Test OoPPseudoHVFIpRHS
        # =============================================================================

        Test.@testset "OoPPseudoHVFIpRHS — call" begin
            phvf = Data.PseudoHamiltonianVectorField(
                FakePHVFIP; is_autonomous=true, is_variable=false, is_inplace=true
            )
            r = Systems.OoPPseudoHVFIpRHS(phvf, _law_fixed, 2, identity, identity)

            u = [1.0, 2.0, 3.0, 4.0]
            λ = Systems.ODEParameters(nothing)
            t = 0.0

            result = r(u, λ, t)
            Test.@test result[1:2] == [1.0, 2.0]
            Test.@test result[3:4] == [-3.0, -4.0]
        end

        # =============================================================================
        # Test OoPPseudoHVFIpFinalizeRHS
        # =============================================================================

        Test.@testset "OoPPseudoHVFIpFinalizeRHS — call SVector" begin
            phvf = Data.PseudoHamiltonianVectorField(
                FakePHVFIP; is_autonomous=true, is_variable=false, is_inplace=true
            )
            r = Systems.OoPPseudoHVFIpFinalizeRHS(phvf, _law_fixed, 2, identity, identity)

            u = SA[1.0, 2.0, 3.0, 4.0]
            λ = Systems.ODEParameters(nothing)
            t = 0.0

            result = r(u, λ, t)
            Test.@test result isa SVector
            Test.@test result[1:2] == SA[1.0, 2.0]
            Test.@test result[3:4] == SA[-3.0, -4.0]
        end

        # =============================================================================
        # Test augmented functors
        # =============================================================================

        Test.@testset "IPPseudoHVFOoPAugRHS — call" begin
            # Autonomous
            phvf = Data.PseudoHamiltonianVectorField(
                FakePHVFAug; is_autonomous=true, is_variable=true
            )
            r = Systems.IPPseudoHVFOoPAugRHS(
                phvf, _law_nonfixed, 2, 1, identity, identity
            )

            du = zeros(5)
            u = [1.0, 2.0, 3.0, 4.0, 0.0]
            λ = Systems.ODEParameters(0.5)
            t = 0.0

            r(du, u, λ, t)
            # law: u_ = x = [1, 2]; h̃vf aug: dx = u_, dp = -p, dpv = zeros(1)
            Test.@test du[1:2] == [1.0, 2.0]
            Test.@test du[3:4] == [-3.0, -4.0]
            Test.@test du[5] == 0.0

            # NonAutonomous
            phvf_na = Data.PseudoHamiltonianVectorField(
                FakePHVFAugNA; is_autonomous=false, is_variable=true
            )
            r_na = Systems.IPPseudoHVFOoPAugRHS(
                phvf_na, _law_nonfixed, 2, 1, identity, identity
            )

            du = zeros(5)
            r_na(du, u, λ, t)
            Test.@test du[1:2] == [1.0, 2.0]
            Test.@test du[3:4] == [-3.0, -4.0]
            Test.@test du[5] == 0.0
        end

        Test.@testset "IPPseudoHVFIpAugRHS — call" begin
            # Autonomous
            phvf = Data.PseudoHamiltonianVectorField(
                FakePHVFAugIP; is_autonomous=true, is_variable=true, is_inplace=true
            )
            r = Systems.IPPseudoHVFIpAugRHS(
                phvf, _law_nonfixed, 2, 1, identity, identity
            )

            du = zeros(5)
            u = [1.0, 2.0, 3.0, 4.0, 0.0]
            λ = Systems.ODEParameters(0.5)
            t = 0.0

            r(du, u, λ, t)
            Test.@test du[1:2] == [1.0, 2.0]
            Test.@test du[3:4] == [-3.0, -4.0]

            # NonAutonomous
            phvf_na = Data.PseudoHamiltonianVectorField(
                FakePHVFAugIPNA; is_autonomous=false, is_variable=true, is_inplace=true
            )
            r_na = Systems.IPPseudoHVFIpAugRHS(
                phvf_na, _law_nonfixed, 2, 1, identity, identity
            )

            du = zeros(5)
            r_na(du, u, λ, t)
            Test.@test du[1:2] == [1.0, 2.0]
            Test.@test du[3:4] == [-3.0, -4.0]
        end

        # =============================================================================
        # Test type stability
        # =============================================================================

        Test.@testset "Type Stability" begin
            phvf_oop = Data.PseudoHamiltonianVectorField(
                FakePHVFOoP; is_autonomous=true, is_variable=false
            )
            phvf_ip = Data.PseudoHamiltonianVectorField(
                FakePHVFIP; is_autonomous=true, is_variable=false, is_inplace=true
            )

            ip_oop = Systems.IPPseudoHVFOoPRHS(phvf_oop, _law_fixed, 2, identity, identity)
            oop_oop = Systems.OoPPseudoHVFOoPRHS(
                phvf_oop, _law_fixed, 2, identity, identity
            )
            ip_ip = Systems.IPPseudoHVFIpRHS(phvf_ip, _law_fixed, 2, identity, identity)
            oop_ip = Systems.OoPPseudoHVFIpRHS(phvf_ip, _law_fixed, 2, identity, identity)

            du = zeros(4)
            u = [1.0, 2.0, 3.0, 4.0]
            λ = Systems.ODEParameters(nothing)
            t = 0.0

            Test.@inferred ip_oop(du, u, λ, t)
            Test.@inferred oop_oop(u, λ, t)
            Test.@inferred ip_ip(du, u, λ, t)
            Test.@inferred oop_ip(u, λ, t)
        end

        # =============================================================================
        # Test display
        # =============================================================================

        Test.@testset "Display" begin
            phvf_oop = Data.PseudoHamiltonianVectorField(
                FakePHVFOoP; is_autonomous=true, is_variable=false
            )
            phvf_ip = Data.PseudoHamiltonianVectorField(
                FakePHVFIP; is_autonomous=true, is_variable=false, is_inplace=true
            )

            ip_oop = Systems.IPPseudoHVFOoPRHS(phvf_oop, _law_fixed, 2, identity, identity)
            oop_oop = Systems.OoPPseudoHVFOoPRHS(
                phvf_oop, _law_fixed, 2, identity, identity
            )
            ip_ip = Systems.IPPseudoHVFIpRHS(phvf_ip, _law_fixed, 2, identity, identity)
            oop_ip = Systems.OoPPseudoHVFIpRHS(phvf_ip, _law_fixed, 2, identity, identity)
            oop_finalize = Systems.OoPPseudoHVFIpFinalizeRHS(
                phvf_ip, _law_fixed, 2, identity, identity
            )

            Test.@test occursin("IPPseudoHVFOoPRHS", sprint(show, ip_oop))
            Test.@test occursin("converts:", sprint(show, ip_oop))
            Test.@test occursin("OoPPseudoHVFOoPRHS", sprint(show, oop_oop))
            Test.@test occursin("converts:", sprint(show, oop_oop))
            Test.@test occursin("IPPseudoHVFIpRHS", sprint(show, ip_ip))
            Test.@test occursin("converts:", sprint(show, ip_ip))
            Test.@test occursin("OoPPseudoHVFIpRHS", sprint(show, oop_ip))
            Test.@test occursin("converts:", sprint(show, oop_ip))
            Test.@test occursin("OoPPseudoHVFIpFinalizeRHS", sprint(show, oop_finalize))
            Test.@test occursin("converts:", sprint(show, oop_finalize))
        end
    end
end

end # module

# CRITICAL: Redefine in outer scope for TestRunner
test_pseudo_hvf_rhs_functors() = TestPseudoHVFRHSFunctors.test_pseudo_hvf_rhs_functors()
