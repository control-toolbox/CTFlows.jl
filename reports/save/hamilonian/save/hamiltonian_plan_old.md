# Plan d'implémentation — type `Hamiltonian` dans CTFlows.jl

## Vue d'ensemble

L'ajout du type `Hamiltonian` suit la chaîne de construction suivante :

```
Hamiltonian + ADStrategy
        │
        ▼
HamiltonianVectorField  ──────────────────────────────┐
        │                                              │ (chemin direct alternatif)
        ▼                                              │
HamiltonianSystem ◄────────────────────────────────────┘
  (+ rhs augmenté si NonFixed)
        │
        ▼
HamiltonianFlow  ──→  call(augment=true) ──→ solution augmentée
```

---

## Phase 1 — Type `Hamiltonian` dans le module `Data`

### 1.1 Définition du type

Nouveau fichier : `src/data/hamiltonian.jl`

```julia
struct Hamiltonian{F<:Function, TD<:TimeDependence, VD<:VariableDependence, MD<:AbstractMutabilityTrait}
    f::F
end
```

Traits identiques à `VectorField` et `HamiltonianVectorField`. La fonction encapsulée retourne un **scalaire** : `H([t,] x, p[, v]) -> Real`.

### 1.2 Détection de mutabilité

Helpers internes `_oop_arity_h` et `_detect_mutability_h` (même pattern que `_oop_arity_vf` / `_detect_mutability_vf`) :

| TD | VD | arité OOP |
|---|---|---|
| Autonomous | Fixed | 2 (x, p) |
| NonAutonomous | Fixed | 3 (t, x, p) |
| Autonomous | NonFixed | 3 (x, p, v) |
| NonAutonomous | NonFixed | 4 (t, x, p, v) |

Pour `InPlace`, arité = OOP + 1 (un buffer de sortie scalaire : `dH`).  
> **Note :** le cas InPlace pour un hamiltonien scalaire est rare, mais on le supporte par cohérence avec le reste du package.

### 1.3 Constructeur avec keyword args

```julia
function Hamiltonian(f;
    is_autonomous::Bool = Common.__is_autonomous(),
    is_variable::Bool   = Common.__is_variable(),
    is_inplace::Union{Bool, Nothing} = Common.__is_inplace()
)
```

### 1.4 Signatures d'appel

- **Naturelles** : une par combinaison de traits (8 au total, comme `VectorField`).
- **Uniformes** `(t, x, p, v)` : utilisées en interne par les helpers AD pour ne pas se soucier des traits.

### 1.5 `Base.show`

Format identique aux autres types du module `Data`.

### 1.6 Export

Ajouter `Hamiltonian` aux exports de `Data` et à `Systems.jl`.

---

## Phase 2 — Stratégie AD dans le module `Integrators`

### Motivation

Pour construire un `HamiltonianVectorField` à partir d'un `Hamiltonian`, il faut un backend de différentiation automatique (`∂H/∂x`, `∂H/∂p`, `∂H/∂v`). Ce backend est une **stratégie au sens de `CTSolvers`**, ce qui permet :

- de router les options à plat lors de `Flow(h; ad_backend=:forwarddiff, reltol=1e-8, ...)` ;
- d'avoir des messages d'erreur structurés si les options sont invalides ;
- d'être extensible sans modifier le code existant (OCP).

### 2.1 Hiérarchie de types

Nouveau fichier : `src/integrators/ad_strategy.jl`

```julia
abstract type AbstractADStrategy <: CTSolvers.Strategies.AbstractStrategy end

struct ForwardDiffADTag <: Common.AbstractTag end

struct ForwardDiffAD{O<:CTSolvers.Strategies.StrategyOptions} <: AbstractADStrategy
    options::O
end
```

### 2.2 Contrat `CTSolvers.Strategies`

```julia
CTSolvers.Strategies.id(::Type{<:ForwardDiffAD})          = :forwarddiff_ad
CTSolvers.Strategies.description(::Type{<:ForwardDiffAD}) = "ForwardDiff AD backend for Hamiltonian gradient."
CTSolvers.Strategies.metadata(::Type{<:ForwardDiffAD})    = ...  # options : chunk_size, tag...
```

### 2.3 Stub + extension

