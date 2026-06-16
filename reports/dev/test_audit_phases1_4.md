# Audit des tests manquants — Phases 1 à 4 (refactor closures)

## Phase 1 — `WithActiveArg` + primitives

**Fichier** : `test/suite/differentiation/test_arg_placement.jl`

### T1.1 — Allocation nulle du functor lui-même
```julia
Test.@testset "WithActiveArg: zero allocations on call" begin
    f(a, b, c) = a + b + c
    w = Differentiation.WithActiveArg(f, Val(2))
    w(1.0, 2.0, 3.0)  # warm-up
    Test.@test (@allocated w(1.0, 2.0, 3.0)) == 0
end
```
`WithActiveArg` est utilisé à l'intérieur de `PoissonBracket` et `TimeDeriv_*` à chaque
pas d'intégration. Le mécanisme `@generated` ne doit rien allouer sur le tas.

### T1.2 — Type-stabilité pour slot 1 et slot 3
```julia
Test.@testset "WithActiveArg: @inferred slot 1 and slot 3" begin
    f(a, b, c) = a + b + c
    w1 = Differentiation.WithActiveArg(f, Val(1))
    w3 = Differentiation.WithActiveArg(f, Val(3))
    Test.@test (Test.@inferred w1(1.0, 2.0, 3.0)) == 6.0
    Test.@test (Test.@inferred w3(1.0, 2.0, 3.0)) == 6.0
end
```
Le test existant ne couvre que `Val(2)`. Les slots 1 et 3 exercent des branches
différentes du `@generated` (padding avant/après).

### T1.3 — Contenu des champs de l'erreur `IncorrectArgument`
```julia
Test.@testset "WithActiveArg: IncorrectArgument fields" begin
    f(a, b) = a + b
    w = Differentiation.WithActiveArg(f, Val(5))
    try
        w(1, 2)
        Test.@test false
    catch err
        Test.@test err isa Exceptions.IncorrectArgument
        Test.@test occursin("5", err.got)       # rapporte le slot demandé
        Test.@test occursin("3", err.expected)  # rapporte la borne max
    end
end
```
Le test courant ne vérifie qu'`isa IncorrectArgument` — pas que les champs `got`/`expected`
sont remplis de façon utile, ce qui est le contrat déclaré de ce type d'exception.

### T1.4 — Slot 0 lève bien l'erreur
```julia
Test.@testset "WithActiveArg: slot 0 throws" begin
    f(a, b) = a + b
    w0 = Differentiation.WithActiveArg(f, Val(0))
    Test.@test_throws Exceptions.IncorrectArgument w0(1, 2)
end
```
La condition dans `@generated` est `1 ≤ Slot ≤ total`. Seul `Slot > total` est testé ;
`Slot = 0` touche l'autre branche de la même garde.

---

## Phase 2 — `LiftedHamiltonianFunction`

**Fichier** : `test/suite/differential_geometry/test_lift_dg.jl`

### T2.1 — Type concret `LiftedHamiltonianFunction`
```julia
Test.@testset "Lift() - retourne un LiftedHamiltonianFunction" begin
    F(x) = [x[2], -x[1]]
    H = DifferentialGeometry.Lift(F)
    Test.@test H isa DifferentialGeometry.LiftedHamiltonianFunction
    Test.@test H isa DifferentialGeometry.LiftedHamiltonianFunction{typeof(F), Traits.Autonomous, Traits.Fixed}
end
```
Le test existant vérifie `H isa Function` (trop large). Le type concret paramétré est
ce qui garantit que le dispatch sur `(TD,VD)` est résolu à la compilation.

### T2.2 — Type-stabilité de l'appel
```julia
Test.@testset "Lift() - @inferred" begin
    F(x) = [x[2], -x[1]]
    H = DifferentialGeometry.Lift(F)
    x0 = [1.0, 2.0]; p0 = [3.0, 4.0]
    Test.@test_nowarn Test.@inferred H(x0, p0)
end
```
`LiftedHamiltonianFunction` est sur le chemin chaud de `PoissonBracket`. L'inférence doit être
totale pour éviter les boîtes dynamiques dans l'intégrateur.

