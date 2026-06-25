module TestSciMLRHSFunctors

import Test
import CTFlows: CTFlows
import CTFlows.Common: Common
import CTBase.Traits: Traits
import CTFlows.Systems: Systems
import SciMLBase: SciMLBase, ODEFunction
using OrdinaryDiffEqTsit5: OrdinaryDiffEqTsit5
using StaticArrays: SA, SVector

const CTFlowsSciMLFlows = Base.get_extension(CTFlows, :CTFlowsSciMLFlows)

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

function test_sciml_rhs_functors()
    Test.@testset "SciML RHS Functors" verbose=VERBOSE showtiming=SHOWTIMING begin

        # =============================================================================
        # Fake ODE functions for testing
        # =============================================================================

        FakeFIP = (du, u, p, t) -> (du .= -u)
        FakeFOoP = (u, p, t) -> -u

        # =============================================================================
        # Test abstract types
        # =============================================================================

        Test.@testset "Abstract types" begin
            f_ip = ODEFunction(FakeFIP)
            f_oop = ODEFunction{false}(FakeFOoP)

            ip_ip = CTFlowsSciMLFlows.IPSciMLIpRHS(f_ip)
            oop_ip = CTFlowsSciMLFlows.OoPSciMLIpRHS(f_ip)
            oop_finalize = CTFlowsSciMLFlows.OoPSciMLIpFinalizeRHS(f_ip)
            ip_oop = CTFlowsSciMLFlows.IPSciMLOoPRHS(f_oop)
            oop_oop = CTFlowsSciMLFlows.OoPSciMLOoPRHS(f_oop)

            Test.@test ip_ip isa Systems.AbstractIPRHS
            Test.@test ip_ip isa Systems.AbstractRHS{Traits.InPlace}
            Test.@test oop_ip isa Systems.AbstractOoPRHS
            Test.@test oop_ip isa Systems.AbstractRHS{Traits.OutOfPlace}
            Test.@test oop_finalize isa Systems.AbstractOoPRHS
            Test.@test oop_finalize isa Systems.AbstractRHS{Traits.OutOfPlace}
            Test.@test ip_oop isa Systems.AbstractIPRHS
            Test.@test ip_oop isa Systems.AbstractRHS{Traits.InPlace}
            Test.@test oop_oop isa Systems.AbstractOoPRHS
            Test.@test oop_oop isa Systems.AbstractRHS{Traits.OutOfPlace}
        end

        # =============================================================================
        # Test IPSciMLIpRHS
        # =============================================================================

        Test.@testset "IPSciMLIpRHS — call" begin
            f = ODEFunction(FakeFIP)
            r = CTFlowsSciMLFlows.IPSciMLIpRHS(f)

            du = zeros(2)
            u = [1.0, 2.0]
            λ = Common.ODEParameters(2.0)
            t = 0.0

            r(du, u, λ, t)
            Test.@test du ≈ -u
        end

        # =============================================================================
        # Test OoPSciMLIpRHS
        # =============================================================================

        Test.@testset "OoPSciMLIpRHS — call" begin
            f = ODEFunction(FakeFIP)
            r = CTFlowsSciMLFlows.OoPSciMLIpRHS(f)

            u = [1.0, 2.0]
            λ = Common.ODEParameters(2.0)
            t = 0.0

            result = r(u, λ, t)
            Test.@test result ≈ -u
            Test.@test result isa Vector
        end

        # =============================================================================
        # Test OoPSciMLIpFinalizeRHS
        # =============================================================================

        Test.@testset "OoPSciMLIpFinalizeRHS — call SVector" begin
            f = ODEFunction(FakeFIP)
            r = CTFlowsSciMLFlows.OoPSciMLIpFinalizeRHS(f)

            u = SA[1.0, 2.0]
            λ = Common.ODEParameters(2.0)
            t = 0.0

            result = r(u, λ, t)
            Test.@test result ≈ -u
            Test.@test result isa SVector
        end

        # =============================================================================
        # Test IPSciMLOoPRHS
        # =============================================================================

        Test.@testset "IPSciMLOoPRHS — call" begin
            f = ODEFunction{false}(FakeFOoP)
            r = CTFlowsSciMLFlows.IPSciMLOoPRHS(f)

            du = zeros(2)
            u = [1.0, 2.0]
            λ = Common.ODEParameters(2.0)
            t = 0.0

            r(du, u, λ, t)
            Test.@test du ≈ -u
        end

        # =============================================================================
        # Test OoPSciMLOoPRHS
        # =============================================================================

        Test.@testset "OoPSciMLOoPRHS — call" begin
            f = ODEFunction{false}(FakeFOoP)
            r = CTFlowsSciMLFlows.OoPSciMLOoPRHS(f)

            u = [1.0, 2.0]
            λ = Common.ODEParameters(2.0)
            t = 0.0

            result = r(u, λ, t)
            Test.@test result ≈ -u
        end

        # =============================================================================
        # Test type stability
        # =============================================================================

        Test.@testset "Type Stability" begin
            f_ip = ODEFunction(FakeFIP)
            f_oop = ODEFunction{false}(FakeFOoP)

            ip_ip = CTFlowsSciMLFlows.IPSciMLIpRHS(f_ip)
            oop_ip = CTFlowsSciMLFlows.OoPSciMLIpRHS(f_ip)
            oop_finalize = CTFlowsSciMLFlows.OoPSciMLIpFinalizeRHS(f_ip)
            ip_oop = CTFlowsSciMLFlows.IPSciMLOoPRHS(f_oop)
            oop_oop = CTFlowsSciMLFlows.OoPSciMLOoPRHS(f_oop)

            du = zeros(2)
            u = [1.0, 2.0]
            u_svec = SA[1.0, 2.0]
            λ = Common.ODEParameters(2.0)
            t = 0.0

            Test.@inferred ip_ip(du, u, λ, t)
            Test.@inferred oop_ip(u, λ, t)
            Test.@inferred oop_finalize(u_svec, λ, t)
            Test.@inferred ip_oop(du, u, λ, t)
            Test.@inferred oop_oop(u, λ, t)
        end

        # =============================================================================
        # Test display
        # =============================================================================

        Test.@testset "Display" begin
            f_ip = ODEFunction(FakeFIP)
            f_oop = ODEFunction{false}(FakeFOoP)

            ip_ip = CTFlowsSciMLFlows.IPSciMLIpRHS(f_ip)
            oop_ip = CTFlowsSciMLFlows.OoPSciMLIpRHS(f_ip)
            oop_finalize = CTFlowsSciMLFlows.OoPSciMLIpFinalizeRHS(f_ip)
            ip_oop = CTFlowsSciMLFlows.IPSciMLOoPRHS(f_oop)
            oop_oop = CTFlowsSciMLFlows.OoPSciMLOoPRHS(f_oop)

            Test.@test occursin("IPSciMLIpRHS", sprint(show, ip_ip))
            Test.@test occursin("converts:", sprint(show, ip_ip))
            Test.@test occursin("OoPSciMLIpRHS", sprint(show, oop_ip))
            Test.@test occursin("converts:", sprint(show, oop_ip))
            Test.@test occursin("OoPSciMLIpFinalizeRHS", sprint(show, oop_finalize))
            Test.@test occursin("converts:", sprint(show, oop_finalize))
            Test.@test occursin("IPSciMLOoPRHS", sprint(show, ip_oop))
            Test.@test occursin("converts:", sprint(show, ip_oop))
            Test.@test occursin("OoPSciMLOoPRHS", sprint(show, oop_oop))
            Test.@test occursin("converts:", sprint(show, oop_oop))
        end

    end
end

end # module

# CRITICAL: Redefine in outer scope for TestRunner
test_sciml_rhs_functors() = TestSciMLRHSFunctors.test_sciml_rhs_functors()
