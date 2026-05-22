"""
Test suite for variable costate integration (augmented Hamiltonian systems).

Tests the `variable_costate=true` kwarg on Hamiltonian flows, which enables
integration of the augmented state `[x; p; pv]` where `pv` is the costate of the variable.
"""
module TestVariableCostate

import Test
import CTBase.Exceptions
import CTFlows.Common
import CTFlows.Systems
import CTFlows.Flows
import CTFlows.Solutions
import CTFlows.Integrators
import CTFlows.Differentiation
import CTFlows.Data

using SciMLBase: SciMLBase
using OrdinaryDiffEqTsit5: OrdinaryDiffEqTsit5, Tsit5
using StaticArrays: SA, SVector, MVector
using ForwardDiff: ForwardDiff
using ADTypes: ADTypes
using DifferentiationInterface: DifferentiationInterface as DI

const VERBOSE = isdefined(Main, :TestOptions) ? Main.TestOptions.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestOptions) ? Main.TestOptions.SHOWTIMING : true
const ATOL = 1e-3

# =============================================================================
# Fake types for testing
# =============================================================================

# Fake integration result
struct FakeIntegrationResult <: Integrators.AbstractIntegrationResult
    u_final::Vector{Float64}
end

Integrators.final_state(r::FakeIntegrationResult) = r.u_final

# Fake AD backend for variable harmonic oscillator: H = 0.5*(v^2*x^2 + p^2)
struct FakeVariableHarmonicADBackend <: Differentiation.AbstractADBackend end

function Differentiation.hamiltonian_gradient(backend::FakeVariableHarmonicADBackend, h, t, x, p, v, cache)
    return (v.^2 .* x, p)  # ∂H/∂x = v^2*x, ∂H/∂p = p
end

function Differentiation.variable_gradient(backend::FakeVariableHarmonicADBackend, h, t, x, p, v, cache)
    return v .* sum(abs2, x)  # ∂H/∂v = v*x^2 (for scalar v)
end

function Differentiation.prepare_cache(backend::FakeVariableHarmonicADBackend, h, typical_t, typical_x, typical_p, typical_v)
    return nothing
end

# =============================================================================
# Reference systems for numerical testing
# =============================================================================

# Variable harmonic oscillator: H = 0.5*(v^2*sum(x^2) + sum(p^2)) -> dx = p, dp = -v^2*x, dpv = -v*sum(x^2)
const H_VAR_HARMONIC = Data.Hamiltonian((x, p, v) -> 0.5*(v^2*sum(abs2, x) + sum(abs2, p));
                                         is_autonomous=true, is_variable=true)
const BACKEND_FAKE = FakeVariableHarmonicADBackend()
const HSYS_FAKE_N1 = Systems.HamiltonianSystem(H_VAR_HARMONIC, BACKEND_FAKE; state_dimension=1)
const HSYS_FAKE_N2 = Systems.HamiltonianSystem(H_VAR_HARMONIC, BACKEND_FAKE; state_dimension=2)

# DifferentiationInterface backends
const DI_BACKEND_CACHED    = Differentiation.DifferentiationInterface(; ad_backend=ADTypes.AutoForwardDiff(), prepare_cache=true)
const DI_BACKEND_UNCACHED  = Differentiation.DifferentiationInterface(; ad_backend=ADTypes.AutoForwardDiff(), prepare_cache=false)
const HSYS_DI_N1_CACHED    = Systems.HamiltonianSystem(H_VAR_HARMONIC, DI_BACKEND_CACHED; state_dimension=1)
const HSYS_DI_N1_UNCACHED  = Systems.HamiltonianSystem(H_VAR_HARMONIC, DI_BACKEND_UNCACHED; state_dimension=1)
const HSYS_DI_N2_CACHED    = Systems.HamiltonianSystem(H_VAR_HARMONIC, DI_BACKEND_CACHED; state_dimension=2)
const HSYS_DI_N2_UNCACHED  = Systems.HamiltonianSystem(H_VAR_HARMONIC, DI_BACKEND_UNCACHED; state_dimension=2)

const INTEG = Integrators.SciML()

# =============================================================================
# Unit tests for _aug_split_solution
# =============================================================================