### T2.3 — Champ `.f` préservé (pas de closure intermédiaire)
```julia
Test.@testset "Lift() - champ f stocké" begin
    F(x) = [x[2], -x[1]]
    H = DifferentialGeometry.Lift(F)
    Test.@test H.f === F
end
```
Détecte une régression où `Lift` envelopperait `F` dans une closure avant de le stocker.

### T2.4 — Functor stocké dans `Data.Hamiltonian` (path VectorField)
```julia
Test.@testset "Lift() - VectorField: functor interne est LiftedHamiltonianFunction" begin
    X = Data.VectorField(x -> [x[2], -x[1]]; is_autonomous=true, is_variable=false)
    H = DifferentialGeometry.Lift(X)
    Test.@test H.f isa DifferentialGeometry.LiftedHamiltonianFunction
end
```
Quand `Lift` reçoit un `VectorField`, il construit un `Data.Hamiltonian` dont le champ
`.f` est un `LiftedHamiltonianFunction`. Aucun test ne vérifie ça actuellement.

---

## Phase 3 — Functors dans le cache DI

**Fichier** : `test/suite/extensions/test_differentiation_interface_extension.jl`

### T3.1 — `cache.h_x / h_p` sont des `WithActiveArg` (Fixed)
```julia
Test.@testset "Cache functor types (Fixed)" begin
    backend = Differentiation.DifferentiationInterface(; ad_backend=ADTypes.AutoForwardDiff(), prepare_cache=true)
    cache = Differentiation.prepare_cache(backend, FAKE_HAMILTONIAN_FIXED, 0.0, [1.0, 2.0], [3.0, 4.0], nothing)
    Test.@test cache.h_x isa Differentiation.WithActiveArg
    Test.@test cache.h_p isa Differentiation.WithActiveArg
    Test.@test cache.h_v === nothing  # Fixed → pas de functor v
end
```
Test de contrat de la Phase 3 : le cache stocke des functors, pas des closures. Si
quelqu'un réintroduit une closure, `isa Differentiation.WithActiveArg` échoue.

### T3.2 — `cache.h_v` est un `WithActiveArg` (NonFixed)
```julia
Test.@testset "Cache functor types (NonFixed)" begin
    backend = Differentiation.DifferentiationInterface(; ad_backend=ADTypes.AutoForwardDiff(), prepare_cache=true)
    cache = Differentiation.prepare_cache(backend, FAKE_HAMILTONIAN_NONFIXED, 0.0, [1.0, 2.0], [3.0, 4.0], [5.0])
    Test.@test cache.h_x isa Differentiation.WithActiveArg
    Test.@test cache.h_p isa Differentiation.WithActiveArg
    Test.@test cache.h_v isa Differentiation.WithActiveArg
end
```
Le chemin NonFixed crée un troisième functor `h_v`. La même garantie s'applique.

### T3.3 — Slot paramétrique correct
```julia
Test.@testset "Cache: slots corrects" begin
    backend = Differentiation.DifferentiationInterface(; ad_backend=ADTypes.AutoForwardDiff(), prepare_cache=true)
    cache = Differentiation.prepare_cache(backend, FAKE_HAMILTONIAN_FIXED, 0.0, [1.0, 2.0], [3.0, 4.0], nothing)
    # FAKE_HAMILTONIAN_FIXED est Autonomous → signature h(x,p) → slot 1 pour x, slot 2 pour p
    Test.@test cache.h_x isa Differentiation.WithActiveArg{<:Any, 1}
    Test.@test cache.h_p isa Differentiation.WithActiveArg{<:Any, 2}
end
```
Un swap de slots (`h_x` et `h_p` inversés) produirait des gradients incorrects sans faire
échouer les tests de valeur si le Hamiltonien test est symétrique en x et p.

---

## Phase 4 — `PoissonBracket`

**Fichier** : `test/suite/differential_geometry/test_poisson_dg.jl`

