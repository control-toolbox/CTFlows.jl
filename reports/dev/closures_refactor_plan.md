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
`_Lift` (4) → `LiftedHamiltonianFunction{F,TD,VD}` à 4 call methods. Pur algébrique (`H = p'·f(x)`),
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

---

# Annexe — Code détaillé par site

> Code de référence pour l'agent qui implémente. Les numéros de ligne ci-dessous
> correspondent à l'état au moment de la rédaction ; vérifier avant d'éditer.
> Tout est **qualifié** (`Module.symbol`) conformément à `CLAUDE.md`.

## A.1 `WithActiveArg` — `src/Differentiation/arg_placement.jl` (nouveau)

```julia
# =============================================================================
# WithActiveArg — functor de réinsertion d'argument (pur, sans backend)
# =============================================================================

"""
$(TYPEDEF)

Functor qui appelle `f` en plaçant l'argument *actif* au slot `Slot` et en remplissant
les positions restantes avec les constantes passées, dans l'ordre.

Remplace les closures de réordonnancement du type `h_x(x,t,p,v) = h(t,x,p,v)`.

Appelé comme `w(active, c₁, …, c_N)` ⇒ `f(arg₁, …, arg_{N+1})` avec `active` au slot
`Slot`. `Slot` est un paramètre de type (entier) ⇒ réordonnancement résolu à la
compilation, sans allocation ni world-age.
"""
struct WithActiveArg{F,Slot}
    f::F
    WithActiveArg{F,Slot}(f::F) where {F,Slot} = new{F,Slot}(f)
end

WithActiveArg(f, ::Val{Slot}) where {Slot} = WithActiveArg{typeof(f),Slot}(f)
WithActiveArg(f, slot::Integer) = WithActiveArg(f, Val(Int(slot)))

@generated function (w::WithActiveArg{F,Slot})(active, consts::Vararg{Any,N}) where {F,Slot,N}
    total = N + 1
    (1 ≤ Slot ≤ total) || return :(throw(ArgumentError(
        "WithActiveArg: slot $($Slot) out of range for $($total) argument(s)")))
    args = Vector{Any}(undef, total)
    args[Slot] = :active
    ci = 1
    for pos in 1:total
        pos == Slot && continue
        args[pos] = :(consts[$ci]); ci += 1
    end
    return :(w.f($(args...)))
end
```

Inclure dans `Differentiation.jl` **avant** `abstract_ad_backend.jl` (le contrat ne
l'utilise pas directement, mais l'export est groupé). Ajouter `include("arg_placement.jl")`
et `export WithActiveArg`.

⚠️ `@generated` : le corps ne doit lire QUE les paramètres de type (`Slot`, `N`), jamais
les valeurs runtime. C'est respecté ici.

## A.2 Stubs de contrat — `src/Differentiation/abstract_ad_backend.jl`

Ajouter, dans le style des stubs existants (même `Exceptions.NotImplemented`) :

```julia
function differentiate(backend::AbstractADBackend, f, ::Val{Slot}, active, consts...) where {Slot}
    throw(Exceptions.NotImplemented(
        "differentiate not implemented for $(typeof(backend))";
        required_method = "differentiate(backend::$(typeof(backend)), f, ::Val{Slot}, active, consts...)",
        suggestion = "Load CTFlowsDifferentiationInterface (load DifferentiationInterface)",
        context = "AD backend contract",
    ))
end

function pushforward(backend::AbstractADBackend, f, ::Val{Slot}, x, dx, consts...) where {Slot}
    throw(Exceptions.NotImplemented(
        "pushforward not implemented for $(typeof(backend))";
        required_method = "pushforward(backend::$(typeof(backend)), f, ::Val{Slot}, x, dx, consts...)",
        suggestion = "Load CTFlowsDifferentiationInterface (load DifferentiationInterface)",
        context = "AD backend contract",
    ))
end
```

Dans `Differentiation.jl` : `export differentiate`, `export pushforward`.

## A.3 Implémentations — `ext/CTFlowsDifferentiationInterface.jl`

