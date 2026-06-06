# Audit des closures — remplacement par des callable structs

## Objectif et motivation

Le projet remplace les closures par des **callable structs** (functors). Ce document
justifie ce choix et recense exhaustivement les closures restantes dans `src/` et `ext/`.

### Pourquoi les callable structs sont préférables aux closures

**Stabilité de type.**
Une closure capture ses variables dans un struct anonyme généré par le compilateur. Si
une variable capturée a un type abstrait au moment de la capture, le struct résultant
est lui aussi paramétré par un type abstrait → instabilité de type dans les chemins
chauds (intégrateurs, gradients). Un callable struct avec des champs explicitement
paramétrés garantit la stabilité à la construction.

```julia
# Closure : si `vf` est AbstractVectorField → type du struct anonyme instable
rhs = (du, u, p, t) -> vf(du, t, u, Common.variable(p))

# Callable struct : F, TD, VD sont des paramètres concrets → stable
struct IPVFOoPRHS{F,TD,VD} <: AbstractIPRHS
    vf::Data.VectorField{F,TD,VD,Traits.OutOfPlace}
end
(f::IPVFOoPRHS)(du, u, p, t) = (du .= f.vf(t, u, Common.variable(p)); nothing)
```

**Intégration dans la hiérarchie de types et le dispatch.**
Les callable structs participent au système de dispatch de Julia. La hiérarchie
`AbstractRHS{T<:AbstractMutabilityTrait}` permet de dispatcher sur le trait de
mutabilité sans `isa`/`typeof` — cohérent avec la philosophie `types-traits-interfaces.md`.
Les closures, produisant des types anonymes (`var"#42#43"`), ne peuvent pas participer à
ce dispatch.

**Problèmes de world-age absents.**
Une closure définie dans une fonction locale capture un monde de compilation donné. Si
une méthode est définie *après* la création de la closure, la closure ne la voit pas
(erreur de world-age ou appel dans un monde antérieur). Les callable structs avec des
méthodes définies au top-level du module n'ont pas ce problème — c'est la raison de la
règle CLAUDE.md *"Fake types at module top-level — never inside test functions"*.

**Introspection et affichage.**
`typeof(rhs)` sur un callable struct donne `IPVFOoPRHS{var"#f#1", Autonomous, Fixed}` —
inspecable, affichable proprement (`Base.show` par dispatch), sérialisable.
Sur une closure : `var"#42#43"` — opaque.

**Précompilation.**
Les méthodes de callable structs se précompilent intégralement. Les closures capturant
des objets non-`isbits` génèrent fréquemment des invalidations et bloquent la
précompilation des modules.

**Compatibilité AD.**
Les backends de différentiation automatique (ForwardDiff, Zygote, …) traversent les
callable structs avec les règles ChainRules habituelles. Certains backends ont des
difficultés à propager le gradient à travers des types anonymes de closures imbriquées.

### Ce qui a déjà été fait

Les RHS de `VectorFieldSystem` ont été convertis en Phase G (voir git log
`bfd6b5a`). Les fichiers `rhs_functors.jl`, `hamiltonian_rhs_functors.jl`,
`hvf_rhs_functors.jl` sont entièrement basés sur des callable structs avec la hiérarchie
`AbstractRHS{T}` → `AbstractIPRHS` / `AbstractOoPRHS`.

### Refactor closures de différentiation — résultat final (phases A–E)

Les phases A à E du refactor ont traité tous les sites de closures de différentiation
listés ci-dessous. Voir `reports/dev/closures_refactor_action_plan.md` pour le détail.

| Site | Phase | Functor introduit | Statut |
|---|---|---|---|
| `src/DifferentialGeometry/lift.jl` | B/2 | `LiftedHamiltonian{F,TD,VD}` | ✅ Terminé |
| `src/Solutions/hamiltonian_vector_field_solution.jl` | B/2 | `StateProjection{S}`, `CostateProjection{S}` | ✅ Terminé |
| `ext/CTFlowsDifferentiationInterface.jl` (`h_x/h_p/h_v`) | C/3 | `WithActiveArg(h, Val(1/2/3))` | ✅ Terminé |
| `src/DifferentialGeometry/poisson.jl` | D/4 | `PoissonBracket{TH,TG,B,TD,VD}` | ✅ Terminé |
| `src/DifferentialGeometry/time_derivative.jl` | D/4 | `TimeDeriv_F`, `TimeDeriv_HVF`, `TimeDeriv_VF`, `TimeDeriv_Ham` | ✅ Terminé |
| `src/DifferentialGeometry/ad.jl` | E/5 | `Ad{TX,TF,B,TD,VD}` | ✅ Terminé |

