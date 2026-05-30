# Rapport d'avancement — Remplacement des closures par des structs appelables

**Date:** 30 mai 2026  
**Objectif:** Remplacer toutes les closures par des structs appelables (functors) pour améliorer la lisibilité, la composabilité et les stack traces.

---

## Résumé exécutif

- **Closures totales identifiées:** 17
- **Closures remplacées:** 14 (82%)
- **Closures restantes:** 3 (HamiltonianSystem)
- **Fichiers créés:** 3 fichiers de functors
- **Statut:** Phase 1 (remplacement mécanique) presque terminée, reste Phase 2 (HamiltonianSystem)

---

## 1. Ce qui a été fait ✅

### 1.1 VectorFieldSystem (5 closures) — **COMPLÉTÉ**

**Fichier créé:** `src/Systems/rhs_functors.jl`

**Functors implémentés:**
- `IPVFOoPRHS{F,TD,VD}` — in-place pour out-of-place VectorField
- `IPVFIpRHS{F,TD,VD}` — in-place pour in-place VectorField
- `OoPVFOoPRHS{F,TD,VD}` — out-of-place pour out-of-place VectorField
- `OoPVFIpRHS{F,TD,VD}` — out-of-place pour in-place VectorField
- `OoPVFIpFinalizeRHS{F,TD,VD}` — out-of-place avec conversion de type

**Hiérarchie abstraite:**
```julia
abstract type AbstractRHS{T<:Traits.AbstractMutabilityTrait} end
abstract type AbstractIPRHS <: AbstractRHS{Traits.InPlace} end
abstract type AbstractOoPRHS <: AbstractRHS{Traits.OutOfPlace} end
```

**Intégration:** `src/Systems/vector_field_system.jl` utilise les functors dans les constructeurs. Les paramètres de type `RHS<:Function` et `OOPROHS<:Function` ont été remplacés par `RHS<:AbstractIPRHS` et `OOPROHS<:AbstractOoPRHS`.

**Bénéfices:**
- Stack traces lisibles: `IPVFIpRHS{...}` au lieu de `var"#3#4"`
- Types inspectables et dispatch possibles
- Docstrings complètes pour chaque functor

---

### 1.2 HamiltonianVectorFieldSystem (4 closures + 2 augmentées) — **COMPLÉTÉ**

**Fichier créé:** `src/Systems/hvf_rhs_functors.jl`

**Functors implémentés:**
- `IPHVFOoPRHS{F,TD,VD,CX,CP}` — in-place pour out-of-place HVF
- `IPHVFIpRHS{F,TD,VD,CX,CP}` — in-place pour in-place HVF
- `OoPHVFOoPRHS{F,TD,VD,CX,CP}` — out-of-place pour out-of-place HVF
- `OoPHVFIpRHS{F,TD,VD,CX,CP}` — out-of-place pour in-place HVF
- `OoPHVFIpFinalizeRHS{F,TD,VD,CX,CP}` — out-of-place avec conversion
- `IPHVFOoPAugRHS{F,TD,VD}` — in-place augmenté (variable costate)
- `IPHVFIpAugRHS{F,TD,VD}` — in-place augmenté (variable costate)

**Hiérarchie abstraite:**
```julia
abstract type AbstractHVFRHS{T<:Traits.AbstractMutabilityTrait} <: AbstractRHS{T} end
abstract type AbstractIPHVFRHS <: AbstractHVFRHS{Traits.InPlace} end
abstract type AbstractOoPHVFRHS <: AbstractHVFRHS{Traits.OutOfPlace} end
```

**Intégration:** `src/Systems/hamiltonian_vector_field_system.jl` utilise les functors dans `build_rhs` et `build_oop_rhs`. Les captures `N`, `cx`, `cp` sont maintenant des champs typés des functors.

**Bénéfices:**
- Capture de `N::Int`, `cx`, `cp` comme champs typés (plus opaque)
- Construction lazy préservée via `build_rhs`
- Support des systèmes augmentés pour variable costate

---

### 1.3 SciMLFunctionSystem (5 closures) — **COMPLÉTÉ**

**Fichier créé:** `ext/CTFlowsSciML/sciml_rhs_functors.jl`

