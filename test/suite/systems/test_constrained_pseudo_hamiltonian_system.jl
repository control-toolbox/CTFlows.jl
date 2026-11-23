module TestConstrainedPseudoHamiltonianSystem

using Test: Test
using CTBase: Data
using CTBase: Traits
using CTBase: Differentiation
using CTBase: Exceptions
using CTFlows: Systems
using ADTypes: ADTypes
using DifferentiationInterface: DifferentiationInterface
using ForwardDiff: ForwardDiff

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

# Constrained pseudo-Hamiltonians H(x, p, u, μ[, v]) of the tests.
cph_scalar(x, p, u, μ) = p * (-x + u) + 0.5 * u^2 + μ * x
cph_variable(x, p, u, μ, v) = p * (v * (-x) + u) + 0.5 * u^2 + μ * x * v

function _backend()
    return Differentiation.DifferentiationInterface(; ad_backend=ADTypes.AutoForwardDiff())
end

function test_constrained_pseudo_hamiltonian_system()
    Test.@testset "ConstrainedPseudoHamiltonianSystem Tests" verbose = VERBOSE showtiming =
        SHOWTIMING begin

        # ====================================================================
        # UNIT — construction, getters; the same objects as the :total mode
        #   H(x,p,u,μ) = p(-x+u) + 0.5u² + μ·x, law u=-p, μ(x,p)=x
        # ====================================================================

        Test.@testset "Unit: build_system, getters, hamiltonian()" begin
            H = Data.ConstrainedPseudoHamiltonian(cph_scalar)
            law = Data.DynClosedLoop((x, p) -> -p)
            μ = Data.Multiplier((x, p) -> x)
            be = _backend()
            sys = Systems.build_system(H, law, μ, be)

            Test.@test sys isa Systems.ConstrainedPseudoHamiltonianSystem
            Test.@test sys isa Systems.AbstractHamiltonianSystem
            Test.@test Systems.pseudo_hamiltonian(sys) === H     # μ explicit
            Test.@test Systems.control_law(sys) === law
            Test.@test Systems.multiplier(sys) === μ
            Test.@test Systems.backend(sys) === be

            h = Systems.hamiltonian(sys)                         # with the μ·g term
            Test.@test h isa Data.ComposedConstrainedHamiltonian
            Test.@test Data.pseudo_hamiltonian(h) === H
            Test.@test Data.control_law(h) === law
            Test.@test Data.multiplier(h) === μ
            # x=2, p=3: u=-3, μ=2 ⇒ 3(-2-3) + 4.5 + 2·2
            Test.@test h(2.0, 3.0) ≈ 3.0 * (-5.0) + 4.5 + 4.0 atol = 1e-12
        end

        # ====================================================================
        # UNIT — RHS functors compute the frozen-(u, μ) constrained flow
        #   at x=1, p=2: u_=-2, μ_=1 (frozen) ⇒
        #     ∂ₓH = -p + μ_ = -1,  ∂ₚH = -x + u_ = -3
        #     du = [∂p; -∂x] = [-3; 1]
        #   (a :total flow, differentiating through μ=x, would instead give -∂x = 0)
        # ====================================================================

        Test.@testset "Unit: ConstrainedPseudoHamIpRHS / OoPRHS (scalar, frozen μ)" begin
            H = Data.ConstrainedPseudoHamiltonian(cph_scalar)
            law = Data.DynClosedLoop((x, p) -> -p)
            μ = Data.Multiplier((x, p) -> x)
            be = _backend()

            ip = Systems.ConstrainedPseudoHamIpRHS(
                H, law, μ, be, 1, Systems._safe_only, Systems._safe_only
            )
            du = zeros(2)
            ip(du, [1.0, 2.0], Systems.ODEParameters(nothing), 0.0)
            Test.@test du ≈ [-3.0, 1.0] atol = 1e-10

            oop = Systems.ConstrainedPseudoHamOoPRHS(
                H, law, μ, be, 1, Systems._safe_only, Systems._safe_only
            )
            Test.@test oop([1.0, 2.0], Systems.ODEParameters(nothing), 0.0) ≈ [-3.0, 1.0] atol =
                1e-10
        end

        # ====================================================================
        # UNIT — variable-costate trait + augmented RHS (NonFixed)
        #   H(x,p,u,μ,v) = p(v(-x)+u) + 0.5u² + μ·x·v, law u=p, μ≡c
        #   at x=1, p=2, v=0.5, c=0.3: u_=2, μ_=0.3 (frozen)
        #     ∂ᵥH = p(-x) + μ_·x = -1.7 ⇒ ṗv = 1.7
        # ====================================================================

        Test.@testset "Unit: variable_costate_trait + augmented RHS (NonFixed)" begin
            H = Data.ConstrainedPseudoHamiltonian(cph_variable; is_variable=true)
            law = Data.DynClosedLoop((x, p, v) -> p; is_variable=true)
            c = 0.3
            μ = Data.Multiplier((x, p) -> c)
            be = _backend()
            sys = Systems.build_system(H, law, μ, be)
            Test.@test Traits.variable_costate_trait(sys) === Traits.SupportsVariableCostate

            aug = Systems.ConstrainedPseudoHamIpAugRHS(
                H, law, μ, be, 1, 1, Systems._safe_only, Systems._safe_only
            )
            du = zeros(3)
            aug(du, [1.0, 2.0, 0.0], Systems.ODEParameters(0.5), 0.0)
            Test.@test du[3] ≈ 1.7 atol = 1e-10
        end

        # ====================================================================
        # ERROR — the pseudo-Hamiltonian gradient getters need μ frozen first
        # ====================================================================

        Test.@testset "Error: pseudo-Hamiltonian gradient getters on a constrained system" begin
            H = Data.ConstrainedPseudoHamiltonian(cph_scalar)
            law = Data.DynClosedLoop((x, p) -> -p)
            μ = Data.Multiplier((x, p) -> x)
            sys = Systems.build_system(H, law, μ, _backend())
            Test.@test_throws Exceptions.IncorrectArgument Systems.get_pseudo_hamiltonian_gradient(
                sys
            )
            Test.@test_throws Exceptions.IncorrectArgument Systems.get_pseudo_variable_gradient(
                sys
            )
        end

        # ====================================================================
        # UNIT — show
        # ====================================================================

        Test.@testset "Unit: show" begin
            H = Data.ConstrainedPseudoHamiltonian(cph_scalar)
            law = Data.DynClosedLoop((x, p) -> -p)
            μ = Data.Multiplier((x, p) -> x)
            sys = Systems.build_system(H, law, μ, _backend())
            s = sprint(show, sys)
            Test.@test occursin("ConstrainedPseudoHamiltonianSystem", s)
        end
    end
    return nothing
end

end # module

function test_constrained_pseudo_hamiltonian_system()
    return TestConstrainedPseudoHamiltonianSystem.test_constrained_pseudo_hamiltonian_system()
end
