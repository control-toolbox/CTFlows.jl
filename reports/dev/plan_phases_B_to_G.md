# Plan: refactor traits / paramétrage / dispatch — phases B → G

Plan dérivé de [`action_plan.md`](action_plan.md) et conforme au gabarit
[`dev/planning.md`](../../dev/planning.md). Couvre les phases **B à G** en un seul
document. La phase **A** (nettoyage des exceptions) est indépendante et traitée à part.

## What and why

Aligner `Flows` et `Systems` sur le modèle déjà en place dans `Configs` : **un type abstrait
par nom, un paramètre de trait par axe orthogonal, dispatch via extracteur**. La séquence va
du moins risqué (renommage mécanique) au plus structurel (tuple multiphase) :

```text
B. dynamics rename → C. Systems param. → D. Flows param. + merge
                                                ↓
        G. Data (dispatch abstrait) ← F. MultiPhase ← E. Interfaces & dispatch
```

Chaque phase est **testable indépendamment** et protégée par des **alias** qui préservent
les noms publics (sauf le renommage net de la phase B). Les docstrings ne sont **pas**
retouchées pendant l'implémentation — elles sont rédigées en dernier ; seuls les `@ref`
cassés par un renommage sont corrigés au fil de l'eau.

## Décisions de conception (validées)

1. **AD n'est plus un paramètre de type.** `AbstractHamiltonianSystem{TD,VD,AT}` perd `AT`
   dès la **phase C** ; `ad_trait` devient un trait extrait défini sur les types concrets.
   Cohérent avec l'action plan (« fold the AD axis back into `ad_trait` ») et avec la
   philosophie. Cela anticipe une partie de la phase E, d'où ce plan élargi.
