# Synthèse — Techniques de remplacement des closures par des callable structs (Julia)

> Document de référence générique, illustré par le refactor de CTFlows.jl.
> Applicable à tout package Julia qui construit des fonctions à partir d'autres fonctions.

---

## Pourquoi remplacer les closures ?

| Problème | Cause | Conséquence |
|---|---|---|
| **Type opaque** | `typeof(rhs)` = `var"#42#43"` | Pas de dispatch, pas d'introspection |
| **World-age** | Closure définie dans une fonction locale | Erreur si une méthode est ajoutée après |
| **Instabilité de type** | Variable capturée de type abstrait | Pénalité d'inférence dans les chemins chauds |
| **Allocations sur le chemin chaud** | Closures imbriquées recréées à chaque appel | Pression GC dans les intégrateurs |
| **Précompilation fragile** | Captures non-`isbits` | Invalidations, temps de chargement |
| **AD difficile** | Types anonymes | Certains backends ne propagent pas le gradient |

Un **callable struct** (functor) résout tous ces problèmes : type nommé, paramétré,
inspectable, défini au top-level, compatible dispatch et AD.

---

## Vue d'ensemble des patterns

| # | Pattern | Cas d'usage | Complexité |
|---|---|---|---|
| 1 | [Functor simple](#1-functor-simple) | Closure capturant un objet, signature fixe | ★☆☆ |
| 2 | [Functor paramétré par traits](#2-functor-paramétré-par-traits) | N variantes selon des types/traits | ★★☆ |
| 3 | [Hiérarchie abstraite](#3-hiérarchie-abstraite-de-callable-structs) | Dispatch sur la nature du callable | ★★☆ |
| 4 | [WithActiveArg — slot AD](#4-withactivearg--réordonnancement-dargument-pour-lad) | Fermer tous les args sauf un (AD) | ★★☆ |
| 5 | [Pushforward — JVP sans closure](#5-pushforward--jvp-sans-closure-imbriquée) | `d/ds f(x + s·dx)\|₀` (Lie, JAC) | ★★★ |
| 6 | [Buffer pré-alloué](#6-buffer-pré-alloué-dans-le-functor) | Wrapper OoP→IP évitant `similar` | ★★☆ |
| 7 | [Construction lazy → constructeur de struct](#7-construction-lazy--factory-en-constructeur-de-struct) | `build_rhs` capturant des dépendances | ★★☆ |
| 8 | [Contrainte `<: Function`](#8-contrainte--function-dans-les-types-conteneurs) | Conteneur imposant `F<:Function` | ★★☆ |

---

## 1. Functor simple

### Cas typique

Une fonction fabrique retourne une closure qui capture un seul objet.

```julia
# AVANT — closure
function build_rhs(vf)
    return function (du, u, p, t)
        du .= vf(t, u, p)
    end
end
rhs = build_rhs(my_vf)   # typeof(rhs) = var"#2#3"
```

### Solution : callable struct

```julia
# APRÈS — callable struct
struct MyRHS{F}
    vf::F
end

(f::MyRHS)(du, u, p, t) = (du .= f.vf(t, u, p); nothing)

rhs = MyRHS(my_vf)   # typeof(rhs) = MyRHS{typeof(my_vf)}
```

### Règle

> **Toute closure `x -> f(x, captured)` avec une seule variable capturée devient un struct
> à un champ.** La signature de l'ancienne closure devient la call method.

---

## 2. Functor paramétré par traits

### Cas typique

Plusieurs variantes d'une même closure selon des combinaisons de types/traits.
Pattern fréquent dans les codes à dispatch multiple sur des propriétés (temporelle, spatiale…).

```julia
# AVANT — 4 closures, une par combinaison (TD × VD)
_build(f, ::Type{Autonomous},    ::Type{Fixed})    = (x, p)       -> p' * f(x)
_build(f, ::Type{Autonomous},    ::Type{NonFixed}) = (x, p, v)    -> p' * f(x, v)
_build(f, ::Type{NonAutonomous}, ::Type{Fixed})    = (t, x, p)    -> p' * f(t, x)
_build(f, ::Type{NonAutonomous}, ::Type{NonFixed}) = (t, x, p, v) -> p' * f(t, x, v)
```

### Solution : un struct, plusieurs call methods

```julia
# APRÈS — un seul struct, paramétré, 4 call methods
struct LiftedFn{TF, TD, VD}
    f::TF
end
LiftedFn(f, ::Type{TD}, ::Type{VD}) where {TD,VD} =
    LiftedFn{typeof(f), TD, VD}(f)

(L::LiftedFn{TF, Autonomous,    Fixed})(x, p)       where {TF} = p' * L.f(x)
(L::LiftedFn{TF, Autonomous,    NonFixed})(x, p, v) where {TF} = p' * L.f(x, v)
(L::LiftedFn{TF, NonAutonomous, Fixed})(t, x, p)    where {TF} = p' * L.f(t, x)
(L::LiftedFn{TF, NonAutonomous, NonFixed})(t, x, p, v) where {TF} = p' * L.f(t, x, v)

# La factory devient triviale :
_build(f, ::Type{TD}, ::Type{VD}) where {TD,VD} = LiftedFn(f, TD, VD)
```

### Avantages spécifiques

- Les paramètres de type `TD`, `VD` encodent statiquement la variante → call method
  sélectionnée à la compilation, pas à l'exécution.
- Un seul type à documenter, tester, sérialiser.
- `typeof(L)` = `LiftedFn{MyFunc, Autonomous, Fixed}` — complètement lisible.

### Règle

> **Quand N closures se distinguent uniquement par des types en argument, les fondre en
> un seul struct paramétré par ces types, avec N call methods.**

---

## 3. Hiérarchie abstraite de callable structs

### Quand l'utiliser

Plusieurs functors partagent une interface commune (même signature d'appel) mais ont
des comportements différents (ex. in-place vs out-of-place). On veut pouvoir dispatcher
sur la famille sans énumérer les types concrets.

### Structure

```julia
# Types abstraits = "interfaces"
abstract type AbstractRHS end
abstract type AbstractIPRHS  <: AbstractRHS end   # in-place  : (du, u, p, t) -> nothing
abstract type AbstractOoPRHS <: AbstractRHS end   # out-of-place : (u, p, t) -> du

# Functors concrets
struct IPOoPRHS{F, TD, VD} <: AbstractIPRHS
    vf::VectorField{F, TD, VD, OutOfPlace}
end
(f::IPOoPRHS)(du, u, p, t) = (du .= f.vf(t, u, p); nothing)

struct OoPIpRHS{F, TD, VD} <: AbstractOoPRHS
    vf::VectorField{F, TD, VD, InPlace}
end
(f::OoPIpRHS)(u, p, t) = (dx = similar(u); f.vf(dx, t, u, p); dx)

# Dispatch générique
select_rhs(vf::VectorField{F,TD,VD,OutOfPlace}) where {F,TD,VD} = IPOoPRHS(vf)
select_rhs(vf::VectorField{F,TD,VD,InPlace})    where {F,TD,VD} = IPIpRHS(vf)
```

### Bénéfice pour les conteneurs

Le struct système peut maintenant être paramétré sur l'interface abstraite :

```julia
# Avant : paramètre opaque
struct MySystem{F, TD, VD, RHS <: Function}
    rhs::RHS
end

# Après : paramètre inspecable
struct MySystem{F, TD, VD, RHS <: AbstractIPRHS}
    rhs::RHS
end
```

Et les tests deviennent génériques : `@test rhs isa AbstractIPRHS`.

---

## 4. `WithActiveArg` — réordonnancement d'argument pour l'AD

### Cas typique

Les backends AD différentient une fonction **d'une seule variable** ; pour dériver
par rapport à un argument particulier d'une fonction multi-arguments, on fabrique
une closure qui fixe tous les autres.

```julia
# AVANT — closures créées à chaque appel (allocation sur le chemin chaud)
function grad_hamiltonian(backend, H, t, x, p)
    gx = gradient(backend, y -> H(t, y, p), x)   # closure sur (t, p)
    gp = gradient(backend, q -> H(t, x, q), p)   # closure sur (t, x)
    return gx, gp
end
```

### Solution : functor de réinsertion d'argument

```julia
# Functor pur (sans backend), défini AU TOP-LEVEL du module
struct WithActiveArg{F, Slot}
    f::F
end
WithActiveArg(f, ::Val{S}) where {S} = WithActiveArg{typeof(f), S}(f)
WithActiveArg(f, s::Integer) = WithActiveArg(f, Val(Int(s)))

# La méthode @generated place `active` au slot Slot, `consts` aux positions restantes
@generated function (w::WithActiveArg{F,Slot})(active, consts::Vararg{Any,N}) where {F,Slot,N}
    total = N + 1
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

### Usage

```julia
# Créer une fois (éventuellement stocker dans un cache)
H_x = WithActiveArg(H, Val(2))   # H(t, x, p) → différentier par rapport à x (slot 2)
H_p = WithActiveArg(H, Val(3))   # H(t, x, p) → différentier par rapport à p (slot 3)

# Appel : active en premier, constantes dans l'ordre des slots restants
# H_x(x, t, p) → H(t, x, p) avec x actif
gx = gradient(backend, H_x, x, t, p)   # plus de closure à créer
gp = gradient(backend, H_p, p, t, x)
```

### Propriétés clés

- **`@generated`** : le réordonnancement est résolu à la compilation via `Slot` (paramètre
  de type entier). Zéro coût runtime, pas d'allocation.
- **Top-level** : pas de world-age, pas de conflit avec les définitions ultérieures.
- **Générique** : `Slot` peut être n'importe quel entier → remplace toute famille
  `h_x/h_p/h_v/h_t` par `WithActiveArg(h, Val(1/2/3/4))`.

### Règle

> **Toute closure `y -> f(const1, y, const2, ...)` passée à un backend AD devient
> `WithActiveArg(f, Val(slot_de_y))`.** La closure n'est plus créée à chaque appel.

---

## 5. Pushforward — JVP sans closure imbriquée

### Cas typique

Le calcul d'une dérivée directionnelle (`d/ds f(x + s·dx)|₀`) génère une closure
imbriquée recréée à chaque appel, sur le chemin chaud des intégrateurs.

```julia
# AVANT — crochet de Lie, 3 closures imbriquées créées À CHAQUE APPEL
function lie_bracket(X, Y, backend)
    return function (x)
        X_x = X(x)
        Ŷ   = x_ -> Y(x_)                  # closure 1
        X̂   = x_ -> X(x_)                  # closure 2
        g(s) = Ŷ(x + s * X_x)              # closure 3
        dY  = derivative(backend, g, 0.0)
        h(s) = X̂(x + s * Y(x))
        dX  = derivative(backend, h, 0.0)
        return dY - dX
    end
end
```

### Solution : utiliser `pushforward` (JVP)

`pushforward(f, backend, x, (dx,))` calcule `J_f(x) · dx` sans closure.

```julia
# APRÈS — functor, appels pushforward explicites, zéro closure créée
struct LieBracket{TX, TY, TB, TD, VD}
    X::TX
    Y::TY
    backend::TB
end

function (a::LieBracket{TX, TY, TB, Autonomous, Fixed})(x) where {TX, TY, TB}
    X_x = a.X(x)
    dY  = pushforward(a.backend, a.Y, Val(1), x, X_x)   # J_Y(x)·X(x)
    Y_x = a.Y(x)
    dX  = pushforward(a.backend, a.X, Val(1), x, Y_x)   # J_X(x)·Y(x)
    return dY - dX
end
```

### Correspondance avec les primitives DI

| Motif closure | Primitive de remplacement | Signature |
|---|---|---|
| `s -> f(x + s*dx)` (scalaire → scalaire) | `DI.derivative` + `WithActiveArg` | `differentiate(b, f, Val(s), t, consts...)` |
| `y -> f(y, const...)` (vecteur → scalaire) | `DI.gradient` + `WithActiveArg` | `differentiate(b, f, Val(s), x, consts...)` |
| `x_ -> X(x_)` passé à une dérivée directionnelle | `DI.pushforward` | `pushforward(b, X, Val(s), x, dx, consts...)` |

### Contrat minimal à exposer

```julia
# Stubs dans le module core (throwent NotImplemented)
function differentiate(backend, f, ::Val{Slot}, active, consts...) where {Slot} end
function pushforward(backend, f, ::Val{Slot}, x, dx, consts...) where {Slot} end

# Implémentation dans l'extension AD (ForwardDiff, DifferentiationInterface…)
function differentiate(backend::MyADBackend, f, ::Val{Slot}, active, consts...) where {Slot}
    w = WithActiveArg(f, Val(Slot))
    return my_gradient_or_derivative(w, backend, active, consts...)
end
function pushforward(backend::MyADBackend, f, ::Val{Slot}, x, dx, consts...) where {Slot}
    w  = WithActiveArg(f, Val(Slot))
    ty = DI.pushforward(w, di_backend(backend), x, (dx,), map(DI.Constant, consts)...)
    return only(ty)
end
```

### Points de vigilance

- **`only(ty)`** : `DI.pushforward` renvoie un tuple de tangentes, un par seed. Avec
  un seed unique `(dx,)`, `only(ty)` extrait le résultat scalaire ou vectoriel.
- **Dispatch scalaire/vecteur préservé** : `pushforward` d'une fonction scalaire renvoie
  un `Number`, d'une vectorielle un `AbstractVector`. Le dispatch sur le retour
  (`_bracket(::Number, ...)` vs `_bracket(::AbstractVector, ...)`) reste valide.
- **Structure du seed** : `dx` doit avoir la même structure que `x` (requis par DI).

---

## 6. Buffer pré-alloué dans le functor

### Cas typique

Un wrapper out-of-place autour d'une fonction in-place doit allouer un tampon à chaque
appel, ce qui provoque une pression GC dans les boucles numériques.

```julia
# AVANT — alloue similar(u) à chaque appel
struct OoPIpRHS{F}
    vf::F
end
(f::OoPIpRHS)(u, p, t) = (dx = similar(u); f.vf(dx, t, u, p); dx)
```

### Solution : champ buffer dans le functor

```julia
# APRÈS — buffer pré-alloué, zéro allocation par appel
struct OoPIpRHS{F, BUF}
    vf ::F
    buf::BUF
end

# Constructeur avec initialisation du buffer
OoPIpRHS(vf, u0::AbstractVector) = OoPIpRHS(vf, similar(u0))

function (f::OoPIpRHS)(u, p, t)
    f.vf(f.buf, t, u, p)
    copy(f.buf)   # ou return f.buf si thread-safety garantie par l'appelant
end
```

### Note sur le multi-threading

> ⚠️ Un buffer unique n'est **pas thread-safe**. Pour du parallélisme :
> - `Vector{BUF}` indexé par `threadid()`, ou
> - `TaskLocalValue{BUF}` (package `ThreadingUtilities`).

---

## 7. Construction lazy → constructeur de struct

### Cas typique

Une fonction `build_rhs(sys, x0, p0)` crée une closure capturant `x0`, `p0` et des
objets dérivés (`N`, `cx`, `cp`). Elle est appelée "lazy" (lors de la résolution,
pas de la définition du système).

```julia
# AVANT — factory de closure
function build_rhs(sys::MySystem, x0, p0)
    N  = length(x0)
    cx = make_coerce(x0)
    cp = make_coerce(p0)
    return function (du, u, p, t)
        x, px  = split(u, N)
        dx, dp = split(du, N)
        sys.hvf(dx, dp, t, cx(x), cp(px), variable(p))
        nothing
    end
end
```

### Solution : struct avec tous les champs capturés

```julia
# APRÈS — struct dont les champs = captures de l'ancienne closure
struct MyIPRHS{F, TD, VD, CX, CP} <: AbstractIPRHS
    hvf::HVF{F, TD, VD, InPlace}
    N  ::Int
    cx ::CX
    cp ::CP
end

function (f::MyIPRHS)(du, u, p, t)
    x, px  = split(u, f.N)
    dx, dp = split(du, f.N)
    f.hvf(dx, dp, t, f.cx(x), f.cp(px), variable(p))
    nothing
end

# build_rhs devient un constructeur de struct
function build_rhs(sys::MySystem{F,TD,VD,InPlace}, x0, p0) where {F,TD,VD}
    return MyIPRHS(sys.hvf, length(x0), make_coerce(x0), make_coerce(p0))
end
```

### Avantage : suppression des paramètres de type opaques

Le système parent peut supprimer ses paramètres `RHS<:Function` devenus inutiles :

```julia
# Avant
struct MySystem{F, TD, VD, RHS <: Function, OOPROHS <: Function}

# Après — le type du RHS est déterminé par F, TD, VD, MD
struct MySystem{F, TD, VD, MD}
    hvf::HVF{F, TD, VD, MD}
    # Les types des champs rhs/rhs_oop sont inférés depuis F, TD, VD, MD
end
```

---

## 8. Contrainte `<: Function` dans les types conteneurs

### Problème

Certains conteneurs imposent `F <: Function` sur leurs paramètres :

```julia
struct Hamiltonian{F <: Function, TD, VD}
    f::F
end
```

Un callable struct ordinaire n'est **pas** sous-type de `Function` → erreur à la
construction.

### Solution : déclarer le functor `<: Function`

```julia
# AVANT (impossible à stocker dans Hamiltonian)
struct LiftedH{TF, TD, VD}
    f::TF
end

# APRÈS (<: Function satisfait la contrainte)
struct LiftedH{TF, TD, VD} <: Function
    f::TF
end
```

### Quand c'est légitime

`<: Function` est légal en Julia. C'est exactement la relation de type des closures
remplacées (toute closure est `<: Function`). Cette déclaration :
- satisfait les contraintes existantes sans les relaxer,
- ne casse aucune annotation `::Function` dans le reste du code,
- est sémantiquement correcte (le struct *est* une fonction appelable).

> **Ne pas relâcher la contrainte `F<:Function` du conteneur** — c'est plus invasif
> et contraire à l'intention des types `Data.*`.

### Quand ne pas l'utiliser

`WithActiveArg` n'est pas stocké dans un conteneur contraint → pas besoin de `<: Function`.
La déclaration n'est nécessaire que pour les functors destinés à être champs d'un struct
paramétré par `F<:Function`.

---

## Tableau de décision — quel pattern utiliser ?

```
La closure capture N variables
        │
        ├─ N = 1, signature fixe
        │   └─ → Pattern 1 (Functor simple)
        │
        ├─ N = 1, plusieurs variantes selon des types
        │   └─ → Pattern 2 (Functor paramétré par traits)
        │
        ├─ N > 1, construction au moment de la résolution
        │   └─ → Pattern 7 (Construction lazy → constructeur de struct)
        │
        └─ La closure est passée à un backend AD
                │
                ├─ Elle fixe des arguments (partielle : y -> f(y, const1, const2))
                │   └─ → Pattern 4 (WithActiveArg)
                │
                └─ Elle calcule une dérivée directionnelle (s -> f(x + s*dx))
                    └─ → Pattern 5 (Pushforward / JVP)

Plusieurs functors ont la même interface ?
→ Pattern 3 (Hiérarchie abstraite)

Le wrapper OoP crée similar(u) à chaque appel ?
→ Pattern 6 (Buffer pré-alloué)

Le functor doit être stocké dans un struct F<:Function ?
→ Pattern 8 (<: Function)
```

---

## Priorités recommandées

| Ordre | Pattern | Raison |
|---|---|---|
| 1 | Functors simples (1, 2, 3) | Gain immédiat, risque nul, changement mécanique |
| 2 | WithActiveArg (4) | Elimine les allocations du cache AD, fondation pour le reste |
| 3 | Pushforward (5) | Nécessite WithActiveArg, cas le plus délicat (dispatch scalaire/vecteur) |
| 4 | Buffer pré-alloué (6) | Optimisation, à faire si les flows sont appelés en boucle |
| 5 | Suppression des `RHS<:Function` (via 3, 7) | Nettoyage, à faire après validation des tests |

---

## Pitfalls généraux

### `@generated` — règle stricte
Le corps d'une `@generated` function ne doit lire **que les paramètres de type**,
jamais les valeurs runtime. Violer cette règle produit des erreurs silencieuses ou
des résultats non déterministes.

### World-age
Définir des types ou méthodes à l'intérieur de fonctions (dont les fonctions de test)
crée des problèmes de world-age. **Toujours définir les callable structs au top-level
du module.** En test : fake types au top-level du fichier, jamais dans un `@testset`.

### Conflit de noms entre DI et le module
`DI.pushforward` vs `Differentiation.pushforward` : **toujours qualifier** dans les
extensions pour éviter les ambiguïtés.

### Thread-safety des buffers
Un buffer dans un functor est **partagé entre tous les appels** de cette instance.
Un functor avec buffer ne peut pas être appelé en parallèle sans protection.

### Backends AD et callable structs
La plupart des backends (ForwardDiff via DI, Zygote avec ChainRules) traversent
correctement les callable structs. Certains backends anciens peuvent avoir des
difficultés avec les types custom passés à `gradient`. **Valider backend par backend**
avant de convertir les closures internes passées à `gradient`/`derivative`.

---

## Résumé des types introduits (exemple CTFlows.jl)

| Functor | Remplace | Pattern(s) |
|---|---|---|
| `IPVFOoPRHS{F,TD,VD}` | `_build_rhs_vf_oop` | 1, 2, 3 |
| `OoPVFIpRHS{F,TD,VD,BUF}` | `_build_oop_rhs_vf_ip` | 1, 6 |
| `IPHVFIpRHS{F,TD,VD,CX,CP}` | closure de `build_rhs` (HVF) | 7, 3 |
| `LiftedHamiltonian{TF,TD,VD}` | 4 closures `_Lift` | 2, 8 |
| `StateProjection{S}` | `t -> sol(t)[1]` | 1 |
| `WithActiveArg{F,Slot}` | `h_x/h_p/h_v`, closures `y -> H(y,p)` | 4 |
| `PoissonBracket{TH,TG,TB,TD,VD}` | 4 closures `_Poisson` + 16 closures internes | 2, 4, 8 |
| `TimeDerivHVF{TX,TB,STD,VD}` | 4 closures `_∂ₜ_hvf` + closures internes | 2, 4, 8 |
| `Ad{TX,TF,TB,TD,VD}` | 4 closures `_ad` + 12 closures internes | 2, 5, 8 |
