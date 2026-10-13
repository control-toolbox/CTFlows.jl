"""
Flow accessors across every kind of flow (issue #438).

`hamiltonian`, `hamiltonian_vector_field`, `vector_field`, `pseudo_hamiltonian`,
`control_law` and the four gradient getters either return a value or raise an
`IncorrectArgument` that says what the flow holds — never a `MethodError`. The gradient
functors accept the short forms of the Hamiltonian (`(x, p)`, `(t, x, p)`, `(x, p, v)`)
besides the full `(t, x, p, v)`.
"""

module TestFlowAccessors

using Test: Test
using CTBase: Data
using CTBase: Exceptions
using CTModels: CTModels
using CTFlows: Flows
using CTFlows: Systems
using OrdinaryDiffEqTsit5: OrdinaryDiffEqTsit5  # SciML integrator for Flow(...)
using ForwardDiff: ForwardDiff  # triggers the DI ForwardDiff extension (AutoForwardDiff)

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

# ── double integrator: ẋ = (x₂, u), ∫ u²/2 → min ────────────────────────────

function _di_ocp()
    pre = CTModels.Building.PreModel()
    CTModels.Building.time_dependence!(pre; autonomous=true)
    CTModels.Building.time!(pre; t0=0.0, tf=1.0)
    CTModels.Building.state!(pre, 2)
    CTModels.Building.control!(pre, 1)
    CTModels.Building.dynamics!(pre, (r, t, x, u, v) -> (r[1]=x[2]; r[2]=u; nothing))
    CTModels.Building.objective!(pre, :min; lagrange=(t, x, u, v) -> 0.5 * u^2)
    return CTModels.Building.build(pre)
end

const OCP = _di_ocp()

# ── accessors and flows ──────────────────────────────────────────────────────

const ACCESSORS = (
    Systems.hamiltonian,
    Systems.hamiltonian_vector_field,
    Systems.vector_field,
    Systems.pseudo_hamiltonian,
    Systems.control_law,
    Systems.get_hamiltonian_gradient,
    Systems.get_variable_gradient,
    Systems.get_pseudo_hamiltonian_gradient,
    Systems.get_pseudo_variable_gradient,
)

const ALL = Set(ACCESSORS)
const HAM = Set((Systems.hamiltonian, Systems.hamiltonian_vector_field, Systems.vector_field,
    Systems.get_hamiltonian_gradient, Systems.get_variable_gradient))
const STATE = Set((Systems.vector_field,))

# (label, flow builder, accessors that apply); the others must raise IncorrectArgument
const CASES = (
    ("Hamiltonian(H)", () -> Flows.Flow(Data.Hamiltonian((x, p) -> 0.5 * sum(p .^ 2))), HAM),
    (
        "HamiltonianVectorField(Hv)",
        () -> Flows.Flow(Data.HamiltonianVectorField((x, p) -> (p, zero(x)))),
        Set((Systems.hamiltonian_vector_field, Systems.vector_field)),
    ),
    (
        "PseudoHamiltonianVectorField(Hv), law",
        () -> Flows.Flow(
            Data.PseudoHamiltonianVectorField((x, p, u) -> (u, zero(p))),
            Data.DynClosedLoop((x, p) -> p),
        ),
        Set((Systems.control_law,)),
    ),
    (
        "PseudoHamiltonian(Hp), law",
        () -> Flows.Flow(
            Data.PseudoHamiltonian((x, p, u) -> p * u - u^2 / 2),
            Data.DynClosedLoop((x, p) -> p),
        ),
        ALL,
    ),
    ("ocp, law", () -> Flows.Flow(OCP, Data.DynClosedLoop((x, p) -> p[2])), ALL),
    (
        "ocp, law (:total)",
        () -> Flows.Flow(OCP, Data.DynClosedLoop((x, p) -> p[2]); hamiltonian_type=:total),
        ALL,
    ),
    ("VectorField(f)", () -> Flows.Flow(Data.VectorField(x -> -x)), STATE),
    (
        "ocp, OpenLoop(u)",
        () -> Flows.Flow(OCP, Data.OpenLoop(t -> 1.0)),
        Set((Systems.vector_field, Systems.control_law)),
    ),
    (
        "ControlledVectorField(f), law",
        () -> Flows.Flow(
            Data.ControlledVectorField((x, u) -> -x + u), Data.ClosedLoop(x -> -x)
        ),
        Set((Systems.vector_field, Systems.control_law)),
    ),
)

# ── pseudo-Hamiltonians for the four (time, variable) dependences ───────────

