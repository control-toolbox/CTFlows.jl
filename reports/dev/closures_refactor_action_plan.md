# Plan: éliminer les closures de différentiation (callable structs)

> Plan d'action exécutable suivant [`dev/planning.md`](../../dev/planning.md).
> Conception détaillée et code de référence : [`closures_refactor_plan.md`](closures_refactor_plan.md).
> Inventaire : [`closures_audit.md`](closures_audit.md).

## What and why

Remplacer les closures de différentiation de `DifferentialGeometry` (et les helpers de
réordonnancement d'arguments de l'extension DI) par des **callable structs**. But :
stabilité de type, suppression du world-age, zéro allocation de closure par évaluation sur
le chemin chaud des intégrateurs, et cohérence avec `dev/philosophy/types-traits-interfaces.md`.
On introduit deux primitives de contrat AD (`differentiate`, `pushforward`) + un functor de
réinsertion d'argument (`WithActiveArg`) qui unifient tous les sites.

## Scope

- **Files added**:
  - `src/Differentiation/arg_placement.jl` (`WithActiveArg`)
  - `test/suite/differentiation/test_arg_placement.jl` (+ tests primitives)
- **Files modified**:
  - `src/Differentiation/abstract_ad_backend.jl` (stubs `differentiate`, `pushforward`)
  - `src/Differentiation/Differentiation.jl` (include + exports)
  - `ext/CTFlowsDifferentiationInterface.jl` (impl primitives + `h_x/h_p/h_v` → `WithActiveArg`)
  - `src/DifferentialGeometry/lift.jl`, `poisson.jl`, `time_derivative.jl`, `ad.jl`
  - `src/Solutions/hamiltonian_vector_field_solution.jl`
- **Files deleted**: aucun.
- **Public API changes**: **non** pour les noms publics (`Lift`, `Poisson`, `∂ₜ`, `ad`,
  `state`, `costate` inchangés). **Oui** (ajout only) : nouveaux exports internes
  `Differentiation.{differentiate, pushforward, WithActiveArg}`.

## Phases

### Phase A — Primitives core + implémentation extension
Steps:
1. Créer `src/Differentiation/arg_placement.jl` : struct `WithActiveArg{F,Slot}`,
   constructeurs (`::Val{Slot}` et `::Integer`), méthode `@generated` (cf. annexe A.1).
2. `src/Differentiation/Differentiation.jl` : `include("arg_placement.jl")` (avant
   `abstract_ad_backend.jl`) ; `export WithActiveArg, differentiate, pushforward`.
3. `src/Differentiation/abstract_ad_backend.jl` : ajouter les stubs `differentiate(backend,
   f, ::Val{Slot}, active, consts...)` et `pushforward(backend, f, ::Val{Slot}, x, dx,
   consts...)` (style `NotImplemented` existant, cf. annexe A.2).
4. `ext/CTFlowsDifferentiationInterface.jl` : implémenter `Differentiation.differentiate` et
   `Differentiation.pushforward` (réutilisent `_derivator`, `DI.Constant`, `DI.pushforward`
   + `only`, cf. annexe A.3).
5. Ajouter `test/suite/differentiation/test_arg_placement.jl` : `WithActiveArg` (réinsertion
   + `@inferred`) et `differentiate`/`pushforward` vs dérivées analytiques (`H=½‖p‖²+‖x‖²`,
   champ linéaire `A·x`). **Fake types au top-level** du fichier de test.
Checkpoint: `test/suite/differentiation` via MCP — vert avant de continuer.

### Phase B — Sites sans AD (risque nul)
Steps:
1. `src/DifferentialGeometry/lift.jl` : `LiftedHamiltonian{TF,TD,VD} <: Function` + 4 call
   methods ; `_Lift` renvoie le functor (annexe A.4).
2. `src/Solutions/hamiltonian_vector_field_solution.jl` : `StateProjection`/`CostateProjection`
   (`<: Function`) ; `state`/`costate` renvoient les functors (annexe A.5).
Checkpoint: `test/suite/differential_geometry` + `test/suite/solutions` — vert.

### Phase C — Réordonnancement interne de l'extension DI
Steps:
1. `ext/CTFlowsDifferentiationInterface.jl` : remplacer les closures `h_x/h_p/h_v` par
   `Differentiation.WithActiveArg(h, Val(2/3/4))` dans `prepare_cache` et `update!` ; le
   cache `_DifferentiationInterfaceCache` stocke les functors.
2. Chemins non cachés (`::Nothing`) de `hamiltonian_gradient`/`variable_gradient` : déléguer
   à `Differentiation.differentiate` (annexe A.3).
Checkpoint: `test/suite/differentiation` + `test/suite/systems` + `test/suite/extensions` — vert.

### Phase D — Partielles (poisson, time_derivative)
Steps:
1. `src/DifferentialGeometry/poisson.jl` : `PoissonBracket{TH,TG,TB,TD,VD} <: Function` + 4
   call methods (slots explicites) ; `_Poisson` renvoie le functor (annexe A.6).
2. `src/DifferentialGeometry/time_derivative.jl` : helper `_zero_like` ; `TimeDerivFunction`
   pour `∂ₜ(::Function)` ; functors `TimeDerivHVF/TimeDerivVF/TimeDerivHam` (`<: Function`,
   param. TD source + VD) ; `_∂ₜ_*` renvoient les functors (annexe A.7).
Checkpoint: `test/suite/differential_geometry` — vert (Poisson + ∂ₜ).

### Phase E — JVP (ad.jl)
Steps:
1. `src/DifferentialGeometry/ad.jl` : `Ad{TX,TF,TB,TD,VD} <: Function` + 4 call methods
   (pushforward de `foo`) ; remplacer `_ad_result` par `_ad_bracket` (1 méthode scalaire +
   4 vectorielles, 2ᵉ pushforward de `X`) ; `_ad` renvoie le functor (annexe A.8).
2. Vérifier que `@Lie` consomme le résultat sans supposer une closure anonyme (difficulté #6).
Checkpoint: `test/suite/differential_geometry` puis **suite complète** via MCP — vert.

### Phase F — Docstrings + nettoyage
Steps:
1. Docstrings des nouveaux types/méthodes publics (`WithActiveArg`, `differentiate`,
   `pushforward`, et les functors exposés via les types `Data.*`), API stabilisée.
2. `grep` `Differentiation.gradient`/`derivative` : si plus aucun usage dans `src/`, noter
   (ne pas supprimer sans confirmation — voir Human checkpoints).
3. Mettre à jour `closures_audit.md` (marquer les sites traités).
Checkpoint: suite complète verte + `generate_report`.

## Human checkpoints
- ⛔ Demander avant le premier commit (après Phase E ou F selon découpage convenu).
- ⛔ Demander avant tout push sur `develop`/`main`.
- ⛔ Demander avant de supprimer les stubs `gradient`/`derivative` (Phase F step 2).
- ⛔ Demander si une décision de conception hors-plan surgit (ex. la contrainte `F<:Function`
  des structs `Data.*` exigeait une autre solution que `<: Function` — cf. difficulté #7).

## Out of scope
- Caching / préparation DI pour `Poisson`/`ad`/`∂ₜ` (ouvert par les primitives, pas implémenté ici).
- Lambdas `ntuple` de `ext/CTFlowsStaticArrays.jl` (inlinées, zéro allocation) et lambdas
  `map` de `src/MultiPhase/multiphase_flow.jl` (pas des closures) — laissées telles quelles.
- Suppression effective des stubs `gradient`/`derivative` (décision Phase F + checkpoint humain).
- Toute modification des contraintes de type des structs `Data.*` (on ne les relâche pas).
