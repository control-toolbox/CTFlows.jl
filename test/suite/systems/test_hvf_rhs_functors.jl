module TestHVFRHSFunctors

import Test
import CTFlows.Common: Common
import CTFlows.Data: Data
import CTFlows.Systems: Systems
import CTFlows.Traits: Traits
import StaticArrays: SA, SVector

const VERBOSE = isdefined(Main, :TestOptions) ? Main.TestOptions.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestOptions) ? Main.TestOptions.SHOWTIMING : true

# =============================================================================
# Fake functions for testing (top-level)
# =============================================================================

const FakeHVF = (x, p) -> (x, -p)
const FakeHVFOoP = (x, p) -> (x, -p)
const FakeHVFIP = (dx, dp, x, p) -> (dx .= x; dp .= -p)

# NonAutonomous/Fixed
const FakeHVFNA   = (t, x, p)         -> (x, -p)
const FakeHVFNAIP = (dx, dp, t, x, p) -> (dx .= x; dp .= -p; nothing)

# Autonomous/NonFixed (non-augmented)
const FakeHVFNF   = (x, p, v)           -> (p, -x)
const FakeHVFNFIP = (dx, dp, x, p, v)   -> (dx .= p; dp .= -x; nothing)

# NonAutonomous/NonFixed (non-augmented)
const FakeHVFNANF   = (t, x, p, v)           -> (p, -x)
const FakeHVFNANFIP = (dx, dp, t, x, p, v)   -> (dx .= p; dp .= -x; nothing)

# OoP augmentée : doit accepter variable_costate
const FakeHVFAug = (x, p, v; variable_costate::Bool=false) -> (p, -x, zeros(1))

# IP augmentée : doit accepter variable_costate et dpv, ET écrire dans dx/dp
const FakeHVFAugIP = (dx, dp, x, p, v; dpv=nothing, variable_costate::Bool=false) -> begin
    dx .= p
    dp .= -x
    if dpv !== nothing; dpv .= zeros(1); end
    nothing
end

# Fakes NonAutonomous
const FakeHVFAugNA = (t, x, p, v; variable_costate::Bool=false) -> (p, -x, zeros(1))
const FakeHVFAugIPNA = (dx, dp, t, x, p, v; dpv=nothing, variable_costate::Bool=false) -> begin
    dx .= p; dp .= -x
    if dpv !== nothing; dpv .= zeros(1); end
    nothing
end