Test.@testset "Unit: _aug_split_solution" begin
    u = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0]
    n = 2  # state dimension

    x, p, pv = Solutions._aug_split_solution(u, n)

    Test.@test x == [1.0, 2.0]
    Test.@test p == [3.0, 4.0]
    Test.@test pv == [5.0, 6.0, 7.0, 8.0]
end

# =============================================================================
# Unit tests for build_solution with AugmentedHamiltonianTrait
# =============================================================================

Test.@testset "Unit: build_solution AugmentedHamiltonianTrait" begin
    u_final = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0]
    initial_state = [1.0, 2.0]  # n = 2
    result = FakeIntegrationResult(u_final)

    xf, pf, pvf = Solutions.build_solution(
        Common.PointTrait,
        Common.AugmentedHamiltonianTrait,
        initial_state,
        result,
    )

    Test.@test xf == [1.0, 2.0]
    Test.@test pf == [3.0, 4.0]
    Test.@test pvf == [5.0, 6.0, 7.0, 8.0]
end

# =============================================================================
# Unit tests for trait type hierarchy
# =============================================================================

Test.@testset "Unit: trait type hierarchy" begin
    Test.@test Common.SupportsVariableCostate <: Common.AbstractVariableCostateCapability
    Test.@test Common.NoVariableCostate <: Common.AbstractVariableCostateCapability
    Test.@test Common.AbstractVariableCostateCapability <: Common.AbstractTrait
end

# =============================================================================
# Unit tests for default variable_costate_trait
# =============================================================================

Test.@testset "Unit: variable_costate_trait default" begin
    Test.@test Common.variable_costate_trait(42) === Common.NoVariableCostate
    Test.@test Common.variable_costate_trait("anything") === Common.NoVariableCostate
    Test.@test Common.variable_costate_trait(nothing) === Common.NoVariableCostate
end

# =============================================================================
# Unit tests for ad_trait on flows
# =============================================================================

Test.@testset "Unit: ad_trait on flows" begin
    # Default implementation on AbstractFlow returns WithoutAD
    Test.@test Common.ad_trait("fake_flow") === Common.WithoutAD
    Test.@test Common.ad_trait(42) === Common.WithoutAD
end

# =============================================================================
# Integration tests: variable_costate_trait on real systems
# =============================================================================

Test.@testset "Integration: variable_costate_trait on systems" begin
    # Fixed HamiltonianSystem -> NoVariableCostate
    h_fixed = Data.Hamiltonian((x, p) -> 0.5*(sum(abs2, x) + sum(abs2, p)); is_autonomous=true, is_variable=false)
    sys_fixed = Systems.HamiltonianSystem(h_fixed, BACKEND_FAKE)
    Test.@test Common.variable_costate_trait(sys_fixed) === Common.NoVariableCostate

    # NonFixed HamiltonianSystem -> SupportsVariableCostate
    Test.@test Common.variable_costate_trait(HSYS_FAKE_N1) === Common.SupportsVariableCostate
    Test.@test Common.variable_costate_trait(HSYS_FAKE_N2) === Common.SupportsVariableCostate

    # DI backends also support variable costate
    Test.@test Common.variable_costate_trait(HSYS_DI_N1_CACHED) === Common.SupportsVariableCostate
    Test.@test Common.variable_costate_trait(HSYS_DI_N1_UNCACHED) === Common.SupportsVariableCostate
end

# =============================================================================
# Integration tests: ad_trait on real systems
# =============================================================================

Test.@testset "Integration: ad_trait on systems" begin
    # HamiltonianSystem always has WithAD
    Test.@test Common.ad_trait(HSYS_FAKE_N1) === Common.WithAD
    Test.@test Common.ad_trait(HSYS_FAKE_N2) === Common.WithAD

    # DI backends also have WithAD
    Test.@test Common.ad_trait(HSYS_DI_N1_CACHED) === Common.WithAD
end

# =============================================================================
# Integration tests: FakeADBackend numerical flow calculations
# =============================================================================

