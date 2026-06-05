module TestHamiltonianGetter

import Test
import ADTypes
import DifferentiationInterface
import CTFlows.Common
import CTFlows.Traits
import CTFlows.Data
import CTFlows.Systems
import CTFlows.Differentiation

const VERBOSE = isdefined(Main, :TestOptions) ? Main.TestOptions.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestOptions) ? Main.TestOptions.SHOWTIMING : true

# ==============================================================================
# Fake types for testing
# ==============================================================================

struct FakeADBackend <: Differentiation.AbstractADBackend end

struct MockADBackend <: Differentiation.AbstractADBackend end

# Fake system for contract stub test
struct FakeHamiltonianSystem <: Systems.AbstractHamiltonianSystem{Traits.Autonomous, Traits.Fixed} end

# Mock implementations for testing (without full extension)
function Differentiation.hamiltonian_gradient(backend::MockADBackend, h, t, x, p, v, cache)
    # Simple mock: return zero gradients
    ∂x = zero(x)
    ∂p = zero(p)
    return (∂x, ∂p)
end

function Differentiation.variable_gradient(backend::MockADBackend, h, t, x, p, v, cache)
    return 0.0
end

function Differentiation.ad_backend(backend::MockADBackend)
    return ADTypes.AutoForwardDiff()
end

# ==============================================================================
# Test function
# ==============================================================================