### T4.1 — Type concret `PoissonBracket`
```julia
Test.@testset "Poisson() - retourne un PoissonBracket" begin
    H(x, p) = p[1]^2 / 2 + x[1]
    G(x, p) = p[2]^2 / 2 + x[2]
    PB = DifferentialGeometry.Poisson(H, G)
    Test.@test PB isa DifferentialGeometry.PoissonBracket
    Test.@test PB isa DifferentialGeometry.PoissonBracket{typeof(H), typeof(G), <:Differentiation.AbstractADBackend, Traits.Autonomous, Traits.Fixed}
end
```
`isa Function` ne détecte pas une régression où `_Poisson` retournerait une closure.

### T4.2 — Type-stabilité de l'appel
```julia
Test.@testset "Poisson() - @inferred (Autonomous/Fixed)" begin
    H(x, p) = p[1]^2 / 2 + x[1]^2
    G(x, p) = x[1] * p[1]
    PB = DifferentialGeometry.Poisson(H, G)
    x0 = [1.0, 2.0]; p0 = [0.5, 1.0]
    PB(x0, p0)  # warm-up
    Test.@test_nowarn Test.@inferred PB(x0, p0)
end
```
`PoissonBracket` est sur le chemin chaud (ex. bracket de Lie itéré).

### T4.3 — Valeurs analytiques pour les 3 autres combinaisons TD×VD
Les tests "NonAutonomous Fixed / Autonomous NonFixed / NonAutonomous NonFixed" actuels
ne vérifient que `val isa Number` — ils ne testent pas que le calcul est correct.

```julia
Test.@testset "Poisson() - valeur correcte NonAutonomous/Fixed" begin
    # {H,G} avec H(t,x,p)=t*p[1], G(t,x,p)=x[1]
    # ∂H/∂p=[t,0], ∂H/∂x=0, ∂G/∂p=0, ∂G/∂x=[1,0]
    # {H,G} = ∂H/∂p · ∂G/∂x - ∂H/∂x · ∂G/∂p = t*1 - 0 = t
    H(t, x, p) = t * p[1]
    G(t, x, p) = x[1]
    PB = DifferentialGeometry.Poisson(H, G; is_autonomous=false, is_variable=false)
    t0 = 3.0; x0 = [1.0, 2.0]; p0 = [0.5, 1.0]
    Test.@test PB(t0, x0, p0) ≈ t0 atol=1e-6
end

Test.@testset "Poisson() - valeur correcte Autonomous/NonFixed" begin
    # H(x,p,v)=v[1]*p[1], G(x,p,v)=x[1]
    # {H,G} = v[1]
    H(x, p, v) = v[1] * p[1]
    G(x, p, v) = x[1]
    PB = DifferentialGeometry.Poisson(H, G; is_autonomous=true, is_variable=true)
    x0 = [1.0, 2.0]; p0 = [0.5, 1.0]; v0 = [4.0]
    Test.@test PB(x0, p0, v0) ≈ v0[1] atol=1e-6
end

Test.@testset "Poisson() - valeur correcte NonAutonomous/NonFixed" begin
    # H(t,x,p,v)=t*v[1]*p[1], G(t,x,p,v)=x[1]
    # {H,G} = t*v[1]
    H(t, x, p, v) = t * v[1] * p[1]
    G(t, x, p, v) = x[1]
    PB = DifferentialGeometry.Poisson(H, G; is_autonomous=false, is_variable=true)
    t0 = 2.0; x0 = [1.0, 2.0]; p0 = [0.5, 1.0]; v0 = [3.0]
    Test.@test PB(t0, x0, p0, v0) ≈ t0 * v0[1] atol=1e-6
end
```
Un test `val isa Number` passe même si le signe est inversé ou si le résultat vaut `NaN`.

---

## Phase 4 — `TimeDeriv_*`

**Fichier** : `test/suite/differential_geometry/test_time_derivative_dg.jl`

### T5.1 — Type concret `TimeDeriv_F`
```julia
Test.@testset "∂ₜ() - retourne un TimeDeriv_F" begin
    f(t, x) = t^2 + x[1]
    df = DifferentialGeometry.∂ₜ(f)
    Test.@test df isa DifferentialGeometry.TimeDeriv_F
end
```
Le test existant vérifie seulement la valeur. `isa TimeDeriv_F` est le contrat de Phase 4.