```julia
function Differentiation.differentiate(
    backend::Differentiation.DifferentiationInterface, f, ::Val{Slot}, active, consts...
) where {Slot}
    di = Differentiation.ad_backend(backend)
    w  = Differentiation.WithActiveArg(f, Val(Slot))
    return _derivator(typeof(active))(w, di, active, map(DI.Constant, consts)...)
end

function Differentiation.pushforward(
    backend::Differentiation.DifferentiationInterface, f, ::Val{Slot}, x, dx, consts...
) where {Slot}
    di = Differentiation.ad_backend(backend)
    w  = Differentiation.WithActiveArg(f, Val(Slot))
    ty = DI.pushforward(w, di, x, (dx,), map(DI.Constant, consts)...)
    return only(ty)
end
```

Réordonnancement interne du cache : remplacer les trois closures locales

```julia
h_x(x, t, p, v) = h(t, x, p, v)   # → Differentiation.WithActiveArg(h, Val(2))
h_p(p, t, x, v) = h(t, x, p, v)   # → Differentiation.WithActiveArg(h, Val(3))
h_v(v, t, x, p) = h(t, x, p, v)   # → Differentiation.WithActiveArg(h, Val(4))
```

dans `prepare_cache` (≈L137) et `update!` (≈L161). Les champs `cache.h_x/h_p/h_v`
stockent désormais des `WithActiveArg` (types concrets ⇒ cache plus inspectable). Les
appels `_derivator(...)(cache.h_x, cache.p_x, di, x, DI.Constant(t), …)` restent identiques.

Chemins **non cachés** (`::Nothing`) de `hamiltonian_gradient`/`variable_gradient` : on
peut soit créer les `WithActiveArg` localement, soit **déléguer** :

```julia
function Differentiation.hamiltonian_gradient(backend::Differentiation.DifferentiationInterface,
    h::Data.AbstractHamiltonian, t, x, p, v, ::Nothing)
    gx = Differentiation.differentiate(backend, h, Val(2), x, t, p, v)
    gp = Differentiation.differentiate(backend, h, Val(3), p, t, x, v)
    return (gx, gp)
end
# variable_gradient(::Nothing) : Differentiation.differentiate(backend, h, Val(4), v, t, x, p)
```

## A.4 `src/DifferentialGeometry/lift.jl` (sans AD, le plus simple)

```julia
struct LiftedHamiltonianFunction{TF,TD,VD} <: Function   # <: Function : voir difficulté #7
    f::TF
end
LiftedHamiltonianFunction(f, ::Type{TD}, ::Type{VD}) where {TD,VD} =
    LiftedHamiltonianFunction{typeof(f),TD,VD}(f)

(L::LiftedHamiltonianFunction{TF,Traits.Autonomous,   Traits.Fixed})(x, p)       where {TF} = p' * L.f(x)
(L::LiftedHamiltonianFunction{TF,Traits.Autonomous,   Traits.NonFixed})(x, p, v) where {TF} = p' * L.f(x, v)
(L::LiftedHamiltonianFunction{TF,Traits.NonAutonomous,Traits.Fixed})(t, x, p)    where {TF} = p' * L.f(t, x)
(L::LiftedHamiltonianFunction{TF,Traits.NonAutonomous,Traits.NonFixed})(t, x, p, v) where {TF} = p' * L.f(t, x, v)

# remplace les 4 _Lift :
_Lift(f, ::Type{TD}, ::Type{VD}) where {TD,VD} = LiftedHamiltonianFunction(f, TD, VD)
```

`Lift(X::Data.AbstractVectorField)` continue d'appeler `Data.Hamiltonian(_Lift(...), TD, VD)` :
le functor se stocke dans `Hamiltonian.f` sans changement.

## A.5 `src/Solutions/hamiltonian_vector_field_solution.jl`

```julia
struct StateProjection{S}   <: Function; sol::S; end
struct CostateProjection{S} <: Function; sol::S; end
(a::StateProjection)(t)   = a.sol(t)[1]
(a::CostateProjection)(t) = a.sol(t)[2]

state(sol::HamiltonianVectorFieldSolution)   = StateProjection(sol)
costate(sol::HamiltonianVectorFieldSolution) = CostateProjection(sol)
```

