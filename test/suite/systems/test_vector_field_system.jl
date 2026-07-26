module TestVectorFieldSystem

using Test: Test
import CTFlows.Systems
import CTFlows.Configs
import CTBase.Data
import CTBase.Traits
import StaticArrays: SA, StaticArrays

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

# ==============================================================================
# Test function
# ==============================================================================

function test_vector_field_system()
    Test.@testset "VectorFieldSystem Tests" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ====================================================================
        # UNIT TESTS - Abstract Types
        # ====================================================================

        Test.@testset "Abstract Types" begin
            vf = Data.VectorField(x -> x; is_autonomous=true, is_variable=false)
            sys = Systems.VectorFieldSystem(vf)
            Test.@test sys isa Systems.VectorFieldSystem
            Test.@test sys isa Systems.AbstractSystem
        end

        # ====================================================================
        # UNIT TESTS - Construction
        # ====================================================================

        Test.@testset "Construction" begin
            Test.@testset "constructs from VectorField" begin
                vf = Data.VectorField(x -> x; is_autonomous=true, is_variable=false)
                sys = Systems.VectorFieldSystem(vf)
                Test.@test sys isa Systems.VectorFieldSystem
                Test.@test sys isa Systems.AbstractSystem
            end

            Test.@testset "trait propagation - Autonomous Fixed" begin
                vf = Data.VectorField(x -> x; is_autonomous=true, is_variable=false)
                sys = Systems.VectorFieldSystem(vf)
                Test.@test Traits.time_dependence(sys) === Traits.Autonomous
                Test.@test Traits.variable_dependence(sys) === Traits.Fixed
            end

            Test.@testset "trait propagation - NonAutonomous Fixed" begin
                vf = Data.VectorField(
                    (t, x) -> t .* x; is_autonomous=false, is_variable=false
                )
                sys = Systems.VectorFieldSystem(vf)
                Test.@test Traits.time_dependence(sys) === Traits.NonAutonomous
                Test.@test Traits.variable_dependence(sys) === Traits.Fixed
            end

            Test.@testset "trait propagation - Autonomous NonFixed" begin
                vf = Data.VectorField(
                    (x, v) -> x .+ v; is_autonomous=true, is_variable=true
                )
                sys = Systems.VectorFieldSystem(vf)
                Test.@test Traits.time_dependence(sys) === Traits.Autonomous
                Test.@test Traits.variable_dependence(sys) === Traits.NonFixed
            end

            Test.@testset "trait propagation - NonAutonomous NonFixed" begin
                vf = Data.VectorField(
                    (t, x, v) -> t .* x .+ v; is_autonomous=false, is_variable=true
                )
                sys = Systems.VectorFieldSystem(vf)
                Test.@test Traits.time_dependence(sys) === Traits.NonAutonomous
                Test.@test Traits.variable_dependence(sys) === Traits.NonFixed
            end
        end

        # ====================================================================
        # UNIT TESTS - vector_field getter
        # ====================================================================

        Test.@testset "vector_field getter" begin
            vf = Data.VectorField(x -> -x; is_autonomous=true, is_variable=false)
            sys = Systems.VectorFieldSystem(vf)
            Test.@test Systems.vector_field(sys) === sys.vf
            Test.@test Systems.vector_field(sys) === vf
        end

        # ====================================================================
        # UNIT TESTS - Contract Implementation
        # ====================================================================

        Test.@testset "Contract Implementation" begin
            # Lazy systems (issue #357): get_ip_rhs/get_oop_rhs read x0 from the config
            # to build the coercion — the config's x0 must match the u actually used.
            cfg(x0) = Configs.StateEndPointConfig(0.0, x0, 1.0)

            Test.@testset "get_ip_rhs returns callable" begin
                vf = Data.VectorField(x -> -x; is_autonomous=true, is_variable=false)
                sys = Systems.VectorFieldSystem(vf)
                rhs = Systems.get_ip_rhs(sys, cfg([1.0, 2.0]))
                Test.@test rhs isa Systems.AbstractRHS
            end

            Test.@testset "get_ip_rhs function has correct signature (du, u, p, t)" begin
                vf = Data.VectorField(x -> -x; is_autonomous=true, is_variable=false)
                sys = Systems.VectorFieldSystem(vf)
                rhs = Systems.get_ip_rhs(sys, cfg([1.0, 2.0]))
                du = zeros(2)
                u = [1.0, 2.0]
                p = Systems.ODEParameters(nothing)
                t = 0.0
                # Should not throw - signature is correct
                rhs(du, u, p, t)
                Test.@test du ≈ [-1.0, -2.0] atol=1e-10
            end

            Test.@testset "get_ip_rhs function fills du in place" begin
                vf = Data.VectorField(x -> -x; is_autonomous=true, is_variable=false)
                sys = Systems.VectorFieldSystem(vf)
                rhs = Systems.get_ip_rhs(sys, cfg([1.0, 2.0]))
                du = zeros(2)
                p = Systems.ODEParameters(nothing)
                rhs(du, [1.0, 2.0], p, 0.0)
                Test.@test du ≈ [-1.0, -2.0] atol=1e-10
            end

            Test.@testset "get_ip_rhs function uses underlying VectorField" begin
                vf1 = Data.VectorField(x -> 2 .* x; is_autonomous=true, is_variable=false)
                vf2 = Data.VectorField(x -> 3 .* x; is_autonomous=true, is_variable=false)
                sys1 = Systems.VectorFieldSystem(vf1)
                sys2 = Systems.VectorFieldSystem(vf2)
                rhs1 = Systems.get_ip_rhs(sys1, cfg([1.0, 1.0]))
                rhs2 = Systems.get_ip_rhs(sys2, cfg([1.0, 1.0]))
                du1 = zeros(2)
                du2 = zeros(2)
                p = Systems.ODEParameters(nothing)
                rhs1(du1, [1.0, 1.0], p, 0.0)
                rhs2(du2, [1.0, 1.0], p, 0.0)
                Test.@test du1 ≈ [2.0, 2.0] atol=1e-10
                Test.@test du2 ≈ [3.0, 3.0] atol=1e-10
            end

            Test.@testset "get_oop_rhs returns callable" begin
                vf = Data.VectorField(x -> -x; is_autonomous=true, is_variable=false)
                sys = Systems.VectorFieldSystem(vf)
                rhs_oop = Systems.get_oop_rhs(sys, cfg([1.0, 2.0]))
                Test.@test rhs_oop isa Systems.AbstractRHS
            end

            Test.@testset "get_oop_rhs function has correct signature (u, p, t)" begin
                vf = Data.VectorField(x -> -x; is_autonomous=true, is_variable=false)
                sys = Systems.VectorFieldSystem(vf)
                rhs_oop = Systems.get_oop_rhs(sys, cfg([1.0, 2.0]))
                u = [1.0, 2.0]
                p = Systems.ODEParameters(nothing)
                t = 0.0
                du = rhs_oop(u, p, t)
                Test.@test du ≈ [-1.0, -2.0] atol=1e-10
            end

            Test.@testset "get_oop_rhs is lazy (not cached across calls)" begin
                vf = Data.VectorField(x -> -x; is_autonomous=true, is_variable=false)
                sys = Systems.VectorFieldSystem(vf)
                rhs_oop1 = Systems.get_oop_rhs(sys, cfg([1.0, 2.0]))
                rhs_oop2 = Systems.get_oop_rhs(sys, cfg([1.0, 2.0]))
                Test.@test rhs_oop1 isa Systems.AbstractRHS
                Test.@test rhs_oop2 isa Systems.AbstractRHS
                # Built fresh each call (config-driven, per issue #357), unlike the
                # previous eager implementation which cached one closure at construction.
            end

            Test.@testset "get_ip_rhs with matrix" begin
                vf = Data.VectorField(x -> -x; is_autonomous=true, is_variable=false)
                sys = Systems.VectorFieldSystem(vf)
                u = [1.0 2.0 3.0; 4.0 5.0 6.0]
                rhs = Systems.get_ip_rhs(sys, cfg(u))
                du = zeros(2, 3)
                p = Systems.ODEParameters(nothing)
                rhs(du, u, p, 0.0)
                Test.@test du ≈ -u atol=1e-10
            end

            Test.@testset "get_oop_rhs with matrix" begin
                vf = Data.VectorField(x -> -x; is_autonomous=true, is_variable=false)
                sys = Systems.VectorFieldSystem(vf)
                u = [1.0 2.0 3.0; 4.0 5.0 6.0]
                rhs_oop = Systems.get_oop_rhs(sys, cfg(u))
                p = Systems.ODEParameters(nothing)
                du = rhs_oop(u, p, 0.0)
                Test.@test du ≈ -u atol=1e-10
            end
        end

        # ====================================================================
        # UNIT TESTS - Complex numbers
        # ====================================================================

        Test.@testset "Complex numbers" begin
            vf = Data.VectorField(x -> -x; is_autonomous=true, is_variable=false)
            sys = Systems.VectorFieldSystem(vf)
            cplx_cfg = Configs.StateEndPointConfig(0.0, [1.0 + 2.0im, 3.0 + 4.0im], 1.0)
            rhs = Systems.get_ip_rhs(sys, cplx_cfg)
            rhs_oop = Systems.get_oop_rhs(sys, cplx_cfg)
            p = Systems.ODEParameters(nothing)

            Test.@testset "get_ip_rhs - complex vector" begin
                u = [1.0 + 2.0im, 3.0 + 4.0im]
                du = zeros(ComplexF64, 2)
                rhs(du, u, p, 0.0)
                Test.@test du ≈ [-1.0-2.0im, -3.0-4.0im] atol=1e-10
            end

            Test.@testset "get_oop_rhs - complex vector" begin
                u = [1.0 + 2.0im, 3.0 + 4.0im]
                du = rhs_oop(u, p, 0.0)
                Test.@test du ≈ [-1.0-2.0im, -3.0-4.0im] atol=1e-10
            end

            Test.@testset "get_ip_rhs - complex matrix" begin
                u = [1.0+2.0im 5.0+6.0im; 3.0+4.0im 7.0+8.0im]
                du = zeros(ComplexF64, 2, 2)
                rhs(du, u, p, 0.0)
                Test.@test du ≈ -u atol=1e-10
            end

            Test.@testset "get_oop_rhs - complex matrix" begin
                u = [1.0+2.0im 5.0+6.0im; 3.0+4.0im 7.0+8.0im]
                du = rhs_oop(u, p, 0.0)
                Test.@test du ≈ -u atol=1e-10
            end
        end

        # ====================================================================
        # UNIT TESTS - SVector unit
        # ====================================================================

        Test.@testset "SVector unit" begin
            Test.@testset "get_oop_rhs with SVector" begin
                vf = Data.VectorField(x -> -x; is_autonomous=true, is_variable=false)
                sys = Systems.VectorFieldSystem(vf)
                u = SA[1.0, 2.0]
                rhs_oop = Systems.get_oop_rhs(sys, Configs.StateEndPointConfig(0.0, u, 1.0))
                p = Systems.ODEParameters(nothing)
                du = rhs_oop(u, p, 0.0)
                Test.@test du == SA[-1.0, -2.0]
            end

            Test.@testset "get_oop_rhs with SVector complex" begin
                vf = Data.VectorField(x -> -x; is_autonomous=true, is_variable=false)
                sys = Systems.VectorFieldSystem(vf)
                u = SA[1.0 + 2.0im, 3.0 + 4.0im]
                rhs_oop = Systems.get_oop_rhs(sys, Configs.StateEndPointConfig(0.0, u, 1.0))
                p = Systems.ODEParameters(nothing)
                du = rhs_oop(u, p, 0.0)
                Test.@test du == SA[-1.0 - 2.0im, -3.0 - 4.0im]
            end
        end

        # ====================================================================
        # UNIT TESTS - InPlace VectorField
        # ====================================================================

        Test.@testset "InPlace VectorField" begin
            Test.@testset "OOP: get_oop_rhs returns the plain OOP functor (no finalize path)" begin
                vf = Data.VectorField(x -> -x; is_autonomous=true, is_variable=false)
                sys = Systems.VectorFieldSystem(vf)
                f = Systems.get_oop_rhs(
                    sys, Configs.StateEndPointConfig(0.0, [1.0, 2.0], 1.0)
                )
                Test.@test f isa Systems.AbstractRHS
            end

            Test.@testset "IP: get_oop_rhs with immutable u returns finalize functor" begin
                vf = Data.VectorField(
                    (du, x) -> (du .= -x); is_autonomous=true, is_variable=false
                )
                sys = Systems.VectorFieldSystem(vf)
                u = SA[1.0, 2.0]
                f = Test.@test_logs (:warn, r"InPlace VectorField") Systems.get_oop_rhs(
                    sys, Configs.StateEndPointConfig(0.0, u, 1.0)
                )
                Test.@test f isa Systems.AbstractRHS
            end

            Test.@testset "IP: get_ip_rhs fills du via in-place call" begin
                vf = Data.VectorField(
                    (du, x) -> (du .= -x); is_autonomous=true, is_variable=false
                )
                sys = Systems.VectorFieldSystem(vf)
                du = zeros(2)
                p = Systems.ODEParameters(nothing)
                config = Configs.StateEndPointConfig(0.0, [1.0, 2.0], 1.0)
                Systems.get_ip_rhs(sys, config)(du, [1.0, 2.0], p, 0.0)
                Test.@test du ≈ [-1.0, -2.0]
            end

            Test.@testset "IP: rhs_oop_finalize returns SVector for SVector u" begin
                vf = Data.VectorField(
                    (du, x) -> (du .= -x); is_autonomous=true, is_variable=false
                )
                sys = Systems.VectorFieldSystem(vf)
                u = SA[1.0, 2.0]
                f = Test.@test_logs (:warn, r"InPlace VectorField") Systems.get_oop_rhs(
                    sys, Configs.StateEndPointConfig(0.0, u, 1.0)
                )
                p = Systems.ODEParameters(nothing)
                du = f(u, p, 0.0)
                Test.@test du ≈ SA[-1.0, -2.0]
                Test.@test du isa StaticArrays.SVector
            end
        end

        # ====================================================================
        # UNIT TESTS - Trait Methods
        # ====================================================================

        Test.@testset "Trait Methods" begin
            Test.@testset "time_dependence returns correct trait" begin
                vf_aut = Data.VectorField(x -> x; is_autonomous=true, is_variable=false)
                sys_aut = Systems.VectorFieldSystem(vf_aut)
                Test.@test Traits.time_dependence(sys_aut) === Traits.Autonomous

                vf_nonaut = Data.VectorField(
                    (t, x) -> t .* x; is_autonomous=false, is_variable=false
                )
                sys_nonaut = Systems.VectorFieldSystem(vf_nonaut)
                Test.@test Traits.time_dependence(sys_nonaut) === Traits.NonAutonomous
            end

            Test.@testset "variable_dependence returns correct trait" begin
                vf_fixed = Data.VectorField(x -> x; is_autonomous=true, is_variable=false)
                sys_fixed = Systems.VectorFieldSystem(vf_fixed)
                Test.@test Traits.variable_dependence(sys_fixed) === Traits.Fixed

                vf_nonfixed = Data.VectorField(
                    (x, v) -> x .+ v; is_autonomous=true, is_variable=true
                )
                sys_nonfixed = Systems.VectorFieldSystem(vf_nonfixed)
                Test.@test Traits.variable_dependence(sys_nonfixed) === Traits.NonFixed
            end
        end

        # ====================================================================
        # UNIT TESTS - Show Methods
        # ====================================================================

        Test.@testset "Show Methods" begin
            vf = Data.VectorField(x -> x; is_autonomous=true, is_variable=false)
            sys = Systems.VectorFieldSystem(vf)

            Test.@testset "Base.show (compact)" begin
                io = IOBuffer()
                show(io, sys)
                str = String(take!(io))
                Test.@test occursin("VectorFieldSystem", str)
                Test.@test occursin("time_dependence", str)
                Test.@test occursin("variable_dependence", str)
                Test.@test occursin("autonomous", str)
                Test.@test occursin("fixed (no variable)", str)
                Test.@test occursin("out-of-place", str)
                Test.@test occursin("natural call", str)
                Test.@test occursin("uniform call", str)
            end

            Test.@testset "Base.show (text/plain)" begin
                io = IOBuffer()
                show(io, MIME("text/plain"), sys)
                str = String(take!(io))
                Test.@test occursin("VectorFieldSystem", str)
                Test.@test occursin("time_dependence", str)
            end
        end

        # ====================================================================
        # UNIT TESTS - Common Trait Predicates
        # ====================================================================

        Test.@testset "Common Trait Predicates" begin
            Test.@testset "has_time_dependence_trait returns true" begin
                vf = Data.VectorField(x -> x; is_autonomous=true, is_variable=false)
                sys = Systems.VectorFieldSystem(vf)
                Test.@test Traits.has_time_dependence_trait(sys) === true
            end

            Test.@testset "has_variable_dependence_trait returns true" begin
                vf = Data.VectorField(x -> x; is_autonomous=true, is_variable=false)
                sys = Systems.VectorFieldSystem(vf)
                Test.@test Traits.has_variable_dependence_trait(sys) === true
            end

            Test.@testset "is_autonomous / is_nonautonomous" begin
                vf_aut = Data.VectorField(x -> x; is_autonomous=true, is_variable=false)
                sys_aut = Systems.VectorFieldSystem(vf_aut)
                Test.@test Traits.is_autonomous(sys_aut) === true
                Test.@test Traits.is_nonautonomous(sys_aut) === false

                vf_nonaut = Data.VectorField(
                    (t, x) -> t .* x; is_autonomous=false, is_variable=false
                )
                sys_nonaut = Systems.VectorFieldSystem(vf_nonaut)
                Test.@test Traits.is_autonomous(sys_nonaut) === false
                Test.@test Traits.is_nonautonomous(sys_nonaut) === true
            end

            Test.@testset "is_variable / is_nonvariable" begin
                vf_fixed = Data.VectorField(x -> x; is_autonomous=true, is_variable=false)
                sys_fixed = Systems.VectorFieldSystem(vf_fixed)
                Test.@test Traits.is_variable(sys_fixed) === false
                Test.@test Traits.is_nonvariable(sys_fixed) === true

                vf_nonfixed = Data.VectorField(
                    (x, v) -> x .+ v; is_autonomous=true, is_variable=true
                )
                sys_nonfixed = Systems.VectorFieldSystem(vf_nonfixed)
                Test.@test Traits.is_variable(sys_nonfixed) === true
                Test.@test Traits.is_nonvariable(sys_nonfixed) === false
            end
        end

        # ====================================================================
        # UNIT TESTS - Exports Verification
        # ====================================================================

        Test.@testset "Exports Verification" begin
            Test.@testset "Exported types" begin
                Test.@test isdefined(Systems, :VectorFieldSystem)
            end
            Test.@testset "Exported getters" begin
                Test.@test isdefined(Systems, :vector_field)
            end
        end
    end
end

end # module

test_vector_field_system() = TestVectorFieldSystem.test_vector_field_system()
