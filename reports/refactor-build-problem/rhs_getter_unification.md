# Refactor : unification des getters RHS et simplification de `build_problem`

## Contexte

Ce document décrit un problème d'architecture identifié lors de l'ajout d'`OptimalControlFlowSystem`
(PR `Flow(ocp::CTModels.Models.Model)`). L'ajout de ce nouveau système a mis en évidence une
duplication de protocoles dans la couche Systems / SciML extension.

---

## Problème actuel : deux familles de getters RHS

### Famille 1 — `rhs` / `rhs_oop` (sur `AbstractSystem`)

Définis dans `src/Systems/abstract_system.jl:263–326` comme contrat de `AbstractSystem`.
Implémentés **uniquement** par `VectorFieldSystem` (`src/Systems/vector_field_system.jl`).

```julia
rhs(sys::VectorFieldSystem)     → sys.rhs      # simple accesseur de champ
rhs_oop(sys::VectorFieldSystem) → sys.rhs_oop  # idem
```

Les functors sont construits **au moment de la construction du système** (eager), stockés
dans les champs typés `rhs::RHS` et `rhs_oop::OOPROHS` du struct.

### Famille 2 — `build_rhs` / `build_oop_rhs` (sur `AbstractHamiltonianSystem`)

Définis dans `src/Systems/abstract_system.jl:341–373` comme contrat de `AbstractHamiltonianSystem`.
Implémentés par `HamiltonianSystem`, `HamiltonianVectorFieldSystem`, et désormais
`OptimalControlFlowSystem`.

```julia
build_rhs(sys::HamiltonianSystem, x0, p0, _, _)          → HamIpRHS(...)   # lazy
build_oop_rhs(sys::HamiltonianSystem, x0, p0, _, _)      → HamOoPRHS(...)  # lazy
build_rhs(sys::HVFSystem, x0, p0)                        → IPHVFOoPRHS(...) # lazy
build_rhs(sys::OptimalControlFlowSystem, _, _, _, _)     → sys.rhs_ip      # eager (accesseur)
build_oop_rhs(sys::OptimalControlFlowSystem, _, _, _, _) → sys.rhs_oop     # eager (accesseur)
```

### Le symptôme dans `build_and_solve.jl`

La dualité des familles force des overloads spécialisés dans l'extension SciML
(`ext/CTFlowsSciMLIntegrator/build_and_solve.jl`). Actuellement il y a **5 overloads** de
`Integrators.build_problem` :

| Overload | system type | config type |
|---|---|---|
| 1 | `AbstractSystem` | `AbstractConfig` |
| 2 | `HamiltonianVectorFieldSystem` | `AbstractHamiltonianConfig` |
| 3 | `HamiltonianSystem` | `AbstractHamiltonianConfig` |
| 4 | `HamiltonianSystem` | `AbstractAugmentedHamiltonianConfig` |
| 5 | `OptimalControlFlowSystem` | `AbstractHamiltonianConfig` |
| 6 | `OptimalControlFlowSystem` | `AbstractAugmentedHamiltonianConfig` |

Chaque nouvel type de système oblige à écrire **deux** nouveaux overloads (non-augmenté +
augmenté). Le corps de chaque overload est quasiment identique : extraire `x0, p0, t0,
variable` de la config, appeler le getter, créer l'`ODEProblem`.

### Cause racine

La famille 2 (`build_rhs`) a été conçue pour transmettre `x0`/`p0` au getter parce que
`HamiltonianSystem` en a besoin : il construit les fonctions de coercition
`cx = Common.make_coerce(x0)` et `cp = Common.make_coerce(p0)` qui encodent le type concret
du tableau initial (Vector, SVector, matrice...). Ces informations ne sont pas disponibles à
la construction du système, seulement au moment de l'intégration.

```julia
function build_rhs(sys::HamiltonianSystem, x0, p0, _, _)
    N  = _state_dim(x0)          # ← besoin de x0
    cx = Common.make_coerce(x0)  # ← besoin de x0
    cp = Common.make_coerce(p0)  # ← besoin de p0
    return HamIpRHS(sys.h, sys.backend, N, cx, cp)
end
```

Pour `HamiltonianVectorFieldSystem`, le même besoin existe (`x0`/`p0` pour les coercitions).

En revanche, `OptimalControlFlowSystem` et `VectorFieldSystem` n'ont pas ce besoin : toute
l'information est disponible à la construction. `OptimalControlFlowSystem` ignore les quatre
arguments `_, _, _, _` de `build_rhs`.

