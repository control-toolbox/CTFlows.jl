# Remplacement des closures par des structs appelables

## 1. Contexte et motivation

Le code actuel construit des closures via des fonctions `_build_rhs_*` ou `build_rhs`/`build_oop_rhs`. Ces closures capturent des variables concrètes et sont stockées dans des champs typés `RHS<:Function` ou créées à la volée. Le type `Function` est opaque : le compilateur ne peut pas inspecter sa structure, ce qui pénalise la composabilité, les stack traces et l'extensibilité.

Les structs appelables (*functors*) sont l'idiome Julia pour ce cas : ils donnent un **type nommé, paramétré, inspectable**.

---

## 2. Inventaire des closures actuelles

### 2.1 `VectorFieldSystem` — closures pré-calculées à la construction

| Champ | Builder | Signature |
|---|---|---|
| `rhs` | `_build_rhs_vf_oop` / `_build_rhs_vf_ip` | `(du, u, λ, t) -> nothing` |
| `rhs_oop` | `_build_oop_rhs_vf_oop` / `_build_oop_rhs_vf_ip` | `(u, λ, t) -> du` |
| `rhs_oop_finalize` | `_build_finalize_rhs_vf_ip` | `(u, λ, t) -> du` |

Ces trois closures capturent toutes le même `vf` — **aucune information supplémentaire**. Le struct appelable est donc strictement équivalent, avec un type nommé en prime.

### 2.2 `HamiltonianVectorFieldSystem` et `HamiltonianSystem` — closures lazy (`build_rhs`, `build_oop_rhs`)

Construites à l'appel de `build_problem`, elles capturent `vf`/`h`/`backend` **plus** `N::Int`, `cx`, `cp` (inférés depuis `x0`, `p0`). Ce sont ces captures supplémentaires qui justifient la construction lazy — et qui font aussi l'intérêt principal des structs appelables ici.

---

## 3. Design proposé

### 3.1 Hiérarchie abstraite des RHS

```julia
abstract type AbstractRHS end
abstract type AbstractOoPRHS end
```

Permet le dispatch et des tests génériques (`@test rhs isa AbstractRHS`).

### 3.2 `VectorFieldSystem` — trois functors

```julia
# In-place, out-of-place vector field
struct VFOoPRHS{F, TD, VD} <: AbstractRHS
    vf::Data.VectorField{F, TD, VD, Traits.OutOfPlace}
end
(f::VFOoPRHS)(du, u, λ, t) = (du .= f.vf(t, u, Common.variable(λ)); nothing)

struct VFIpRHS{F, TD, VD} <: AbstractRHS
    vf::Data.VectorField{F, TD, VD, Traits.InPlace}
end
(f::VFIpRHS)(du, u, λ, t) = (f.vf(du, t, u, Common.variable(λ)); nothing)

# Out-of-place wrappers
struct VFOoPOoPRHS{F, TD, VD} <: AbstractOoPRHS
    vf::Data.VectorField{F, TD, VD, Traits.OutOfPlace}
end
(f::VFOoPOoPRHS)(u, λ, t) = f.vf(t, u, Common.variable(λ))

struct VFIpOoPRHS{F, TD, VD} <: AbstractOoPRHS
    vf::Data.VectorField{F, TD, VD, Traits.InPlace}
end
(f::VFIpOoPRHS)(u, λ, t) = (dx = similar(u); f.vf(dx, t, u, Common.variable(λ)); dx)

struct VFIpFinalizeRHS{F, TD, VD} <: AbstractOoPRHS
    vf::Data.VectorField{F, TD, VD, Traits.InPlace}
end
(f::VFIpFinalizeRHS)(u, λ, t) = (dx = similar(u); f.vf(dx, t, u, Common.variable(λ)); typeof(u)(dx))
```

`VectorFieldSystem` perd alors ses paramètres `RHS` et `OOPROHS` qui deviennent **déterministes** :

```julia
struct VectorFieldSystem{F, TD, VD, MD} <: AbstractStateSystem{TD, VD}
    vf  ::Data.VectorField{F, TD, VD, MD}
    rhs ::VFOoPRHS{F, TD, VD}    # ou VFIpRHS selon MD
    rhs_oop         # VFOoPOoPRHS / VFIpOoPRHS
    rhs_oop_finalize  # VFIpFinalizeRHS ou Nothing
end
```

Les paramètres `RHS<:Function` et `OOPROHS<:Function` disparaissent : le type du champ est **inféré statiquement** depuis `F, TD, VD, MD`.

### 3.3 `HamiltonianVectorFieldSystem` — functors lazy avec cache de forme

Le gain principal est ici : les captures `N`, `cx`, `cp` sont des champs typés.

```julia
struct HVFIpRHS{F, TD, VD, CX, CP} <: AbstractRHS
    hvf ::Data.HamiltonianVectorField{F, TD, VD, Traits.InPlace}
    N   ::Int
    cx  ::CX   # typeof(_make_coerce(x0))
    cp  ::CP
end
(f::HVFIpRHS)(du, u, λ, t) = begin
    x, p   = _ham_split(u,  f.N)
    dx, dp = _ham_split(du, f.N)
    f.hvf(dx, dp, t, f.cx(x), f.cp(p), Common.variable(λ))
    nothing
end

struct HVFOoPRHS{F, TD, VD, CX, CP} <: AbstractRHS
    hvf ::Data.HamiltonianVectorField{F, TD, VD, Traits.OutOfPlace}
    N   ::Int
    cx  ::CX
    cp  ::CP
end
(f::HVFOoPRHS)(du, u, λ, t) = begin
    x, p   = _ham_split(u, f.N)
    dx, dp = f.hvf(t, f.cx(x), f.cp(p), Common.variable(λ))
    _ham_assign!(du, dx, dp, f.N)
    nothing
end
```