2. **Pas d'alias de rétro-compatibilité** pour les anciens noms de traits (renommage net en B).
3. **Le périmètre de l'axe dynamique s'arrête à `Flows`/`Systems`.** `Data` et `Solutions`
   **ne sont pas** paramétrés par `D` (noms distincts, structures différentes — voir la note
   de périmètre dans l'action plan, §G).

## Scope global

- **API publique** : oui.
  - B : renommages de traits + `content_trait`→`dynamics_trait`.
  - C : `AbstractSystem` gagne un 3ᵉ paramètre `D` ; `AbstractStateSystem`/
    `AbstractHamiltonianSystem` deviennent des **alias** ; `AbstractHamiltonianSystem` perd `AT`.
  - D : `AbstractFlow` gagne `D` ; `StateFlow`/`HamiltonianFlow` fusionnent en `Flow` (alias
    conservés).
  - E : `build_system` accepte des entrées abstraites ; méthodes d'interface définies sur
    les types abstraits.
  - F : champ `flows` de MultiPhase devient un `Tuple` (lève la contrainte de type homogène).
  - G : `Systems` consomme les types `Data` abstraits ; extracteur constant optionnel.

---

## Phase B — Rename `content` → `dynamics`

Mapping :

| Actuel | Cible |
|---|---|
| `AbstractContentTrait` | `AbstractDynamicsTrait` |
| `StateTrait` | `StateDynamics` |
| `HamiltonianTrait` | `HamiltonianDynamics` |
| `AugmentedHamiltonianTrait` | `AugmentedHamiltonianDynamics` |
| `content_trait(·)` | `dynamics_trait(·)` (Configs) |

Steps :
1. `git mv src/Traits/content.jl src/Traits/dynamics.jl` ; renommer les 4 types
   (noms + `@ref` internes uniquement).
2. [Traits.jl](../../src/Traits/Traits.jl) : `include("dynamics.jl")`, exports, ligne
   « Content type » de la docstring module.
3. [Traits/abstract.jl](../../src/Traits/abstract.jl), [Traits/mode.jl](../../src/Traits/mode.jl) :
   références `AbstractContentTrait`/`StateTrait`/`HamiltonianTrait` (exemples + `@ref`).
4. Consommateurs :
   - [Configs/abstract.jl](../../src/Configs/abstract.jl) : paramètre `Content`→`Dyn`, borne
     `<:Traits.AbstractDynamicsTrait`, alias, extracteur `content_trait`→`dynamics_trait`.
   - [Configs/concrete.jl](../../src/Configs/concrete.jl) : `Traits.StateTrait`→`Traits.StateDynamics`, etc.
   - [Configs/Configs.jl](../../src/Configs/Configs.jl) : export + docstring module.
   - [Solutions/building.jl](../../src/Solutions/building.jl) : `::Type{Traits.StateTrait}`→`::Type{Traits.StateDynamics}` (+ Ham./Augmented).
   - [Flows/calling.jl:256](../../src/Flows/calling.jl#L256) : `Configs.content_trait`→`Configs.dynamics_trait`.
5. Tests : `git mv test/suite/traits/test_content.jl test_dynamics.jl` + maj noms ; maj
   références dans `traits/test_traits_module.jl`, `configs/*`,
   `solutions/test_building_solutions.jl`, `flows/*`,
   `multiphase/test_calling_multiphase.jl`, `extensions/test_sciml_extension.jl`.
6. [docs/api_reference.jl:39](../../docs/api_reference.jl#L39) : `"content.jl"`→`"dynamics.jl"`.

Checkpoint : suites `traits`, `configs`, `solutions`, `flows` via MCP, puis suite complète.

---

## Phase C — Paramétrer les systèmes par la dynamique

Steps :
1. [Systems/abstract_system.jl](../../src/Systems/abstract_system.jl) :
   - `abstract type AbstractSystem{TD<:Traits.TimeDependence, VD<:Traits.VariableDependence, D<:Traits.AbstractDynamicsTrait} end`.
   - `const AbstractStateSystem{TD,VD} = AbstractSystem{TD,VD,Traits.StateDynamics}`.
   - `const AbstractHamiltonianSystem{TD,VD} = AbstractSystem{TD,VD,Traits.HamiltonianDynamics}`
     (suppression du paramètre `AT`).
   - Extracteur `Traits.dynamics_trait(::AbstractSystem{TD,VD,D}) where {TD,VD,D} = D`.
   - Adapter `time_dependence`/`variable_dependence` au 3ᵉ paramètre.
2. Types concrets — clauses de supertype :
   - [vector_field_system.jl:36](../../src/Systems/vector_field_system.jl#L36) :
     `<: AbstractStateSystem{TD,VD}` (l'alias absorbe, inchangé en pratique).
   - [hamiltonian_system.jl:47](../../src/Systems/hamiltonian_system.jl#L47) :
     `<: AbstractHamiltonianSystem{TD,VD}` (retrait de `Traits.WithAD`).
   - [hamiltonian_vector_field_system.jl:41](../../src/Systems/hamiltonian_vector_field_system.jl#L41) :
     `<: AbstractHamiltonianSystem{TD,VD}` (retrait de `Traits.WithoutAD`).
3. **AD redevient un trait extrait** :
   - Supprimer `Traits.ad_trait(::AbstractHamiltonianSystem{TD,VD,AT}) = AT`.
   - Ajouter `Traits.ad_trait(::HamiltonianSystem) = Traits.WithAD` et
     `Traits.ad_trait(::HamiltonianVectorFieldSystem) = Traits.WithoutAD`.
   - Défaut `ad_trait(::Any) = WithoutAD` ([Traits/ad.jl:127](../../src/Traits/ad.jl#L127)) inchangé.
   - ⚠️ [Flows/abstract_flow.jl:85](../../src/Flows/abstract_flow.jl#L85) :
     `AbstractHamiltonianFlow{...,S<:Systems.AbstractHamiltonianSystem{TD,VD,<:Traits.AbstractADTrait}}`
     → retirer le 3ᵉ argument (`{TD,VD}`). À faire ici car ça casse à la compilation.
4. [Systems/Systems.jl](../../src/Systems/Systems.jl) : exporter `dynamics_trait` (cohérence Configs).
5. Vérifier l'extension SciML : `SciMLFunctionSystem <: AbstractStateSystem{NonAutonomous,NonFixed}`
   compile verbatim (alias arité 2). Aucune édition attendue.

Checkpoint : suite `systems`, puis `differentiation`/`extensions`, puis suite complète.

---

## Phase D — Paramétrer les flots + fusionner les types concrets

Steps :
1. [Flows/abstract_flow.jl](../../src/Flows/abstract_flow.jl) — **un seul nom abstrait, `D`
   comme paramètre d'axe, sur le modèle `Configs`** (option (b), tranchée) :
   - `abstract type AbstractFlow{TD,VD,D<:Traits.AbstractDynamicsTrait} end`.
   - `const AbstractStateFlow{TD,VD} = AbstractFlow{TD,VD,Traits.StateDynamics}` (perd `S`).
   - `const AbstractHamiltonianFlow{TD,VD} = AbstractFlow{TD,VD,Traits.HamiltonianDynamics}` (perd `S`).
   - Le couplage flot↔système est préservé **structurellement** par le partage de `D` au
     niveau concret (`S<:AbstractSystem{TD,VD,D}` ⇒ un `StateFlow` force
     `S<:AbstractStateSystem{TD,VD}`). Inutile de porter `S` dans le type abstrait.
   - Extracteur `Traits.dynamics_trait(::AbstractFlow{TD,VD,D}) = D`.
   - Adapter `time_dependence`/`variable_dependence`.
   - `ad_trait(f::AbstractHamiltonianFlow)` délègue au système — inchangé (alias 2 params).
2. [Flows/flow.jl](../../src/Flows/flow.jl) : fusionner `StateFlow`/`HamiltonianFlow` en
   `struct Flow{TD,VD,D,S<:Systems.AbstractSystem{TD,VD,D},I<:Integrators.AbstractIntegrator} <: AbstractFlow{TD,VD,D}`
   (champs `system::S`, `integrator::I`), + alias
   `const StateFlow{TD,VD,S,I} = Flow{TD,VD,Traits.StateDynamics,S,I}` et
   `const HamiltonianFlow{TD,VD,S,I} = Flow{TD,VD,Traits.HamiltonianDynamics,S,I}`.
   - `system`/`integrator`/`build_flow` : définir une fois sur `Flow` (les méthodes par type
     fusionnent). Les deux `build_flow` actuels deviennent un seul (dispatch sur le système
     via `dynamics_trait`).
   - `Systems.hamiltonian_vector_field(flow::HamiltonianFlow{...})` : les 2 overloads
     restent valides (l'alias matche).
3. [Flows/calling.jl](../../src/Flows/calling.jl) : signatures d'appel sur les alias
   (`AbstractStateFlow`/`AbstractHamiltonianFlow`) — quasi inchangées.
4. [Flows/registry.jl](../../src/Flows/registry.jl), [Flows/building.jl](../../src/Flows/building.jl),
   [Flows/flow_routing.jl](../../src/Flows/flow_routing.jl) : adapter toute référence directe à
   `StateFlow`/`HamiltonianFlow` comme **types concrets** (constructeurs → restent OK via alias).
5. MultiPhase (transition) : [multiphase_flow.jl:33-80](../../src/MultiPhase/multiphase_flow.jl#L33-L80)
   référence `Flows.StateFlow{TD,VD,S,I}`/`HamiltonianFlow{TD,VD,S,I}` dans le champ `flows::Vector{...}`
   — reste compilable via alias (le refactor du conteneur est en phase F).

Checkpoint : suites `flows`, `extensions`, `multiphase`, puis suite complète.

---

## Phase E — Interfaces & dispatch sur les types abstraits

Steps :
1. [Systems/building.jl](../../src/Systems/building.jl) : `build_system` accepte des entrées
   **abstraites** :
   - `build_system(::Data.AbstractVectorField)`, `(::Data.AbstractHamiltonianVectorField)`,
     `(::Data.AbstractHamiltonian, backend)` au lieu des types concrets.
2. [Systems/hamiltonian_getter.jl](../../src/Systems/hamiltonian_getter.jl),
   [hamiltonian_system.jl](../../src/Systems/hamiltonian_system.jl),
   [hamiltonian_vector_field_system.jl](../../src/Systems/hamiltonian_vector_field_system.jl) :
   définir `hamiltonian_vector_field`/`build_rhs`/`build_oop_rhs`/`rhs` **une fois** sur
   `AbstractHamiltonianSystem`/`AbstractStateSystem`, brancher sur `Traits.ad_trait(sys)`
   (et `Traits.mutability`) plutôt que sur les types concrets. Conserver le comportement.
3. Stubs `NotImplemented` sur les types abstraits pour les méthodes de contrat (déjà présents
   pour `rhs`/`rhs_oop` ; compléter si besoin).
4. **Ne pas** introduire de nouveau type abstrait (pas de `AbstractSystemWithAD`) — AD est un trait.

Checkpoint : suites `systems`, `differentiation`, `extensions`, puis suite complète.

---

## Phase F — MultiPhase : tuple + contrainte de dynamique

Steps :
1. [MultiPhase/multiphase_flow.jl](../../src/MultiPhase/multiphase_flow.jl) : champ
   `flows::Tuple{Vararg{Flows.AbstractFlow{TD,VD,D}}}` au lieu de `Vector{Flow{TD,VD,S,I}}`
   (lève la contrainte de `S`/`I` homogènes). Adapter les paramètres de type des deux structs.
2. [MultiPhase/concatenation.jl](../../src/MultiPhase/concatenation.jl) : `*` construit un
   **tuple** : `(get_flows(f1)..., get_flows(f2)...)` au lieu de `vcat`.
3. Méthodes `*` explicites pour l'erreur état × Hamiltonien (`PreconditionError`).
4. `_handoff` : vérification dimensionnelle au runtime (`PreconditionError`).
5. `get_flows`/`get_systems`/`get_integrators` : retours adaptés (tuple).

Checkpoint : suite `multiphase`, puis suite complète.

---

## Phase G — Data : dispatch abstrait

Steps :
1. S'assurer que `Systems` consomme `Data.AbstractVectorField`/`AbstractHamiltonian` plutôt
   que les types concrets là où c'est pertinent (suite de la phase E — surtout vérification).
2. Confirmer que les constructeurs typés (`VectorField(f, TD, VD, MD)`, etc.) sont en place.
3. Extracteur constant **optionnel** `Traits.dynamics_trait(::AbstractVectorField) = StateDynamics`
   (une ligne, aucune modif de struct) — uniquement si un consommateur le requiert.

> Périmètre : `Data`/`Solutions` ne reçoivent **pas** de paramètre `D`. Voir la note détaillée
> dans [`action_plan.md`](action_plan.md) (§ « Scope boundary »).

Checkpoint : suites `data`, `systems`, puis suite complète.

---

## Décision tranchée (phase D) — option (b)

Les abstraits intermédiaires `AbstractStateFlow`/`AbstractHamiltonianFlow` **deviennent des
alias 2-paramètres** de `AbstractFlow{TD,VD,Dyn}` (perte du paramètre `S`), exactement comme
`AbstractStateConfig` dans `Configs`. Le couplage flot↔système est préservé structurellement
par le partage de `D` dans le `Flow{TD,VD,D,S,I}` concret (`S<:AbstractSystem{TD,VD,D}`). C'est
l'état cible aligné sur le principe « un type abstrait par nom » du `CLAUDE.md`.

Conséquence : les signatures de dispatch passant `AbstractStateFlow{TD,VD,S}` (3 params)
passent à `{TD,VD}` (2 params) ; `S` s'obtient via `system(flow)`. Churn concentré dans
`calling.jl` et les types MultiPhase (ces derniers retravaillés en phase F).

## Human checkpoints

- ⛔ Demander avant **tout commit** — un commit par phase, après checkpoint vert.
- ⛔ Demander avant tout push sur `develop`.
- ⛔ Demander si une décision de conception non prévue surgit.

## Out of scope
- Phase **A** (exceptions) — indépendante, traitée séparément.
- Rédaction/réécriture des docstrings : **dernière étape**, une fois l'API stabilisée (après G).
  Pendant B→G, seuls les `@ref` cassés par un renommage sont corrigés.
- Toute évolution de `Data`/`Solutions` au-delà des points listés en G.