Test.@testset "Integration: FakeADBackend variable_costate flow" begin
    # Scalar x0, p0 with variable frequency v=2
    # H = 0.5*(v^2*x^2 + p^2) -> dx = p, dp = -v^2*x
    # With x0=1, p0=0, v=2: x(t) = cos(2t), p(t) = -2*sin(2t)
    # At t=pi/4: x(pi/4) = cos(pi/2) = 0, p(pi/4) = -2*sin(pi/2) = -2

    Test.@testset "scalar with variable_costate=true" begin
        hflow = Flows.build_flow(HSYS_FAKE_N1, INTEG)
        xf, pf, pvf = hflow(0.0, 1.0, 0.0, π/4; variable=2.0, variable_costate=true)

        Test.@test xf isa Real
        Test.@test pf isa Real
        Test.@test pvf isa Real
        Test.@test xf ≈ 0.0  atol=ATOL
        Test.@test pf ≈ -2.0  atol=ATOL
        # pv is the costate of the variable, its value depends on the integral of -v*x^2
        Test.@test isfinite(pvf)
    end

    Test.@testset "scalar with variable_costate=false (default)" begin
        hflow = Flows.build_flow(HSYS_FAKE_N1, INTEG)
        xf, pf = hflow(0.0, 1.0, 0.0, π/4; variable=2.0, variable_costate=false)

        Test.@test xf isa Real
        Test.@test pf isa Real
        Test.@test xf ≈ 0.0  atol=ATOL
        Test.@test pf ≈ -2.0  atol=ATOL
    end

    Test.@testset "vector with variable_costate=true" begin
        hflow = Flows.build_flow(HSYS_FAKE_N2, INTEG)
        x0 = [1.0, 0.0]
        p0 = [0.0, 1.0]
        xf, pf, pvf = hflow(0.0, x0, p0, π/4; variable=[2.0, 2.0], variable_costate=true)

        Test.@test xf isa AbstractVector && length(xf) == 2
        Test.@test pf isa AbstractVector && length(pf) == 2
        Test.@test pvf isa AbstractVector && length(pvf) == 2
        # With v=[2,2]: x1(t)=cos(2t), x2(t)=sin(2t)
        # At t=pi/4: x1=0, x2=1, p1=-2, p2=0
        Test.@test xf[1] ≈ 0.0  atol=ATOL
        Test.@test xf[2] ≈ 1.0  atol=ATOL
        Test.@test pf[1] ≈ -2.0  atol=ATOL
        Test.@test pf[2] ≈ 0.0  atol=ATOL
        Test.@test isfinite(pvf[1])
        Test.@test isfinite(pvf[2])
    end

    Test.@testset "SVector with variable_costate=true" begin
        hflow = Flows.build_flow(HSYS_FAKE_N2, INTEG)
        xf, pf, pvf = hflow(0.0, SA[1.0, 0.0], SA[0.0, 1.0], π/4; variable=SA[2.0, 2.0], variable_costate=true)

        Test.@test xf isa AbstractVector
        Test.@test pf isa AbstractVector
        Test.@test pvf isa AbstractVector
        Test.@test length(xf) == 2
        Test.@test length(pf) == 2
        Test.@test length(pvf) == 2
    end
end

# =============================================================================
# Integration tests: DifferentiationInterface numerical flow calculations
# =============================================================================

