module TestConstrainedPseudoHamiltonianSystem

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

function test_constrained_pseudo_hamiltonian_system()
    Test.@testset "ConstrainedPseudoHamiltonianSystem Tests" verbose = VERBOSE showtiming =
        SHOWTIMING begin

        # ====================================================================
        # UNIT — construction, getters, hamiltonian() returns the base composed H
        # ====================================================================

        Test.@testset "Unit: build_system, getters, hamiltonian()" begin
            h̃ = Data.PseudoHamiltonian((x, p, u) -> p * (-x + u) + 0.5 * u^2)
            law = Data.DynClosedLoop((x, p) -> -p)
            g = Data.StateConstraint(x -> x)
            μ = Data.Multiplier((x, p) -> x)
            be = _backend()
            sys = Systems.build_system(h̃, law, g, μ, be)

            Test.@test sys isa Systems.ConstrainedPseudoHamiltonianSystem
            Test.@test sys isa Systems.AbstractHamiltonianSystem
            Test.@test Systems.pseudo_hamiltonian(sys) === h̃    # base H̃ (no μ·g)
            Test.@test Systems.control_law(sys) === law
            Test.@test Systems.constraint(sys) === g
            Test.@test Systems.multiplier(sys) === μ
            Test.@test Systems.backend(sys) === be

            H = Systems.hamiltonian(sys)                        # base composed (no μ·g)
            Test.@test H isa Data.ComposedHamiltonian
            Test.@test H(2.0, 3.0) ≈ -3.0 * 2.0 - 0.5 * 3.0^2 atol = 1e-12
        end

        # ====================================================================
        # UNIT — FrozenConstrainedPseudoHamiltonian value + frozen-μ differentiation
        # ====================================================================

        Test.@testset "Unit: FrozenConstrainedPseudoHamiltonian value" begin
            h̃ = Data.PseudoHamiltonian((x, p, u) -> p * (-x + u) + 0.5 * u^2)
            g = Data.StateConstraint(x -> x)
            h̃c = Systems.FrozenConstrainedPseudoHamiltonian(h̃, g, 1.0)   # μ_ = 1
            Test.@test h̃c isa Data.AbstractPseudoHamiltonian
            Test.@test Traits.time_dependence(h̃c) === Traits.Autonomous
            Test.@test Traits.variable_dependence(h̃c) === Traits.Fixed
            # H̃c(t,x,p,u,v) = p(-x+u) + 0.5u² + μ_·x
            Test.@test h̃c(0.0, 2.0, 3.0, -1.0, nothing) ≈
                3.0 * (-2.0 - 1.0) + 0.5 * 1.0 + 1.0 * 2.0 atol = 1e-12
        end

        # ====================================================================
        # UNIT — RHS functors compute the frozen-(u, μ) constrained flow
        #   h̃(x,p,u)=p(-x+u)+0.5u², law u=-p, g(x)=x, μ(x,p)=x  (state-dependent)
        #   at x=1, p=2: u_=-2, μ_=1(frozen) ⇒
        #     ∂ₓ[H̃+μ_·g] = -p + μ_ = -1,  ∂ₚ[H̃+μ_·g] = -x+u_ = -3
        #     du = [∂p; -∂x] = [-3; 1]
        #   (a :total flow, differentiating through μ=x, would instead give -∂x = 0)
        # ====================================================================

        Test.@testset "Unit: ConstrainedPseudoHamIpRHS / OoPRHS (scalar, frozen μ)" begin
            h̃ = Data.PseudoHamiltonian((x, p, u) -> p * (-x + u) + 0.5 * u^2)
            law = Data.DynClosedLoop((x, p) -> -p)
            g = Data.StateConstraint(x -> x)
            μ = Data.Multiplier((x, p) -> x)
            be = _backend()

            ip = Systems.ConstrainedPseudoHamIpRHS(
                h̃, law, g, μ, be, 1, Systems._safe_only, Systems._safe_only
            )
            du = zeros(2)
            ip(du, [1.0, 2.0], Systems.ODEParameters(nothing), 0.0)
            Test.@test du ≈ [-3.0, 1.0] atol = 1e-10

            oop = Systems.ConstrainedPseudoHamOoPRHS(
                h̃, law, g, μ, be, 1, Systems._safe_only, Systems._safe_only
            )
            Test.@test oop([1.0, 2.0], Systems.ODEParameters(nothing), 0.0) ≈ [-3.0, 1.0] atol =
                1e-10
        end

        # ====================================================================
        # UNIT — variable-costate trait + augmented RHS (NonFixed)
        #   h̃(x,p,u,v)=p(v*(-x)+u)+0.5u², law u=p, g(x,v)=x*v, μ≡c
        #   at x=1,p=2,v=0.5,c=0.3: u_=2, μ_=0.3(frozen)
        #     ∂ᵥ[H̃+μ_·(x*v)] = p*(-x) + μ_*x = 2*(-1)+0.3*1 = -1.7 ⇒ ṗv = 1.7
        # ====================================================================

        Test.@testset "Unit: variable_costate_trait + augmented RHS (NonFixed)" begin
            h̃ = Data.PseudoHamiltonian(
                (x, p, u, v) -> p * (v * (-x) + u) + 0.5 * u^2; is_variable=true
            )
            law = Data.DynClosedLoop((x, p, v) -> p; is_variable=true)
            g = Data.StateConstraint((x, v) -> x * v; is_variable=true)
            c = 0.3
            μ = Data.Multiplier((x, p) -> c)
            be = _backend()
            sys = Systems.build_system(h̃, law, g, μ, be)
            Test.@test Traits.variable_costate_trait(sys) === Traits.SupportsVariableCostate

            aug = Systems.ConstrainedPseudoHamIpAugRHS(
                h̃, law, g, μ, be, 1, 1, Systems._safe_only, Systems._safe_only
            )
            du = zeros(3)
            aug(du, [1.0, 2.0, 0.0], Systems.ODEParameters(0.5), 0.0)
            # ṗv = -∂ᵥ[H̃+μ_·g] = -(-1.7) = 1.7
            Test.@test du[3] ≈ 1.7 atol = 1e-10
        end

        # ====================================================================
        # UNIT — show
        # ====================================================================

        Test.@testset "Unit: show" begin
            h̃ = Data.PseudoHamiltonian((x, p, u) -> p * (-x + u) + 0.5 * u^2)
            law = Data.DynClosedLoop((x, p) -> -p)
            g = Data.StateConstraint(x -> x)
            μ = Data.Multiplier((x, p) -> x)
            sys = Systems.build_system(h̃, law, g, μ, _backend())
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