`build_rhs` devient un constructeur de functor plutôt qu'une factory de closure :

```julia
function build_rhs(sys::HamiltonianVectorFieldSystem{F,TD,VD,Traits.InPlace}, x0, p0) where {F,TD,VD}
    return HVFIpRHS(sys.hvf, _state_dim(x0), _make_coerce(x0), _make_coerce(p0))
end
```

### 3.4 `HamiltonianSystem` (AD) — idem

```julia
struct HamIpRHS{F, TD, VD, B, CX, CP} <: AbstractRHS
    h       ::Data.Hamiltonian{F, TD, VD}
    backend ::B
    N       ::Int
    cx      ::CX
    cp      ::CP
end
(f::HamIpRHS)(du, u, λ, t) = begin
    x, p   = _ham_split(u, f.N)
    ∂x, ∂p = Differentiation.hamiltonian_gradient(
                  f.backend, f.h, t, f.cx(x), f.cp(p),
                  Common.variable(λ), Common.cache(λ))
    _ham_assign!(du, ∂p, -∂x, f.N)
    nothing
end
```

---

## 4. Opportunités de cache

### 4.1 Buffer pré-alloué dans `VFIpOoPRHS`

Actuellement, `_build_oop_rhs_vf_ip` fait `similar(u)` **à chaque appel**. Avec un functor, on peut stocker le buffer :

```julia
struct VFIpOoPRHS{F, TD, VD, BUF} <: AbstractOoPRHS
    vf  ::Data.VectorField{F, TD, VD, Traits.InPlace}
    buf ::BUF   # Vector pré-alloué
end
(f::VFIpOoPRHS)(u, λ, t) = (f.vf(f.buf, t, u, Common.variable(λ)); copy(f.buf))
```

Constructeur :
```julia
VFIpOoPRHS(vf, u0::AbstractVector) = VFIpOoPRHS(vf, similar(u0))
```

> ⚠️ Ce buffer n'est **pas thread-safe**. Pour du multi-threading, utiliser un `Vector` de buffers ou un `TaskLocalValue` (package `ThreadingUtilities`).

### 4.2 Buffer dans `HVFIpOoPRHS`

Même logique pour les Hamiltonians in-place out-of-place : `dx` et `dp` peuvent être pré-alloués.

```julia
struct HVFIpOoPRHS{F, TD, VD, CX, CP, BUF} <: AbstractOoPRHS
    hvf ::Data.HamiltonianVectorField{F, TD, VD, Traits.InPlace}
    N   ::Int
    cx  ::CX
    cp  ::CP
    buf ::BUF   # similar(u0) pour [dx; dp]
end
```

### 4.3 Cache AD dans `HamIpRHS`

Le backend AD peut nécessiter des buffers internes (seed vectors, dual number buffers). Ces derniers sont actuellement gérés par `Common.cache(λ)` passé à `hamiltonian_gradient`. Si ce cache est alloué à chaque `build_problem`, le stocker dans le functor est une alternative :

```julia
struct HamIpRHS{..., CACHE}
    ...
    ad_cache ::CACHE
end
```

Cela suppose que `hamiltonian_gradient` accepte un cache externe — à valider selon l'API de `Differentiation`.

---

## 5. Impact sur `VectorFieldSystem`

Avec les functors, les paramètres de type `RHS` et `OOPROHS` (actuellement `<:Function`) peuvent être **supprimés** ou remplacés par des types concrets déterministes :

```julia
# Avant
struct VectorFieldSystem{F, TD, VD, MD, RHS<:Function, OOPROHS<:Function, FINRHS} ...

# Après (OutOfPlace)
struct VectorFieldSystem{F, TD, VD, Traits.OutOfPlace} ...
# les champs rhs/rhs_oop ont des types entièrement déterminés par F,TD,VD
```

Avantage : `typeof(sys)` encode **toute** l'information structurelle. Pas de `typeof(rhs)` dans le constructeur.

---

## 6. Récapitulatif des bénéfices

| Aspect | Closure actuelle | Struct appelable |
|---|---|---|
| Type-stabilité | ✅ (captures concrètes) | ✅ |
| Stack traces | `var"#3#4"` | `HVFIpRHS{...}` |
| Dispatch sur le type du RHS | ❌ | ✅ |
| Buffer pré-alloué | ❌ | ✅ |
| Sérialisation / precompilation | Fragile | Robuste |
| Paramètres `RHS<:Function` dans le système | Nécessaires | Supprimables |
| Extensibilité (extension de package) | ❌ | ✅ (méthode sur le functor) |

---

## 7. Recommandation de priorité

1. **Court terme** — `VectorFieldSystem` : gain immédiat de lisibilité et suppression des paramètres de type `RHS`/`OOPROHS`. Changement mécanique, risque faible.
2. **Moyen terme** — Hamiltonians lazy (`build_rhs`) : le gain de buffer pré-alloué est significatif si les flows sont appelés en boucle (optimisation, tir multiple).
3. **Long terme** — cache AD dans `HamIpRHS` : dépend de l'API de `Differentiation`, à évaluer au cas par cas.
