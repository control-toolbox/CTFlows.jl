module TestPseudoHamiltonianSystem

using Test: Test
using CTBase: Data
using CTBase: Traits
using CTBase: Differentiation
using CTFlows: Systems
using ADTypes: ADTypes
using DifferentiationInterface: DifferentiationInterface
using ForwardDiff: ForwardDiff

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

function _backend()
    return Differentiation.DifferentiationInterface(; ad_backend=ADTypes.AutoForwardDiff())
end

function test_pseudo_hamiltonian_system()
    Test.@testset "PseudoHamiltonianSystem Tests" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ====================================================================
        # UNIT — construction, getters, hamiltonian() returns ComposedHamiltonian
        # ====================================================================

        Test.@testset "Unit: build_system, getters, hamiltonian()" begin
            # H̃(x,p,u) = p*(-x+u) + 0.5u² ; law u(x,p) = -p
            h̃ = Data.PseudoHamiltonian((x, p, u) -> p * (-x + u) + 0.5 * u^2)
            law = Data.DynClosedLoop((x, p) -> -p)
            be = _backend()
            sys = Systems.build_system(h̃, law, be)

            Test.@test sys isa Systems.PseudoHamiltonianSystem
            Test.@test sys isa Systems.AbstractHamiltonianSystem
            Test.@test Systems.pseudo_hamiltonian(sys) === h̃
            Test.@test Systems.control_law(sys) === law
            Test.@test Systems.backend(sys) === be

            H = Systems.hamiltonian(sys)
            Test.@test H isa Data.ComposedHamiltonian
            # H(x,p) = H̃(x,p,-p) = p*(-x-p) + 0.5p² = -px - 0.5p²
            Test.@test H(2.0, 3.0) ≈ -3.0 * 2.0 - 0.5 * 3.0^2 atol = 1e-12
        end

        # ====================================================================
        # UNIT — RHS functors compute the partial-derivative flow (u fixed)
        # ====================================================================

        Test.@testset "Unit: PseudoHamIpRHS / PseudoHamOoPRHS (scalar)" begin
            h̃ = Data.PseudoHamiltonian((x, p, u) -> p * (-x + u) + 0.5 * u^2)
            law = Data.DynClosedLoop((x, p) -> -p)
            be = _backend()
            # x=1, p=2 ⇒ u=-p=-2 ; ∂H̃/∂x=-p=-2, ∂H̃/∂p=-x+u=-3 ⇒ du=[∂p;-∂x]=[-3, 2]
            ip = Systems.PseudoHamIpRHS(
                h̃, law, be, 1, Systems._safe_only, Systems._safe_only
            )
            du = zeros(2)
            ip(du, [1.0, 2.0], Systems.ODEParameters(nothing), 0.0)
            Test.@test du ≈ [-3.0, 2.0] atol = 1e-10

            oop = Systems.PseudoHamOoPRHS(
                h̃, law, be, 1, Systems._safe_only, Systems._safe_only
            )
            Test.@test oop([1.0, 2.0], Systems.ODEParameters(nothing), 0.0) ≈ [-3.0, 2.0] atol =
                1e-10
        end

        Test.@testset "Unit: PseudoHamIpRHS (2-D)" begin
            # H̃(x,p,u) = p·x + 0.5‖u‖² ; law u(x,p) = -p (⇒ ∂H̃/∂u = u+... not used here)
            # ∂H̃/∂x = p, ∂H̃/∂p = x (u held fixed) ⇒ du = [x; -p]
            h̃ = Data.PseudoHamiltonian((x, p, u) -> sum(p .* x) + 0.5 * sum(u .^ 2))
            law = Data.DynClosedLoop((x, p) -> -p)
            be = _backend()
            ip = Systems.PseudoHamIpRHS(h̃, law, be, 2, identity, identity)
            du = zeros(4)
            ip(du, [1.0, 2.0, 3.0, 4.0], Systems.ODEParameters(nothing), 0.0)
            # x=[1,2], p=[3,4] ⇒ du = [∂p; -∂x] = [x; -p] = [1,2,-3,-4]
            Test.@test du ≈ [1.0, 2.0, -3.0, -4.0] atol = 1e-10
        end

        # ====================================================================
        # UNIT — augmented RHS (variable costate), u held fixed
        # ====================================================================

        Test.@testset "Unit: PseudoHamIpAugRHS ṗv = -∂H̃/∂v (u fixed)" begin
            # H̃(x,p,u,v) = p*(-x+u) + 0.5u² + 0.5 v² x ; law u(x,p,v) = -p
            h̃ = Data.PseudoHamiltonian(
                (x, p, u, v) -> p * (-x + u) + 0.5 * u^2 + 0.5 * v^2 * x; is_variable=true
            )
            law = Data.DynClosedLoop((x, p, v) -> -p; is_variable=true)
            be = _backend()
            aug = Systems.PseudoHamIpAugRHS(
                h̃, law, be, 1, 1, Systems._safe_only, Systems._safe_only
            )
            du = zeros(3)
            # x=1,p=2,v=3 ⇒ u=-2 ; ∂H̃/∂x=-p+0.5v²=2.5, ∂H̃/∂p=-x+u=-3, ∂H̃/∂v=v·x=3
            # du = [∂p; -∂x; -∂v] = [-3; -2.5; -3]
            aug(du, [1.0, 2.0, 0.0], Systems.ODEParameters(3.0), 0.0)
            Test.@test du ≈ [-3.0, -2.5, -3.0] atol = 1e-10
        end

        # ====================================================================
        # CONTRACT — variable-costate capability trait
        # ====================================================================

        Test.@testset "Contract: variable_costate_trait" begin
            be = _backend()
            fixed = Systems.build_system(
                Data.PseudoHamiltonian((x, p, u) -> p * u),
                Data.DynClosedLoop((x, p) -> -p),
                be,
            )
            nonfixed = Systems.build_system(
                Data.PseudoHamiltonian((x, p, u, v) -> p * u + v; is_variable=true),
                Data.DynClosedLoop((x, p, v) -> -p; is_variable=true),
                be,
            )
            Test.@test Traits.variable_costate_trait(fixed) === Traits.NoVariableCostate
            Test.@test Traits.variable_costate_trait(nonfixed) ===
                Traits.SupportsVariableCostate
        end

        # ====================================================================
        # UNIT — type stability of the hot-path RHS call
        # ====================================================================

        Test.@testset "Unit: RHS functor call is type-stable" begin
            h̃ = Data.PseudoHamiltonian((x, p, u) -> p * (-x + u) + 0.5 * u^2)
            law = Data.DynClosedLoop((x, p) -> -p)
            oop = Systems.PseudoHamOoPRHS(
                h̃, law, _backend(), 1, Systems._safe_only, Systems._safe_only
            )
            Test.@test_nowarn Test.@inferred oop(
                [1.0, 2.0], Systems.ODEParameters(nothing), 0.0
            )
        end

        # ====================================================================
        # ERROR — build_system rejects a non-DynClosedLoop control law
        # ====================================================================

        Test.@testset "Error: non-DynClosedLoop law rejected by build_system" begin
            h̃ = Data.PseudoHamiltonian((x, p, u) -> p * u)
            be = _backend()
            Test.@test_throws MethodError Systems.build_system(
                h̃, Data.OpenLoop(t -> 1.0), be
            )
            Test.@test_throws MethodError Systems.build_system(
                h̃, Data.ClosedLoop(x -> -x), be
            )
        end
    end
end

end # module

function test_pseudo_hamiltonian_system()
    return TestPseudoHamiltonianSystem.test_pseudo_hamiltonian_system()
end