### La dette créée par `OptimalControlFlowSystem`

L'ajout d'`OptimalControlFlowSystem` a rendu la tension visible : on a un système eager
(functors pré-construits) qui doit quand même satisfaire l'interface `build_rhs(sys, x0, p0,
_, _)` pour que `build_problem` l'appelle. On paie le coût des 4 arguments inutiles et d'un
overload `build_problem` supplémentaire juste pour satisfaire la convention.

---

## Proposition : famille unifiée `get_ip_rhs` / `get_oop_rhs` / `get_ip_rhs_augmented`

### Principe

Passer la **config** entière au getter, et laisser chaque système extraire ce dont il a
besoin. Les systèmes eager ignorent la config. Les systèmes lazy la lisent.

```
get_ip_rhs(sys, config)           → AbstractIPRHS   (non-augmenté, in-place)
get_oop_rhs(sys, config)          → AbstractOoPRHS  (non-augmenté, out-of-place)
get_ip_rhs_augmented(sys, config) → AbstractIPRHS   (augmenté, toujours in-place)
```

### Implémentations par système

```julia
# VectorFieldSystem — eager, ignore la config
get_ip_rhs(sys::VectorFieldSystem, _)  = sys.rhs
get_oop_rhs(sys::VectorFieldSystem, _) = sys.rhs_oop

# OptimalControlFlowSystem — eager, ignore la config
get_ip_rhs(sys::OptimalControlFlowSystem, _)           = sys.rhs_ip
get_oop_rhs(sys::OptimalControlFlowSystem, _)          = sys.rhs_oop
get_ip_rhs_augmented(sys::OptimalControlFlowSystem, _) = sys.rhs_aug

# HamiltonianSystem — lazy, lit x0/p0 depuis la config
function get_ip_rhs(sys::HamiltonianSystem, config::AbstractHamiltonianConfig)
    x0 = Configs.initial_state(config)
    p0 = Configs.initial_costate(config)
    return HamIpRHS(sys.h, sys.backend, _state_dim(x0),
                    Common.make_coerce(x0), Common.make_coerce(p0))
end
function get_oop_rhs(sys::HamiltonianSystem, config::AbstractHamiltonianConfig)
    x0 = Configs.initial_state(config)
    p0 = Configs.initial_costate(config)
    return HamOoPRHS(sys.h, sys.backend, _state_dim(x0),
                     Common.make_coerce(x0), Common.make_coerce(p0))
end
function get_ip_rhs_augmented(sys::HamiltonianSystem, config::AbstractAugmentedHamiltonianConfig)
    n_x = length(Configs.initial_state(config))
    n_v = length(Configs.initial_variable_costate(config))
    return HamIpAugRHS(sys.h, sys.backend, n_x, n_v)
end

# HamiltonianVectorFieldSystem — lazy, lit x0/p0 depuis la config
function get_ip_rhs(sys::HamiltonianVectorFieldSystem{...,OutOfPlace}, config)
    x0, p0 = Configs.initial_state(config), Configs.initial_costate(config)
    return IPHVFOoPRHS(sys.hvf, _state_dim(x0),
                       Common.make_coerce(x0), Common.make_coerce(p0))
end
# ... variants InPlace, augmented, etc.
```

### `build_problem` simplifié

Le trait `Traits.dynamics_trait(sys)` (`StateDynamics` vs `HamiltonianDynamics`) et la
hiérarchie de config (`AbstractConfig` < `AbstractHamiltonianConfig` <
`AbstractAugmentedHamiltonianConfig`) permettent un check de compatibilité en entrée,
analogue à `_check_outofplace` dans `src/DifferentialGeometry/ad_types.jl` :

```julia
_check_dyn_config(::Type{Traits.StateDynamics},       ::AbstractConfig)                     = nothing
_check_dyn_config(::Type{Traits.HamiltonianDynamics}, ::AbstractHamiltonianConfig)          = nothing
_check_dyn_config(::Type{Traits.HamiltonianDynamics}, ::AbstractAugmentedHamiltonianConfig) = nothing
_check_dyn_config(D, C) = throw(PreconditionError("incompatible system dynamics ($D) and config ($C)"))
```

Puis les **deux seuls overloads** nécessaires dans `build_and_solve.jl` :

```julia
# Cas non-augmenté — couvre State + Hamiltonian
function Integrators.build_problem(
    integ::SciML, system::AbstractSystem, config::AbstractConfig; variable,
)
    _check_dyn_config(Traits.dynamics_trait(system), config)
    u0 = Configs.initial_condition(config)
    λ  = Common.ODEParameters(variable)
    if ismutable(u0)
        f! = Systems.get_ip_rhs(system, config)
        return ODEProblem(f!, u0, Configs.tspan(config), λ)
    else
        f = Systems.get_oop_rhs(system, config)
        return ODEProblem(f, u0, Configs.tspan(config), λ)
    end
