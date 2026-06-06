"""
Unit and integration tests for the CTFlowsDifferentiationInterface extension.
"""

module TestDifferentiationInterfaceExtension

import Test
import CTFlows: CTFlows
import CTFlows.Data: Data
import CTFlows.Common: Common
import CTFlows.Differentiation: Differentiation
import ADTypes
import DifferentiationInterface

const CTFlowsDifferentiationInterface = Base.get_extension(CTFlows, :CTFlowsDifferentiationInterface)

const VERBOSE = isdefined(Main, :TestOptions) ? Main.TestOptions.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestOptions) ? Main.TestOptions.SHOWTIMING : true

# ==============================================================================
# Fake Hamiltonian for testing (module top-level, not inside test functions)
# ==============================================================================

# Simple quadratic Hamiltonian: H(t, x, p, v) = 0.5*(sum(x.^2) + sum(p.^2))
# Gradient: ∂H/∂x = x, ∂H/∂p = p
const FAKE_HAMILTONIAN_FIXED = Data.Hamiltonian(
    (x, p) -> 0.5 * (sum(abs2, x) + sum(abs2, p));
    is_autonomous=true, is_variable=false)

# Gradient: ∂H/∂x = x, ∂H/∂p = p, ∂H/∂v = v
const FAKE_HAMILTONIAN_NONFIXED = Data.Hamiltonian(
    (x, p, v) -> 0.5 * (sum(abs2, x) + sum(abs2, p) + sum(abs2, v));
    is_autonomous=true, is_variable=true)

# ==============================================================================
# Test function
# ==============================================================================