## A.6 `src/DifferentialGeometry/poisson.jl`

```julia
struct PoissonBracket{TH,TG,TB,TD,VD} <: Function   # <: Function : voir difficulté #7
    H::TH
    G::TG
    backend::TB
end
PoissonBracket(H, G, backend, ::Type{TD}, ::Type{VD}) where {TD,VD} =
    PoissonBracket{typeof(H),typeof(G),typeof(backend),TD,VD}(H, G, backend)

# slots : H(x,p) → x@1,p@2 ;  H(t,x,p) → x@2,p@3 ;  H(x,p,v) → x@1,p@2 ;  H(t,x,p,v) → x@2,p@3
function (P::PoissonBracket{TH,TG,TB,Traits.Autonomous,Traits.Fixed})(x, p) where {TH,TG,TB}
    b = P.backend
    gxH = Differentiation.differentiate(b, P.H, Val(1), x, p)
    gpH = Differentiation.differentiate(b, P.H, Val(2), p, x)
    gxG = Differentiation.differentiate(b, P.G, Val(1), x, p)
    gpG = Differentiation.differentiate(b, P.G, Val(2), p, x)
    return gpH' * gxG - gxH' * gpG
end
function (P::PoissonBracket{TH,TG,TB,Traits.NonAutonomous,Traits.Fixed})(t, x, p) where {TH,TG,TB}
    b = P.backend
    gxH = Differentiation.differentiate(b, P.H, Val(2), x, t, p)
    gpH = Differentiation.differentiate(b, P.H, Val(3), p, t, x)
    gxG = Differentiation.differentiate(b, P.G, Val(2), x, t, p)
    gpG = Differentiation.differentiate(b, P.G, Val(3), p, t, x)
    return gpH' * gxG - gxH' * gpG
end
function (P::PoissonBracket{TH,TG,TB,Traits.Autonomous,Traits.NonFixed})(x, p, v) where {TH,TG,TB}
    b = P.backend
    gxH = Differentiation.differentiate(b, P.H, Val(1), x, p, v)
    gpH = Differentiation.differentiate(b, P.H, Val(2), p, x, v)
    gxG = Differentiation.differentiate(b, P.G, Val(1), x, p, v)
    gpG = Differentiation.differentiate(b, P.G, Val(2), p, x, v)
    return gpH' * gxG - gxH' * gpG
end
function (P::PoissonBracket{TH,TG,TB,Traits.NonAutonomous,Traits.NonFixed})(t, x, p, v) where {TH,TG,TB}
    b = P.backend
    gxH = Differentiation.differentiate(b, P.H, Val(2), x, t, p, v)
    gpH = Differentiation.differentiate(b, P.H, Val(3), p, t, x, v)
    gxG = Differentiation.differentiate(b, P.G, Val(2), x, t, p, v)
    gpG = Differentiation.differentiate(b, P.G, Val(3), p, t, x, v)
    return gpH' * gxG - gxH' * gpG
end

_Poisson(H, G, backend, ::Type{TD}, ::Type{VD}) where {TD,VD} =
    PoissonBracket(H, G, backend, TD, VD)
```

## A.7 `src/DifferentialGeometry/time_derivative.jl`

Helper de zéro structurel (à mettre près du haut du fichier) :

```julia
_zero_like(v::Number)        = zero(v)
_zero_like(v::AbstractArray) = zero(v)
_zero_like(v::Tuple)         = map(_zero_like, v)   # au cas où un HVF renverrait (ẋ, ṗ)
```

Functor générique pour `∂ₜ(f::Function)` (f a toujours le temps en 1ʳᵉ position) :

```julia
struct TimeDerivFunction{TF,TB} <: Function; f::TF; backend::TB; end
(d::TimeDerivFunction)(t, args...) = Differentiation.differentiate(d.backend, d.f, Val(1), t, args...)

# remplace le retour de la closure :
function ∂ₜ(f::Function; ad_backend = __dg_ad_backend())
    backend = _resolve_backend(ad_backend)
    return TimeDerivFunction(f, backend)
end
```

