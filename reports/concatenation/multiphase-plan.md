# Implémentation de la Concaténation de Flots (MultiPhase)

Ce plan implémente l'intégration séquentielle exacte pour la concaténation de flots, en ajoutant une hiérarchie `AbstractStateSystem`/`AbstractHamiltonianSystem`, deux configs hamiltoniens, `StateFlow`/`HamiltonianFlow` en remplacement de `Flow`, et un nouveau submodule `MultiPhase` dédié à la concaténation.

## Ce qui change et pourquoi

- **`Systems`** : `AbstractStateSystem` et `AbstractHamiltonianSystem` sous `AbstractSystem`. `VectorFieldSystem <: AbstractStateSystem`. Permet la contrainte compile-time sur `S` dans `AbstractStateFlow` / `AbstractHamiltonianFlow`.
- **`Common`** : `HamiltonianPointConfig(t0, x0, p0, tf)` et `HamiltonianTrajectoryConfig(tspan, x0, p0)`. `initial_condition` retourne `vcat(x0, p0)`.
- **`Flows`** : `AbstractStateFlow{TD,VD,S<:AbstractStateSystem}` et `AbstractHamiltonianFlow{TD,VD,S<:AbstractHamiltonianSystem}`. `Flow` renommé en `StateFlow`, `HamiltonianFlow` créé. `build_flow` dispatche selon le type de `sys`.
- **`MultiPhase`** : Nouveau submodule (`src/MultiPhase/`). Contient `MultiPhaseSystem`, `MultiPhaseIntegrator` (wrappers passifs pour le contrat `AbstractFlow`), `MultiPhaseStateFlow`, `MultiPhaseHamiltonianFlow`, opérateurs `*`, et `call()` séquentiel.
- **Tests** : 7 fichiers existants à mettre à jour (`Flow` → `StateFlow`). 1 nouveau fichier de tests MultiPhase.

## Graphe de dépendances après modification

```text
Common  (+ HamiltonianPointConfig, HamiltonianTrajectoryConfig)
  ├── Data
  ├── Systems  (+ AbstractStateSystem, AbstractHamiltonianSystem)
  ├── Integrators
  ├── Solutions
  ├── Flows  (+ AbstractStateFlow, AbstractHamiltonianFlow, StateFlow, HamiltonianFlow)
  └── MultiPhase  (dépend de Flows, Systems, Integrators, Common)
```

---

### Step 0 — Branch

```bash
git checkout main && git pull
git checkout -b feature/multiphase-concatenation
```

---

## Phase 1 — Hiérarchie Systems et Common

### Step 1 — `src/Systems/abstract_system.jl`

> 📐 Follow `architecture.md` — OCP: nouvelles abstractions sans modifier le contrat existant.
> 🏗️ Follow `modules.md` — pas d'exports ici, uniquement dans le manifest.

- Ajouter `abstract type AbstractStateSystem{TD, VD} <: AbstractSystem{TD, VD} end`
- Ajouter `abstract type AbstractHamiltonianSystem{TD, VD} <: AbstractSystem{TD, VD} end`

> ⛔ Pas de docstrings dans cette étape.

### Step 2 — `src/Systems/Systems.jl`

> 🏗️ Follow `modules.md` — Exports en fin de manifest.

- Ajouter `AbstractStateSystem`, `AbstractHamiltonianSystem` à l'`export`.

### Step 3 — `src/Systems/vector_field_system.jl`

> 📐 Follow `architecture.md` — LSP: sous-type concret doit honorer le contrat du parent.

- Changer `struct VectorFieldSystem{...} <: AbstractSystem{TD, VD}` en `<: AbstractStateSystem{TD, VD}`.

### Step 4 — `src/Common/configs.jl`

> 📐 Follow `architecture.md` — ISP: configs Hamiltoniens séparés.

- Ajouter `struct HamiltonianPointConfig{T0, X0, P0, TF} <: AbstractConfig{X0}` avec champs `t0, x0, p0, tf`.
- Ajouter `struct HamiltonianTrajectoryConfig{TS, X0, P0} <: AbstractConfig{X0}` avec champs `tspan, x0, p0`.
- Implémenter `tspan` pour les deux nouveaux types.
- Implémenter `initial_condition` : retourne `vcat(c.x0, c.p0)`.
- Implémenter `Base.show` pour les deux.