**Primitives ajoutées :**
- `Differentiation.WithActiveArg{F,Slot}` — réinsertion d'argument au slot `Slot` (Phase A/1)
- `Differentiation.differentiate(backend, f, ::Val{Slot}, active, consts...)` — dérivée partielle (Phase A/1)
- `Differentiation.pushforward(backend, f, ::Val{Slot}, x, dx, consts...)` — JVP (Phase A/1)

**Stubs `gradient`/`derivative` (anciens) :**
`Differentiation.gradient` et `Differentiation.derivative` sont toujours déclarés dans
`src/Differentiation/abstract_ad_backend.jl` et implémentés dans l'extension
`CTFlowsDifferentiationInterface.jl`. Ils ne sont plus appelés depuis `src/` (les 4 sites
DG utilisent désormais `pushforward`/`differentiate`). La suppression de ces stubs et de
leur implémentation dans l'ext nécessite un checkpoint humain explicite (voir plan)
car `gradient`/`derivative` peuvent être utilisés par du code utilisateur externe.

---

## Inventaire des closures restantes

### 1. `src/DifferentialGeometry/lift.jl` — 4 closures

Fonction `_Lift` : retourne une closure qui calcule `H(·) = p' * f(·)`.

```julia
_Lift(f, ::Type{Traits.Autonomous},    ::Type{Traits.Fixed})    = (x, p)       -> p' * f(x)
_Lift(f, ::Type{Traits.Autonomous},    ::Type{Traits.NonFixed}) = (x, p, v)    -> p' * f(x, v)
_Lift(f, ::Type{Traits.NonAutonomous}, ::Type{Traits.Fixed})    = (t, x, p)    -> p' * f(t, x)
_Lift(f, ::Type{Traits.NonAutonomous}, ::Type{Traits.NonFixed}) = (t, x, p, v) -> p' * f(t, x, v)
```

| # | Variables capturées | Signature retournée |
|---|---|---|
| 1 | `f` | `(x, p)` |
| 2 | `f` | `(x, p, v)` |
| 3 | `f` | `(t, x, p)` |
| 4 | `f` | `(t, x, p, v)` |

La closure retournée est wrappée dans un `Data.Hamiltonian` par l'appelant.
Cible naturelle : un functor `LiftedHamiltonian{F, TD, VD}`.

---

### 2. `src/DifferentialGeometry/time_derivative.jl` — 12 closures

Trois familles de 4 variantes TD×VD, chacune retournant une closure calculant une
dérivée temporelle via AD.

**`_∂ₜ_hvf` (HamiltonianVectorField) :**

```julia
_∂ₜ_hvf(X, b, ::Autonomous,    ::Fixed)    = (t, x, p)    -> Differentiation.derivative(b, s -> X(x, p),       t)
_∂ₜ_hvf(X, b, ::Autonomous,    ::NonFixed) = (t, x, p, v) -> Differentiation.derivative(b, s -> X(x, p, v),    t)
_∂ₜ_hvf(X, b, ::NonAutonomous, ::Fixed)    = (t, x, p)    -> Differentiation.derivative(b, s -> X(s, x, p),    t)
_∂ₜ_hvf(X, b, ::NonAutonomous, ::Fixed)    = (t, x, p, v) -> Differentiation.derivative(b, s -> X(s, x, p, v), t)
```

**`_∂ₜ_vf` (VectorField) :**