Même pattern que `SciML` :
- `build_ad_strategy(::Type{<:AbstractTag}; kwargs...)` lève `ExtensionError` par défaut.
- L'extension `CTFlowsForwardDiff` (chargée par `using ForwardDiff`) fournit l'implémentation réelle.

### 2.4 Fonction `gradient_hamiltonian`

```julia
# Interface publique de la stratégie AD
function gradient_hamiltonian(ad::AbstractADStrategy, h::Data.Hamiltonian, t, x, p, v)
    # Retourne (dx, dp) = (∂H/∂p, -∂H/∂x) via la signature uniforme de h
end

function gradient_hamiltonian_variable(ad::AbstractADStrategy, h::Data.Hamiltonian, t, x, p, v)
    # Retourne dpv = -∂H/∂v
end
```

Ces fonctions sont implémentées dans l'extension et utilisent la signature uniforme `h(t, x, p, v)` pour faire abstraction des traits.

---

## Phase 3 — Conversion `Hamiltonian` → `HamiltonianVectorField`

### 3.1 Nouvelle fonction dans `Data`

```julia
function hamiltonian_vector_field(h::Hamiltonian{F, TD, VD, OutOfPlace}, ad) -> HamiltonianVectorField
```

Construit un `HamiltonianVectorField{..., OutOfPlace}` dont la fonction interne est :

```julia
(t, x, p, v) -> gradient_hamiltonian(ad, h, t, x, p, v)
```

Les traits `TD`, `VD` sont hérités du `Hamiltonian`. Le résultat est toujours **OutOfPlace** (le gradient AD retourne une nouvelle valeur).

> **Principe KISS :** on ne construit pas une version InPlace de ce vecteur champ issu de l'AD ; si l'utilisateur veut InPlace, il écrit directement son `HamiltonianVectorField`.

### 3.2 Localisation

Ce code vit dans `src/data/hamiltonian.jl` ou un fichier `src/data/hamiltonian_conversions.jl`, et dépend de l'interface `gradient_hamiltonian` (abstraction, pas de l'implémentation concrète).

---

## Phase 4 — `HamiltonianSystem` depuis un `Hamiltonian`

### 4.1 Nouveaux constructeurs dans `build_system`

```julia
# Sans dimension connue
function build_system(h::Data.Hamiltonian, ad::Integrators.AbstractADStrategy)
    hvf = Data.hamiltonian_vector_field(h, ad)
    return HamiltonianSystem(hvf)
end

# Avec dimension connue
function build_system(h::Data.Hamiltonian, state_dimension::Int, ad::Integrators.AbstractADStrategy)
    hvf = Data.hamiltonian_vector_field(h, ad)
    return HamiltonianSystem(hvf, state_dimension)
end
```

### 4.2 Stockage du `Hamiltonian` original dans `HamiltonianSystem` (pour l'augmentation)

Le `HamiltonianSystem` doit optionnellement conserver le `Hamiltonian` source ET le `AbstractADStrategy`, afin de construire le RHS augmenté. Deux options :

**Option A — Stocker dans le type (recommandé)**

Ajouter des paramètres de type optionnels à `HamiltonianSystem` :

```julia
struct HamiltonianSystem{N, F, TD, VD, MD, RHS, OOPROHS, FINRHS, AUGMENTRHS} <: ...
    ...
    rhs_augmented::AUGMENTRHS  # Nothing si pas de Hamiltonian source
end
```

`AUGMENTRHS = Nothing` pour les systèmes construits depuis un `HamiltonianVectorField` direct.  
`AUGMENTRHS = <closure>` pour les systèmes construits depuis un `Hamiltonian` + AD.

**Option B — Laisser au `HamiltonianFlow`**

Le flow stocke séparément `(system, integrator, hamiltonian_source, ad_strategy)` et construit le RHS augmenté à la demande lors de `call(augment=true)`.

> **Recommandation : Option A**, car elle suit le principe de DIP (le système encapsule tout ce dont il a besoin) et évite d'alourdir le `Flow`.

---

## Phase 5 — RHS augmenté

### 5.1 Principe

