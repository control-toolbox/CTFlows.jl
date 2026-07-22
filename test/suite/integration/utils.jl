# Shared shooting helpers for test/suite/integration/.
#
# This file is NOT a module — it is `include`d at module scope inside each test
# module.  The including module must import:
#   using Test: Test
#   using NonlinearSolve: NonlinearProblem, SimpleNewtonRaphson, solve

"""
    test_shooting(shoot!, ξ_exact, ξ_guess; atol=1e-8)

Shared shooting-test helper for `test/suite/integration/`.

`shoot!` must have the flat-vector signature `shoot!(s, ξ) → nothing` where
`length(s) == length(ξ)`.

1. Assert `‖shoot!(s, ξ_exact)‖₂ < atol`  (PMP derivation check).
2. Solve from `ξ_guess` with `SimpleNewtonRaphson`.
3. Assert `‖shoot!(s, ξ_opt)‖₂ < atol`  (convergence check).

Returns `ξ_opt` for downstream quantitative assertions.
"""
function test_shooting(shoot!, ξ_exact, ξ_guess; atol=1e-8)
    n = length(ξ_exact)
    s = zeros(n)

    shoot!(s, ξ_exact)
    Test.@test sqrt(sum(abs2, s)) < atol

    prob = NonlinearProblem((s, ξ, _) -> shoot!(s, ξ), ξ_guess)
    nl = solve(
        prob, SimpleNewtonRaphson(); abstol=1e-10, reltol=1e-10, show_trace=Val(false)
    )

    sc = zeros(n)
    shoot!(sc, nl.u)
    Test.@test sqrt(sum(abs2, sc)) < atol

    return nl.u
end