Functors pour HVF / VF / Ham (param. par TD source `STD` + VD ; TD résultat = NonAutonomous).
Exemple HVF (mêmes patrons pour VF avec `(t,x)`/`(t,x,v)` et Ham avec `(t,x,p)`/`(t,x,p,v)`) :

```julia
struct TimeDerivHVF{TX,TB,STD,VD} <: Function; X::TX; backend::TB; end   # <: Function : voir #7
TimeDerivHVF(X, backend, ::Type{STD}, ::Type{VD}) where {STD,VD} =
    TimeDerivHVF{typeof(X),typeof(backend),STD,VD}(X, backend)

# source NonAutonomous → vraie dérivée temporelle (slot 1 = temps)
(d::TimeDerivHVF{TX,TB,Traits.NonAutonomous,Traits.Fixed})(t, x, p) where {TX,TB} =
    Differentiation.differentiate(d.backend, d.X, Val(1), t, x, p)
(d::TimeDerivHVF{TX,TB,Traits.NonAutonomous,Traits.NonFixed})(t, x, p, v) where {TX,TB} =
    Differentiation.differentiate(d.backend, d.X, Val(1), t, x, p, v)
# source Autonomous → zéro structurel (la source n'a pas de slot temps)
(d::TimeDerivHVF{TX,TB,Traits.Autonomous,Traits.Fixed})(t, x, p) where {TX,TB} =
    _zero_like(d.X(x, p))
(d::TimeDerivHVF{TX,TB,Traits.Autonomous,Traits.NonFixed})(t, x, p, v) where {TX,TB} =
    _zero_like(d.X(x, p, v))

_∂ₜ_hvf(X, b, ::Type{TD}, ::Type{VD}) where {TD,VD} = TimeDerivHVF(X, b, TD, VD)
```

Le wrapping `Data.HamiltonianVectorField(d, Traits.NonAutonomous, VD, Traits.OutOfPlace)`
est inchangé.

## A.8 `src/DifferentialGeometry/ad.jl` (JVP — le plus délicat)

```julia
struct Ad{TX,TF,TB,TD,VD} <: Function; X::TX; foo::TF; backend::TB; end   # <: Function : voir #7
Ad(X, foo, backend, ::Type{TD}, ::Type{VD}) where {TD,VD} =
    Ad{typeof(X),typeof(foo),typeof(backend),TD,VD}(X, foo, backend)

# x est l'état ; slot(x) = 1 (Autonomous) ou 2 (NonAutonomous) ; consts = t et/ou v
(a::Ad{TX,TF,TB,Traits.Autonomous,Traits.Fixed})(x) where {TX,TF,TB} =
    _ad_bracket(Differentiation.pushforward(a.backend, a.foo, Val(1), x, a.X(x)), a, x)
(a::Ad{TX,TF,TB,Traits.NonAutonomous,Traits.Fixed})(t, x) where {TX,TF,TB} =
    _ad_bracket(Differentiation.pushforward(a.backend, a.foo, Val(2), x, a.X(t, x), t), a, t, x)
(a::Ad{TX,TF,TB,Traits.Autonomous,Traits.NonFixed})(x, v) where {TX,TF,TB} =
    _ad_bracket(Differentiation.pushforward(a.backend, a.foo, Val(1), x, a.X(x, v), v), a, x, v)
(a::Ad{TX,TF,TB,Traits.NonAutonomous,Traits.NonFixed})(t, x, v) where {TX,TF,TB} =
    _ad_bracket(Differentiation.pushforward(a.backend, a.foo, Val(2), x, a.X(t, x, v), t, v), a, t, x, v)

# dérivée de Lie (foo scalaire) : dfoo = ∇foo·X(x), déjà calculé
_ad_bracket(dfoo::Number, ::Ad, args...) = dfoo

# crochet de Lie (foo vectoriel) : dfoo - J_X(x)·foo(x)
function _ad_bracket(dfoo::AbstractVector, a::Ad{TX,TF,TB,Traits.Autonomous,Traits.Fixed}, x) where {TX,TF,TB}
    Y_x = a.foo(x)
    return dfoo - Differentiation.pushforward(a.backend, a.X, Val(1), x, Y_x)
end
function _ad_bracket(dfoo::AbstractVector, a::Ad{TX,TF,TB,Traits.NonAutonomous,Traits.Fixed}, t, x) where {TX,TF,TB}
    Y_x = a.foo(t, x)
    return dfoo - Differentiation.pushforward(a.backend, a.X, Val(2), x, Y_x, t)
end
function _ad_bracket(dfoo::AbstractVector, a::Ad{TX,TF,TB,Traits.Autonomous,Traits.NonFixed}, x, v) where {TX,TF,TB}
    Y_x = a.foo(x, v)
    return dfoo - Differentiation.pushforward(a.backend, a.X, Val(1), x, Y_x, v)
end
function _ad_bracket(dfoo::AbstractVector, a::Ad{TX,TF,TB,Traits.NonAutonomous,Traits.NonFixed}, t, x, v) where {TX,TF,TB}
    Y_x = a.foo(t, x, v)
    return dfoo - Differentiation.pushforward(a.backend, a.X, Val(2), x, Y_x, t, v)
end

_ad(X, foo, backend, ::Type{TD}, ::Type{VD}) where {TD,VD} = Ad(X, foo, backend, TD, VD)
```

