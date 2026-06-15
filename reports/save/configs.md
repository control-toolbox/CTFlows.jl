# Config Trait Hierarchy — Two-Dimensional Dispatch

Remplace la hiérarchie de types abstraits par un unique type racine à deux paramètres de type (structs tags subtypant `AbstractTag`) et quatre `const` aliases totalement symétriques, permettant un dispatch orthogonal sur le mode (Point/Trajectory) ET le contenu (State/Hamiltonian).

---

## Ce qui change et pourquoi

**Objectif** : dispatchable sur le mode (Point vs Trajectory) ET le contenu (State vs Hamiltonian) de façon indépendante et symétrique — aucune dimension n'est "primaire".

**Approche : struct tags + `const` aliases (validé conceptuellement en REPL)**

```julia
# 2 abstraits intermédiaires pour séparer mode et contenu
abstract type AbstractModeTag    <: AbstractTag end
abstract type AbstractContentTag <: AbstractTag end

# 4 struct tags (vides, isbits), cohérents avec AbstractTag existant (SciMLTag, Tsit5Tag)
struct PointTag       <: AbstractModeTag    end
struct TrajectoryTag  <: AbstractModeTag    end
struct StateTag       <: AbstractContentTag end
struct HamiltonianTag <: AbstractContentTag end

# Un seul type abstrait racine à 3 paramètres avec contraintes explicites
abstract type AbstractConfig{X0, Mode<:AbstractModeTag, Content<:AbstractContentTag} end

# Quatre aliases totalement symétriques — tous utilisables en dispatch ET isa
const AbstractEndPointConfig{X0, C}       = AbstractConfig{X0, PointTag,      C}
const AbstractTrajectoryConfig{X0, C}  = AbstractConfig{X0, TrajectoryTag,  C}
const AbstractStateConfig{X0, M}       = AbstractConfig{X0, M, StateTag}
const AbstractHamiltonianConfig{X0, M} = AbstractConfig{X0, M, HamiltonianTag}

# Types concrets subtypent DIRECTEMENT depuis AbstractConfig
struct StateEndPointConfig{T0<:Real, X0, TF<:Real}          <: AbstractConfig{X0, PointTag,     StateTag}       end
struct StateTrajectoryConfig{TS<:Tuple{<:Real,<:Real}, X0} <: AbstractConfig{X0, TrajectoryTag, StateTag}     end
struct HamiltonianEndPointConfig{T0<:Real, X0, P0, TF<:Real} <: AbstractConfig{X0, PointTag,     HamiltonianTag} end
struct HamiltonianTrajectoryConfig{TS<:Tuple{<:Real,<:Real}, X0, P0} <: AbstractConfig{X0, TrajectoryTag, HamiltonianTag} end
```

**Patterns de dispatch disponibles :**

| Pattern | Signification |
|---|---|
| `AbstractEndPointConfig` | tous les Point (State + Hamiltonian) |
| `AbstractTrajectoryConfig` | tous les Trajectory |
| `AbstractStateConfig` | tous les State (Point + Trajectory) |
| `AbstractHamiltonianConfig` | tous les Hamiltonian |
| `AbstractStateConfig{<:Number}` | State avec X0 scalaire |
| `AbstractHamiltonianConfig{<:Number}` | Hamiltonian avec X0 scalaire |

**Pourquoi des struct tags plutôt que des entiers ?**
- Cohérent avec le pattern `AbstractTag` existant (`SciMLTag`, `Tsit5Tag`)
- Auto-documenté : `PointTag` est plus clair que `1`
- Contrainte exprimable : `Mode<:AbstractModeTag, Content<:AbstractContentTag`
- Séparation explicite : `AbstractModeTag` vs `AbstractContentTag` empêche le mélange accidentel

**Méthodes unifiées (gains) :**

- `tspan` : 4 méthodes → 2 + stub
- `build_options` SciML : 4 méthodes → 2
- `_extract_initial_state` MultiPhase : 4 méthodes → 2
- `initial_condition` : suppression du `Union{...}`
- `initial_costate` : suppression du `Union{...}`