end

# Cas augmenté — toujours in-place (pv0 = zeros(...) est mutable par construction)
function Integrators.build_problem(
    integ::SciML, system::AbstractSystem, config::AbstractAugmentedHamiltonianConfig; variable,
)
    _check_dyn_config(Traits.dynamics_trait(system), config)
    u0 = Configs.initial_condition(config)
    λ  = Common.ODEParameters(variable)
    f! = Systems.get_ip_rhs_augmented(system, config)
    return ODEProblem(f!, u0, Configs.tspan(config), λ)
end
```

6 overloads → 2. Chaque nouveau type de système n'ajoute plus rien dans l'extension SciML.

### Contrat abstract (dans `abstract_system.jl`)

```julia
# Stubs NotImplemented sur AbstractSystem / AbstractHamiltonianSystem
function get_ip_rhs(system::AbstractSystem, config)
    throw(NotImplemented(...))
end
function get_oop_rhs(system::AbstractSystem, config)
    throw(NotImplemented(...))
end
function get_ip_rhs_augmented(system::AbstractHamiltonianSystem, config)
    throw(NotImplemented(...))
end
```

### Sort des anciennes méthodes

| Méthode actuelle | Remplacée par | Note |
|---|---|---|
| `rhs(sys)` | `get_ip_rhs(sys, _)` | config ignorée pour les systèmes eager |
| `rhs_oop(sys)` | `get_oop_rhs(sys, _)` | idem |
| `build_rhs(sys, x0, p0, t0, v)` | `get_ip_rhs(sys, config)` | config porte x0, p0 |
| `build_oop_rhs(sys, x0, p0, t0, v)` | `get_oop_rhs(sys, config)` | idem |
| `build_rhs_augmented(sys, n_x, n_v, ...)` | `get_ip_rhs_augmented(sys, config)` | n_x, n_v extraits de config |

Les anciens noms peuvent être gardés comme wrappers dépréciés le temps de la migration,
ou supprimés d'un coup si aucun code externe ne les appelle directement.

---

## Impact sur les docstrings manquantes

`build_rhs_augmented` sur `HamiltonianVectorFieldSystem` a actuellement un `# TODO: docstring`
(`hamiltonian_vector_field_system.jl:252`). Ce refactor est l'occasion de tout documenter
d'un coup avec le nouveau nom.

---

## Ce que ce refactor ne touche pas

- La logique des functors eux-mêmes (`HamIpRHS`, `OCPFlowIpRHS`, etc.) — inchangés.
- La hiérarchie `AbstractSystem` / `AbstractHamiltonianSystem` — inchangée.
- La hiérarchie des configs — inchangée.
- L'extension SciML StaticArrays — suit automatiquement via la même interface.

---

## Résumé des gains

| Avant | Après |
|---|---|
| 2 familles de getters (`rhs`/`build_rhs`) | 1 famille (`get_ip_rhs`/`get_oop_rhs`/`get_ip_rhs_augmented`) |
| 6 overloads `build_problem` dans l'extension | 2 |
| Nouveau système → 2 overloads `build_problem` | Nouveau système → 0 overload `build_problem` |
| Arguments émiettés `x0, p0, t0, variable` | Config transmise entière |
| `OptimalControlFlowSystem` ignore 4 args `_` | Même chose, mais sémantique claire |

---

## Priorité et séquençage suggéré

Ce refactor est indépendant des fonctionnalités en cours. Il peut s'appliquer une fois que
l'API `Flow(ocp)` est stabilisée et les tests écrits. Suggéré comme PR autonome après la
finalisation du PR `Flow(ocp)`.

**Fichiers impactés :**
- `src/Systems/abstract_system.jl` (contrat)
- `src/Systems/vector_field_system.jl`
- `src/Systems/hamiltonian_system.jl`
- `src/Systems/hamiltonian_vector_field_system.jl`
- `src/Systems/optimal_control_flow_system.jl`
- `ext/CTFlowsSciMLIntegrator/build_and_solve.jl`