### T5.2 — Functor interne et `@inferred` pour `VectorField`
```julia
Test.@testset "∂ₜ() - VectorField: functor interne est TimeDeriv_VF + @inferred" begin
    X = Data.VectorField((t, x) -> [t * x[2], -t * x[1]]; is_autonomous=false, is_variable=false)
    dX = DifferentialGeometry.∂ₜ(X)
    Test.@test dX.f isa DifferentialGeometry.TimeDeriv_VF
    t0 = 2.0; x0 = [1.0, 2.0]
    dX(t0, x0)  # warm-up
    Test.@test_nowarn Test.@inferred dX(t0, x0)
end
```
Les tests actuels vérifient `dX isa Data.VectorField` mais pas le functor interne ni
la stabilité de type.

### T5.3 — Combinaisons manquantes pour `VectorField` (NonFixed)
```julia
Test.@testset "∂ₜ() - Autonomous NonFixed VectorField → zéro" begin
    X = Data.VectorField((x, v) -> [v[1] * x[2], -x[1]]; is_autonomous=true, is_variable=true)
    dX = DifferentialGeometry.∂ₜ(X)
    Test.@test dX isa Data.AbstractVectorField{Traits.NonAutonomous, Traits.NonFixed, Traits.OutOfPlace}
    Test.@test isapprox(dX(1.0, [1.0, 2.0], [3.0]), [0.0, 0.0]; atol=1e-10)
end

Test.@testset "∂ₜ() - NonAutonomous NonFixed VectorField" begin
    # X(t, x, v) = [t*v[1]*x[2], -x[1]]  →  ∂X/∂t = [v[1]*x[2], 0]
    X = Data.VectorField((t, x, v) -> [t * v[1] * x[2], -x[1]]; is_autonomous=false, is_variable=true)
    dX = DifferentialGeometry.∂ₜ(X)
    t0 = 2.0; x0 = [1.0, 2.0]; v0 = [3.0]
    Test.@test isapprox(dX(t0, x0, v0), [v0[1] * x0[2], 0.0]; atol=1e-6)
end
```

### T5.4 — Combinaisons manquantes pour `Hamiltonian` (Autonomous + NonFixed)
```julia
Test.@testset "∂ₜ() - Autonomous Fixed Hamiltonian → zéro" begin
    H = Data.Hamiltonian((x, p) -> p' * x; is_autonomous=true, is_variable=false)
    dH = DifferentialGeometry.∂ₜ(H)
    Test.@test dH isa Data.AbstractHamiltonian{Traits.NonAutonomous, Traits.Fixed}
    Test.@test dH(1.0, [1.0, 2.0], [3.0, 4.0]) ≈ 0.0 atol=1e-10
end

Test.@testset "∂ₜ() - Autonomous NonFixed Hamiltonian → zéro" begin
    H = Data.Hamiltonian((x, p, v) -> v[1] * p' * x; is_autonomous=true, is_variable=true)
    dH = DifferentialGeometry.∂ₜ(H)
    Test.@test dH isa Data.AbstractHamiltonian{Traits.NonAutonomous, Traits.NonFixed}
    Test.@test dH(1.0, [1.0, 2.0], [3.0, 4.0], [2.0]) ≈ 0.0 atol=1e-10
end

Test.@testset "∂ₜ() - NonAutonomous NonFixed Hamiltonian" begin
    # H(t, x, p, v) = t * v[1] * p[1]  →  ∂H/∂t = v[1]*p[1]
    H = Data.Hamiltonian((t, x, p, v) -> t * v[1] * p[1]; is_autonomous=false, is_variable=true)
    dH = DifferentialGeometry.∂ₜ(H)
    t0 = 2.0; x0 = [1.0]; p0 = [3.0]; v0 = [4.0]
    Test.@test dH(t0, x0, p0, v0) ≈ v0[1] * p0[1] atol=1e-6
end
```

### T5.5 — `HamiltonianVectorField` — entièrement absent
`∂ₜ(X::HamiltonianVectorField)` n'est pas testé du tout alors que c'est une méthode
publique exportée. Ajouter au minimum :