**Ce qui disparaît :**
- `abstract type AbstractEndPointConfig{X0} <: AbstractConfig{X0} end` (remplacé par `const` alias)
- `abstract type AbstractTrajectoryConfig{X0} <: AbstractConfig{X0} end` (remplacé par `const` alias)
- `Union{HamiltonianEndPointConfig, HamiltonianTrajectoryConfig}` dans `initial_condition` et `initial_costate`
- Les 4+4+4 méthodes individuelles réduites

**Ce qui est ajouté :**
- `AbstractModeTag`, `AbstractContentTag` (intermédiaires) dans `abstract_tag.jl`
- `PointTag`, `TrajectoryTag`, `StateTag`, `HamiltonianTag` (concrets) dans `abstract_tag.jl`
- `AbstractStateConfig`, `AbstractHamiltonianConfig` comme nouveaux exports
- `AbstractEndPointConfig`, `AbstractTrajectoryConfig` restent exportés (backward compat) mais deviennent des `const` aliases

---

## Graphe de dépendances (inchangé)

```text
Common (abstract_tag.jl, configs.jl)
  ↓
Integrators (abstract_integrator.jl)
  ↓
CTFlowsSciML (extension)
Solutions (building.jl)
MultiPhase (calling.jl)
```

---

## Step 0 — Branch

```bash
git checkout develop && git pull
git checkout -b feature/config-trait-hierarchy
```

---

## Step 1 — `src/Common/abstract_tag.jl` (modified)

> 🏗️ Follow `modules.md` — structs vides, subtypes de `AbstractTag`, exportés depuis `Common.jl`
> 📐 Follow `architecture.md` — marqueurs de traits, aucun comportement

Ajouter après la définition de `abstract type AbstractTag end` :

```julia
# Intermédiaires pour séparer mode et contenu
abstract type AbstractModeTag    <: AbstractTag end
abstract type AbstractContentTag <: AbstractTag end

# Marqueurs de mode
struct PointTag      <: AbstractModeTag    end
struct TrajectoryTag <: AbstractModeTag    end

# Marqueurs de contenu
struct StateTag       <: AbstractContentTag end
struct HamiltonianTag <: AbstractContentTag end
```

Ces 6 types sont des marqueurs de traits purs (zero bytes, isbits), cohérents avec `SciMLTag` et `Tsit5Tag` qui existent déjà. `AbstractModeTag` et `AbstractContentTag` empêchent le mélange accidentel de tags de dimensions différentes.

> ⛔ Do NOT write docstrings in this step.

---

## Step 2 — `src/Common/Common.jl` (modified)

> 🏗️ Follow `modules.md` — mise à jour des exports

Dans la ligne `export`, ajouter :
- `AbstractModeTag, AbstractContentTag` (intermédiaires)
- `PointTag, TrajectoryTag, StateTag, HamiltonianTag` (concrets)
- `AbstractStateConfig, AbstractHamiltonianConfig`

`AbstractEndPointConfig` et `AbstractTrajectoryConfig` restent dans les exports (ils deviennent des aliases mais les noms sont inchangés).

> ⛔ Do NOT write docstrings in this step.

---

## Step 3 — `src/Common/configs.jl` (modified)

> 📐 Follow `architecture.md` — Open/Closed : les concrets ne changent que leur parent ; DRY : unification des méthodes
> 🏗️ Follow `modules.md` — tous les noms exportés restent identiques
> 🔬 Follow `type-stability.md` — information encodée au niveau du type, zéro runtime check

**Section "Abstract Types" — remplacer les 3 déclarations `abstract type` par :**

```julia
# Un seul type abstrait racine avec contraintes explicites
abstract type AbstractConfig{X0, Mode<:AbstractModeTag, Content<:AbstractContentTag} end

# Quatre aliases symétriques (UnionAll)
const AbstractEndPointConfig{X0, C}       = AbstractConfig{X0, PointTag,      C}
const AbstractTrajectoryConfig{X0, C}  = AbstractConfig{X0, TrajectoryTag,  C}
const AbstractStateConfig{X0, M}       = AbstractConfig{X0, M, StateTag}
const AbstractHamiltonianConfig{X0, M} = AbstractConfig{X0, M, HamiltonianTag}
```

**Section "StateEndPointConfig" — changer le parent :**
- `struct StateEndPointConfig{T0<:Real, X0, TF<:Real} <: AbstractEndPointConfig{X0}` → `<: AbstractConfig{X0, PointTag, StateTag}`