### Step 5 — `src/Common/Common.jl`

> 🏗️ Follow `modules.md` — Exports en fin de manifest.

- Ajouter `HamiltonianPointConfig`, `HamiltonianTrajectoryConfig` à l'`export`.

### Step 6 — Test checkpoint 1 : Systems + Common

> 🧪 Follow `testing-creation.md` — structs fakes au top-level.
> ▶️ Follow `testing-execution.md`.

- Dans `test/suite/systems/test_abstract_system.jl` : ajouter `FakeStateSystem <: Systems.AbstractStateSystem` et `FakeHamiltonianSystem <: Systems.AbstractHamiltonianSystem` au top-level ; ajouter `@testset "Hierarchy"` vérifiant les relations de sous-typage.
- Lancer les tests ciblés :

```bash
julia --project -e 'using Pkg; Pkg.test("CTFlows"; test_args=["suite/systems", "suite/common"])' \
  2>&1 | tee /tmp/ctflows_phase1.log
grep -E "Error|Fail|Test Summary" /tmp/ctflows_phase1.log
```

---

## Phase 2 — Hiérarchie Flows

### Step 7 — `src/Flows/abstract_flow.jl`

> 📐 Follow `architecture.md` — OCP: nouvelles abstractions sans modifier `AbstractFlow`.
> 🏗️ Follow `modules.md` — pas d'exports ici.

- Ajouter `abstract type AbstractStateFlow{TD, VD, S<:Systems.AbstractStateSystem{TD,VD}} <: AbstractFlow{TD, VD} end`
- Ajouter `abstract type AbstractHamiltonianFlow{TD, VD, S<:Systems.AbstractHamiltonianSystem{TD,VD}} <: AbstractFlow{TD, VD} end`

### Step 8 — `src/Flows/flow.jl`

> 📐 Follow `architecture.md` — Multiple Dispatch: deux callables distincts selon le type de flot.

- Renommer `struct Flow{TD,VD,S<:Systems.AbstractSystem,I} <: AbstractFlow` en `struct StateFlow{TD,VD,S<:Systems.AbstractStateSystem{TD,VD},I} <: AbstractStateFlow{TD,VD,S}` (champs `system::S`, `integrator::I` inchangés).
- Ajouter `struct HamiltonianFlow{TD,VD,S<:Systems.AbstractHamiltonianSystem{TD,VD},I} <: AbstractHamiltonianFlow{TD,VD,S}` (mêmes champs).
- Adapter `system`, `integrator`, `build_flow` pour les deux structs :
  - `build_flow(sys::Systems.AbstractStateSystem, int)` → `StateFlow(sys, int)`
  - `build_flow(sys::Systems.AbstractHamiltonianSystem, int)` → `HamiltonianFlow(sys, int)`
- Adapter le callable `StateFlow` : `(f::StateFlow)(t0, x0, tf; ...)` → `Common.PointConfig`.
- Ajouter les callables `HamiltonianFlow` : `(f)(t0, x0, p0, tf; ...)` → `Common.HamiltonianPointConfig` et `(f)(tspan, x0, p0; ...)` → `Common.HamiltonianTrajectoryConfig`.

### Step 9 — `src/Flows/building.jl`

> 🏗️ Follow `modules.md` — entry point générique, pas de logique de dispatch ici.

- **Garder** `function Flow(data::Data.VectorField; opts...)` **inchangé** (délègue à `build_flow` qui dispatche).

### Step 10 — `src/Flows/Flows.jl`

> 🏗️ Follow `modules.md` — Exports en fin de manifest.