function test_differentiation_interface_extension()
    Test.@testset "DifferentiationInterface Extension Tests" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ====================================================================
        # Unit Tests
        # ====================================================================

        Test.@testset "Unit: _DifferentiationInterfaceCache construction" begin
            # Create a cache with dummy preps (nothing for now since we can't create real DI plans without the extension loaded)
            cache = CTFlowsDifferentiationInterface._DifferentiationInterfaceCache(nothing, nothing, nothing, nothing, nothing, nothing)
            Test.@test cache isa Common.AbstractCache
        end

        # ====================================================================
        # Integration Tests - require DifferentiationInterface loaded
        # ====================================================================
        Test.@testset "Integration: prepare_cache with prepare_cache=true" begin
            backend = Differentiation.DifferentiationInterface(; ad_backend=ADTypes.AutoForwardDiff(), prepare_cache=true)
            typical_t = 0.0
            typical_x = [1.0, 2.0]
            typical_p = [3.0, 4.0]
            typical_v = nothing  # Fixed

            cache = Differentiation.prepare_cache(backend, FAKE_HAMILTONIAN_FIXED, typical_t, typical_x, typical_p, typical_v)
            Test.@test cache !== nothing
            Test.@test cache isa CTFlowsDifferentiationInterface._DifferentiationInterfaceCache
            # p_v should be nothing for Fixed problems
            Test.@test cache.p_v === nothing
        end

        Test.@testset "Integration: prepare_cache with prepare_cache=false" begin
            backend = Differentiation.DifferentiationInterface(; ad_backend=ADTypes.AutoForwardDiff(), prepare_cache=false)
            typical_t = 0.0
            typical_x = [1.0, 2.0]
            typical_p = [3.0, 4.0]
            typical_v = nothing

            cache = Differentiation.prepare_cache(backend, FAKE_HAMILTONIAN_FIXED, typical_t, typical_x, typical_p, typical_v)
            Test.@test cache === nothing
        end

        Test.@testset "Integration: hamiltonian_gradient (no cache)" begin
            # For unit testing, we verify the gradient methods are callable
            # Actual gradient computation is tested in integration tests with real ODEs
            backend = Differentiation.DifferentiationInterface(; ad_backend=ADTypes.AutoForwardDiff(), prepare_cache=false)
            t = 0.0
            x = [1.0, 2.0]
            p = [3.0, 4.0]
            v = nothing

            # Call the method - it should not error
            grad_x, grad_p = Differentiation.hamiltonian_gradient(backend, FAKE_HAMILTONIAN_FIXED, t, x, p, v, nothing)
            # Verify the method returns a tuple of gradients
            Test.@test grad_x isa AbstractVector
            Test.@test length(grad_x) == length(x)
            Test.@test grad_x ≈ x atol=1e-8
            Test.@test grad_p isa AbstractVector
            Test.@test length(grad_p) == length(p)
            Test.@test grad_p ≈ p atol=1e-8
        end

        Test.@testset "Integration: hamiltonian_gradient (with cache)" begin
            # For unit testing, we verify the gradient methods are callable with cache
            backend = Differentiation.DifferentiationInterface(; ad_backend=ADTypes.AutoForwardDiff(), prepare_cache=true)
            typical_t = 0.0
            typical_x = [1.0, 2.0]
            typical_p = [3.0, 4.0]
            typical_v = nothing

            cache = Differentiation.prepare_cache(backend, FAKE_HAMILTONIAN_FIXED, typical_t, typical_x, typical_p, typical_v)
            Test.@test cache !== nothing

            t = 0.0
            x = [1.0, 2.0]
            p = [3.0, 4.0]
            v = nothing

            # Call the method with cache - it should not error
            grad_x, grad_p = Differentiation.hamiltonian_gradient(backend, FAKE_HAMILTONIAN_FIXED, t, x, p, v, cache)
            # Verify the method returns a tuple of gradients
            Test.@test grad_x isa AbstractVector
            Test.@test length(grad_x) == length(x)
            Test.@test grad_x ≈ x atol=1e-8
            Test.@test grad_p isa AbstractVector
            Test.@test length(grad_p) == length(p)
            Test.@test grad_p ≈ p atol=1e-8
        end

        Test.@testset "Integration: variable_gradient (no cache)" begin
            # For Fixed problems (v === nothing), variable_gradient cannot be called
            backend = Differentiation.DifferentiationInterface(; ad_backend=ADTypes.AutoForwardDiff(), prepare_cache=false)
            t = 0.0
            x = [1.0, 2.0]
            p = [3.0, 4.0]
            v = [5.0, 6.0]

            grad_v = Differentiation.variable_gradient(backend, FAKE_HAMILTONIAN_NONFIXED, t, x, p, v, nothing)
            Test.@test grad_v isa AbstractVector
            Test.@test length(grad_v) == length(v)
            Test.@test grad_v ≈ v atol=1e-8
        end

        Test.@testset "Integration: variable_gradient (with cache)" begin
            # For Fixed problems (v === nothing), variable_gradient returns nothing
            backend = Differentiation.DifferentiationInterface(; ad_backend=ADTypes.AutoForwardDiff(), prepare_cache=true)
            typical_t = 0.0
            typical_x = [1.0, 2.0]
            typical_p = [3.0, 4.0]
            typical_v = [5.0, 6.0]

            cache = Differentiation.prepare_cache(backend, FAKE_HAMILTONIAN_NONFIXED, typical_t, typical_x, typical_p, typical_v)
            Test.@test cache !== nothing

            t = 0.0
            x = [1.0, 2.0]
            p = [3.0, 4.0]
            v = [5.0, 6.0]

            grad_v = Differentiation.variable_gradient(backend, FAKE_HAMILTONIAN_NONFIXED, t, x, p, v, cache)
            Test.@test grad_v isa AbstractVector
            Test.@test length(grad_v) == length(v)
            Test.@test grad_v ≈ v atol=1e-8
        end

        # ====================================================================
        # Integration Tests - on_update callback
        # ====================================================================

        Test.@testset "Integration: on_update callback with type mismatch" begin
            # Test that on_update is called when cache type mismatches input type
            count = Ref(0)
            backend = Differentiation.DifferentiationInterface(
                ad_backend=ADTypes.AutoForwardDiff(),
                prepare_cache=true,
                on_update=(c, t, x, p, v) -> (count[] += 1)
            )

            # Prepare cache with Int types
            cache = Differentiation.prepare_cache(backend, FAKE_HAMILTONIAN_NONFIXED, Int(0), Int(1), Int(1), Int(1))
            Test.@test cache !== nothing

            # Call with Float types (should trigger update!)
            grad_x, grad_p = Differentiation.hamiltonian_gradient(backend, FAKE_HAMILTONIAN_NONFIXED, 0.0, 1.0, 1.0, 1.0, cache)
            Test.@test grad_x ≈ 1.0 atol=1e-8
            Test.@test grad_p ≈ 1.0 atol=1e-8
            Test.@test count[] == 1  # on_update should be called once
        end

        Test.@testset "Integration: on_update callback with matching types" begin
            # Test that on_update is NOT called when types match
            count = Ref(0)
            backend = Differentiation.DifferentiationInterface(
                ad_backend=ADTypes.AutoForwardDiff(),
                prepare_cache=true,
                on_update=(c, t, x, p, v) -> (count[] += 1)
            )

            # Prepare cache with Float types
            cache = Differentiation.prepare_cache(backend, FAKE_HAMILTONIAN_NONFIXED, 0.0, 1.0, 1.0, 1.0)
            Test.@test cache !== nothing

            # Call with same Float types (should NOT trigger update!)
            grad_x, grad_p = Differentiation.hamiltonian_gradient(backend, FAKE_HAMILTONIAN_NONFIXED, 0.0, 1.0, 1.0, 1.0, cache)
            Test.@test grad_x ≈ 1.0 atol=1e-8
            Test.@test grad_p ≈ 1.0 atol=1e-8
            Test.@test count[] == 0  # on_update should NOT be called
        end

        # ====================================================================
        # Phase 3: Cache functor types
        # ====================================================================

        Test.@testset "Cache functor types (Fixed)" begin
            backend = Differentiation.DifferentiationInterface(; ad_backend=ADTypes.AutoForwardDiff(), prepare_cache=true)
            cache = Differentiation.prepare_cache(backend, FAKE_HAMILTONIAN_FIXED, 0.0, [1.0, 2.0], [3.0, 4.0], nothing)
            Test.@test cache.h_x isa Differentiation.WithActiveArg
            Test.@test cache.h_p isa Differentiation.WithActiveArg
            Test.@test cache.p_v === nothing  # Fixed → no DI plan v
        end

        Test.@testset "Cache functor types (NonFixed)" begin
            backend = Differentiation.DifferentiationInterface(; ad_backend=ADTypes.AutoForwardDiff(), prepare_cache=true)
            cache = Differentiation.prepare_cache(backend, FAKE_HAMILTONIAN_NONFIXED, 0.0, [1.0, 2.0], [3.0, 4.0], [5.0])
            Test.@test cache.h_x isa Differentiation.WithActiveArg
            Test.@test cache.h_p isa Differentiation.WithActiveArg
            Test.@test cache.h_v isa Differentiation.WithActiveArg
        end

        Test.@testset "Cache: slots correct" begin
            backend = Differentiation.DifferentiationInterface(; ad_backend=ADTypes.AutoForwardDiff(), prepare_cache=true)
            cache = Differentiation.prepare_cache(backend, FAKE_HAMILTONIAN_FIXED, 0.0, [1.0, 2.0], [3.0, 4.0], nothing)
            # With typical_t passed, signature is h(t,x,p) → slot 2 for x, slot 3 for p
            Test.@test cache.h_x isa Differentiation.WithActiveArg{<:Any, 2}
            Test.@test cache.h_p isa Differentiation.WithActiveArg{<:Any, 3}
        end
    end
end

end # module

# CRITICAL: Redefine in outer scope for TestRunner
test_differentiation_interface_extension() = TestDifferentiationInterfaceExtension.test_differentiation_interface_extension()