Le dispatch scalaire/vecteur passe de `_ad_result(::Number/::AbstractVector)` à
`_ad_bracket(::Number/::AbstractVector, ...)` — même logique, mais le 2ᵉ pushforward
(`J_X·foo`) reçoit X/backend/slot via le functor `a` au lieu des closures `X̂/h`.

---

# Difficultés anticipées

1. **Cas autonome de `∂ₜ` (structure du zéro).** `∂ₜ` est OutOfPlace-only ; un HVF renvoie
   `H.f(x,p)`, en pratique un `AbstractArray`, mais une fonction interne *pourrait* renvoyer
   un tuple `(ẋ,ṗ)`. D'où `_zero_like` avec une méthode `Tuple`. **Vérifier** sur les tests
   `∂ₜ` HVF que la structure renvoyée correspond à l'avant-refactor (comparer `typeof`).

2. **`pushforward` + `DI.Constant` selon le backend.** Le caching Hamiltonien utilise déjà
   `DI.Constant` avec `AutoForwardDiff` (défaut), donc le motif est éprouvé. **Valider**
   néanmoins `DI.pushforward(..., DI.Constant(...))` avec le backend par défaut avant de
   généraliser (un test unitaire de `pushforward` avec constantes suffit).

3. **`only(ty)`.** `DI.pushforward` renvoie un *tuple* de tangentes (une par seed). On passe
   un seed unique `(dx,)` ⇒ `only(ty)` extrait. Ne pas oublier le déballage, sinon le
   résultat est un tuple à 1 élément (et `dfoo - dX` casserait).

4. **Type seed = type `x`.** Dans `pushforward(b, f, Val(s), x, dx, …)`, `dx` doit avoir la
   même structure que `x` (le code formait déjà `x + s*dx`). Pour un état `SVector`,
   s'assurer que `X(x)` renvoie un `SVector` compatible. Pas une régression, mais à surveiller.