- Remplacer `export AbstractFlow, Flow` par `export AbstractFlow, AbstractStateFlow, AbstractHamiltonianFlow, Flow, StateFlow, HamiltonianFlow`. (`Flow` reste exporté : c'est la fonction publique `Flow(vf; opts...)`)
- Le reste des exports (`system`, `integrator`, `call`, `build_flow`) est inchangé.

### Step 11 — Test checkpoint 2 : Flows

> 🧪 Follow `testing-creation.md` — renommage Flow → StateFlow dans tous les tests existants.
> ▶️ Follow `testing-execution.md`.

- Remplacer `Flow` par `StateFlow` dans les 7 fichiers de tests impactés :
  - `test/suite/flows/test_flow.jl`, `test_abstract_flow.jl`, `test_flow_module.jl`, `test_building_flows.jl`, `test_calling.jl`
  - `test/suite/extensions/test_forwarddiff_extension.jl`, `test_sciml_extension.jl`
- Lancer les tests ciblés :

```bash
julia --project -e 'using Pkg; Pkg.test("CTFlows"; test_args=["suite/flows", "suite/extensions"])' \
  2>&1 | tee /tmp/ctflows_phase2.log
grep -E "Error|Fail|Test Summary" /tmp/ctflows_phase2.log
```

---

## Phase 3 — Submodule MultiPhase

### Step 12 — `src/CTFlows.jl` + `src/MultiPhase/MultiPhase.jl` (new)

> 🏗️ Follow `modules.md` — Chargement topologique : MultiPhase après Flows.

- Créer `src/MultiPhase/MultiPhase.jl` avec `module MultiPhase` :
  - Imports : `Common`, `Systems`, `Integrators`, `Flows`, `DocStringExtensions`, `CTBase.Exceptions`
  - `include` pour les 5 fichiers suivants (Steps 13–16)
  - Exports : `MultiPhaseSystem`, `MultiPhaseIntegrator`, `MultiPhaseStateFlow`, `MultiPhaseHamiltonianFlow`
- Dans `src/CTFlows.jl` : ajouter `include`/`using .MultiPhase` après `using .Flows`.

### Step 13 — `src/MultiPhase/multiphase_system.jl` + `multiphase_integrator.jl` (new)

> 📐 Follow `architecture.md` — SRP: wrappers passifs.

- `MultiPhaseSystem{TD,VD,S<:Systems.AbstractSystem{TD,VD}} <: Systems.AbstractSystem{TD,VD}` : champs `phases::Vector{S}`, `switching_times::Vector{<:Real}` + `Base.show`.
- `MultiPhaseIntegrator{I<:Integrators.AbstractIntegrator}` : champ `phases::Vector{I}` + `Base.show`.

### Step 14 — `src/MultiPhase/multiphase_flow.jl` (new)

> 📐 Follow `architecture.md` — Parametric types.
> 🏗️ Follow `modules.md` — Qualification des symboles siblings.

- `MultiPhaseStateFlow{TD,VD,F<:Flows.AbstractStateFlow{TD,VD,S},S} <: Flows.AbstractStateFlow{TD,VD,S}` : `phases`, `switching_times`, `jumps::Vector{Union{Nothing,Any}}`.
- `MultiPhaseHamiltonianFlow{...} <: Flows.AbstractHamiltonianFlow{...}` : mêmes champs, `jumps::Vector{Union{Nothing,Tuple{...}}}`.
- `Flows.system` et `Flows.integrator` retournent les wrappers `MultiPhaseSystem`/`MultiPhaseIntegrator`.
- Callables `(f)(t0, x0, tf; ...)` et `(f)(tspan, x0; ...)` déléguant à `call` (pour les deux types).

### Step 15 — `src/MultiPhase/concatenation.jl` (new)

> 📐 Follow `architecture.md` — OCP: extension via multiple dispatch.
> ⚠️ Follow `exceptions.md` — `IncorrectArgument` pour temps non croissants.

- `_flatten_phases`, `_flatten_times`, `_flatten_jumps` (dispatch `MultiPhase*Flow` vs `Abstract*Flow`).
- `_validate_switching_times` : throw `IncorrectArgument`.
- `Base.:*` pour `AbstractStateFlow` : 2 variants (sans saut, avec `Δx`).
- `Base.:*` pour `AbstractHamiltonianFlow` : 3 variants (sans saut, `Δp`, `(Δx, Δp)`).

### Step 16 — `src/MultiPhase/calling.jl` (new)

> 📐 Follow `architecture.md` — SRP.
> ⚠️ Follow `exceptions.md` — stub `_build_merged_solution` throw `ExtensionError`.
> 🔬 Follow `type-stability.md` — pré-allouer `t_all`/`u_all`.

- `_make_phase_config`, `_extract_final_state`, `_apply_jump` (dispatch State vs Hamiltonian).
- `call(flow, ::PointConfig)` : boucle séquentielle.
- `call(flow, ::TrajectoryConfig)` : fusion progressive.
- Stub `_build_merged_solution` → `ExtensionError`.

### Step 17 — `ext/CTFlowsSciMLExt.jl`

> 🏗️ Follow `modules.md` — Qualification `CTFlows.MultiPhase._build_merged_solution`.

- Implémenter `CTFlows.MultiPhase._build_merged_solution(t, u, flow)` via `SciMLBase.build_solution`.

### Step 18 — Test checkpoint 3 : MultiPhase

> 🧪 Follow `testing-creation.md` — fakes au top-level, catégories séparées.
> ▶️ Follow `testing-execution.md`.

Créer `test/suite/multiphase/test_multiphase.jl` :

- Top-level : `FakeStateSystem <: Systems.AbstractStateSystem` + `Systems.rhs` ; `FakeStateFlow <: Flows.AbstractStateFlow` + `Flows.system`, `Flows.integrator`.
- `@testset "Wrappers"` : `MultiPhaseSystem`, `MultiPhaseIntegrator`, `show`.
- `@testset "Concatenation"` : `*` sans saut, avec saut, chaînage 3 phases, aplatissement.
- `@testset "Type constraints"` : types `S` différents → `MethodError`.
- `@testset "Validation"` : temps non croissants → `IncorrectArgument`.
- `@testset "call PointConfig"` et `@testset "call TrajectoryConfig"` avec flot trivial.
- `@testset "Extension stub"` : `_build_merged_solution` → `ExtensionError`.

```bash
julia --project -e 'using Pkg; Pkg.test("CTFlows"; test_args=["suite/multiphase"])' \
  2>&1 | tee /tmp/ctflows_phase3.log
grep -E "Error|Fail|Test Summary" /tmp/ctflows_phase3.log
```

---

## Phase 4 — Docstrings (quand tous les tests passent)

### Step 19 — Docstrings (tous les fichiers modifiés)

> 📚 Follow `docstrings.md` — `$(TYPEDEF)` / `$(TYPEDSIGNATURES)`, sections complètes, exemples sûrs.

- `src/Systems/abstract_system.jl` — `AbstractStateSystem`, `AbstractHamiltonianSystem`
- `src/Common/configs.jl` — `HamiltonianPointConfig`, `HamiltonianTrajectoryConfig`, `tspan`, `initial_condition`, `Base.show`
- `src/Flows/abstract_flow.jl` — `AbstractStateFlow`, `AbstractHamiltonianFlow`
- `src/Flows/flow.jl` — `StateFlow`, `HamiltonianFlow`, callables, `build_flow`
- `src/MultiPhase/*.jl` — tous les types et fonctions publics exportés

### Step 20 — Vérification finale

> ▶️ Follow `testing-execution.md`.

```bash
julia --project -e 'using Pkg; Pkg.test("CTFlows")' 2>&1 | tee /tmp/ctflows_final.log
grep -E "Error|Fail|Test Summary" /tmp/ctflows_final.log
```

---

## Files summary

**New**:
- `src/MultiPhase/MultiPhase.jl`
- `src/MultiPhase/multiphase_system.jl`
- `src/MultiPhase/multiphase_integrator.jl`
- `src/MultiPhase/multiphase_flow.jl`
- `src/MultiPhase/concatenation.jl`
- `src/MultiPhase/calling.jl`
- `test/suite/multiphase/test_multiphase.jl`

**Modified**:
- `src/CTFlows.jl` — ajout de MultiPhase (`modules.md`)
- `src/Systems/abstract_system.jl` — +2 abstract types (`architecture.md`)
- `src/Systems/Systems.jl` — exports (`modules.md`)
- `src/Systems/vector_field_system.jl` — héritage (`architecture.md`)
- `src/Common/configs.jl` — +2 config types (`architecture.md`)
- `src/Common/Common.jl` — exports (`modules.md`)
- `src/Flows/abstract_flow.jl` — +2 abstract types (`architecture.md`)
- `src/Flows/flow.jl` — renommage + HamiltonianFlow (`architecture.md`)
- `src/Flows/building.jl` — dispatch build_flow (`modules.md`)
- `src/Flows/Flows.jl` — exports (`modules.md`)
- `ext/CTFlowsSciMLExt.jl` — _build_merged_solution (`modules.md`)
- 7 fichiers de tests flows/extensions — renommage Flow→StateFlow

**Deleted**: aucun
