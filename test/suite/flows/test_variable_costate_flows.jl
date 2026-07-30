"""
Test suite for variable costate integration (augmented Hamiltonian systems).

Tests the `variable_costate=true` kwarg on Hamiltonian flows, which enables
integration of the augmented state `[x; p; pv]` where `pv` is the costate of the variable.
"""
module TestVariableCostateFlows

using Test: Test
using CTBase: CTBase
using CTBase: Core
using CTBase: Data
using CTBase: Exceptions
using CTBase: Traits
using CTFlows: CTFlows
using CTFlows: Configs
using CTFlows: Systems
using CTFlows: Flows
using CTFlows: Trajectories
using CTFlows: Integrators
using CTBase: Differentiation

using SciMLBase: SciMLBase
using OrdinaryDiffEqTsit5: OrdinaryDiffEqTsit5, Tsit5
using StaticArrays: SA, SVector, MVector
using ADTypes: ADTypes
using DifferentiationInterface: DifferentiationInterface as DI
using ForwardDiff: ForwardDiff

# Load extensions for testing
const CTFlowsSciMLIntegrator = Base.get_extension(CTFlows, :CTFlowsSciMLIntegrator)
const CTBaseDifferentiationInterface = Base.get_extension(
    CTBase, :CTBaseDifferentiationInterface
)

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true
const ATOL = 1e-3

# =============================================================================
# Fake types for testing
# =============================================================================

# Fake integration result
struct FakeIntegrationResult <: Integrators.AbstractIntegrationResult
    u_final::Vector{Float64}
end

Integrators.final_state(r::FakeIntegrationResult) = r.u_final

# Fake AD backend for linear Hamiltonian: H = sum(p^2) / (2 * sum(v))
struct FakeVariableHarmonicADBackend <: Differentiation.AbstractADBackend end

function Differentiation.hamiltonian_gradient(
    backend::FakeVariableHarmonicADBackend, h::Data.AbstractHamiltonian, t, x, p, v
)
    sv = sum(v)
    return (zero(x), p ./ sv)
end

function Differentiation.variable_gradient(
    backend::FakeVariableHarmonicADBackend, h::Data.AbstractHamiltonian, t, x, p, v
)
    sv = sum(v)
    sp2 = sum(abs2, p)
    return fill(-sp2 / (2 * sv^2), length(v))
end

# =============================================================================
# Reference systems for numerical testing
# =============================================================================

# Linear Hamiltonian: H = sum(p^2) / (2 * sum(v))
# Equations: dx = p / sum(v), dp = 0, dpv = -sum(p^2) / (2 * sum(v)^2)
# Analytical solution: x(t) = x0 + p0 * (t-t0) / sum(v), p(t) = p0, pv(t) = pv0 - sum(p0^2) * (t-t0) / (2 * sum(v)^2)
H_LINEAR(x, p, v) = sum(abs2, p) / (2 * sum(v))
function solve_linear(t, t0, x0, p0, v)
    # Align the reference costate shape with the "1-D = scalar" convention:
    # a length-1 variable yields a scalar variable costate (like the flow).
    pv0 = Systems._coerce_state(v)(zeros(length(v)))
    dt = t - t0
    sv = sum(v)
    x = x0 .+ p0 .* (dt / sv)
    p = p0
    pv = pv0 .+ sum(abs2, p0) / (2 * sv^2) .* dt
    return x, p, pv
end
const H_LINEAR_VAR = Data.Hamiltonian(H_LINEAR; is_autonomous=true, is_variable=true)
const BACKEND_FAKE = FakeVariableHarmonicADBackend()
const HSYS_FAKE = Systems.HamiltonianSystem(H_LINEAR_VAR, BACKEND_FAKE)

# DifferentiationInterface backend
const DI_BACKEND = Differentiation.DifferentiationInterface(;
    ad_backend=ADTypes.AutoForwardDiff()
)
const HSYS_DI = Systems.HamiltonianSystem(H_LINEAR_VAR, DI_BACKEND)