5. **Dispatch scalaire/vecteur préservé.** `DI.pushforward` d'une fonction scalaire renvoie
   un scalaire (`<:Number`), d'une fonction vectorielle un vecteur. La sélection
   `_ad_bracket(::Number)` vs `(::AbstractVector)` reste donc valide. **Tester** les deux
   (dérivée de Lie d'une fonction *et* crochet de deux champs).

6. **`@Lie` / entrée typée `ad(X,foo,TD,VD)`.** La macro `@Lie` consomme le résultat de `ad`.
   Comme `Ad <: Function` (cf. #7), toute annotation `::Function` sur le résultat reste
   satisfaite — pas d'élargissement nécessaire. Vérifier tout de même que `@Lie` n'inspecte
   pas la *structure* du résultat (champs, `nameof`) en supposant une closure anonyme.

7. **Contrainte `F<:Function` des structs `Data.*` (vérifié).** Les trois structs imposent
   `F<:Function` et leurs call methods sont annotées `{<:Function, …}` :
   - `src/Data/hamiltonian.jl:61` — `Hamiltonian{F<:Function, TD, VD}`
   - `src/Data/vector_field.jl:41` — `VectorField{F<:Function, …}`
   - `src/Data/hamiltonian_vector_field.jl:43` — `HamiltonianVectorField{F<:Function, …}`

   Un callable struct ordinaire n'est **pas** `<:Function` ⇒ échec à la construction
   **et** non-match des call methods. **Résolution** (déjà appliquée dans les snippets
   ci-dessus) : déclarer les functors stockés dans `Data.*` comme `<: Function`
   (`struct PoissonBracket{…} <: Function`, idem `LiftedHamiltonianFunction`, `TimeDeriv*`). C'est
   légal en Julia et **reproduit exactement** la relation de type des closures remplacées
   (toute closure est `<:Function`) — donc aucune autre signature `::Function` ailleurs
   n'est cassée. **Ne PAS** relâcher la contrainte des structs `Data.*` (plus invasif et
   contraire à l'intention). `WithActiveArg` n'est stocké nulle part de contraint et n'a pas
   besoin d'être `<:Function` (passé tel quel à DI).

8. **Closures internes `gradient`/`derivative` désormais inutilisées dans `src/`.** Les
   stubs core `gradient(backend,f,x)` / `derivative(backend,g,t)` restent (API publique,
   tests). Ne pas les supprimer sans un `grep` confirmant zéro usage externe.

9. **Conflit de nom `pushforward`.** `DI` exporte `pushforward` ; on définit
   `Differentiation.pushforward`. Toujours qualifier (`DI.pushforward` vs
   `Differentiation.pushforward`) dans l'extension — ne jamais l'utiliser nu.

10. **World-age / `@generated`.** `WithActiveArg` est top-level ⇒ aucun souci. Mais éviter
    de redéfinir des méthodes `WithActiveArg` dans des fonctions de test (règle CLAUDE.md
    « fake types at top-level »).

11. **`variable_costate` (HVF NonFixed).** Les appels `a.X(t,x,v)` dans `Ad`/`TimeDeriv`
    utilisent la signature naturelle **sans** `variable_costate` — comportement identique à
    l'existant (les closures n'utilisaient pas ce kwarg). Ne pas l'introduire.

---

# Squelette de tests (Phase 1)

```julia
# test/suite/differentiation/test_arg_placement.jl  (fake types AU TOP-LEVEL)
@testset "WithActiveArg" begin
    f(a,b,c) = (a, b, c)
    @test Differentiation.WithActiveArg(f, Val(2))(10, 1, 3) == (1, 10, 3)  # a@2
    @test Differentiation.WithActiveArg(f, Val(1))(10, 2, 3) == (10, 2, 3)
    @test (@inferred Differentiation.WithActiveArg(f, Val(3))(9, 1, 2)) == (1, 2, 9)
end

@testset "differentiate / pushforward (AutoForwardDiff)" begin
    b = CTFlows.DifferentialGeometry._resolve_backend(Common.NotProvided())
    H(x, p) = 0.5 * sum(p.^2) + sum(x.^2)        # ∂x = 2x, ∂p = p
    x = [1.0, 2.0]; p = [3.0, 4.0]
    @test Differentiation.differentiate(b, H, Val(1), x, p) ≈ 2x
    @test Differentiation.differentiate(b, H, Val(2), p, x) ≈ p
    # JVP : champ linéaire X(x)=A*x ⇒ pushforward(X, x, d) = A*d
    A = [0.0 1.0; -1.0 0.0]; X(x) = A*x; d = [5.0, 6.0]
    @test Differentiation.pushforward(b, X, Val(1), x, d) ≈ A*d
end
```

Valeurs de référence à comparer aussi : `Poisson`, `ad` (Lie scalaire + crochet),
`∂ₜ` sur les 4 combinaisons TD×VD, avant/après refactor (mêmes nombres).
