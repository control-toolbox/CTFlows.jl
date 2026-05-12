module TestVectorFieldSystem

import Test
import CTFlows.Systems
import CTFlows.Common
import StaticArrays: SA, StaticArrays

const VERBOSE = isdefined(Main, :TestOptions) ? Main.TestOptions.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestOptions) ? Main.TestOptions.SHOWTIMING : true

# ==============================================================================
# Test function
# ==============================================================================

function test_vector_field_system()
    Test.@testset "VectorFieldSystem Tests" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ====================================================================
        # UNIT TESTS - Abstract Types
        # ====================================================================

        Test.@testset "Abstract Types" begin
            vf = Systems.VectorField(x -> x; is_autonomous=true, is_variable=false)
            sys = Systems.VectorFieldSystem(vf)
            Test.@test sys isa Systems.VectorFieldSystem
            Test.@test sys isa Systems.AbstractSystem
        end

        # ====================================================================
        # UNIT TESTS - Construction
        # ====================================================================

        Test.@testset "Construction" begin
            Test.@testset "constructs from VectorField" begin
                vf = Systems.VectorField(x -> x; is_autonomous=true, is_variable=false)
                sys = Systems.VectorFieldSystem(vf)
                Test.@test sys isa Systems.VectorFieldSystem
                Test.@test sys isa Systems.AbstractSystem
            end

            Test.@testset "trait propagation - Autonomous Fixed" begin
                vf = Systems.VectorField(x -> x; is_autonomous=true, is_variable=false)
                sys = Systems.VectorFieldSystem(vf)
                Test.@test Common.time_dependence(sys) === Common.Autonomous
                Test.@test Common.variable_dependence(sys) === Common.Fixed
            end

            Test.@testset "trait propagation - NonAutonomous Fixed" begin
                vf = Systems.VectorField((t, x) -> t .* x; is_autonomous=false, is_variable=false)
                sys = Systems.VectorFieldSystem(vf)
                Test.@test Common.time_dependence(sys) === Common.NonAutonomous
                Test.@test Common.variable_dependence(sys) === Common.Fixed
            end

            Test.@testset "trait propagation - Autonomous NonFixed" begin
                vf = Systems.VectorField((x, v) -> x .+ v; is_autonomous=true, is_variable=true)
                sys = Systems.VectorFieldSystem(vf)
                Test.@test Common.time_dependence(sys) === Common.Autonomous
                Test.@test Common.variable_dependence(sys) === Common.NonFixed
            end

            Test.@testset "trait propagation - NonAutonomous NonFixed" begin
                vf = Systems.VectorField((t, x, v) -> t .* x .+ v; is_autonomous=false, is_variable=true)
                sys = Systems.VectorFieldSystem(vf)
                Test.@test Common.time_dependence(sys) === Common.NonAutonomous
                Test.@test Common.variable_dependence(sys) === Common.NonFixed
            end
        end

        # ====================================================================
        # UNIT TESTS - Contract Implementation
        # ====================================================================

        Test.@testset "Contract Implementation" begin
            Test.@testset "rhs returns callable" begin
                vf = Systems.VectorField(x -> -x; is_autonomous=true, is_variable=false)
                sys = Systems.VectorFieldSystem(vf)
                rhs = Systems.rhs(sys)
                Test.@test rhs isa Function
            end

            Test.@testset "rhs function has correct signature (du, u, p, t)" begin
                vf = Systems.VectorField(x -> -x; is_autonomous=true, is_variable=false)
                sys = Systems.VectorFieldSystem(vf)
                rhs = Systems.rhs(sys)
                du = zeros(2)
                u = [1.0, 2.0]
                p = Common.ODEParameters(nothing)
                t = 0.0
                # Should not throw - signature is correct
                rhs(du, u, p, t)
                Test.@test du ≈ [-1.0, -2.0] atol=1e-10
            end

            Test.@testset "rhs function fills du in place" begin
                vf = Systems.VectorField(x -> -x; is_autonomous=true, is_variable=false)
                sys = Systems.VectorFieldSystem(vf)
                rhs = Systems.rhs(sys)
                du = zeros(2)
                p = Common.ODEParameters(nothing)
                rhs(du, [1.0, 2.0], p, 0.0)
                Test.@test du ≈ [-1.0, -2.0] atol=1e-10
            end

            Test.@testset "rhs function uses underlying VectorField" begin
                vf1 = Systems.VectorField(x -> 2 .* x; is_autonomous=true, is_variable=false)
                vf2 = Systems.VectorField(x -> 3 .* x; is_autonomous=true, is_variable=false)
                sys1 = Systems.VectorFieldSystem(vf1)
                sys2 = Systems.VectorFieldSystem(vf2)
                rhs1 = Systems.rhs(sys1)
                rhs2 = Systems.rhs(sys2)
                du1 = zeros(2)
                du2 = zeros(2)
                p = Common.ODEParameters(nothing)
                rhs1(du1, [1.0, 1.0], p, 0.0)
                rhs2(du2, [1.0, 1.0], p, 0.0)
                Test.@test du1 ≈ [2.0, 2.0] atol=1e-10
                Test.@test du2 ≈ [3.0, 3.0] atol=1e-10
            end

            Test.@testset "rhs_oop returns callable" begin
                vf = Systems.VectorField(x -> -x; is_autonomous=true, is_variable=false)
                sys = Systems.VectorFieldSystem(vf)
                rhs_oop = Systems.rhs_oop(sys)
                Test.@test rhs_oop isa Function
            end

            Test.@testset "rhs_oop function has correct signature (u, p, t)" begin
                vf = Systems.VectorField(x -> -x; is_autonomous=true, is_variable=false)
                sys = Systems.VectorFieldSystem(vf)
                rhs_oop = Systems.rhs_oop(sys)
                u = [1.0, 2.0]
                p = Common.ODEParameters(nothing)
                t = 0.0
                du = rhs_oop(u, p, t)
                Test.@test du ≈ [-1.0, -2.0] atol=1e-10
            end

            Test.@testset "rhs_oop stored" begin
                vf = Systems.VectorField(x -> -x; is_autonomous=true, is_variable=false)
                sys = Systems.VectorFieldSystem(vf)
                Test.@test sys.rhs_oop isa Function
                Test.@test Systems.rhs_oop(sys) === sys.rhs_oop
            end

            Test.@testset "rhs with matrix" begin
                vf = Systems.VectorField(x -> -x; is_autonomous=true, is_variable=false)
                sys = Systems.VectorFieldSystem(vf)
                rhs = Systems.rhs(sys)
                du = zeros(2, 3)
                u = [1.0 2.0 3.0; 4.0 5.0 6.0]
                p = Common.ODEParameters(nothing)
                rhs(du, u, p, 0.0)
                Test.@test du ≈ -u  atol=1e-10
            end

            Test.@testset "rhs_oop with matrix" begin
                vf = Systems.VectorField(x -> -x; is_autonomous=true, is_variable=false)
                sys = Systems.VectorFieldSystem(vf)
                rhs_oop = Systems.rhs_oop(sys)
                u = [1.0 2.0 3.0; 4.0 5.0 6.0]
                p = Common.ODEParameters(nothing)
                du = rhs_oop(u, p, 0.0)
                Test.@test du ≈ -u  atol=1e-10
            end
        end

        # ====================================================================
        # UNIT TESTS - Complex numbers
        # ====================================================================

        Test.@testset "Complex numbers" begin
            vf = Systems.VectorField(x -> -x; is_autonomous=true, is_variable=false)
            sys = Systems.VectorFieldSystem(vf)
            rhs     = Systems.rhs(sys)
            rhs_oop = Systems.rhs_oop(sys)
            p = Common.ODEParameters(nothing)

            Test.@testset "rhs - complex vector" begin
                u  = [1.0 + 2.0im, 3.0 + 4.0im]
                du = zeros(ComplexF64, 2)
                rhs(du, u, p, 0.0)
                Test.@test du ≈ [-1.0-2.0im, -3.0-4.0im]  atol=1e-10
            end

            Test.@testset "rhs_oop - complex vector" begin
                u  = [1.0 + 2.0im, 3.0 + 4.0im]
                du = rhs_oop(u, p, 0.0)
                Test.@test du ≈ [-1.0-2.0im, -3.0-4.0im]  atol=1e-10
            end

            Test.@testset "rhs - complex matrix" begin
                u  = [1.0+2.0im  5.0+6.0im; 3.0+4.0im  7.0+8.0im]
                du = zeros(ComplexF64, 2, 2)
                rhs(du, u, p, 0.0)
                Test.@test du ≈ -u  atol=1e-10
            end

            Test.@testset "rhs_oop - complex matrix" begin
                u  = [1.0+2.0im  5.0+6.0im; 3.0+4.0im  7.0+8.0im]
                du = rhs_oop(u, p, 0.0)
                Test.@test du ≈ -u  atol=1e-10
            end
        end

        # ====================================================================
        # UNIT TESTS - SVector unit
        # ====================================================================

        Test.@testset "SVector unit" begin
            Test.@testset "rhs_oop with SVector" begin
                vf = Systems.VectorField(x -> -x; is_autonomous=true, is_variable=false)
                sys = Systems.VectorFieldSystem(vf)
                rhs_oop = Systems.rhs_oop(sys)
                u = SA[1.0, 2.0]
                p = Common.ODEParameters(nothing)
                du = rhs_oop(u, p, 0.0)
                Test.@test du == SA[-1.0, -2.0]
            end

            Test.@testset "rhs_oop with SVector complex" begin
                vf = Systems.VectorField(x -> -x; is_autonomous=true, is_variable=false)
                sys = Systems.VectorFieldSystem(vf)
                rhs_oop = Systems.rhs_oop(sys)
                u = SA[1.0+2.0im, 3.0+4.0im]
                p = Common.ODEParameters(nothing)
                du = rhs_oop(u, p, 0.0)
                Test.@test du == SA[-1.0-2.0im, -3.0-4.0im]
            end
        end

        # ====================================================================
        # UNIT TESTS - InPlace VectorField
        # ====================================================================

        Test.@testset "InPlace VectorField" begin
            Test.@testset "OOP: rhs_oop_finalize is Nothing" begin
                vf  = Systems.VectorField(x -> -x; is_autonomous=true, is_variable=false)
                sys = Systems.VectorFieldSystem(vf)
                Test.@test sys.rhs_oop_finalize === nothing
            end

            Test.@testset "IP: rhs_oop_finalize is Function" begin
                vf  = Systems.VectorField((du, x) -> (du .= -x); is_autonomous=true, is_variable=false)
                sys = Systems.VectorFieldSystem(vf)
                Test.@test sys.rhs_oop_finalize isa Function
            end

            Test.@testset "IP: rhs fills du via in-place call" begin
                vf  = Systems.VectorField((du, x) -> (du .= -x); is_autonomous=true, is_variable=false)
                sys = Systems.VectorFieldSystem(vf)
                du  = zeros(2)
                p   = Common.ODEParameters(nothing)
                Systems.rhs(sys)(du, [1.0, 2.0], p, 0.0)
                Test.@test du ≈ [-1.0, -2.0]
            end

            Test.@testset "IP: rhs_oop(sys, true) === sys.rhs_oop" begin
                vf  = Systems.VectorField((du, x) -> (du .= -x); is_autonomous=true, is_variable=false)
                sys = Systems.VectorFieldSystem(vf)
                Test.@test Systems.rhs_oop(sys, true) === sys.rhs_oop
            end

            Test.@testset "IP: rhs_oop(sys, false) === sys.rhs_oop_finalize and warns" begin
                vf  = Systems.VectorField((du, x) -> (du .= -x); is_autonomous=true, is_variable=false)
                sys = Systems.VectorFieldSystem(vf)
                f   = Test.@test_logs (:warn, r"InPlace VectorField") Systems.rhs_oop(sys, false)
                Test.@test f === sys.rhs_oop_finalize
            end

            Test.@testset "IP: rhs_oop(sys, true) returns mutable Vector" begin
                vf  = Systems.VectorField((du, x) -> (du .= -x); is_autonomous=true, is_variable=false)
                sys = Systems.VectorFieldSystem(vf)
                f   = Systems.rhs_oop(sys, true)
                p   = Common.ODEParameters(nothing)
                du  = f([1.0, 2.0], p, 0.0)
                Test.@test du ≈ [-1.0, -2.0]
                Test.@test du isa Vector
            end

            Test.@testset "IP: rhs_oop_finalize returns SVector for SVector u" begin
                vf  = Systems.VectorField((du, x) -> (du .= -x); is_autonomous=true, is_variable=false)
                sys = Systems.VectorFieldSystem(vf)
                f   = sys.rhs_oop_finalize
                u   = SA[1.0, 2.0]
                p   = Common.ODEParameters(nothing)
                du  = f(u, p, 0.0)
                Test.@test du ≈ SA[-1.0, -2.0]
                Test.@test du isa StaticArrays.SVector
            end

            Test.@testset "OOP: rhs_oop(sys, false) still returns sys.rhs_oop" begin
                vf  = Systems.VectorField(x -> -x; is_autonomous=true, is_variable=false)
                sys = Systems.VectorFieldSystem(vf)
                Test.@test Systems.rhs_oop(sys, true)  === sys.rhs_oop
                Test.@test Systems.rhs_oop(sys, false) === sys.rhs_oop
            end
        end

        # ====================================================================
        # UNIT TESTS - Trait Methods
        # ====================================================================

        Test.@testset "Trait Methods" begin
            Test.@testset "time_dependence returns correct trait" begin
                vf_aut = Systems.VectorField(x -> x; is_autonomous=true, is_variable=false)
                sys_aut = Systems.VectorFieldSystem(vf_aut)
                Test.@test Common.time_dependence(sys_aut) === Common.Autonomous

                vf_nonaut = Systems.VectorField((t, x) -> t .* x; is_autonomous=false, is_variable=false)
                sys_nonaut = Systems.VectorFieldSystem(vf_nonaut)
                Test.@test Common.time_dependence(sys_nonaut) === Common.NonAutonomous
            end

            Test.@testset "variable_dependence returns correct trait" begin
                vf_fixed = Systems.VectorField(x -> x; is_autonomous=true, is_variable=false)
                sys_fixed = Systems.VectorFieldSystem(vf_fixed)
                Test.@test Common.variable_dependence(sys_fixed) === Common.Fixed

                vf_nonfixed = Systems.VectorField((x, v) -> x .+ v; is_autonomous=true, is_variable=true)
                sys_nonfixed = Systems.VectorFieldSystem(vf_nonfixed)
                Test.@test Common.variable_dependence(sys_nonfixed) === Common.NonFixed
            end
        end

        # ====================================================================
        # UNIT TESTS - Common Trait Predicates
        # ====================================================================

        Test.@testset "Common Trait Predicates" begin
            Test.@testset "has_time_dependence_trait returns true" begin
                vf = Systems.VectorField(x -> x; is_autonomous=true, is_variable=false)
                sys = Systems.VectorFieldSystem(vf)
                Test.@test Common.has_time_dependence_trait(sys) === true
            end

            Test.@testset "has_variable_dependence_trait returns true" begin
                vf = Systems.VectorField(x -> x; is_autonomous=true, is_variable=false)
                sys = Systems.VectorFieldSystem(vf)
                Test.@test Common.has_variable_dependence_trait(sys) === true
            end

            Test.@testset "is_autonomous / is_nonautonomous" begin
                vf_aut = Systems.VectorField(x -> x; is_autonomous=true, is_variable=false)
                sys_aut = Systems.VectorFieldSystem(vf_aut)
                Test.@test Common.is_autonomous(sys_aut) === true
                Test.@test Common.is_nonautonomous(sys_aut) === false

                vf_nonaut = Systems.VectorField((t, x) -> t .* x; is_autonomous=false, is_variable=false)
                sys_nonaut = Systems.VectorFieldSystem(vf_nonaut)
                Test.@test Common.is_autonomous(sys_nonaut) === false
                Test.@test Common.is_nonautonomous(sys_nonaut) === true
            end

            Test.@testset "is_variable / is_nonvariable" begin
                vf_fixed = Systems.VectorField(x -> x; is_autonomous=true, is_variable=false)
                sys_fixed = Systems.VectorFieldSystem(vf_fixed)
                Test.@test Common.is_variable(sys_fixed) === false
                Test.@test Common.is_nonvariable(sys_fixed) === true

                vf_nonfixed = Systems.VectorField((x, v) -> x .+ v; is_autonomous=true, is_variable=true)
                sys_nonfixed = Systems.VectorFieldSystem(vf_nonfixed)
                Test.@test Common.is_variable(sys_nonfixed) === true
                Test.@test Common.is_nonvariable(sys_nonfixed) === false
            end
        end

        # ====================================================================
        # UNIT TESTS - Exports Verification
        # ====================================================================

        Test.@testset "Exports Verification" begin
            Test.@testset "Exported types" begin
                Test.@test isdefined(Systems, :VectorFieldSystem)
            end
        end
    end
end

end # module

test_vector_field_system() = TestVectorFieldSystem.test_vector_field_system()