# Scalar-only Hamiltonian with variable: H = x³/3 - log(p) + v³/3
# This will fail if x, p, or v are treated as vectors
# Gradients: ∂H/∂x = x*x, ∂H/∂p = -1/p, ∂H/∂v = v*v
H_SCALAR_VAR(x, p, v) = x^3/3 - log(p) + v^3/3
const H_SCALAR_VAR_H = Data.Hamiltonian(H_SCALAR_VAR; is_autonomous=true, is_variable=true)
const HSYS_SCALAR_VAR = Systems.HamiltonianSystem(H_SCALAR_VAR_H, DI_BACKEND)

const INTEG = Integrators.SciML()

function test_variable_costate_flows()
    Test.@testset "Variable Costate Tests" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ====================================================================
        # UNIT TESTS
        # ====================================================================

        Test.@testset "Unit: _aug_split_solution" begin
            u = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0]
            x0 = [1.0, 2.0]  # n = 2
            pv0 = [5.0, 6.0, 7.0, 8.0]

            x, p, pv = Trajectories._aug_split_solution(u, x0, pv0)

            Test.@test x == [1.0, 2.0]
            Test.@test p == [3.0, 4.0]
            Test.@test pv == [5.0, 6.0, 7.0, 8.0]
        end

        Test.@testset "Unit: build_trajectory AugmentedHamiltonianDynamics" begin
            u_final = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0]
            x0 = [1.0, 2.0]  # n = 2
            p0 = [3.0, 4.0]
            pv0 = [5.0, 6.0, 7.0, 8.0]
            config = Configs.AugmentedHamiltonianEndPointConfig(0, x0, p0, pv0, 1)
            result = FakeIntegrationResult(u_final)

            xf, pf, pvf = Trajectories.build_trajectory(
                Configs.mode_trait(config), Traits.dynamics_trait(config), config, result
            )

            Test.@test xf == [1.0, 2.0]
            Test.@test pf == [3.0, 4.0]
            Test.@test pvf == [5.0, 6.0, 7.0, 8.0]
        end

        Test.@testset "Unit: trait type hierarchy" begin
            Test.@test Traits.SupportsVariableCostate <:
                Traits.AbstractVariableCostateCapability
            Test.@test Traits.NoVariableCostate <: Traits.AbstractVariableCostateCapability
            Test.@test Traits.AbstractVariableCostateCapability <: Traits.AbstractTrait
        end

        Test.@testset "Unit: variable_costate_trait default" begin
            Test.@test Traits.variable_costate_trait(42) === Traits.NoVariableCostate
            Test.@test Traits.variable_costate_trait("anything") ===
                Traits.NoVariableCostate
            Test.@test Traits.variable_costate_trait(nothing) === Traits.NoVariableCostate
        end

        Test.@testset "Unit: ad_trait on flows" begin
            # Default implementation on AbstractFlow returns WithoutAD
            Test.@test Traits.ad_trait("fake_flow") === Traits.WithoutAD
            Test.@test Traits.ad_trait(42) === Traits.WithoutAD
        end

        # ====================================================================
        # INTEGRATION TESTS
        # ====================================================================

        Test.@testset "Integration: variable_costate_trait on systems" begin
            # Fixed HamiltonianSystem -> NoVariableCostate
            h_fixed = Data.Hamiltonian(
                (x, p) -> 0.5*(sum(abs2, x) + sum(abs2, p));
                is_autonomous=true,
                is_variable=false,
            )
            sys_fixed = Systems.HamiltonianSystem(h_fixed, BACKEND_FAKE)
            Test.@test Traits.variable_costate_trait(sys_fixed) === Traits.NoVariableCostate

            # NonFixed HamiltonianSystem -> SupportsVariableCostate
            Test.@test Traits.variable_costate_trait(HSYS_FAKE) ===
                Traits.SupportsVariableCostate
            Test.@test Traits.variable_costate_trait(HSYS_FAKE) ===
                Traits.SupportsVariableCostate

            # DI backends also support variable costate
            Test.@test Traits.variable_costate_trait(HSYS_DI) ===
                Traits.SupportsVariableCostate
            Test.@test Traits.variable_costate_trait(HSYS_DI) ===
                Traits.SupportsVariableCostate
        end

        Test.@testset "Integration: ad_trait on systems" begin
            # HamiltonianSystem always has WithAD
            Test.@test Traits.ad_trait(HSYS_FAKE) === Traits.WithAD
            Test.@test Traits.ad_trait(HSYS_FAKE) === Traits.WithAD

            # DI backends also have WithAD
            Test.@test Traits.ad_trait(HSYS_DI) === Traits.WithAD
        end

        Test.@testset "Integration: FakeADBackend variable_costate flow" begin
            # Linear Hamiltonian: H = sum(p^2) / (2 * sum(v))
            # Equations: dx = p / sum(v), dp = 0, dpv = -sum(p^2) / (2 * sum(v)^2)
            # Analytical: x(t) = x0 + p0 * (t-t0) / sum(v), p(t) = p0, pv(t) = -sum(p0^2) * (t-t0) / (2 * sum(v)^2)

            Test.@testset "scalar with variable_costate=true" begin
                hflow = Flows.build_flow(HSYS_FAKE, INTEG)
                t0, tf = 0.0, 1.0
                x0, p0 = 1.0, 2.0
                v = 3.0
                xf, pf, pvf = hflow(t0, x0, p0, tf; variable=v, variable_costate=true)

                # Analytical solution
                xf_ref, pf_ref, pvf_ref = solve_linear(tf, t0, x0, p0, v)

                Test.@test xf isa Real
                Test.@test pf isa Real
                Test.@test pvf isa Real
                Test.@test xf ≈ xf_ref atol=ATOL
                Test.@test pf ≈ pf_ref atol=ATOL
                Test.@test pvf ≈ pvf_ref atol=ATOL
            end

            Test.@testset "scalar with variable_costate=false (default)" begin
                hflow = Flows.build_flow(HSYS_FAKE, INTEG)
                t0, tf = 0.0, 1.0
                x0, p0 = 1.0, 2.0
                v = 3.0
                xf, pf = hflow(t0, x0, p0, tf; variable=v, variable_costate=false)

                # Analytical solution (without pv)
                xf_ref, pf_ref, _ = solve_linear(tf, t0, x0, p0, v)

                Test.@test xf isa Real
                Test.@test pf isa Real
                Test.@test xf ≈ xf_ref atol=ATOL
                Test.@test pf ≈ pf_ref atol=ATOL
            end

            Test.@testset "vector with variable_costate=true" begin
                hflow = Flows.build_flow(HSYS_FAKE, INTEG)
                t0, tf = 0.0, 1.0
                x0 = [1.0, 2.0]
                p0 = [3.0, 4.0]
                v = [5.0, 6.0]
                xf, pf, pvf = hflow(t0, x0, p0, tf; variable=v, variable_costate=true)

                # Analytical solution
                xf_ref, pf_ref, pvf_ref = solve_linear(tf, t0, x0, p0, v)

                Test.@test xf isa AbstractVector && length(xf) == 2
                Test.@test pf isa AbstractVector && length(pf) == 2
                Test.@test pvf isa AbstractVector && length(pvf) == 2
                Test.@test xf ≈ xf_ref atol=ATOL
                Test.@test pf ≈ pf_ref atol=ATOL
                Test.@test pvf ≈ pvf_ref atol=ATOL
            end

            Test.@testset "SVector with variable_costate=true" begin
                hflow = Flows.build_flow(HSYS_FAKE, INTEG)
                t0, tf = 0.0, 1.0
                x0 = SA[1.0, 2.0]
                p0 = SA[3.0, 4.0]
                v = SA[5.0, 6.0]
                xf, pf, pvf = hflow(t0, x0, p0, tf; variable=v, variable_costate=true)

                # Analytical solution
                xf_ref, pf_ref, pvf_ref = solve_linear(tf, t0, x0, p0, v)

                Test.@test xf isa AbstractVector
                Test.@test pf isa AbstractVector
                Test.@test pvf isa AbstractVector
                Test.@test length(xf) == 2
                Test.@test length(pf) == 2
                Test.@test length(pvf) == 2
                Test.@test xf ≈ xf_ref atol=ATOL
                Test.@test pf ≈ pf_ref atol=ATOL
                Test.@test pvf ≈ pvf_ref atol=ATOL
            end
        end

        Test.@testset "Integration: DI variable_costate flow" begin
            Test.@testset "scalar with variable_costate=true" begin
                hflow = Flows.build_flow(HSYS_DI, INTEG)
                t0, tf = 0.0, 1.0
                x0, p0 = 1.0, 2.0
                v = 3.0
                xf, pf, pvf = hflow(t0, x0, p0, tf; variable=v, variable_costate=true)

                # Analytical solution
                xf_ref, pf_ref, pvf_ref = solve_linear(tf, t0, x0, p0, v)

                Test.@test xf isa Real
                Test.@test pf isa Real
                Test.@test pvf isa Real
                Test.@test xf ≈ xf_ref atol=ATOL
                Test.@test pf ≈ pf_ref atol=ATOL
                Test.@test pvf ≈ pvf_ref atol=ATOL
            end

            Test.@testset "scalar vector-v with variable_costate=true" begin
                hflow = Flows.build_flow(HSYS_DI, INTEG)
                t0, tf = 0.0, 1.0
                x0, p0 = 1.0, 2.0
                v = [3.0] # length-1 variable → scalar variable costate (1-D = scalar)
                xf, pf, pvf = hflow(t0, x0, p0, tf; variable=v, variable_costate=true)

                # Analytical solution
                xf_ref, pf_ref, pvf_ref = solve_linear(tf, t0, x0, p0, v)

                Test.@test xf isa Real
                Test.@test pf isa Real
                Test.@test pvf isa Real
                Test.@test xf ≈ xf_ref atol=ATOL
                Test.@test pf ≈ pf_ref atol=ATOL
                Test.@test pvf ≈ pvf_ref atol=ATOL
            end

            Test.@testset "vector with variable_costate=true" begin
                hflow = Flows.build_flow(HSYS_DI, INTEG)
                t0, tf = 0.0, 1.0
                x0 = [1.0, 2.0]
                p0 = [3.0, 4.0]
                v = [5.0, 6.0]
                xf, pf, pvf = hflow(t0, x0, p0, tf; variable=v, variable_costate=true)

                # Analytical solution
                xf_ref, pf_ref, pvf_ref = solve_linear(tf, t0, x0, p0, v)

                Test.@test xf isa AbstractVector && length(xf) == 2
                Test.@test pf isa AbstractVector && length(pf) == 2
                Test.@test pvf isa AbstractVector && length(pvf) == 2
                Test.@test xf ≈ xf_ref atol=ATOL
                Test.@test pf ≈ pf_ref atol=ATOL
                Test.@test pvf ≈ pvf_ref atol=ATOL
            end

            Test.@testset "comparison FakeADBackend vs DI" begin
                # Both should give the same numerical result
                hflow_fake = Flows.build_flow(HSYS_FAKE, INTEG)
                hflow_di = Flows.build_flow(HSYS_DI, INTEG)

                t0, tf = 0.0, 1.0
                x0, p0 = 1.0, 2.0
                v = 3.0

                xf_f, pf_f, pvf_f = hflow_fake(
                    t0, x0, p0, tf; variable=v, variable_costate=true
                )
                xf_d, pf_d, pvf_d = hflow_di(
                    t0, x0, p0, tf; variable=v, variable_costate=true
                )

                Test.@test xf_f ≈ xf_d atol=ATOL
                Test.@test pf_f ≈ pf_d atol=ATOL
                Test.@test pvf_f ≈ pvf_d atol=ATOL
            end
        end

        Test.@testset "Integration: regression tests" begin
            Test.@testset "variable_costate=false default unchanged" begin
                hflow = Flows.build_flow(HSYS_FAKE, INTEG)
                t0, tf = 0.0, 1.0
                x0, p0 = 1.0, 2.0
                v = 3.0
                xf, pf = hflow(t0, x0, p0, tf; variable=v)

                # Analytical solution (without pv)
                xf_ref, pf_ref, _ = solve_linear(tf, t0, x0, p0, v)

                Test.@test xf isa Real
                Test.@test pf isa Real
                Test.@test xf ≈ xf_ref atol=ATOL
                Test.@test pf ≈ pf_ref atol=ATOL
            end
        end

        # ====================================================================
        # SCALAR-ONLY TESTS - verify scalar dispatch (x*x + p*p + v*v)
        # ====================================================================

        Test.@testset "Scalar-only Hamiltonian with variable (x³/3 - log(p) + v³/3)" begin
            Test.@testset "scalar x0, p0, v with variable_costate=true" begin
                hflow = Flows.build_flow(HSYS_SCALAR_VAR, INTEG)
                # H = x³/3 - log(p) + v³/3 → ∂H/∂x = x², ∂H/∂p = -1/p, ∂H/∂v = v²
                # Equations: ẋ = 1/p, ṗ = -x², ṗv = -v²
                # This will fail if x, p, or v are treated as vectors (can't do x*x, 1/p, v*v on vectors)
                t0, tf = 0.0, 0.1
                x0, p0, v = 0.5, 1.0, 0.5
                xf, pf, pvf = hflow(t0, x0, p0, tf; variable=v, variable_costate=true)
                # Just verify it integrates without error and returns scalars
                Test.@test xf isa Real
                Test.@test pf isa Real
                Test.@test pvf isa Real
                Test.@test pf > 0  # p should stay positive
            end
        end

        # ====================================================================
        # ERROR TESTS
        # ====================================================================

        Test.@testset "Error: variable_costate=true on Fixed system" begin
            h_fixed = Data.Hamiltonian(
                (x, p) -> 0.5*(sum(abs2, x) + sum(abs2, p));
                is_autonomous=true,
                is_variable=false,
            )
            sys_fixed = Systems.HamiltonianSystem(h_fixed, BACKEND_FAKE)
            hflow = Flows.build_flow(sys_fixed, INTEG)
            Test.@test_throws Exceptions.PreconditionError hflow(
                0.0, 1.0, 0.0, 1.0; variable_costate=true
            )
        end

        Test.@testset "Error: variable_costate=true without variable on NonFixed" begin
            hflow = Flows.build_flow(HSYS_FAKE, INTEG)
            Test.@test_throws Exceptions.PreconditionError hflow(
                0.0, 1.0, 0.0, 1.0; variable_costate=true
            )
        end

        Test.@testset "Error: HamiltonianVectorFieldSystem with variable_costate" begin
            # HamiltonianVectorFieldSystem has NoVariableCostate (Fixed only)
            hvf = Data.HamiltonianVectorField(
                (x, p) -> (p, -x); is_autonomous=true, is_variable=false
            )
            sys_hvf = Systems.HamiltonianVectorFieldSystem(hvf)
            hflow = Flows.build_flow(sys_hvf, INTEG)
            Test.@test_throws Exceptions.PreconditionError hflow(
                0.0, 1.0, 0.0, 1.0; variable_costate=true
            )
        end

        Test.@testset "Error: variable_costate=true with trajectory config" begin
            hflow = Flows.build_flow(HSYS_FAKE, INTEG)
            t0, tf = 0.0, 1.0
            x0, p0 = 1.0, 2.0
            v = 3.0
            Test.@test_throws Exceptions.PreconditionError hflow(
                (t0, tf), x0, p0; variable=v, variable_costate=true
            )
        end
    end
end

end # module

# CRITICAL: Redefine in outer scope for TestRunner
test_variable_costate_flows() = TestVariableCostateFlows.test_variable_costate_flows()