const X, P, U, T, V = [1.0, 2.0], [3.0, 4.0], 0.7, 0.3, [0.5]

const TRAIT_CASES = (
    (
        "autonomous, fixed",
        true,
        false,
        (x, p, u) -> p[1] * x[2] + p[2] * u - u^2 / 2 + x[1]^2,
        (x, p) -> p[2],
    ),
    (
        "non-autonomous, fixed",
        false,
        false,
        (t, x, p, u) -> t * (p[1] * x[2] + p[2] * u) - u^2 / 2 + x[1]^2,
        (t, x, p) -> p[2],
    ),
    (
        "autonomous, non-fixed",
        true,
        true,
        (x, p, u, v) -> p[1] * x[2] + v[1] * p[2] * u - u^2 / 2 + x[1]^2,
        (x, p, v) -> p[2],
    ),
    (
        "non-autonomous, non-fixed",
        false,
        true,
        (t, x, p, u, v) -> t * (p[1] * x[2] + v[1] * p[2] * u) - u^2 / 2 + x[1]^2,
        (t, x, p, v) -> p[2],
    ),
)

function test_flow_accessors()
    Test.@testset "Flow accessors (issue #438)" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ====================================================================
        # every accessor on every flow: a value or an IncorrectArgument
        # ====================================================================

        Test.@testset "$label" for (label, build, applies) in CASES
            f = build()
            for acc in ACCESSORS
                if acc in applies
                    Test.@test acc(f) !== nothing
                else
                    Test.@test_throws Exceptions.IncorrectArgument acc(f)
                end
            end
        end

        Test.@testset "the error says what the flow holds" begin
            f = Flows.Flow(Data.VectorField(x -> -x))
            err = try
                Systems.hamiltonian(f)
            catch e
                e
            end
            Test.@test err isa Exceptions.IncorrectArgument
            Test.@test occursin("state flow", err.got)
            Test.@test occursin("vector_field", err.suggestion)

            h = Flows.Flow(Data.HamiltonianVectorField((x, p) -> (p, zero(x))))
            err = try
                Systems.control_law(h)
            catch e
                e
            end
            Test.@test occursin("Hamiltonian vector field", err.got)
            Test.@test occursin("hamiltonian_vector_field", err.suggestion)
        end

        Test.@testset "control_law returns the stored law" begin
            law = Data.OpenLoop(t -> 1.0)
            Test.@test Systems.control_law(Flows.Flow(OCP, law)) === law
            dlaw = Data.DynClosedLoop((x, p) -> p)
            f = Flows.Flow(Data.PseudoHamiltonianVectorField((x, p, u) -> (u, zero(p))), dlaw)
            Test.@test Systems.control_law(f) === dlaw
        end

        # ====================================================================
        # gradients: short forms agree with the full forms
        # ====================================================================

        Test.@testset "issue #438 reproducer" begin
            g = Systems.get_hamiltonian_gradient(
                Flows.Flow(OCP, Data.DynClosedLoop((x, p) -> p[2]))
            )
            x, p = [1.0, 2.0], [12.0, 6.0]
            Test.@test g(x, p) == g(0.0, x, p, Float64[])
            Test.@test g(x, p) == ([0.0, 12.0], [2.0, 6.0])
        end

        Test.@testset "gradient short forms [$label]" for (label, aut, var, h̃, u) in
                                                          TRAIT_CASES

            f = Flows.Flow(
                Data.PseudoHamiltonian(h̃; is_autonomous=aut, is_variable=var),
                Data.DynClosedLoop(u; is_autonomous=aut, is_variable=var),
            )
            g = Systems.get_hamiltonian_gradient(f)
            gv = Systems.get_variable_gradient(f)
            gp = Systems.get_pseudo_hamiltonian_gradient(f)
            gpv = Systems.get_pseudo_variable_gradient(f)
            v = var ? V : nothing
            full, fullp = g(T, X, P, v), gp(T, X, P, U, v)
            if aut && !var
                Test.@test g(X, P) == full
                Test.@test gp(X, P, U) == fullp
            elseif !aut && !var
                Test.@test g(T, X, P) == full
                Test.@test gp(T, X, P, U) == fullp
            elseif aut && var
                Test.@test g(X, P, V) == full
                Test.@test gp(X, P, U, V) == fullp
                Test.@test gv(X, P, V) == gv(T, X, P, V)
                Test.@test gpv(X, P, U, V) == gpv(T, X, P, U, V)
            else
                Test.@test full isa Tuple   # the full form is the natural one
            end
        end
    end
end

end # module

test_flow_accessors() = TestFlowAccessors.test_flow_accessors()