```julia
_∂ₜ_vf(X, b, ::Autonomous,    ::Fixed)    = (t, x)    -> Differentiation.derivative(b, s -> X(x),       t)
_∂ₜ_vf(X, b, ::Autonomous,    ::NonFixed) = (t, x, v) -> Differentiation.derivative(b, s -> X(x, v),    t)
_∂ₜ_vf(X, b, ::NonAutonomous, ::Fixed)    = (t, x)    -> Differentiation.derivative(b, s -> X(s, x),    t)
_∂ₜ_vf(X, b, ::NonAutonomous, ::NonFixed) = (t, x, v) -> Differentiation.derivative(b, s -> X(s, x, v), t)
```

**`_∂ₜ_ham` (Hamiltonian) :**

```julia
_∂ₜ_ham(H, b, ::Autonomous,    ::Fixed)    = (t, x, p)    -> Differentiation.derivative(b, s -> H(x, p),       t)
_∂ₜ_ham(H, b, ::Autonomous,    ::NonFixed) = (t, x, p, v) -> Differentiation.derivative(b, s -> H(x, p, v),    t)
_∂ₜ_ham(H, b, ::NonAutonomous, ::Fixed)    = (t, x, p)    -> Differentiation.derivative(b, s -> H(s, x, p),    t)
_∂ₜ_ham(H, b, ::NonAutonomous, ::NonFixed) = (t, x, p, v) -> Differentiation.derivative(b, s -> H(s, x, p, v), t)
```

| Variables capturées | Présence de closure imbriquée |
|---|---|
| `X` (ou `H`) et `b` (backend AD) | Oui — `s -> X(...)` passé à `derivative` |

Chaque closure externe capture `X`/`H` et `b`. Elle contient elle-même une closure
interne `s -> X(...)` créée à chaque *appel* (pas à la construction) — coût d'allocation
par évaluation.

Cible naturelle : un functor `TimeDerivativeRHS{X, B, TD, VD}` dont l'appel recrée la
closure interne (problème plus délicat — voir §Discussion ci-dessous).

---

### 3. `src/DifferentialGeometry/poisson.jl` — 4 closures

Fonction `_Poisson` : retourne une closure calculant `{H, G}(·)` par gradients AD.

```julia
function _Poisson(H, G, backend, ::Autonomous, ::Fixed)
    return function (x, p)
        gxH = Differentiation.gradient(backend, y -> H(y, p), x)
        gpH = Differentiation.gradient(backend, q -> H(x, q), p)
        gxG = Differentiation.gradient(backend, y -> G(y, p), x)
        gpG = Differentiation.gradient(backend, q -> G(x, q), p)
        return gpH' * gxG - gxH' * gpG
    end
end
# + 3 variantes (NonAutonomous/Fixed, Autonomous/NonFixed, NonAutonomous/NonFixed)
```

| # | Variables capturées | Closures imbriquées (créées à chaque appel) |
|---|---|---|
| 1 | `H, G, backend` | 4 × `y -> H(...)`, `q -> H(...)`, etc. |
| 2 | `H, G, backend` | 4 × idem (avec `t` fixé dans le corps) |
| 3 | `H, G, backend` | 4 × idem (avec `v` fixé dans le corps) |
| 4 | `H, G, backend` | 4 × idem (avec `t` et `v`) |

Les closures imbriquées passées à `gradient` sont les plus coûteuses : elles sont
re-allouées à chaque évaluation du crochet de Poisson.

---

### 4. `src/DifferentialGeometry/ad.jl` — closures imbriquées

Fonction `_ad` : 4 variantes TD×VD, chacune retournant une closure de dérivée de Lie.
Chaque closure externe contient 3 closures internes créées à chaque appel.

```julia
function _ad(X, foo, backend, ::Autonomous, ::Fixed)
    return function (x)                        # CLOSURE EXTERNE capturant X, foo, backend
        X_x  = X(x)
        X̂    = x_ -> X(x_)                   # CLOSURE INTERNE 1 : capture X
        f̂    = x_ -> foo(x_)                 # CLOSURE INTERNE 2 : capture foo
        g(s) = f̂(x + s * X_x)               # CLOSURE INTERNE 3 : capture f̂, x, X_x
        dfoo = Differentiation.derivative(backend, g, 0.0)
        return _ad_result(X̂, f̂, dfoo, x, X_x, backend)
    end
end
```

