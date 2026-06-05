# Plan de refactor — éliminer les closures de différentiation

> Compagnon de [`closures_audit.md`](closures_audit.md) (l'inventaire). Ce document
> décrit *comment* supprimer les closures de différentiation, en s'appuyant sur les
> primitives de DifferentiationInterface.jl (DI).

## 1. Motivation (rappel)

Les closures restantes les plus coûteuses sont les closures **imbriquées** de
`DifferentialGeometry` (`ad.jl`, `poisson.jl`, `time_derivative.jl`), recréées **à chaque
appel** sur le chemin chaud des intégrateurs, plus les helpers de réordonnancement
d'arguments répétés dans l'extension `CTFlowsDifferentiationInterface.jl`
(`h_x(x,t,p,v) = h(t,x,p,v)`, …). Bénéfices de la conversion en callable structs :
stabilité de type, absence de world-age, zéro allocation de closure par évaluation,
introspection, et cohérence avec `dev/philosophy/types-traits-interfaces.md`.

## 2. Insight unificateur

Toute closure de différentiation du projet est l'un de deux motifs :

| Motif | Description | Primitive DI | Sites |
|---|---|---|---|
| **Partielle** | « fixer tous les arguments sauf un, dériver le restant » | `DI.gradient` / `DI.derivative` + `DI.Constant` | `poisson.jl`, `time_derivative.jl`, réordonnancement ext DI |
| **Pushforward (JVP)** | « dériver le long d'une direction » `d/ds f(x+s·dx)\|₀` | `DI.pushforward` | `ad.jl` (dérivée/crochet de Lie) |

L'extension exprime déjà le premier motif via `DI.Constant`. L'idée d'un struct paramétré
par `Val{N}` (slot de la variable active) est exactement un **functor de réinsertion
d'argument**, qui généralise les helpers `h_x/h_p/h_v`.

## 3. Primitives DI disponibles (signatures vérifiées)

`x` (point) et le seed (direction/cotangent) sont des arguments **séparés** ; le seed est
un **tuple** ; les constantes passent en **contextes** `DI.Constant(...)` ; la préparation
est optionnelle.

```julia
# Forward mode — JVP. tx tuple de tangentes, renvoie un tuple ty.
pushforward(f, [prep,] backend, x, tx, [contexts...]) -> ty
prepare_pushforward(f, backend, x, tx, [contexts...]) -> prep

# Reverse mode — VJP. ty tuple de cotangentes, renvoie tx.
pullback(f, [prep,] backend, x, ty, [contexts...]) -> tx

# Déjà utilisés : gradient/derivative acceptent aussi des contextes.
gradient(f, [prep,] backend, x, [contexts...])
derivative(f, [prep,] backend, x, [contexts...])
```

- **Partielle** → `gradient`/`derivative` avec `DI.Constant` pour les arguments gelés
  (déjà le mécanisme du cache Hamiltonien).
- **JVP** → `pushforward(f, backend, x, (dx,), Constant…)` ; on déballe le 1-tuple.
- **Pullback** : non requis explicitement — `DI.gradient` d'une fonction scalaire l'utilise
  déjà sous un backend reverse-mode. Mentionné car disponible si un Jacobien-transposé
  apparaît plus tard.

## 4. Surface de contrat à ajouter

### 4.1 `WithActiveArg{F,Slot}` — functor de réinsertion (core, sans backend)

Nouveau fichier `src/Differentiation/arg_placement.jl`. Callable struct pur : capture `f`
et un slot (paramètre de type entier). Méthode `@generated` qui place l'argument actif au
slot `Slot` et remplit les positions restantes avec les constantes (varargs), dans l'ordre.

```julia
struct WithActiveArg{F,Slot}
    f::F
end
WithActiveArg(f, slot::Int) = WithActiveArg{typeof(f),slot}(f)

@generated function (w::WithActiveArg{F,Slot})(active, consts::Vararg{Any,N}) where {F,Slot,N}
    # appelle w.f(arg_1, …, arg_{N+1}) avec `active` au slot Slot,
    # et consts[1..N] aux autres slots dans l'ordre
end
```

Top-level → pas de world-age, pas d'allocation par appel, type-stable. Testable sans DI.

### 4.2 Deux stubs dans `abstract_ad_backend.jl` (implémentés dans l'ext)

```julia
# Dérivée partielle / gradient w.r.t. le slot `Slot`, en gelant `consts`.
function differentiate(backend::AbstractADBackend, f, ::Val{Slot}, active, consts...) where {Slot}
    throw(Exceptions.NotImplemented(...))   # même style que gradient/derivative
end

# Pushforward (JVP) de `f` en `x` dans la direction `dx`, slot actif `Slot`, `consts` gelés.
function pushforward(backend::AbstractADBackend, f, ::Val{Slot}, x, dx, consts...) where {Slot}
    throw(Exceptions.NotImplemented(...))
end
```

Exporter `differentiate`, `pushforward`, `WithActiveArg` depuis `Differentiation.jl`.

### 4.3 Implémentations dans `CTFlowsDifferentiationInterface.jl`

```julia
function Differentiation.differentiate(b::Differentiation.DifferentiationInterface, f, ::Val{Slot}, active, consts...) where {Slot}
    di = Differentiation.ad_backend(b)
    w  = Differentiation.WithActiveArg(f, Val(Slot))
    return _derivator(typeof(active))(w, di, active, map(DI.Constant, consts)...)
end

function Differentiation.pushforward(b::Differentiation.DifferentiationInterface, f, ::Val{Slot}, x, dx, consts...) where {Slot}
    di = Differentiation.ad_backend(b)
    w  = Differentiation.WithActiveArg(f, Val(Slot))
    ty = DI.pushforward(w, di, x, (dx,), map(DI.Constant, consts)...)
    return only(ty)
end
```

`_derivator(typeof(active))` choisit déjà `DI.derivative` (scalaire) ou `DI.gradient`
(tableau) — réutilisé tel quel. Les DG ne voient jamais `WithActiveArg` : elles appellent
seulement les méthodes de contrat.

## 5. Mécanique des slots

Signature uniforme `h(t,x,p,v)` = slots 1-4 :
∂/∂t→`Val(1)`, ∂/∂x→`Val(2)`, ∂/∂p→`Val(3)`, ∂/∂v→`Val(4)`.
Pour `poisson` autonome `H(x,p)` : ∂/∂x→`Val(1)`, ∂/∂p→`Val(2)`.
Les constantes sont passées dans l'ordre des slots restants.

## 6. Refactor site par site

### `ext/CTFlowsDifferentiationInterface.jl`
Remplacer les helpers `h_x/h_p/h_v` par `WithActiveArg(h, Val(2/3/4))` dans `prepare_cache`,
`update!`, et les deux `hamiltonian_gradient`/`variable_gradient`. Le cache
`_DifferentiationInterfaceCache` stocke des functors (champs concrets) au lieu de closures.
Les chemins **non cachés** peuvent déléguer à `differentiate`.

### `src/DifferentialGeometry/poisson.jl`
`_Poisson` (4 closures) → `PoissonBracket{H,G,B,TD,VD}` à 4 call methods (idiome des call
methods de `Data.Hamiltonian`). Les 16 closures internes `y->H(...)` deviennent, p.ex. pour
NonAutonomous/NonFixed :
```julia
gxH = Differentiation.differentiate(b, H, Val(2), x, t, p, v)
gpH = Differentiation.differentiate(b, H, Val(3), p, t, x, v)
# … gxG, gpG via G
return gpH' * gxG - gxH' * gpG
```

### `src/DifferentialGeometry/time_derivative.jl`
`_∂ₜ_hvf/_∂ₜ_vf/_∂ₜ_ham` (12 closures) → functors `TimeDeriv*{X,B,VD}`.
- NonAutonomous : `Differentiation.differentiate(b, X, Val(1), t, consts...)` (active = `t`
  scalaire → `DI.derivative`).
- Autonomous : renvoyer `zero(X(consts...))` **sans AD** (la source n'a pas de slot temps).

### `src/DifferentialGeometry/ad.jl` (dérivée / crochet de Lie)
`_ad` (4 closures externes) + `_ad_result` → functors `Ad{X,F,B,TD,VD}`. **Toutes** les
closures imbriquées (`X̂, f̂, g, h`) disparaissent au profit de `pushforward` :
```julia
X_x  = X(x)                                              # (slot via Val selon TD/VD)
dfoo = Differentiation.pushforward(b, foo, Val(slot), x, X_x, consts...)   # foo'(x)·X_x
# cas scalaire (dérivée de Lie d'une fonction) : retourner dfoo
# cas vectoriel (crochet de Lie de deux champs) :
Y_x  = foo(x)
dX   = Differentiation.pushforward(b, X, Val(slot), x, Y_x, consts...)     # X'(x)·Y_x
return dfoo - dX
```
Le dispatch scalaire/vecteur de `_ad_result` (déjà présent) est conservé : il sépare
« dérivée de Lie scalaire » de « crochet de Lie vectoriel ».

### `src/DifferentialGeometry/lift.jl`
`_Lift` (4) → `LiftedHamiltonian{F,TD,VD}` à 4 call methods. Pur algébrique (`H = p'·f(x)`),
aucune AD, aucune closure interne.

### `src/Solutions/hamiltonian_vector_field_solution.jl`
`state`/`costate` → `StateProjection{S}` / `CostateProjection{S}` (champ `sol`), call method
`(a::StateProjection)(t) = a.sol(t)[1]`.

### Laissés tels quels
`ext/CTFlowsStaticArrays.jl` (lambdas `ntuple`, inlinées via `Val(N)`, zéro allocation) et
`src/MultiPhase/multiphase_flow.jl` (lambdas `map` dans `show`, sans capture — pas des
closures au sens strict).

## 7. Pourquoi c'est sûr

- Les types `Data.{VectorField,Hamiltonian,HamiltonianVectorField}` ont un champ `f::F`
  paramétrique : un functor s'y stocke/appelle exactement comme une closure ; constructeurs
  typés `T(f, TD, VD[, MD])` inchangés.
- Tout backend appelle via les signatures uniformes → agnostique closure/functor ;
  ForwardDiff passe par DI.
- `DI.Constant` et `DI.pushforward` sont des APIs DI stables, déjà la base de l'extension.
- Chaque site est indépendamment testable et protégé par les noms publics existants.
- Bonus : `pushforward`/`differentiate` admettent la préparation DI — `ad`/`poisson`/`∂ₜ`
  pourront bénéficier du caching plus tard, comme les gradients Hamiltoniens.

## 8. Phasage et vérification

0. **Doc** (ce fichier).
1. **Primitives core** : `WithActiveArg` + stubs `differentiate`/`pushforward` + exports ;
   implémentations ext ; tests unitaires vs dérivées analytiques (`H=½‖p‖²`, champs
   linéaires) sur les 4 combinaisons TD×VD.
2. **Sans risque** : `lift.jl`, accesseurs `Solutions`.
3. **Réordonnancement ext DI** : `h_x/h_p/h_v` → `WithActiveArg` ; cache stocke les functors.
4. **Partielles** : `poisson.jl`, `time_derivative.jl`.
5. **JVP** : `ad.jl` (cas le plus délicat — dispatch scalaire/vecteur de `_ad_result`).

À chaque phase : tests via le MCP `ct-dev-mcp` (`get_test_command` → run avec `tee` →
`generate_report`), suite ciblée puis suite complète. `@inferred` sur les nouveaux functors,
`@allocated == 0` (hors résultat) sur un appel partiel/JVP représentatif. Vérifier que le
caching (`prepare_cache=true`) marche toujours et que Poisson / Lie / ∂ₜ donnent des valeurs
identiques à l'avant-refactor. Docstrings en dernier. **Aucun commit sans accord explicite.**
```
A. WithActiveArg + stubs  →  B. lift + solutions  →  C. ext DI reorder
                                                            ↓
                                  E. ad.jl (JVP)  ←  D. poisson + time_derivative
```