**Section "StateTrajectoryConfig" — changer le parent :**
- `struct StateTrajectoryConfig{TS<:Tuple{<:Real,<:Real}, X0} <: AbstractTrajectoryConfig{X0}` → `<: AbstractConfig{X0, TrajectoryTag, StateTag}`

**Section "HamiltonianEndPointConfig" — changer le parent :**
- `struct HamiltonianEndPointConfig{T0<:Real, X0, P0, TF<:Real} <: AbstractEndPointConfig{X0}` → `<: AbstractConfig{X0, PointTag, HamiltonianTag}`

**Section "HamiltonianTrajectoryConfig" — changer le parent :**
- `struct HamiltonianTrajectoryConfig{TS<:Tuple{<:Real,<:Real}, X0, P0} <: AbstractTrajectoryConfig{X0}` → `<: AbstractConfig{X0, TrajectoryTag, HamiltonianTag}`

**Section "Interface: tspan" — 4 méthodes → 2 + stub :**

Supprimer les 4 méthodes individuelles `tspan(::StateEndPointConfig)`, `tspan(::HamiltonianEndPointConfig)`, `tspan(::StateTrajectoryConfig)`, `tspan(::HamiltonianTrajectoryConfig)`.

Remplacer par :
```julia
function tspan(c::AbstractEndPointConfig)::Tuple{Real, Real}
    return (c.t0, c.tf)
end

function tspan(c::AbstractTrajectoryConfig)::Tuple{Real, Real}
    return c.tspan
end
```

Stub `tspan(c::AbstractConfig)` → `NotImplemented` inchangé.

**Section "Generic Accessor Functions" — `initial_condition` :**

Remplacer les 3 méthodes actuelles par :
```julia
# State scalaire
function initial_condition(c::AbstractStateConfig{<:Number})
    return [c.x0]
end

# State vecteur (fallback)
function initial_condition(c::AbstractStateConfig)
    return c.x0
end

# Hamiltonien (scalaire et vecteur)
function initial_condition(c::AbstractHamiltonianConfig)
    return vcat(c.x0, c.p0)
end
```

**Section "Generic Accessor Functions" — `initial_costate` :**

Remplacer les 2 méthodes actuelles (dont la `Union`) par :
```julia
function initial_costate(c::AbstractHamiltonianConfig)
    return c.p0
end

function initial_costate(c::AbstractStateConfig)
    throw(Exceptions.PreconditionError(
        "initial_costate is only defined for Hamiltonian configs";
        context = "initial_costate - requires Hamiltonian config",
        reason = "config type $(typeof(c)) does not have a costate field",
        suggestion = "use HamiltonianEndPointConfig or HamiltonianTrajectoryConfig instead",
    ))
end
```

**`initial_state` :** inchangé — `c::Common.AbstractConfig` sans paramètre couvre tout.

> ⛔ Do NOT write docstrings in this step. Leave existing docstrings untouched; updated methods get `# TODO: docstring`.

---

## Step 4 — Test Checkpoint: Core Configs

> 🧪 Follow `testing-creation.md` — structs fake à top-level du module ; testsets séparés
> ▶️ Follow `testing-execution.md`

Modifier `test/suite/common/test_configs.jl` :

**Fake types (top-level) — mettre à jour les parents :**
```julia
# Avant:
struct FakeConfig{X0} <: Common.AbstractConfig{X0} end
struct FakeConfigWithTspan{X0} <: Common.AbstractConfig{X0} end

# Après:
struct FakeConfig{X0} <: Common.AbstractConfig{X0, Common.PointTag, Common.StateTag} end
struct FakeConfigWithTspan{X0} <: Common.AbstractConfig{X0, Common.PointTag, Common.StateTag} end
```