function test_hvf_rhs_functors()
    Test.@testset "HVF RHS Functors Tests" verbose=VERBOSE showtiming=SHOWTIMING begin

        # =============================================================================
        # Test hierarchy
        # =============================================================================

        Test.@testset "Abstract types" begin
            # Out-of-place HVF
            hvf_oop = Data.HamiltonianVectorField(FakeHVFOoP; is_autonomous=true, is_variable=false)
            ip_hvf_oop = Systems.IPHVFOoPRHS(hvf_oop, 2, identity, identity)
            oop_hvf_oop = Systems.OoPHVFOoPRHS(hvf_oop, 2, identity, identity)

            Test.@test ip_hvf_oop isa Systems.AbstractIPHVFRHS
            Test.@test ip_hvf_oop isa Systems.AbstractRHS{Traits.InPlace}
            Test.@test oop_hvf_oop isa Systems.AbstractOoPHVFRHS
            Test.@test oop_hvf_oop isa Systems.AbstractRHS{Traits.OutOfPlace}

            # In-place HVF
            hvf_ip = Data.HamiltonianVectorField(FakeHVFIP; is_autonomous=true, is_variable=false, is_inplace=true)
            ip_hvf_ip = Systems.IPHVFIpRHS(hvf_ip, 2, identity, identity)
            oop_hvf_ip = Systems.OoPHVFIpRHS(hvf_ip, 2, identity, identity)
            oop_finalize = Systems.OoPHVFIpFinalizeRHS(hvf_ip, 2, identity, identity)

            Test.@test ip_hvf_ip isa Systems.AbstractIPHVFRHS
            Test.@test ip_hvf_ip isa Systems.AbstractRHS{Traits.InPlace}
            Test.@test oop_hvf_ip isa Systems.AbstractOoPHVFRHS
            Test.@test oop_hvf_ip isa Systems.AbstractRHS{Traits.OutOfPlace}
            Test.@test oop_finalize isa Systems.AbstractOoPHVFRHS
            Test.@test oop_finalize isa Systems.AbstractRHS{Traits.OutOfPlace}
        end

        # =============================================================================
        # Test IPVFOoPRHS
        # =============================================================================

        Test.@testset "IPHVFOoPRHS — call" begin
            # Autonomous/Fixed
            hvf = Data.HamiltonianVectorField(FakeHVFOoP; is_autonomous=true, is_variable=false)
            r = Systems.IPHVFOoPRHS(hvf, 2, identity, identity)

            du = zeros(4)
            u = [1.0, 2.0, 3.0, 4.0]
            λ = Common.ODEParameters(nothing)
            t = 0.0

            r(du, u, λ, t)
            Test.@test du[1:2] == [1.0, 2.0]
            Test.@test du[3:4] == [-3.0, -4.0]

            # NonAutonomous/Fixed
            hvf_na = Data.HamiltonianVectorField(FakeHVFNA; is_autonomous=false, is_variable=false)
            r_na = Systems.IPHVFOoPRHS(hvf_na, 2, identity, identity)

            du = zeros(4)
            r_na(du, u, λ, t)
            Test.@test du[1:2] == [1.0, 2.0]
            Test.@test du[3:4] == [-3.0, -4.0]

            # Autonomous/NonFixed
            v_val = 1.5
            λ_v = Common.ODEParameters(v_val)
            hvf_nf = Data.HamiltonianVectorField(FakeHVFNF; is_autonomous=true, is_variable=true)
            r_nf = Systems.IPHVFOoPRHS(hvf_nf, 2, identity, identity)

            du = zeros(4)
            r_nf(du, u, λ_v, t)
            Test.@test du[1:2] == [3.0, 4.0]
            Test.@test du[3:4] == [-1.0, -2.0]

            # NonAutonomous/NonFixed
            hvf_naf = Data.HamiltonianVectorField(FakeHVFNANF; is_autonomous=false, is_variable=true)
            r_naf = Systems.IPHVFOoPRHS(hvf_naf, 2, identity, identity)

            du = zeros(4)
            r_naf(du, u, λ_v, t)
            Test.@test du[1:2] == [3.0, 4.0]
            Test.@test du[3:4] == [-1.0, -2.0]
        end

        # =============================================================================
        # Test IPVFIpRHS
        # =============================================================================

        Test.@testset "IPHVFIpRHS — call" begin
            # Autonomous/Fixed
            hvf = Data.HamiltonianVectorField(FakeHVFIP; is_autonomous=true, is_variable=false, is_inplace=true)
            r = Systems.IPHVFIpRHS(hvf, 2, identity, identity)

            du = zeros(4)
            u = [1.0, 2.0, 3.0, 4.0]
            λ = Common.ODEParameters(nothing)
            t = 0.0

            r(du, u, λ, t)
            Test.@test du[1:2] == [1.0, 2.0]
            Test.@test du[3:4] == [-3.0, -4.0]

            # NonAutonomous/Fixed
            hvf_na = Data.HamiltonianVectorField(FakeHVFNAIP; is_autonomous=false, is_variable=false, is_inplace=true)
            r_na = Systems.IPHVFIpRHS(hvf_na, 2, identity, identity)

            du = zeros(4)
            r_na(du, u, λ, t)
            Test.@test du[1:2] == [1.0, 2.0]
            Test.@test du[3:4] == [-3.0, -4.0]

            # Autonomous/NonFixed
            v_val = 1.5
            λ_v = Common.ODEParameters(v_val)
            hvf_nf = Data.HamiltonianVectorField(FakeHVFNFIP; is_autonomous=true, is_variable=true, is_inplace=true)
            r_nf = Systems.IPHVFIpRHS(hvf_nf, 2, identity, identity)

            du = zeros(4)
            r_nf(du, u, λ_v, t)
            Test.@test du[1:2] == [3.0, 4.0]
            Test.@test du[3:4] == [-1.0, -2.0]

            # NonAutonomous/NonFixed
            hvf_naf = Data.HamiltonianVectorField(FakeHVFNANFIP; is_autonomous=false, is_variable=true, is_inplace=true)
            r_naf = Systems.IPHVFIpRHS(hvf_naf, 2, identity, identity)

            du = zeros(4)
            r_naf(du, u, λ_v, t)
            Test.@test du[1:2] == [3.0, 4.0]
            Test.@test du[3:4] == [-1.0, -2.0]
        end

        # =============================================================================
        # Test OoPHVFOoPRHS
        # =============================================================================

        Test.@testset "OoPHVFOoPRHS — call" begin
            # Autonomous/Fixed
            hvf = Data.HamiltonianVectorField(FakeHVFOoP; is_autonomous=true, is_variable=false)
            r = Systems.OoPHVFOoPRHS(hvf, 2, identity, identity)

            u = [1.0, 2.0, 3.0, 4.0]
            λ = Common.ODEParameters(nothing)
            t = 0.0

            result = r(u, λ, t)
            Test.@test result[1:2] == [1.0, 2.0]
            Test.@test result[3:4] == [-3.0, -4.0]

            # NonAutonomous/Fixed
            hvf_na = Data.HamiltonianVectorField(FakeHVFNA; is_autonomous=false, is_variable=false)
            r_na = Systems.OoPHVFOoPRHS(hvf_na, 2, identity, identity)

            result = r_na(u, λ, t)
            Test.@test result[1:2] == [1.0, 2.0]
            Test.@test result[3:4] == [-3.0, -4.0]

            # Autonomous/NonFixed
            v_val = 1.5
            λ_v = Common.ODEParameters(v_val)
            hvf_nf = Data.HamiltonianVectorField(FakeHVFNF; is_autonomous=true, is_variable=true)
            r_nf = Systems.OoPHVFOoPRHS(hvf_nf, 2, identity, identity)

            result = r_nf(u, λ_v, t)
            Test.@test result[1:2] == [3.0, 4.0]
            Test.@test result[3:4] == [-1.0, -2.0]

            # NonAutonomous/NonFixed
            hvf_naf = Data.HamiltonianVectorField(FakeHVFNANF; is_autonomous=false, is_variable=true)
            r_naf = Systems.OoPHVFOoPRHS(hvf_naf, 2, identity, identity)

            result = r_naf(u, λ_v, t)
            Test.@test result[1:2] == [3.0, 4.0]
            Test.@test result[3:4] == [-1.0, -2.0]
        end

        # =============================================================================
        # Test OoPHVFIpRHS
        # =============================================================================

        Test.@testset "OoPHVFIpRHS — call" begin
            # Autonomous/Fixed
            hvf = Data.HamiltonianVectorField(FakeHVFIP; is_autonomous=true, is_variable=false, is_inplace=true)
            r = Systems.OoPHVFIpRHS(hvf, 2, identity, identity)

            u = [1.0, 2.0, 3.0, 4.0]
            λ = Common.ODEParameters(nothing)
            t = 0.0

            result = r(u, λ, t)
            Test.@test result[1:2] == [1.0, 2.0]
            Test.@test result[3:4] == [-3.0, -4.0]

            # NonAutonomous/Fixed
            hvf_na = Data.HamiltonianVectorField(FakeHVFNAIP; is_autonomous=false, is_variable=false, is_inplace=true)
            r_na = Systems.OoPHVFIpRHS(hvf_na, 2, identity, identity)

            result = r_na(u, λ, t)
            Test.@test result[1:2] == [1.0, 2.0]
            Test.@test result[3:4] == [-3.0, -4.0]

            # Autonomous/NonFixed
            v_val = 1.5
            λ_v = Common.ODEParameters(v_val)
            hvf_nf = Data.HamiltonianVectorField(FakeHVFNFIP; is_autonomous=true, is_variable=true, is_inplace=true)
            r_nf = Systems.OoPHVFIpRHS(hvf_nf, 2, identity, identity)

            result = r_nf(u, λ_v, t)
            Test.@test result[1:2] == [3.0, 4.0]
            Test.@test result[3:4] == [-1.0, -2.0]

            # NonAutonomous/NonFixed
            hvf_naf = Data.HamiltonianVectorField(FakeHVFNANFIP; is_autonomous=false, is_variable=true, is_inplace=true)
            r_naf = Systems.OoPHVFIpRHS(hvf_naf, 2, identity, identity)

            result = r_naf(u, λ_v, t)
            Test.@test result[1:2] == [3.0, 4.0]
            Test.@test result[3:4] == [-1.0, -2.0]
        end

        # =============================================================================
        # Test OoPHVFIpFinalizeRHS
        # =============================================================================

        Test.@testset "OoPHVFIpFinalizeRHS — call SVector" begin
            # Autonomous/Fixed
            hvf = Data.HamiltonianVectorField(FakeHVFIP; is_autonomous=true, is_variable=false, is_inplace=true)
            r = Systems.OoPHVFIpFinalizeRHS(hvf, 2, identity, identity)

            u = SA[1.0, 2.0, 3.0, 4.0]
            λ = Common.ODEParameters(nothing)
            t = 0.0

            result = r(u, λ, t)
            Test.@test result isa SVector
            Test.@test result[1:2] == SA[1.0, 2.0]
            Test.@test result[3:4] == SA[-3.0, -4.0]

            # NonAutonomous/Fixed
            hvf_na = Data.HamiltonianVectorField(FakeHVFNAIP; is_autonomous=false, is_variable=false, is_inplace=true)
            r_na = Systems.OoPHVFIpFinalizeRHS(hvf_na, 2, identity, identity)

            result = r_na(u, λ, t)
            Test.@test result isa SVector
            Test.@test result[1:2] == SA[1.0, 2.0]
            Test.@test result[3:4] == SA[-3.0, -4.0]

            # Autonomous/NonFixed
            v_val = 1.5
            λ_v = Common.ODEParameters(v_val)
            hvf_nf = Data.HamiltonianVectorField(FakeHVFNFIP; is_autonomous=true, is_variable=true, is_inplace=true)
            r_nf = Systems.OoPHVFIpFinalizeRHS(hvf_nf, 2, identity, identity)

            result = r_nf(u, λ_v, t)
            Test.@test result isa SVector
            Test.@test result[1:2] == SA[3.0, 4.0]
            Test.@test result[3:4] == SA[-1.0, -2.0]

            # NonAutonomous/NonFixed
            hvf_naf = Data.HamiltonianVectorField(FakeHVFNANFIP; is_autonomous=false, is_variable=true, is_inplace=true)
            r_naf = Systems.OoPHVFIpFinalizeRHS(hvf_naf, 2, identity, identity)

            result = r_naf(u, λ_v, t)
            Test.@test result isa SVector
            Test.@test result[1:2] == SA[3.0, 4.0]
            Test.@test result[3:4] == SA[-1.0, -2.0]
        end

        # =============================================================================
        # Test augmented functors
        # =============================================================================

        Test.@testset "IPHVFOoPAugRHS — call" begin
            # Autonomous
            hvf = Data.HamiltonianVectorField(FakeHVFAug; is_autonomous=true, is_variable=true)
            r = Systems.IPHVFOoPAugRHS(hvf, 2, 1)

            du = zeros(5)
            u = [1.0, 2.0, 3.0, 4.0, 0.0]
            λ = Common.ODEParameters(0.5)
            t = 0.0

            r(du, u, λ, t)
            Test.@test du[1:2] == [3.0, 4.0]
            Test.@test du[3:4] == [-1.0, -2.0]
            Test.@test du[5] == 0.0

            # NonAutonomous
            hvf_na = Data.HamiltonianVectorField(FakeHVFAugNA; is_autonomous=false, is_variable=true)
            r_na = Systems.IPHVFOoPAugRHS(hvf_na, 2, 1)

            du = zeros(5)
            r_na(du, u, λ, t)
            Test.@test du[1:2] == [3.0, 4.0]
            Test.@test du[3:4] == [-1.0, -2.0]
            Test.@test du[5] == 0.0
        end

        Test.@testset "IPHVFIpAugRHS — call" begin
            # Autonomous
            hvf = Data.HamiltonianVectorField(FakeHVFAugIP; is_autonomous=true, is_variable=true, is_inplace=true)
            r = Systems.IPHVFIpAugRHS(hvf, 2, 1)

            du = zeros(5)
            u = [1.0, 2.0, 3.0, 4.0, 0.0]
            λ = Common.ODEParameters(0.5)
            t = 0.0

            r(du, u, λ, t)
            Test.@test du[1:2] == [3.0, 4.0]
            Test.@test du[3:4] == [-1.0, -2.0]

            # NonAutonomous
            hvf_na = Data.HamiltonianVectorField(FakeHVFAugIPNA; is_autonomous=false, is_variable=true, is_inplace=true)
            r_na = Systems.IPHVFIpAugRHS(hvf_na, 2, 1)

            du = zeros(5)
            r_na(du, u, λ, t)
            Test.@test du[1:2] == [3.0, 4.0]
            Test.@test du[3:4] == [-1.0, -2.0]
        end

        # =============================================================================
        # Test type stability
        # =============================================================================

        Test.@testset "Type Stability" begin
            hvf_oop = Data.HamiltonianVectorField(FakeHVFOoP; is_autonomous=true, is_variable=false)
            hvf_ip = Data.HamiltonianVectorField(FakeHVFIP; is_autonomous=true, is_variable=false, is_inplace=true)

            ip_hvf_oop = Systems.IPHVFOoPRHS(hvf_oop, 2, identity, identity)
            oop_hvf_oop = Systems.OoPHVFOoPRHS(hvf_oop, 2, identity, identity)
            ip_hvf_ip = Systems.IPHVFIpRHS(hvf_ip, 2, identity, identity)
            oop_hvf_ip = Systems.OoPHVFIpRHS(hvf_ip, 2, identity, identity)

            du = zeros(4)
            u = [1.0, 2.0, 3.0, 4.0]
            u_svec = SA[1.0, 2.0, 3.0, 4.0]
            λ = Common.ODEParameters(nothing)
            t = 0.0

            Test.@inferred ip_hvf_oop(du, u, λ, t)
            Test.@inferred oop_hvf_oop(u, λ, t)
            Test.@inferred ip_hvf_ip(du, u, λ, t)
            Test.@inferred oop_hvf_ip(u, λ, t)
        end

        # =============================================================================
        # Test display
        # =============================================================================

        Test.@testset "Display" begin
            hvf_oop = Data.HamiltonianVectorField(FakeHVFOoP; is_autonomous=true, is_variable=false)
            hvf_ip = Data.HamiltonianVectorField(FakeHVFIP; is_autonomous=true, is_variable=false, is_inplace=true)

            ip_hvf_oop = Systems.IPHVFOoPRHS(hvf_oop, 2, identity, identity)
            oop_hvf_oop = Systems.OoPHVFOoPRHS(hvf_oop, 2, identity, identity)
            ip_hvf_ip = Systems.IPHVFIpRHS(hvf_ip, 2, identity, identity)
            oop_hvf_ip = Systems.OoPHVFIpRHS(hvf_ip, 2, identity, identity)
            oop_finalize = Systems.OoPHVFIpFinalizeRHS(hvf_ip, 2, identity, identity)

            Test.@test occursin("IPHVFOoPRHS", sprint(show, ip_hvf_oop))
            Test.@test occursin("converts:", sprint(show, ip_hvf_oop))
            Test.@test occursin("OoPHVFOoPRHS", sprint(show, oop_hvf_oop))
            Test.@test occursin("converts:", sprint(show, oop_hvf_oop))
            Test.@test occursin("IPHVFIpRHS", sprint(show, ip_hvf_ip))
            Test.@test occursin("converts:", sprint(show, ip_hvf_ip))
            Test.@test occursin("OoPHVFIpRHS", sprint(show, oop_hvf_ip))
            Test.@test occursin("converts:", sprint(show, oop_hvf_ip))
            Test.@test occursin("OoPHVFIpFinalizeRHS", sprint(show, oop_finalize))
            Test.@test occursin("converts:", sprint(show, oop_finalize))
        end

    end
end

end # module

# CRITICAL: Redefine in outer scope for TestRunner
test_hvf_rhs_functors() = TestHVFRHSFunctors.test_hvf_rhs_functors()