Test.@testset "Integration: DI variable_costate flow" begin
    Test.@testset "scalar cached with variable_costate=true" begin
        hflow = Flows.build_flow(HSYS_DI_N1_CACHED, INTEG)
        xf, pf, pvf = hflow(0.0, 1.0, 0.0, π/4; variable=2.0, variable_costate=true)

        Test.@test xf isa Real
        Test.@test pf isa Real
        Test.@test pvf isa Real
        Test.@test xf ≈ 0.0  atol=ATOL
        Test.@test pf ≈ -2.0  atol=ATOL
    end

    Test.@testset "scalar uncached with variable_costate=true" begin
        hflow = Flows.build_flow(HSYS_DI_N1_UNCACHED, INTEG)
        xf, pf, pvf = hflow(0.0, 1.0, 0.0, π/4; variable=2.0, variable_costate=true)

        Test.@test xf isa Real
        Test.@test pf isa Real
        Test.@test pvf isa Real
        Test.@test xf ≈ 0.0  atol=ATOL
        Test.@test pf ≈ -2.0  atol=ATOL
    end

    Test.@testset "vector cached with variable_costate=true" begin
        hflow = Flows.build_flow(HSYS_DI_N2_CACHED, INTEG)
        x0 = [1.0, 0.0]
        p0 = [0.0, 1.0]
        xf, pf, pvf = hflow(0.0, x0, p0, π/4; variable=[2.0, 2.0], variable_costate=true)

        Test.@test xf isa AbstractVector && length(xf) == 2
        Test.@test pf isa AbstractVector && length(pf) == 2
        Test.@test pvf isa AbstractVector && length(pvf) == 2
        Test.@test xf[1] ≈ 0.0  atol=ATOL
        Test.@test xf[2] ≈ 1.0  atol=ATOL
    end

    Test.@testset "comparison FakeADBackend vs DI" begin
        # Both should give the same numerical result
        hflow_fake = Flows.build_flow(HSYS_FAKE_N1, INTEG)
        hflow_di   = Flows.build_flow(HSYS_DI_N1_CACHED, INTEG)

        xf_f, pf_f, pvf_f = hflow_fake(0.0, 1.0, 0.0, π/4; variable=2.0, variable_costate=true)
        xf_d, pf_d, pvf_d = hflow_di(0.0, 1.0, 0.0, π/4; variable=2.0, variable_costate=true)

        Test.@test xf_f ≈ xf_d  atol=ATOL
        Test.@test pf_f ≈ pf_d  atol=ATOL
    end
end

# =============================================================================
# Integration tests: error cases and regression
# =============================================================================

Test.@testset "Integration: error cases" begin
    Test.@testset "variable_costate=true on Fixed system" begin
        h_fixed = Data.Hamiltonian((x, p) -> 0.5*(sum(abs2, x) + sum(abs2, p)); is_autonomous=true, is_variable=false)
        sys_fixed = Systems.HamiltonianSystem(h_fixed, BACKEND_FAKE)
        hflow = Flows.build_flow(sys_fixed, INTEG)
        Test.@test_throws Exceptions.IncorrectArgument hflow(0.0, 1.0, 0.0, π/4; variable_costate=true)
    end

    Test.@testset "variable_costate=true without variable on NonFixed" begin
        hflow = Flows.build_flow(HSYS_FAKE_N1, INTEG)
        Test.@test_throws Exceptions.IncorrectArgument hflow(0.0, 1.0, 0.0, π/4; variable_costate=true)
    end
end

Test.@testset "Integration: regression tests" begin
    Test.@testset "variable_costate=false default unchanged" begin
        hflow = Flows.build_flow(HSYS_FAKE_N1, INTEG)
        xf, pf = hflow(0.0, 1.0, 0.0, π/4; variable=2.0)

        Test.@test xf isa Real
        Test.@test pf isa Real
        Test.@test xf ≈ 0.0  atol=ATOL
        Test.@test pf ≈ -2.0  atol=ATOL
    end

    Test.@testset "trajectory config with variable_costate=true" begin
        hflow = Flows.build_flow(HSYS_FAKE_N1, INTEG)
        sol = hflow((0.0, π/4), 1.0, 0.0; variable=2.0, variable_costate=true)
        Test.@test sol isa Solutions.HamiltonianVectorFieldSolution
    end
end

# =============================================================================
# Integration tests: HamiltonianVectorFieldSystem (no AD)
# =============================================================================

Test.@testset "Integration: HamiltonianVectorFieldSystem error" begin
    # HamiltonianVectorFieldSystem has NoVariableCostate (Fixed only)
    hvf = Data.HamiltonianVectorField((x, p) -> (p, -x); is_autonomous=true, is_variable=false)
    sys_hvf = Systems.HamiltonianVectorFieldSystem(hvf; state_dimension=1)
    hflow = Flows.build_flow(sys_hvf, INTEG)
    Test.@test_throws Exceptions.IncorrectArgument hflow(0.0, 1.0, 0.0, π/4; variable_costate=true)
end

function test_variable_costate()
    Test.@testset "Variable Costate Tests" verbose=VERBOSE showtiming=SHOWTIMING begin
        # All tests are defined at module level above
    end
end

end # module

# CRITICAL: Redefine in outer scope for TestRunner
test_variable_costate() = TestVariableCostate.test_variable_costate()