**Functors implémentés:**
- `IPSciMLIpRHS{F}` — in-place pour in-place SciML function
- `OoPSciMLIpRHS{F}` — out-of-place pour in-place SciML function
- `OoPSciMLIpFinalizeRHS{F}` — out-of-place avec conversion
- `IPSciMLOoPRHS{F}` — in-place pour out-of-place SciML function
- `OoPSciMLOoPRHS{F}` — out-of-place pour out-of-place SciML function

**Intégration:** `ext/CTFlowsSciML/sciml_function_system.jl` utilise les functors dans les constructeurs.

**Bénéfices:**
- Même pattern que VectorFieldSystem
- Extension SciML cohérente avec le core

---

## 2. Ce qui reste à faire ❌

### 2.1 HamiltonianSystem (3 closures) — **PRIORITÉ HAUTE**

**Fichier concerné:** `src/Systems/hamiltonian_system.jl`

**Closures actuelles:**
- `build_rhs` (lignes 88-99) — capture `h`, `backend`, `N`, `cx`, `cp`
- `build_oop_rhs` (lignes 117-127) — capture `h`, `backend`, `N`, `cx`, `cp`
- `build_rhs_augmented` (lignes 150-161) — capture `h`, `backend`, `n_x`, `n_v`

**Functors à créer (proposés dans callable_structs_report.md §3.4):**
```julia
# In-place avec AD
struct HamIpRHS{F, TD, VD, B, CX, CP} <: AbstractIPRHS
    h       ::Data.Hamiltonian{F, TD, VD}
    backend ::B
    N       ::Int
    cx      ::CX
    cp      ::CP
end

# Out-of-place avec AD
struct HamOoPRHS{F, TD, VD, B, CX, CP} <: AbstractOoPRHS
    h       ::Data.Hamiltonian{F, TD, VD}
    backend ::B
    N       ::Int
    cx      ::CX
    cp      ::CP
end

# Augmenté avec AD
struct HamIpAugRHS{F, TD, VD, B} <: AbstractIPRHS
    h       ::Data.Hamiltonian{F, TD, VD}
    backend ::B
    n_x     ::Int
    n_v     ::Int
end
```

**Action requise:**
1. Créer `src/Systems/hamiltonian_rhs_functors.jl`
2. Implémenter les 3 functors avec leurs call signatures
3. Modifier `build_rhs`, `build_oop_rhs`, `build_rhs_augmented` pour retourner les functors
4. Ajouter les tests correspondants

---

### 2.2 Buffer pré-alloué — **PRIORITÉ MOYENNE**

**Objectif:** Éviter les allocations répétées dans les functors out-of-place pour in-place functions.

**Fonctions concernées:**
- `OoPVFIpRHS` (ligne 131 de rhs_functors.jl) — alloue `similar(u)` à chaque appel
- `OoPHVFIpRHS` (ligne 158 de hvf_rhs_functors.jl) — alloue `dx, dp` à chaque appel
- `OoPSciMLIpRHS` (ligne 51 de sciml_rhs_functors.jl) — alloue `similar(u)` à chaque appel

**Design proposé (callable_structs_report.md §4.1):**
```julia
struct OoPVFIpRHS{F, TD, VD, BUF} <: AbstractOoPRHS
    vf  ::Data.VectorField{F, TD, VD, Traits.InPlace}
    buf ::BUF   # Vector pré-alloué
end

# Constructeur avec buffer
OoPVFIpRHS(vf, u0::AbstractVector) = OoPVFIpRHS(vf, similar(u0))

# Call signature utilise le buffer
function (f::OoPVFIpRHS)(u, λ, t)
    f.vf(f.buf, t, u, Common.variable(λ))
    copy(f.buf)  # ou return f.buf si thread-safe
end
```

**Note importante:** Les buffers pré-alloués ne sont **pas thread-safe**. Pour du multi-threading, il faudrait utiliser un `Vector` de buffers ou un `TaskLocalValue` (package `ThreadingUtilities`).

---

### 2.3 Cache AD — **PRIORITÉ BASSE**

**Objectif:** Stocker le cache AD dans le functor pour éviter les allocations répétées dans `hamiltonian_gradient`.