**Ajouter `@testset "Trait Aliases"` :**
```julia
Test.@testset "Trait Aliases" begin
    # Mode aliases
    Test.@test StateEndPointConfig       <: Common.AbstractEndPointConfig
    Test.@test HamiltonianEndPointConfig <: Common.AbstractEndPointConfig
    Test.@test StateTrajectoryConfig  <: Common.AbstractTrajectoryConfig
    Test.@test HamiltonianTrajectoryConfig <: Common.AbstractTrajectoryConfig

    # Content aliases
    Test.@test StateEndPointConfig       <: Common.AbstractStateConfig
    Test.@test StateTrajectoryConfig  <: Common.AbstractStateConfig
    Test.@test HamiltonianEndPointConfig <: Common.AbstractHamiltonianConfig
    Test.@test HamiltonianTrajectoryConfig <: Common.AbstractHamiltonianConfig

    # Negative checks
    Test.@test !(StateEndPointConfig       <: Common.AbstractHamiltonianConfig)
    Test.@test !(HamiltonianEndPointConfig <: Common.AbstractStateConfig)
    Test.@test !(StateEndPointConfig       <: Common.AbstractTrajectoryConfig)
end
```

**Vérifier `tspan` unifié :**
```julia
Test.@testset "tspan unified dispatch" begin
    sp  = Common.StateEndPointConfig(0.0, [1.0], 1.0)
    st  = Common.StateTrajectoryConfig((0.0, 1.0), [1.0])
    hp  = Common.HamiltonianEndPointConfig(0.0, [1.0], [0.5], 1.0)
    ht  = Common.HamiltonianTrajectoryConfig((0.0, 1.0), [1.0], [0.5])

    Test.@test Common.tspan(sp) == (0.0, 1.0)
    Test.@test Common.tspan(st) == (0.0, 1.0)
    Test.@test Common.tspan(hp) == (0.0, 1.0)
    Test.@test Common.tspan(ht) == (0.0, 1.0)
end
```

```bash
julia --project -e 'using Pkg; Pkg.test("CTFlows"; test_args=["suite/common/test_configs"])' \
  2>&1 | tee /tmp/ctflows_step4.log
grep -E "Error|Fail|Test Summary" /tmp/ctflows_step4.log
```

---

## Step 5 — `ext/CTFlowsSciML.jl` (modified)

> 📐 Follow `architecture.md` — DRY : 4 méthodes → 2 via dispatch sur les aliases

**`build_options` — remplacer les 4 méthodes par 2 :**

Supprimer :
- `Integrators.build_options(integ::SciML, config::Common.StateEndPointConfig)`
- `Integrators.build_options(integ::SciML, config::Common.HamiltonianEndPointConfig)`
- `Integrators.build_options(integ::SciML, config::Common.StateTrajectoryConfig)`
- `Integrators.build_options(integ::SciML, config::Common.HamiltonianTrajectoryConfig)`

Remplacer par :
```julia
function Integrators.build_options(integ::SciML, config::Common.AbstractEndPointConfig)
    return integ.options_point
end

function Integrators.build_options(integ::SciML, config::Common.AbstractTrajectoryConfig)
    return integ.options_trajectory
end
```

`build_options(integ::SciML, config::Nothing)` → inchangé.

> ⛔ Do NOT write docstrings in this step.

---

## Step 6 — `src/MultiPhase/calling.jl` (modified)

> 📐 Follow `architecture.md` — DRY : 4 méthodes → 2 via dispatch sur `AbstractStateConfig` / `AbstractHamiltonianConfig`

**`_extract_initial_state` — remplacer les 4 méthodes par 2 :**

Supprimer :
- `_extract_initial_state(config::Common.StateEndPointConfig)`
- `_extract_initial_state(config::Common.StateTrajectoryConfig)`
- `_extract_initial_state(config::Common.HamiltonianEndPointConfig)`
- `_extract_initial_state(config::Common.HamiltonianTrajectoryConfig)`

Remplacer par :
```julia
_extract_initial_state(config::Common.AbstractStateConfig) =
    Common.initial_state(config)

_extract_initial_state(config::Common.AbstractHamiltonianConfig) =
    (Common.initial_state(config), Common.initial_costate(config))
```

> ⛔ Do NOT write docstrings in this step.

---

## Step 7 — `src/Solutions/building.jl` (modified)

> 📐 Follow `architecture.md` — utiliser les aliases là où le dispatch est unique

Les 5 méthodes `build_solution` restent nécessaires (elles combinent système + config). Mettre à jour les signatures :