```julia
Test.@testset "∂ₜ() - NonAutonomous Fixed HamiltonianVectorField" begin
    # X(t,x,p) = (t*p, -t*x)  →  ∂X/∂t = (p, -x)
    X = Data.HamiltonianVectorField((t, x, p) -> (t * p, -t * x);
        is_autonomous=false, is_variable=false)
    dX = DifferentialGeometry.∂ₜ(X)
    Test.@test dX isa Data.HamiltonianVectorField
    Test.@test dX isa Data.AbstractHamiltonianVectorField{Traits.NonAutonomous, Traits.Fixed, Traits.OutOfPlace}
    t0 = 2.0; x0 = [1.0]; p0 = [3.0]
    dx, dp = dX(t0, x0, p0)
    Test.@test dx ≈ p0 atol=1e-6
    Test.@test dp ≈ -x0 atol=1e-6
end

Test.@testset "∂ₜ() - Autonomous Fixed HamiltonianVectorField → zéro" begin
    X = Data.HamiltonianVectorField((x, p) -> (p, -x); is_autonomous=true, is_variable=false)
    dX = DifferentialGeometry.∂ₜ(X)
    Test.@test dX isa Data.AbstractHamiltonianVectorField{Traits.NonAutonomous, Traits.Fixed, Traits.OutOfPlace}
    dx, dp = dX(1.0, [1.0], [3.0])
    Test.@test dx ≈ [0.0] atol=1e-10
    Test.@test dp ≈ [0.0] atol=1e-10
end

# + idem pour les 2 cas NonFixed
# + @inferred sur l'un des appels
```

---

## Résumé

| #    | Phase | Fichier                                     | Critère manquant                                  |
|------|-------|---------------------------------------------|---------------------------------------------------|
| T1.1 | 1     | `test_arg_placement.jl`                     | `@allocated == 0` sur appel functor               |
| T1.2 | 1     | `test_arg_placement.jl`                     | `@inferred` slot 1 et slot 3                      |
| T1.3 | 1     | `test_arg_placement.jl`                     | Champs `got`/`expected` de l'erreur               |
| T1.4 | 1     | `test_arg_placement.jl`                     | Slot 0 lève bien `IncorrectArgument`              |
| T2.1 | 2     | `test_lift_dg.jl`                           | `isa LiftedHamiltonianFunction{F,TD,VD}`                  |
| T2.2 | 2     | `test_lift_dg.jl`                           | `@inferred` sur l'appel                           |
| T2.3 | 2     | `test_lift_dg.jl`                           | `.f === F` (pas de closure intermédiaire)         |
| T2.4 | 2     | `test_lift_dg.jl`                           | `.f isa LiftedHamiltonianFunction` (path VectorField)     |
| T3.1 | 3     | `test_differentiation_interface_extension.jl` | `cache.h_x/h_p isa WithActiveArg` (Fixed)       |
| T3.2 | 3     | `test_differentiation_interface_extension.jl` | `cache.h_v isa WithActiveArg` (NonFixed)         |
| T3.3 | 3     | `test_differentiation_interface_extension.jl` | Slot paramétrique correct dans le type           |
| T4.1 | 4     | `test_poisson_dg.jl`                        | `isa PoissonBracket{H,G,B,TD,VD}`                 |
| T4.2 | 4     | `test_poisson_dg.jl`                        | `@inferred` sur l'appel                           |
| T4.3 | 4     | `test_poisson_dg.jl`                        | Valeurs analytiques pour 3 TD×VD restants         |
| T5.1 | 4     | `test_time_derivative_dg.jl`                | `isa TimeDeriv_F`                                 |
| T5.2 | 4     | `test_time_derivative_dg.jl`                | `dX.f isa TimeDeriv_VF` + `@inferred`             |
| T5.3 | 4     | `test_time_derivative_dg.jl`                | NonFixed VectorField : Autonomous (zéro) + NonAut |
| T5.4 | 4     | `test_time_derivative_dg.jl`                | Autonomous Ham (zéro Fixed+NonFixed) + NonAut NonFixed |
| T5.5 | 4     | `test_time_derivative_dg.jl`                | `HamiltonianVectorField` — 4 cas entièrement absents |