| Closure | Variables capturées | Fréquence de création |
|---|---|---|
| Externe `(x) -> ...` | `X, foo, backend` | À la construction |
| `X̂ = x_ -> X(x_)` | `X` (+ `t`, `v` pour NonAut/NonFixed) | À chaque appel |
| `f̂ = x_ -> foo(x_)` | `foo` (+ `t`, `v`) | À chaque appel |
| `g(s) = f̂(x + s * X_x)` | `f̂, x, X_x` | À chaque appel |

Les 3 closures internes sont les plus problématiques : elles allouent à chaque appel de
la fonction de Lie, ce qui impacte les intégrateurs numériques.

---

### 5. `src/Solutions/hamiltonian_vector_field_solution.jl` — 2 closures

Accesseurs sémantiques retournant une projection temporelle.

```julia
function state(sol::HamiltonianVectorFieldSolution)
    return t -> sol(t)[1]    # capture sol
end

function costate(sol::HamiltonianVectorFieldSolution)
    return t -> sol(t)[2]    # capture sol
end
```

Ces closures sont simples (1 variable capturée, pas de closures imbriquées). Le type
retourné est `Function` — opaque pour l'appelant. Cible : callable structs
`StateAccessor{S}` / `CostateAccessor{S}` avec un champ `sol::S`.

---

### 6. `ext/CTFlowsStaticArrays.jl` — 4 lambdas `ntuple`

Lambdas passées à `ntuple` pour construire des `SVector`/`SMatrix`.

```julia
x_part = SVector(ntuple(i -> u[i],     Val(N)))
p_part = SVector(ntuple(i -> u[N+i],   Val(N)))
# + 2 variantes SMatrix
```

Ces lambdas capturent `u` et `N`, mais sont passées à `ntuple` qui les inline
statiquement (le compilateur les spécialise via `Val(N)` — pas d'allocation en pratique).
**Priorité faible** : l'impact performance est nul ; la conversion en functor alourdirait
le code sans bénéfice.

---

### 7. `src/MultiPhase/multiphase_flow.jl` — 2 lambdas `map`

Dans `Base.show` uniquement.

```julia
map(s -> string(nameof(typeof(s))), sys)
map(i -> string(nameof(typeof(i))), integ)
```

Pas de capture de variable du scope englobant (les lambdas n'utilisent que leur
argument). **Pas des closures** au sens strict — pas de conversion nécessaire.

---

## Synthèse et priorités

| Fichier | Closures | Closures imbriquées | Priorité |
|---|---|---|---|
| `DifferentialGeometry/ad.jl` | 4 externes | 3×4 = 12 internes (par appel) | **Haute** |
| `DifferentialGeometry/poisson.jl` | 4 externes | 4×4 = 16 internes (par appel) | **Haute** |
| `DifferentialGeometry/time_derivative.jl` | 12 externes | 12 internes (par appel) | **Haute** |
| `DifferentialGeometry/lift.jl` | 4 | — | Moyenne |
| `Solutions/hvf_solution.jl` | 2 | — | Faible |
| `ext/CTFlowsStaticArrays.jl` | 4 `ntuple` | — | Négligeable |

Les closures **haute priorité** (DifferentialGeometry) ont deux problèmes :
1. La **closure externe** : type anonyme, instabilité si le type capturé est abstrait.
2. Les **closures internes créées à chaque appel** : allocations à chaque évaluation
   numérique — directement sur le chemin chaud des intégrateurs.

### Note sur les closures internes passées aux backends AD

Les closures `y -> H(y, p)` passées à `Differentiation.gradient` sont un pattern
standard en AD Julia — elles "fixent" tous les arguments sauf celui différentié.
La conversion en callable struct est techniquement possible (un functor
`FixSecondArg{H,P}` par exemple) mais certains backends AD (Zygote en particulier)
peuvent avoir des difficultés à différentier à travers un callable struct custom si les
règles ChainRules ne sont pas définies. **Ce point doit être validé backend par backend
avant toute conversion des closures internes.**

La conversion des closures **externes** (celles retournées et wrappées dans les types
`Data.*`) est sans risque et constitue la première cible.
