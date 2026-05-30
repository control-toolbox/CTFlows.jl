module TestRhsFunctors

import Test
import CTFlows.Common
import CTFlows.Data
import CTFlows.Systems
import CTFlows.Traits
import StaticArrays

const VERBOSE = isdefined(Main, :TestOptions) ? Main.TestOptions.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestOptions) ? Main.TestOptions.SHOWTIMING : true

# =============================================================================
# Fake types for testing (top-level)
# =============================================================================

const FakeF = x -> -x
const FakeFIP = (du, x) -> du .= -x

# NonAutonomous/Fixed
const FakeFNA   = (t, x)       -> -x
const FakeFNAIP = (du, t, x)   -> (du .= -x; nothing)

# Autonomous/NonFixed
const FakeFNF   = (x, v)       -> -x
const FakeFNFIP = (du, x, v)   -> (du .= -x; nothing)

# NonAutonomous/NonFixed
const FakeFNANF   = (t, x, v)   -> -x
const FakeFNANFIP = (du, t, x, v) -> (du .= -x; nothing)

function test_rhs_functors()
    Test.@testset "RHS Functors Tests" verbose=VERBOSE showtiming=SHOWTIMING begin

        # =============================================================================
        # Test hierarchy
        # =============================================================================

        Test.@testset "Hiérarchie abstraite" begin
            # Out-of-place VectorField
            vf_oop = Data.VectorField(FakeF; is_autonomous=true, is_variable=false)
            ip_vf_oop = Systems.IPVFOoPRHS(vf_oop)
            oop_vf_oop = Systems.OoPVFOoPRHS(vf_oop)

            Test.@test ip_vf_oop isa Systems.AbstractIPRHS
            Test.@test ip_vf_oop isa Systems.AbstractRHS{Traits.InPlace}
            Test.@test oop_vf_oop isa Systems.AbstractOoPRHS
            Test.@test oop_vf_oop isa Systems.AbstractRHS{Traits.OutOfPlace}

            # In-place VectorField
            vf_ip = Data.VectorField(FakeFIP; is_autonomous=true, is_variable=false)
            ip_vf_ip = Systems.IPVFIpRHS(vf_ip)
            oop_vf_ip = Systems.OoPVFIpRHS(vf_ip)
            oop_vf_finalize = Systems.OoPVFIpFinalizeRHS(vf_ip)

            Test.@test ip_vf_ip isa Systems.AbstractIPRHS
            Test.@test ip_vf_ip isa Systems.AbstractRHS{Traits.InPlace}
            Test.@test oop_vf_ip isa Systems.AbstractOoPRHS
            Test.@test oop_vf_ip isa Systems.AbstractRHS{Traits.OutOfPlace}
            Test.@test oop_vf_finalize isa Systems.AbstractOoPRHS
            Test.@test oop_vf_finalize isa Systems.AbstractRHS{Traits.OutOfPlace}
        end

        # =============================================================================
        # Test IPVFOoPRHS
        # =============================================================================

        Test.@testset "IPVFOoPRHS — appel" begin
            # Autonomous/Fixed
            vf = Data.VectorField(FakeF; is_autonomous=true, is_variable=false)
            f = Systems.IPVFOoPRHS(vf)

            du = zeros(2)
            u = [1.0, 2.0]
            λ = Common.ODEParameters(nothing)
            t = 0.0

            f(du, u, λ, t)
            Test.@test du ≈ -u

            # NonAutonomous/Fixed
            vf_na = Data.VectorField(FakeFNA; is_autonomous=false, is_variable=false)
            f_na = Systems.IPVFOoPRHS(vf_na)

            du = zeros(2)
            f_na(du, u, λ, t)
            Test.@test du ≈ -u

            # Autonomous/NonFixed
            v_val = 1.5
            λ_v = Common.ODEParameters(v_val)
            vf_nf = Data.VectorField(FakeFNF; is_autonomous=true, is_variable=true)
            f_nf = Systems.IPVFOoPRHS(vf_nf)

            du = zeros(2)
            f_nf(du, u, λ_v, t)
            Test.@test du ≈ -u

            # NonAutonomous/NonFixed
            vf_naf = Data.VectorField(FakeFNANF; is_autonomous=false, is_variable=true)
            f_naf = Systems.IPVFOoPRHS(vf_naf)

            du = zeros(2)
            f_naf(du, u, λ_v, t)
            Test.@test du ≈ -u
        end

        # =============================================================================
        # Test IPVFIpRHS
        # =============================================================================

        Test.@testset "IPVFIpRHS — appel" begin
            # Autonomous/Fixed
            vf = Data.VectorField(FakeFIP; is_autonomous=true, is_variable=false)
            f = Systems.IPVFIpRHS(vf)

            du = zeros(2)
            u = [1.0, 2.0]
            λ = Common.ODEParameters(nothing)
            t = 0.0

            f(du, u, λ, t)
            Test.@test du ≈ -u

            # NonAutonomous/Fixed
            vf_na = Data.VectorField(FakeFNAIP; is_autonomous=false, is_variable=false)
            f_na = Systems.IPVFIpRHS(vf_na)

            du = zeros(2)
            f_na(du, u, λ, t)
            Test.@test du ≈ -u

            # Autonomous/NonFixed
            v_val = 1.5
            λ_v = Common.ODEParameters(v_val)
            vf_nf = Data.VectorField(FakeFNFIP; is_autonomous=true, is_variable=true)
            f_nf = Systems.IPVFIpRHS(vf_nf)

            du = zeros(2)
            f_nf(du, u, λ_v, t)
            Test.@test du ≈ -u

            # NonAutonomous/NonFixed
            vf_naf = Data.VectorField(FakeFNANFIP; is_autonomous=false, is_variable=true)
            f_naf = Systems.IPVFIpRHS(vf_naf)

            du = zeros(2)
            f_naf(du, u, λ_v, t)
            Test.@test du ≈ -u
        end

        # =============================================================================
        # Test OoPVFOoPRHS
        # =============================================================================

        Test.@testset "OoPVFOoPRHS — appel" begin
            # Autonomous/Fixed
            vf = Data.VectorField(FakeF; is_autonomous=true, is_variable=false)
            f = Systems.OoPVFOoPRHS(vf)

            u = [1.0, 2.0]
            λ = Common.ODEParameters(nothing)
            t = 0.0

            result = f(u, λ, t)
            Test.@test result ≈ -u

            # NonAutonomous/Fixed
            vf_na = Data.VectorField(FakeFNA; is_autonomous=false, is_variable=false)
            f_na = Systems.OoPVFOoPRHS(vf_na)

            result = f_na(u, λ, t)
            Test.@test result ≈ -u

            # Autonomous/NonFixed
            v_val = 1.5
            λ_v = Common.ODEParameters(v_val)
            vf_nf = Data.VectorField(FakeFNF; is_autonomous=true, is_variable=true)
            f_nf = Systems.OoPVFOoPRHS(vf_nf)

            result = f_nf(u, λ_v, t)
            Test.@test result ≈ -u

            # NonAutonomous/NonFixed
            vf_naf = Data.VectorField(FakeFNANF; is_autonomous=false, is_variable=true)
            f_naf = Systems.OoPVFOoPRHS(vf_naf)

            result = f_naf(u, λ_v, t)
            Test.@test result ≈ -u
        end

        # =============================================================================
        # Test OoPVFIpRHS
        # =============================================================================

        Test.@testset "OoPVFIpRHS — appel" begin
            # Autonomous/Fixed
            vf = Data.VectorField(FakeFIP; is_autonomous=true, is_variable=false)
            f = Systems.OoPVFIpRHS(vf)

            u = [1.0, 2.0]
            λ = Common.ODEParameters(nothing)
            t = 0.0

            result = f(u, λ, t)
            Test.@test result ≈ -u
            Test.@test result isa Vector

            # NonAutonomous/Fixed
            vf_na = Data.VectorField(FakeFNAIP; is_autonomous=false, is_variable=false)
            f_na = Systems.OoPVFIpRHS(vf_na)

            result = f_na(u, λ, t)
            Test.@test result ≈ -u

            # Autonomous/NonFixed
            v_val = 1.5
            λ_v = Common.ODEParameters(v_val)
            vf_nf = Data.VectorField(FakeFNFIP; is_autonomous=true, is_variable=true)
            f_nf = Systems.OoPVFIpRHS(vf_nf)

            result = f_nf(u, λ_v, t)
            Test.@test result ≈ -u

            # NonAutonomous/NonFixed
            vf_naf = Data.VectorField(FakeFNANFIP; is_autonomous=false, is_variable=true)
            f_naf = Systems.OoPVFIpRHS(vf_naf)

            result = f_naf(u, λ_v, t)
            Test.@test result ≈ -u
        end

        # =============================================================================
        # Test OoPVFIpFinalizeRHS
        # =============================================================================

        Test.@testset "OoPVFIpFinalizeRHS — appel SVector" begin
            # Autonomous/Fixed
            vf = Data.VectorField(FakeFIP; is_autonomous=true, is_variable=false)
            f = Systems.OoPVFIpFinalizeRHS(vf)

            u = StaticArrays.SA[1.0, 2.0]
            λ = Common.ODEParameters(nothing)
            t = 0.0

            result = f(u, λ, t)
            Test.@test result ≈ -u
            Test.@test result isa StaticArrays.SVector

            # NonAutonomous/Fixed
            vf_na = Data.VectorField(FakeFNAIP; is_autonomous=false, is_variable=false)
            f_na = Systems.OoPVFIpFinalizeRHS(vf_na)

            result = f_na(u, λ, t)
            Test.@test result ≈ -u
            Test.@test result isa StaticArrays.SVector

            # Autonomous/NonFixed
            v_val = 1.5
            λ_v = Common.ODEParameters(v_val)
            vf_nf = Data.VectorField(FakeFNFIP; is_autonomous=true, is_variable=true)
            f_nf = Systems.OoPVFIpFinalizeRHS(vf_nf)

            result = f_nf(u, λ_v, t)
            Test.@test result ≈ -u
            Test.@test result isa StaticArrays.SVector

            # NonAutonomous/NonFixed
            vf_naf = Data.VectorField(FakeFNANFIP; is_autonomous=false, is_variable=true)
            f_naf = Systems.OoPVFIpFinalizeRHS(vf_naf)

            result = f_naf(u, λ_v, t)
            Test.@test result ≈ -u
            Test.@test result isa StaticArrays.SVector
        end

        # =============================================================================
        # Test type stability
        # =============================================================================

        Test.@testset "Type Stability" begin
            vf_oop = Data.VectorField(FakeF; is_autonomous=true, is_variable=false)
            vf_ip = Data.VectorField(FakeFIP; is_autonomous=true, is_variable=false)

            f_ip_vf_oop = Systems.IPVFOoPRHS(vf_oop)
            f_ip_vf_ip = Systems.IPVFIpRHS(vf_ip)
            f_oop_vf_oop = Systems.OoPVFOoPRHS(vf_oop)
            f_oop_vf_ip = Systems.OoPVFIpRHS(vf_ip)
            f_oop_finalize = Systems.OoPVFIpFinalizeRHS(vf_ip)

            du = zeros(2)
            u = [1.0, 2.0]
            λ = Common.ODEParameters(nothing)
            t = 0.0

            Test.@inferred f_ip_vf_oop(du, u, λ, t)
            Test.@inferred f_ip_vf_ip(du, u, λ, t)
            Test.@inferred f_oop_vf_oop(u, λ, t)
            Test.@inferred f_oop_vf_ip(u, λ, t)

            u_svec = StaticArrays.SA[1.0, 2.0]
            Test.@inferred f_oop_finalize(u_svec, λ, t)
        end

        # =============================================================================
        # Test display
        # =============================================================================

        Test.@testset "Affichage" begin
            vf_oop = Data.VectorField(FakeF; is_autonomous=true, is_variable=false)
            vf_ip = Data.VectorField(FakeFIP; is_autonomous=true, is_variable=false)

            f_ip_vf_oop = Systems.IPVFOoPRHS(vf_oop)
            f_ip_vf_ip = Systems.IPVFIpRHS(vf_ip)
            f_oop_vf_oop = Systems.OoPVFOoPRHS(vf_oop)
            f_oop_vf_ip = Systems.OoPVFIpRHS(vf_ip)
            f_oop_finalize = Systems.OoPVFIpFinalizeRHS(vf_ip)

            Test.@test occursin("IPVFOoPRHS", sprint(show, f_ip_vf_oop))
            Test.@test occursin("converts:", sprint(show, f_ip_vf_oop))
            Test.@test occursin("IPVFIpRHS", sprint(show, f_ip_vf_ip))
            Test.@test occursin("converts:", sprint(show, f_ip_vf_ip))
            Test.@test occursin("OoPVFOoPRHS", sprint(show, f_oop_vf_oop))
            Test.@test occursin("converts:", sprint(show, f_oop_vf_oop))
            Test.@test occursin("OoPVFIpRHS", sprint(show, f_oop_vf_ip))
            Test.@test occursin("converts:", sprint(show, f_oop_vf_ip))
            Test.@test occursin("OoPVFIpFinalizeRHS", sprint(show, f_oop_finalize))
            Test.@test occursin("converts:", sprint(show, f_oop_finalize))
        end

    end
end

end # module

# CRITICAL: Redefine in outer scope for TestRunner
test_rhs_functors() = TestRhsFunctors.test_rhs_functors()