Pour un `Hamiltonian` `NonFixed` et `augment=true`, on intègre **sans** ajouter `v` comme état (contrairement à l'ancienne implémentation) :

- État augmenté : `z_aug = [x; p; pv]` de taille `2n + m`
- `v` est transmis comme paramètre via `ODEParameters` (déjà existant)
- Dynamique :
  - `dx/dt = ∂H/∂p`
  - `dp/dt = -∂H/∂x`
  - `dpv/dt = -∂H/∂v`

### 5.2 Construction

Nouveau helper interne dans `src/systems/hamiltonian_system.jl` :

```julia
function _build_rhs_augmented(h::Data.Hamiltonian, ad::AbstractADStrategy, ::Val{N}, ::Val{M})
    return function (du, u, λ, t)
        x, p, pv = _aug_split(u, N, M)
        dx_du, dp_du = gradient_hamiltonian(ad, h, t, x, p, λ.variable)
        dpv_du       = gradient_hamiltonian_variable(ad, h, t, x, p, λ.variable)
        _aug_assign!(du, dx_du, dp_du, dpv_du, N, M)
        return nothing
    end
end
```

Helpers `_aug_split` / `_aug_assign!` analogues à `_ham_split` / `_ham_assign!`.

> **Note :** `N` et `M` peuvent être `nothing` (inférence runtime). Si `N=nothing`, l'inférence de `M` se fait sur `length(λ.variable)`.

### 5.3 Quand construire ce RHS ?

À la construction du `HamiltonianSystem` depuis un `Hamiltonian`. Si le système est `Fixed` (pas de variable), `rhs_augmented = nothing`. Si `NonFixed`, le RHS augmenté est pré-calculé et stocké.

---

## Phase 6 — `HamiltonianFlow` et option `augment`

### 6.1 Appel du flow

Le flow reçoit `augment=false` par défaut. Lorsque `augment=true` :

- Le flow doit être `NonFixed` (sinon `IncorrectArgument`).
- Le `HamiltonianSystem` doit avoir `rhs_augmented ≠ nothing` (sinon `PreconditionError` : "ce système n'a pas été construit depuis un Hamiltonian").

```julia
function (f::HamiltonianFlow)(t0, x0, p0, tf;
    variable = Common.__variable(),
    unsafe   = Common.__unsafe(),
    augment  = false,
)
    config = augment ?
        Common.HamiltonianAugmentedPointConfig(t0, x0, p0, tf) :
        Common.HamiltonianPointConfig(t0, x0, p0, tf)
    return call(f, config; variable=variable, unsafe=unsafe)
end
```

### 6.2 Nouveau `Config` : `HamiltonianAugmentedPointConfig` / `HamiltonianAugmentedTrajectoryConfig`

Ces configs signalent au `call` d'utiliser `rhs_augmented` et de découper la solution en `(xf, pf, pvf)`.

### 6.3 Adaptation de `call`

```julia
function call(flow::HamiltonianFlow, config::HamiltonianAugmentedPointConfig; variable, unsafe)
    sys  = system(flow)
    int  = integrator(flow)
    # Vérification
    sys.rhs_augmented === nothing && throw(PreconditionError(...))
    # Construire u0 augmenté : [x0; p0; zeros(m)]
    u0_aug = _build_u0_augmented(config, variable)
    prob   = Integrators.build_problem(int, sys.rhs_augmented, u0_aug, config; variable=variable)
    opts   = Integrators.build_options(int, config)
    result = Integrators.solve_problem(int, prob, opts; unsafe=unsafe)
    return Solutions.build_augmented_solution(result, sys, config)
end
```

### 6.4 Solution augmentée

`build_augmented_solution` découpe `u_final = [xf; pf; pvf]` et retourne soit :
- Un triplet `(xf, pf, pvf)` pour le mode point,
- Des trajectoires `(t -> x(t), t -> p(t), t -> pv(t))` pour le mode trajectoire.

---

## Phase 7 — Constructeurs haut niveau `Flow` depuis un `Hamiltonian`

Nouveau fichier ou ajout dans `src/flows/building.jl` :

```julia
function Flow(h::Data.Hamiltonian; ad=nothing, opts...)
    ad_strategy  = Integrators.build_ad_strategy(; backend=ad)
    system       = Systems.build_system(h, ad_strategy)
    integrator   = Integrators.build_integrator(; opts...)
    return build_flow(system, integrator)
end

function Flow(h::Data.Hamiltonian, state_dimension::Int; ad=nothing, opts...)
    ad_strategy  = Integrators.build_ad_strategy(; backend=ad)
    system       = Systems.build_system(h, state_dimension, ad_strategy)
    integrator   = Integrators.build_integrator(; opts...)
    return build_flow(system, integrator)
end
```

L'option `ad` (ou `ad_backend`) est routée vers la stratégie AD via `CTSolvers`.

---

## Phase 8 — Tests

### 8.1 `Data.Hamiltonian`

- Construction avec toutes les combinaisons de traits.
- Auto-détection de mutabilité (OOP / IP).
- Signatures d'appel naturelles et uniformes.
- `Base.show`.
- Erreurs : arité invalide, méthodes multiples.

### 8.2 Stratégie AD

- `ForwardDiffAD` : construction, `id`, `description`, `metadata`.
- `gradient_hamiltonian` sur tous les traits.
- `gradient_hamiltonian_variable` (NonFixed uniquement).
- `ExtensionError` sans l'extension chargée.
- LSP : tester `gradient_hamiltonian` pour tous les sous-types de `AbstractADStrategy` (préparer un mock).

### 8.3 `HamiltonianSystem` depuis `Hamiltonian`

- `build_system(h, ad)` et `build_system(h, n, ad)`.
- `rhs_augmented !== nothing` si NonFixed.
- `rhs_augmented === nothing` si Fixed.

### 8.4 Flow augmenté

- `flow(t0, x0, p0, tf; augment=true)` pour un hamiltonien NonFixed.
- `PreconditionError` si `augment=true` sur un système construit depuis `HamiltonianVectorField` direct.
- `IncorrectArgument` si `augment=true` sur un flow Fixed.
- Vérification numérique : `pvf = -∫ ∂H/∂v dt` sur un exemple analytique.

---

## Récapitulatif des fichiers à créer / modifier

| Fichier | Action |
|---|---|
| `src/data/hamiltonian.jl` | **Créer** : type, constructeur, signatures, show |
| `src/data/hamiltonian_conversions.jl` | **Créer** : `hamiltonian_vector_field` |
| `src/data/data.jl` | **Modifier** : include + export `Hamiltonian` |
| `src/integrators/ad_strategy.jl` | **Créer** : `AbstractADStrategy`, `ForwardDiffAD`, stubs |
| `src/integrators/integrators.jl` | **Modifier** : include + export |
| `src/systems/hamiltonian_system.jl` | **Modifier** : nouveau champ `rhs_augmented`, helpers `_aug_*` |
| `src/systems/building.jl` | **Modifier** : surcharges `build_system(h, ad)` |
| `src/common/configs.jl` | **Modifier** : ajouter `HamiltonianAugmented*Config` |
| `src/flows/building.jl` | **Modifier** : `Flow(h::Hamiltonian; ...)` |
| `src/flows/flow.jl` | **Modifier** : `call` pour configs augmentées |
| `src/solutions/...` | **Modifier** : `build_augmented_solution` |
| `ext/CTFlowsForwardDiff/` | **Créer** : extension implémentant `gradient_hamiltonian` |
| `test/data/test_hamiltonian.jl` | **Créer** |
| `test/integrators/test_ad_strategy.jl` | **Créer** |
| `test/flows/test_hamiltonian_flow_augmented.jl` | **Créer** |

---

## Points de vigilance

1. **Dépendance circulaire** : `gradient_hamiltonian` est déclarée dans `Integrators` (ou un module `AD`) mais utilisée dans `Systems`. Utiliser une interface abstraite dans `Common` ou passer le backend comme argument (DIP).

2. **Dimension de la variable `v`** : quand `N=nothing`, `M` (dimension de `v`) ne peut pas être déduit statiquement. L'inférence runtime via `length(λ.variable)` doit être robuste (et couverte par les tests).

3. **Routing des options** : l'option `ad` (ou `ad_backend`) ne doit pas être passée à la stratégie `SciML`. S'assurer que `CTSolvers` gère bien le routage par `id` de stratégie.

4. **`augment=true` sans variable** : lever une erreur claire (`IncorrectArgument`) avec suggestion de retirer `augment=true`.

5. **Cohérence `Base.show`** : le `HamiltonianSystem` doit afficher si `rhs_augmented` est disponible.