function test_hamiltonian_getter()
    Test.@testset "Hamiltonian Getter Tests" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ====================================================================
        # UNIT TESTS - Contract
        # ====================================================================

        Test.@testset "Contract: ad_backend stub throws NotImplemented" begin
            backend = FakeADBackend()
            Test.@test_throws Exception Differentiation.ad_backend(backend)
        end

        # ====================================================================
        # FUNCTIONAL TESTS - Hamiltonian getter (structure only)
        # ====================================================================

        Test.@testset "Hamiltonian getter returns HamiltonianVectorField (Autonomous/Fixed)" begin
            h = Data.Hamiltonian((x, p) -> 0.5 * sum(x.^2) + 0.5 * sum(p.^2); is_autonomous=true, is_variable=false)
            hvf = Systems.hamiltonian_vector_field(h; ad_backend=MockADBackend(), inplace=false)
            Test.@test hvf isa Data.HamiltonianVectorField
            Test.@test hvf.f isa Function
        end

        Test.@testset "Hamiltonian getter returns HamiltonianVectorField (NonAutonomous/Fixed)" begin
            h = Data.Hamiltonian((t, x, p) -> t * sum(x.^2) + sum(p.^2); is_autonomous=false, is_variable=false)
            hvf = Systems.hamiltonian_vector_field(h; ad_backend=MockADBackend(), inplace=false)
            Test.@test hvf isa Data.HamiltonianVectorField
            Test.@test hvf.f isa Function
        end

        Test.@testset "Hamiltonian getter returns HamiltonianVectorField (Autonomous/NonFixed)" begin
            h = Data.Hamiltonian((x, p, v) -> 0.5 * sum(x.^2) + 0.5 * sum(p.^2) + v; is_autonomous=true, is_variable=true)
            hvf = Systems.hamiltonian_vector_field(h; ad_backend=MockADBackend(), inplace=false)
            Test.@test hvf isa Data.HamiltonianVectorField
            Test.@test hvf.f isa Function
        end

        Test.@testset "Hamiltonian getter returns HamiltonianVectorField (NonAutonomous/NonFixed)" begin
            h = Data.Hamiltonian((t, x, p, v) -> t * sum(x.^2) + sum(p.^2) + v; is_autonomous=false, is_variable=true)
            hvf = Systems.hamiltonian_vector_field(h; ad_backend=MockADBackend(), inplace=false)
            Test.@test hvf isa Data.HamiltonianVectorField
            Test.@test hvf.f isa Function
        end

        # ====================================================================
        # FUNCTIONAL TESTS - HamiltonianVectorFieldSystem trivial getter
        # ====================================================================

        Test.@testset "HamiltonianVectorFieldSystem trivial getter" begin
            f = (x, p) -> (p, -x)
            hvf = Data.HamiltonianVectorField(f; is_autonomous=true, is_variable=false)
            sys = Systems.HamiltonianVectorFieldSystem(hvf)
            hvf_retrieved = Systems.hamiltonian_vector_field(sys)
            Test.@test hvf_retrieved === hvf
        end

        # ====================================================================
        # FUNCTIONAL TESTS - HamiltonianSystem getter (structure only)
        # ====================================================================

        Test.@testset "HamiltonianSystem getter returns HamiltonianVectorField (Autonomous/Fixed)" begin
            h = Data.Hamiltonian((x, p) -> 0.5 * sum(x.^2) + 0.5 * sum(p.^2); is_autonomous=true, is_variable=false)
            backend = Differentiation.DifferentiationInterface(; ad_backend=ADTypes.AutoForwardDiff())
            sys = Systems.HamiltonianSystem(h, backend)
            hvf = Systems.hamiltonian_vector_field(sys; inplace=false)
            Test.@test hvf isa Data.HamiltonianVectorField
            Test.@test hvf.f isa Function
        end

        # ====================================================================
        # REAL TESTS - with DifferentiationInterface (if loaded)
        # ====================================================================

        Test.@testset "Real test: OOP Autonomous/Fixed" begin
            h = Data.Hamiltonian((x, p) -> 0.5 * sum(x.^2) + 0.5 * sum(p.^2); is_autonomous=true, is_variable=false)
            backend = Differentiation.DifferentiationInterface(; ad_backend=ADTypes.AutoForwardDiff())
            sys = Systems.HamiltonianSystem(h, backend)
            hvf = Systems.hamiltonian_vector_field(sys; inplace=false)
            Test.@test hvf isa Data.HamiltonianVectorField
            
            x = [1.0, 2.0]
            p = [0.5, 1.5]
            result = hvf.f(x, p)
            Test.@test result isa Tuple
            Test.@test length(result) == 2
            Test.@test result[1] ≈ p  # ∂H/∂p = p
            Test.@test result[2] ≈ -x  # -∂H/∂x = -x
        end

        Test.@testset "Real test: OOP NonAutonomous/Fixed" begin
            h = Data.Hamiltonian((t, x, p) -> 0.5 * sum(x.^2) + 0.5 * sum(p.^2); is_autonomous=false, is_variable=false)
            backend = Differentiation.DifferentiationInterface(; ad_backend=ADTypes.AutoForwardDiff())
            sys = Systems.HamiltonianSystem(h, backend)
            hvf = Systems.hamiltonian_vector_field(sys; inplace=false)
            
            t = 1.0
            x = [1.0, 2.0]
            p = [0.5, 1.5]
            result = hvf.f(t, x, p)
            Test.@test result isa Tuple
            Test.@test length(result) == 2
            Test.@test result[1] ≈ p
            Test.@test result[2] ≈ -x
        end

        Test.@testset "Real test: OOP Autonomous/NonFixed without variable_costate" begin
            h = Data.Hamiltonian((x, p, v) -> 0.5 * sum(x.^2) + 0.5 * sum(p.^2) + sum(v); is_autonomous=true, is_variable=true)
            backend = Differentiation.DifferentiationInterface(; ad_backend=ADTypes.AutoForwardDiff())
            sys = Systems.HamiltonianSystem(h, backend)
            hvf = Systems.hamiltonian_vector_field(sys; inplace=false)
            
            x = [1.0, 2.0]
            p = [0.5, 1.5]
            v = [0.1, 0.2]
            result = hvf.f(x, p, v)
            Test.@test result isa Tuple
            Test.@test length(result) == 2
            Test.@test result[1] ≈ p
            Test.@test result[2] ≈ -x
        end

        Test.@testset "Real test: OOP Autonomous/NonFixed with variable_costate=true" begin
            h = Data.Hamiltonian((x, p, v) -> 0.5 * sum(x.^2) + 0.5 * sum(p.^2) + sum(v); is_autonomous=true, is_variable=true)
            backend = Differentiation.DifferentiationInterface(; ad_backend=ADTypes.AutoForwardDiff())
            sys = Systems.HamiltonianSystem(h, backend)
            hvf = Systems.hamiltonian_vector_field(sys; inplace=false)
            
            x = [1.0, 2.0]
            p = [0.5, 1.5]
            v = [0.1, 0.2]
            result = hvf.f(x, p, v; variable_costate=true)
            Test.@test result isa Tuple
            Test.@test length(result) == 3
            Test.@test result[1] ≈ p
            Test.@test result[2] ≈ -x
            Test.@test result[3] ≈ -ones(length(v))  # -∂H/∂v = -1
        end

        Test.@testset "Real test: OOP NonAutonomous/NonFixed without variable_costate" begin
            h = Data.Hamiltonian((t, x, p, v) -> 0.5 * sum(x.^2) + 0.5 * sum(p.^2) + sum(v); is_autonomous=false, is_variable=true)
            backend = Differentiation.DifferentiationInterface(; ad_backend=ADTypes.AutoForwardDiff())
            sys = Systems.HamiltonianSystem(h, backend)
            hvf = Systems.hamiltonian_vector_field(sys; inplace=false)
            
            t = 1.0
            x = [1.0, 2.0]
            p = [0.5, 1.5]
            v = [0.1, 0.2]
            result = hvf.f(t, x, p, v)
            Test.@test result isa Tuple
            Test.@test length(result) == 2
            Test.@test result[1] ≈ p
            Test.@test result[2] ≈ -x
        end

        Test.@testset "Real test: OOP NonAutonomous/NonFixed with variable_costate=true" begin
            h = Data.Hamiltonian((t, x, p, v) -> 0.5 * sum(x.^2) + 0.5 * sum(p.^2) + sum(v); is_autonomous=false, is_variable=true)
            backend = Differentiation.DifferentiationInterface(; ad_backend=ADTypes.AutoForwardDiff())
            sys = Systems.HamiltonianSystem(h, backend)
            hvf = Systems.hamiltonian_vector_field(sys; inplace=false)
            
            t = 1.0
            x = [1.0, 2.0]
            p = [0.5, 1.5]
            v = [0.1, 0.2]
            result = hvf.f(t, x, p, v; variable_costate=true)
            Test.@test result isa Tuple
            Test.@test length(result) == 3
            Test.@test result[1] ≈ p
            Test.@test result[2] ≈ -x
            Test.@test result[3] ≈ -ones(length(v))
        end

        # ====================================================================
        # IP REAL TESTS - In-place calls with DI
        # ====================================================================

        Test.@testset "Real test: IP Autonomous/Fixed" begin
            h = Data.Hamiltonian((x, p) -> 0.5 * sum(x.^2) + 0.5 * sum(p.^2); is_autonomous=true, is_variable=false)
            backend = Differentiation.DifferentiationInterface(; ad_backend=ADTypes.AutoForwardDiff())
            sys = Systems.HamiltonianSystem(h, backend)
            hvf = Systems.hamiltonian_vector_field(sys; inplace=true)
            
            x = [1.0, 2.0]
            p = [0.5, 1.5]
            dx = similar(x)
            dp = similar(p)
            result = hvf.f(dx, dp, x, p)
            Test.@test result === nothing
            Test.@test dx ≈ p
            Test.@test dp ≈ -x
        end

        Test.@testset "Real test: IP NonAutonomous/Fixed" begin
            h = Data.Hamiltonian((t, x, p) -> 0.5 * sum(x.^2) + 0.5 * sum(p.^2); is_autonomous=false, is_variable=false)
            backend = Differentiation.DifferentiationInterface(; ad_backend=ADTypes.AutoForwardDiff())
            sys = Systems.HamiltonianSystem(h, backend)
            hvf = Systems.hamiltonian_vector_field(sys; inplace=true)
            
            t = 1.0
            x = [1.0, 2.0]
            p = [0.5, 1.5]
            dx = similar(x)
            dp = similar(p)
            result = hvf.f(dx, dp, t, x, p)
            Test.@test result === nothing
            Test.@test dx ≈ p
            Test.@test dp ≈ -x
        end

        Test.@testset "Real test: IP Autonomous/NonFixed" begin
            h = Data.Hamiltonian((x, p, v) -> 0.5 * sum(x.^2) + 0.5 * sum(p.^2) + sum(v); is_autonomous=true, is_variable=true)
            backend = Differentiation.DifferentiationInterface(; ad_backend=ADTypes.AutoForwardDiff())
            sys = Systems.HamiltonianSystem(h, backend)
            hvf = Systems.hamiltonian_vector_field(sys; inplace=true)
            
            x = [1.0, 2.0]
            p = [0.5, 1.5]
            v = [0.1, 0.2]
            dx = similar(x)
            dp = similar(p)
            result = hvf.f(dx, dp, x, p, v)
            Test.@test result === nothing
            Test.@test dx ≈ p
            Test.@test dp ≈ -x
        end

        Test.@testset "Real test: IP NonAutonomous/NonFixed" begin
            h = Data.Hamiltonian((t, x, p, v) -> 0.5 * sum(x.^2) + 0.5 * sum(p.^2) + sum(v); is_autonomous=false, is_variable=true)
            backend = Differentiation.DifferentiationInterface(; ad_backend=ADTypes.AutoForwardDiff())
            sys = Systems.HamiltonianSystem(h, backend)
            hvf = Systems.hamiltonian_vector_field(sys; inplace=true)
            
            t = 1.0
            x = [1.0, 2.0]
            p = [0.5, 1.5]
            v = [0.1, 0.2]
            dx = similar(x)
            dp = similar(p)
            result = hvf.f(dx, dp, t, x, p, v)
            Test.@test result === nothing
            Test.@test dx ≈ p
            Test.@test dp ≈ -x
        end

        # ====================================================================
        # TRAITS TESTS - Verify correct traits on returned HVF
        # ====================================================================

        Test.@testset "Traits: OOP Autonomous/Fixed" begin
            h = Data.Hamiltonian((x, p) -> 0.5 * sum(x.^2) + 0.5 * sum(p.^2); is_autonomous=true, is_variable=false)
            backend = Differentiation.DifferentiationInterface(; ad_backend=ADTypes.AutoForwardDiff())
            hvf = Systems.hamiltonian_vector_field(h; ad_backend=backend, inplace=false)
            Test.@test Traits.time_dependence(hvf) == Traits.Autonomous
            Test.@test Traits.variable_dependence(hvf) == Traits.Fixed
            Test.@test Traits.mutability(hvf) == Traits.OutOfPlace
        end

        Test.@testset "Traits: OOP NonAutonomous/Fixed" begin
            h = Data.Hamiltonian((t, x, p) -> 0.5 * sum(x.^2) + 0.5 * sum(p.^2); is_autonomous=false, is_variable=false)
            backend = Differentiation.DifferentiationInterface(; ad_backend=ADTypes.AutoForwardDiff())
            hvf = Systems.hamiltonian_vector_field(h; ad_backend=backend, inplace=false)
            Test.@test Traits.time_dependence(hvf) == Traits.NonAutonomous
            Test.@test Traits.variable_dependence(hvf) == Traits.Fixed
            Test.@test Traits.mutability(hvf) == Traits.OutOfPlace
        end

        Test.@testset "Traits: OOP Autonomous/NonFixed" begin
            h = Data.Hamiltonian((x, p, v) -> 0.5 * sum(x.^2) + 0.5 * sum(p.^2) + sum(v); is_autonomous=true, is_variable=true)
            backend = Differentiation.DifferentiationInterface(; ad_backend=ADTypes.AutoForwardDiff())
            hvf = Systems.hamiltonian_vector_field(h; ad_backend=backend, inplace=false)
            Test.@test Traits.time_dependence(hvf) == Traits.Autonomous
            Test.@test Traits.variable_dependence(hvf) == Traits.NonFixed
            Test.@test Traits.mutability(hvf) == Traits.OutOfPlace
        end

        Test.@testset "Traits: OOP NonAutonomous/NonFixed" begin
            h = Data.Hamiltonian((t, x, p, v) -> 0.5 * sum(x.^2) + 0.5 * sum(p.^2) + sum(v); is_autonomous=false, is_variable=true)
            backend = Differentiation.DifferentiationInterface(; ad_backend=ADTypes.AutoForwardDiff())
            hvf = Systems.hamiltonian_vector_field(h; ad_backend=backend, inplace=false)
            Test.@test Traits.time_dependence(hvf) == Traits.NonAutonomous
            Test.@test Traits.variable_dependence(hvf) == Traits.NonFixed
            Test.@test Traits.mutability(hvf) == Traits.OutOfPlace
        end

        Test.@testset "Traits: IP Autonomous/Fixed" begin
            h = Data.Hamiltonian((x, p) -> 0.5 * sum(x.^2) + 0.5 * sum(p.^2); is_autonomous=true, is_variable=false)
            backend = Differentiation.DifferentiationInterface(; ad_backend=ADTypes.AutoForwardDiff())
            hvf = Systems.hamiltonian_vector_field(h; ad_backend=backend, inplace=true)
            Test.@test Traits.time_dependence(hvf) == Traits.Autonomous
            Test.@test Traits.variable_dependence(hvf) == Traits.Fixed
            Test.@test Traits.mutability(hvf) == Traits.InPlace
        end

        Test.@testset "Traits: IP NonAutonomous/Fixed" begin
            h = Data.Hamiltonian((t, x, p) -> 0.5 * sum(x.^2) + 0.5 * sum(p.^2); is_autonomous=false, is_variable=false)
            backend = Differentiation.DifferentiationInterface(; ad_backend=ADTypes.AutoForwardDiff())
            hvf = Systems.hamiltonian_vector_field(h; ad_backend=backend, inplace=true)
            Test.@test Traits.time_dependence(hvf) == Traits.NonAutonomous
            Test.@test Traits.variable_dependence(hvf) == Traits.Fixed
            Test.@test Traits.mutability(hvf) == Traits.InPlace
        end

        Test.@testset "Traits: IP Autonomous/NonFixed" begin
            h = Data.Hamiltonian((x, p, v) -> 0.5 * sum(x.^2) + 0.5 * sum(p.^2) + sum(v); is_autonomous=true, is_variable=true)
            backend = Differentiation.DifferentiationInterface(; ad_backend=ADTypes.AutoForwardDiff())
            hvf = Systems.hamiltonian_vector_field(h; ad_backend=backend, inplace=true)
            Test.@test Traits.time_dependence(hvf) == Traits.Autonomous
            Test.@test Traits.variable_dependence(hvf) == Traits.NonFixed
            Test.@test Traits.mutability(hvf) == Traits.InPlace
        end

        Test.@testset "Traits: IP NonAutonomous/NonFixed" begin
            h = Data.Hamiltonian((t, x, p, v) -> 0.5 * sum(x.^2) + 0.5 * sum(p.^2) + sum(v); is_autonomous=false, is_variable=true)
            backend = Differentiation.DifferentiationInterface(; ad_backend=ADTypes.AutoForwardDiff())
            hvf = Systems.hamiltonian_vector_field(h; ad_backend=backend, inplace=true)
            Test.@test Traits.time_dependence(hvf) == Traits.NonAutonomous
            Test.@test Traits.variable_dependence(hvf) == Traits.NonFixed
            Test.@test Traits.mutability(hvf) == Traits.InPlace
        end

        # ====================================================================
        # HAMILTONIAN SYSTEM - Missing structure tests
        # ====================================================================

        Test.@testset "HamiltonianSystem getter: NonAutonomous/Fixed" begin
            h = Data.Hamiltonian((t, x, p) -> 0.5 * sum(x.^2) + 0.5 * sum(p.^2); is_autonomous=false, is_variable=false)
            backend = Differentiation.DifferentiationInterface(; ad_backend=ADTypes.AutoForwardDiff())
            sys = Systems.HamiltonianSystem(h, backend)
            hvf = Systems.hamiltonian_vector_field(sys; inplace=false)
            Test.@test hvf isa Data.HamiltonianVectorField
            Test.@test hvf.f isa Function
        end

        Test.@testset "HamiltonianSystem getter: Autonomous/NonFixed" begin
            h = Data.Hamiltonian((x, p, v) -> 0.5 * sum(x.^2) + 0.5 * sum(p.^2) + sum(v); is_autonomous=true, is_variable=true)
            backend = Differentiation.DifferentiationInterface(; ad_backend=ADTypes.AutoForwardDiff())
            sys = Systems.HamiltonianSystem(h, backend)
            hvf = Systems.hamiltonian_vector_field(sys; inplace=false)
            Test.@test hvf isa Data.HamiltonianVectorField
            Test.@test hvf.f isa Function
        end

        Test.@testset "HamiltonianSystem getter: NonAutonomous/NonFixed" begin
            h = Data.Hamiltonian((t, x, p, v) -> 0.5 * sum(x.^2) + 0.5 * sum(p.^2) + sum(v); is_autonomous=false, is_variable=true)
            backend = Differentiation.DifferentiationInterface(; ad_backend=ADTypes.AutoForwardDiff())
            sys = Systems.HamiltonianSystem(h, backend)
            hvf = Systems.hamiltonian_vector_field(sys; inplace=false)
            Test.@test hvf isa Data.HamiltonianVectorField
            Test.@test hvf.f isa Function
        end

        Test.@testset "HamiltonianSystem getter: Autonomous/Fixed with inplace=true" begin
            h = Data.Hamiltonian((x, p) -> 0.5 * sum(x.^2) + 0.5 * sum(p.^2); is_autonomous=true, is_variable=false)
            backend = Differentiation.DifferentiationInterface(; ad_backend=ADTypes.AutoForwardDiff())
            sys = Systems.HamiltonianSystem(h, backend)
            hvf = Systems.hamiltonian_vector_field(sys; inplace=true)
            Test.@test hvf isa Data.HamiltonianVectorField
            Test.@test Traits.mutability(hvf) == Traits.InPlace
        end

        # ====================================================================
        # CONTRACT STUB - AbstractHamiltonianSystem
        # ====================================================================

        Test.@testset "Contract: AbstractHamiltonianSystem stub throws NotImplemented" begin
            sys = FakeHamiltonianSystem()
            Test.@test_throws Exception Systems.hamiltonian_vector_field(sys)
        end

        # ====================================================================
        # IP variable_costate tests
        # ====================================================================

        Test.@testset "Real test: IP Autonomous/NonFixed with variable_costate=true" begin
            h = Data.Hamiltonian((x, p, v) -> 0.5 * sum(x.^2) + 0.5 * sum(p.^2) + sum(v); is_autonomous=true, is_variable=true)
            backend = Differentiation.DifferentiationInterface(; ad_backend=ADTypes.AutoForwardDiff())
            hvf = Systems.hamiltonian_vector_field(h; ad_backend=backend, inplace=true)
            x = [1.0, 2.0]; p = [0.5, 1.5]; v = [0.1, 0.2]
            dx = similar(x); dp = similar(p); dpv = similar(v)
            hvf.f(dx, dp, x, p, v; dpv=dpv, variable_costate=true)
            Test.@test dx  ≈ p
            Test.@test dp  ≈ -x
            Test.@test dpv ≈ -ones(length(v))
        end

        Test.@testset "Real test: IP NonAutonomous/NonFixed with variable_costate=true" begin
            h = Data.Hamiltonian((t, x, p, v) -> 0.5 * sum(x.^2) + 0.5 * sum(p.^2) + sum(v); is_autonomous=false, is_variable=true)
            backend = Differentiation.DifferentiationInterface(; ad_backend=ADTypes.AutoForwardDiff())
            hvf = Systems.hamiltonian_vector_field(h; ad_backend=backend, inplace=true)
            t = 1.0; x = [1.0, 2.0]; p = [0.5, 1.5]; v = [0.1, 0.2]
            dx = similar(x); dp = similar(p); dpv = similar(v)
            hvf.f(dx, dp, t, x, p, v; dpv=dpv, variable_costate=true)
            Test.@test dx  ≈ p
            Test.@test dp  ≈ -x
            Test.@test dpv ≈ -ones(length(v))
        end

        Test.@testset "IP variable_costate=false (default) works without dpv" begin
            h = Data.Hamiltonian((x, p, v) -> 0.5 * sum(x.^2) + 0.5 * sum(p.^2) + sum(v); is_autonomous=true, is_variable=true)
            backend = Differentiation.DifferentiationInterface(; ad_backend=ADTypes.AutoForwardDiff())
            hvf = Systems.hamiltonian_vector_field(h; ad_backend=backend, inplace=true)
            x = [1.0, 2.0]; p = [0.5, 1.5]; v = [0.1, 0.2]
            dx = similar(x); dp = similar(p)
            result = hvf.f(dx, dp, x, p, v)
            Test.@test result === nothing
            Test.@test dx ≈ p
            Test.@test dp ≈ -x
        end

        Test.@testset "IP variable_costate=true without dpv throws PreconditionError" begin
            h = Data.Hamiltonian((x, p, v) -> 0.5 * sum(x.^2) + 0.5 * sum(p.^2) + sum(v); is_autonomous=true, is_variable=true)
            backend = Differentiation.DifferentiationInterface(; ad_backend=ADTypes.AutoForwardDiff())
            hvf = Systems.hamiltonian_vector_field(h; ad_backend=backend, inplace=true)
            x = [1.0, 2.0]; p = [0.5, 1.5]; v = [0.1, 0.2]
            dx = similar(x); dp = similar(p)
            Test.@test_throws Exception hvf.f(dx, dp, x, p, v; variable_costate=true)
        end

        # ====================================================================
        # hasmethod detection tests
        # ====================================================================

        Test.@testset "hasmethod: OOP NonFixed HVF accepts variable_costate kwarg" begin
            h = Data.Hamiltonian((x, p, v) -> 0.5 * sum(x.^2) + 0.5 * sum(p.^2) + sum(v); is_autonomous=true, is_variable=true)
            hvf = Systems.hamiltonian_vector_field(h)
            x = [1.0]; p = [0.5]; v = [0.1]
            Test.@test hasmethod(hvf.f, Tuple{typeof(x), typeof(p), typeof(v)}, (:variable_costate,))
        end

        Test.@testset "hasmethod: OOP Fixed HVF does NOT accept variable_costate kwarg" begin
            h = Data.Hamiltonian((x, p) -> 0.5 * sum(x.^2) + 0.5 * sum(p.^2); is_autonomous=true, is_variable=false)
            hvf = Systems.hamiltonian_vector_field(h)
            x = [1.0]; p = [0.5]
            Test.@test !hasmethod(hvf.f, Tuple{typeof(x), typeof(p)}, (:variable_costate,))
        end

        Test.@testset "hasmethod: IP NonFixed HVF accepts dpv and variable_costate kwargs" begin
            h = Data.Hamiltonian((x, p, v) -> 0.5 * sum(x.^2) + 0.5 * sum(p.^2) + sum(v); is_autonomous=true, is_variable=true)
            hvf = Systems.hamiltonian_vector_field(h; inplace=true)
            x = [1.0]; p = [0.5]; v = [0.1]
            dx = similar(x); dp = similar(p)
            Test.@test hasmethod(
                hvf.f,
                Tuple{typeof(dx), typeof(dp), typeof(x), typeof(p), typeof(v)},
                (:dpv, :variable_costate),
            )
        end

        # ====================================================================
        # OOP variable_costate=false is explicit default
        # ====================================================================

        Test.@testset "OOP variable_costate=false is default — returns 2-tuple" begin
            h = Data.Hamiltonian((x, p, v) -> 0.5 * sum(x.^2) + 0.5 * sum(p.^2) + sum(v); is_autonomous=true, is_variable=true)
            backend = Differentiation.DifferentiationInterface(; ad_backend=ADTypes.AutoForwardDiff())
            hvf = Systems.hamiltonian_vector_field(h; ad_backend=backend)
            x = [1.0, 2.0]; p = [0.5, 1.5]; v = [0.1, 0.2]
            result_default = hvf.f(x, p, v)
            result_false   = hvf.f(x, p, v; variable_costate=false)
            Test.@test length(result_default) == 2
            Test.@test length(result_false)   == 2
            Test.@test result_default[1] ≈ result_false[1]
            Test.@test result_default[2] ≈ result_false[2]
        end

        # ====================================================================
        # EXPORTS
        # ====================================================================

        Test.@testset "hamiltonian_vector_field is exported from Systems" begin
            Test.@test isdefined(Systems, :hamiltonian_vector_field)
        end

    end
end

end # module

test_hamiltonian_getter() = TestHamiltonianGetter.test_hamiltonian_getter()