**Contexte:** Actuellement, `build_rhs` et `build_oop_rhs` passent `Common.cache(λ)` à `Differentiation.hamiltonian_gradient`. Si ce cache est alloué à chaque `build_problem`, le stocker dans le functor pourrait être une optimisation.

**Design proposé (callable_structs_report.md §4.3):**
```julia
struct HamIpRHS{F, TD, VD, B, CX, CP, CACHE}
    h        ::Data.Hamiltonian{F, TD, VD}
    backend  ::B
    N        ::Int
    cx       ::CX
    cp       ::CP
    ad_cache ::CACHE
end
```

**Action requise:**
- Vérifier l'API de `Differentiation.hamiltonian_gradient` pour voir si elle accepte un cache externe
- Si oui, modifier le constructeur pour allouer le cache
- Sinon, laisser tel quel (cache géré par `Common.cache(λ)`)

---

### 2.4 Suppression des paramètres de type — **PRIORITÉ BASSE**

**Objectif:** Simplifier `VectorFieldSystem` en supprimant les paramètres de type `RHS` et `OOPROHS` car ils sont déterministes.

**État actuel:**
```julia
struct VectorFieldSystem{F, TD, VD, MD, RHS<:AbstractIPRHS, OOPROHS<:AbstractOoPRHS, FINRHS}
```

**Cible:**
```julia
struct VectorFieldSystem{F, TD, VD, MD}
    # Les types des champs rhs/rhs_oop sont inférés depuis F, TD, VD, MD
end
```

**Bénéfice:** `typeof(sys)` encode toute l'information structurelle sans paramètres de type explicites.

**Risque:** Changement breaking pour le code qui dépend des paramètres de type actuels. À évaluer avec les tests.

---

## 3. Tableau de synthèse

| Système | Closures | Functors | Statut | Fichier |
|---------|----------|----------|--------|---------|
| VectorFieldSystem | 5 | 5 | ✅ Complété | `src/Systems/rhs_functors.jl` |
| HamiltonianVectorFieldSystem | 4+2 | 4+2 | ✅ Complété | `src/Systems/hvf_rhs_functors.jl` |
| SciMLFunctionSystem | 5 | 5 | ✅ Complété | `ext/CTFlowsSciML/sciml_rhs_functors.jl` |
| HamiltonianSystem | 3 | 0 | ❌ À faire | À créer |
| **Total** | **17** | **14** | **82%** | — |

---

## 4. Priorités recommandées

Selon `callable_structs_report.md` §7:

1. **Court terme** — HamiltonianSystem: terminer le remplacement mécanique des closures. C'est la seule partie manquante de la Phase 1.
2. **Moyen terme** — Buffer pré-alloué: optimisation performance si les flows sont appelés en boucle (optimisation, tir multiple).
3. **Long terme** — Cache AD: dépend de l'API de `Differentiation`, à évaluer au cas par cas.
4. **Nettoyage** — Suppression paramètres de type: à faire après validation des tests.

---

## 5. Tests

**Tests existants:**
- `test/suite/systems/test_rhs_functors.jl` — tests pour VectorFieldSystem functors
- `test/suite/systems/test_hvf_rhs_functors.jl` — tests pour HamiltonianVectorFieldSystem functors
- `test/suite/extensions/test_sciml_rhs_functors.jl` — tests pour SciMLFunctionSystem functors

**Tests à créer:**
- Tests pour HamiltonianSystem functors (une fois implémentés)
- Tests de performance pour buffer pré-alloué (optionnel)

---

## 6. Conclusion

Le remplacement des closures par des structs appelables est à **82%** complété. Les trois systèmes principaux (VectorFieldSystem, HamiltonianVectorFieldSystem, SciMLFunctionSystem) sont terminés. Il reste uniquement HamiltonianSystem, qui utilise encore des closures dans `build_rhs`, `build_oop_rhs` et `build_rhs_augmented`.

La prochaine étape logique est de créer les functors pour HamiltonianSystem, ce qui complètera la Phase 1 (remplacement mécanique). Les optimisations (buffer pré-alloué, cache AD) peuvent être abordées ensuite selon les besoins de performance.