```julia
# Scalar State Point
build_solution(result, sys::VectorFieldSystem, config::Common.AbstractStateConfig{<:Number, PointTag})
# → return final_state(result)[1]   (PointTag importé ou qualifié)

# Vector State Point
build_solution(result, sys::VectorFieldSystem, config::Common.AbstractEndPointConfig{<:Any, StateTag})
# → return final_state(result)

# State Trajectory
build_solution(result, sys::VectorFieldSystem, config::Common.AbstractTrajectoryConfig{<:Any, StateTag})
# → return VectorFieldSolution(result)

# Hamiltonian Point
build_solution(result, sys::HamiltonianVectorFieldSystem, config::Common.AbstractEndPointConfig{<:Any, HamiltonianTag})
# → return _ham_split_solution(...)

# Hamiltonian Trajectory
build_solution(result, sys::HamiltonianVectorFieldSystem, config::Common.AbstractTrajectoryConfig{<:Any, HamiltonianTag})
# → return HamiltonianVectorFieldSolution(result)
```

Note : `PointTag`, `TrajectoryTag`, `StateTag`, `HamiltonianTag` sont dans `Common`, donc s'écrivent `Common.PointTag` etc. dans ce fichier.

> ⛔ Do NOT write docstrings in this step.

---

## Step 8 — Test Checkpoint: Full test suite

> 🧪 Follow `testing-creation.md` — vérifier exports nouveaux dans `test_common_module.jl`
> ▶️ Follow `testing-execution.md`

Modifier `test/suite/common/test_common_module.jl` :
- Ajouter vérification que `AbstractStateConfig`, `AbstractHamiltonianConfig`, `PointTag`, `TrajectoryTag`, `StateTag`, `HamiltonianTag` sont exportés depuis `Common`

```bash
julia --project -e 'using Pkg; Pkg.test("CTFlows")' 2>&1 | tee /tmp/ctflows_step8.log
grep -E "Error|Fail|Test Summary" /tmp/ctflows_step8.log
```

---

## Step 9 — Docstrings (all modified files)

> 📚 Follow `docstrings.md` — `$(TYPEDEF)` / `$(TYPEDSIGNATURES)`, sections complètes, cross-refs

Fichiers et symboles :

- `src/Common/abstract_tag.jl` — `PointTag`, `TrajectoryTag`, `StateTag`, `HamiltonianTag`
- `src/Common/configs.jl` :
  - `AbstractConfig{X0, Mode, Content}` — documenter les 3 paramètres + les 4 aliases
  - `AbstractEndPointConfig`, `AbstractTrajectoryConfig`, `AbstractStateConfig`, `AbstractHamiltonianConfig` — documenter comme aliases
  - `tspan` (2 méthodes unifiées)
  - `initial_condition` (3 méthodes : scalar state, vector state, hamiltonian)
  - `initial_costate` (2 méthodes : hamiltonian, state→PreconditionError)
- `ext/CTFlowsSciML.jl` — `build_options` (2 méthodes)
- `src/MultiPhase/calling.jl` — `_extract_initial_state` (2 méthodes)
- `src/Solutions/building.jl` — `build_solution` (5 méthodes, signatures mises à jour)

---

## Step 10 — Run tests

> ▶️ Follow `testing-execution.md`

```bash
julia --project -e 'using Pkg; Pkg.test()' 2>&1 | tee /tmp/ctflows_config_trait.log
grep -E "Error|Fail|Test Summary" /tmp/ctflows_config_trait.log
```

Attendu : tous les tests passent, zéro failure, zéro error.

---

## Files summary

**Modified :**
- `src/Common/abstract_tag.jl` — 4 nouveaux struct tags (`modules.md`)
- `src/Common/Common.jl` — exports mis à jour (`modules.md`)
- `src/Common/configs.jl` — hiérarchie redessinée, 12 méthodes → 6 (`architecture.md`, `modules.md`)
- `ext/CTFlowsSciML.jl` — `build_options` 4→2 (`architecture.md`)
- `src/MultiPhase/calling.jl` — `_extract_initial_state` 4→2 (`architecture.md`)
- `src/Solutions/building.jl` — signatures vers aliases (`architecture.md`)
- `test/suite/common/test_configs.jl` — fake types + tests traits (`testing-creation.md`)
- `test/suite/common/test_common_module.jl` — vérification exports (`testing-creation.md`)

**New :** aucun

**Deleted :** aucun (les méthodes supprimées sont remplacées, pas des fichiers)
