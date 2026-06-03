# Rapport : Refactorisation vers des interfaces abstraites avec dispatch basé sur des traits

**Date :** 1er juin 2026  
**GitHub Issue :** #251  
**Auteur :** ocots

---

## Résumé

Ce rapport documente l'analyse et la proposition de refactorisation de CTFlows.jl pour utiliser des types abstraits avec des interfaces bien définies et un dispatch basé sur des traits, au lieu d'opérer sur des types concrets. L'objectif est d'améliorer l'extensibilité, la stabilité des types et la clarté des contrats d'interface.

---

## Problème

De nombreuses fonctions dans CTFlows opèrent actuellement sur des types concrets (`VectorField`, `HamiltonianVectorField`, `HamiltonianSystem`, `VectorFieldSystem`, etc.) alors qu'elles pourraient opérer sur des types abstraits avec des interfaces bien définies. Cela limite l'extensibilité et rend la base de code plus rigide que nécessaire.

---

## Problèmes Actuels Identifiés

### 1. Fonctions de construction utilisant des types concrets

Dans `src/Systems/building.jl` :

- `build_system(vf::Data.VectorField)` - devrait accepter `AbstractVectorField`
- `build_system(hvf::Data.HamiltonianVectorField)` - devrait accepter `AbstractHamiltonianVectorField`
- `build_system(h::Data.Hamiltonian, backend::Differentiation.AbstractADBackend)` - Hamiltonian pourrait être abstrait

**Impact :** Les utilisateurs ne peuvent pas créer de sous-types personnalisés sans modifier le code cœur.

### 2. Annotations de types manquantes dans les helpers internes

Dans `src/Systems/hamiltonian_getter.jl` :

- `_make_oop_hvf(h, backend, ...)` - pas de types pour les paramètres `h` et `backend`
- Problème similaire dans toutes les variantes `_make_ip_hvf`

**Impact :** Perte potentielle de stabilité des types et difficulté de raisonnement sur le code.

### 3. Méthodes getter uniquement sur des types concrets

Dans `src/Systems/hamiltonian_getter.jl` et `src/Systems/hamiltonian_system.jl` :

- `hamiltonian_vector_field(sys::HamiltonianVectorFieldSystem)` - uniquement concret
- `hamiltonian_vector_field(sys::HamiltonianSystem)` - uniquement concret
- `hamiltonian(sys::HamiltonianSystem)` et `backend(sys::HamiltonianSystem)` - uniquement concret

**Impact :** Impossible d'utiliser ces getters sur des sous-types personnalisés de `AbstractHamiltonianSystem`.

### 4. Constructeurs RHS sur des types concrets

Dans `src/Systems/hamiltonian_system.jl` :

- `build_rhs(sys::HamiltonianSystem, ...)` - devrait être sur `AbstractHamiltonianSystem`
- `build_oop_rhs(sys::HamiltonianSystem, ...)` - devrait être sur `AbstractHamiltonianSystem`
- `build_rhs_augmented(sys::HamiltonianSystem, ...)` - devrait être sur `AbstractHamiltonianSystem`

**Impact :** Les extensions personnalisées ne peuvent pas bénéficier de ces constructeurs.

### 5. Patterns similaires dans d'autres modules

- `VectorFieldSystem` a des getters uniquement sur le type concret
- Solutions, Flows, Integrators, MultiPhase ont probablement des méthodes spécifiques aux types concrets similaires

**Impact :** Le problème est systémique dans toute la base de code.

---

## Méthodologie Proposée

Le module `Traits` de CTFlows fournit déjà une bonne fondation. Nous devons étendre ce pattern systématiquement.

### 1. Définir des types abstraits pour les structures de données

Créer des types abstraits dans le module `Data` :

- `AbstractVectorField` - supertype pour `VectorField`
- `AbstractHamiltonianVectorField` - supertype pour `HamiltonianVectorField`
- `AbstractHamiltonian` - supertype pour `Hamiltonian`

**Exemple :**
```julia
# Dans src/Data/abstract.jl
abstract type AbstractVectorField end
abstract type AbstractHamiltonianVectorField end
abstract type AbstractHamiltonian end
```

### 2. Définir des interfaces abstraites avec méthodes requises

Pour chaque type abstrait, définir les méthodes d'interface requises.

**Exemple :**
```julia
# Interface pour AbstractHamiltonianSystem
function hamiltonian(sys::AbstractHamiltonianSystem)
    throw(CTBase.Exceptions.NotImplemented(
        "hamiltonian not implemented for this system type";
        required_method = "hamiltonian(sys::AbstractHamiltonianSystem)",
        context = "AbstractHamiltonianSystem interface"
    ))
end

function backend(sys::AbstractSystemWithAD)
    throw(CTBase.Exceptions.NotImplemented(
        "backend not implemented for this system type";
        required_method = "backend(sys::AbstractSystemWithAD)",
        context = "AbstractSystemWithAD interface"
    ))
end
```

### 3. Utiliser le dispatch basé sur des traits

Les méthodes sur les types abstraits doivent dispatcher selon les getters de traits. Le module `Traits` fournit déjà :

- `AbstractADTrait` avec `WithAD` et `WithoutAD`
- `AbstractVariableCostateCapability` avec `SupportsVariableCostate` et `NoVariableCostate`
- Getters de traits : `ad_trait`, `variable_costate_trait`, `time_dependence`, `mutability`, `variable_dependence`

**Exemple de pattern :**
```julia
function hamiltonian_vector_field(sys::AbstractHamiltonianSystem; kwargs...)
    if Traits.ad_trait(sys) === Traits.WithAD
        # Implémentation basée sur AD
        ad_backend = Differentiation.ad_backend(backend(sys))
        return hamiltonian_vector_field(hamiltonian(sys); ad_backend=ad_backend, kwargs...)
    else
        # Implémentation avec champ vectoriel pré-calculé
        return hamiltonian_vector_field_concrete(sys)
    end
end
```

### 4. Déplacer les méthodes vers les types abstraits

- `build_rhs`, `build_oop_rhs`, `hamiltonian_vector_field` devraient fonctionner sur `AbstractHamiltonianSystem`
- `rhs`, `rhs_oop` devraient fonctionner sur `AbstractStateSystem`
- Les fonctions de construction devraient accepter des types de données abstraits

### 5. Ajouter des annotations de types aux helpers internes

Assurer la stabilité des types avec des interfaces abstraites :

```julia
function _make_oop_hvf(
    h::AbstractHamiltonian,
    backend::Differentiation.AbstractADBackend,
    ::Type{Traits.Autonomous},
    ::Type{Traits.Fixed}
)
    return (x, p) -> begin
        ∂x, ∂p = Differentiation.hamiltonian_gradient(backend, h, nothing, x, p, nothing, nothing)
        return (∂p, -∂x)
    end
end
```

---

## Avantages

1. **Extensibilité** : Les utilisateurs peuvent définir des sous-types personnalisés des types abstraits sans modifier le code cœur
2. **Stabilité des types** : Les interfaces abstraites appropriées avec un dispatch basé sur des traits maintiennent la stabilité des types
3. **Contrats clairs** : Les types abstraits avec des méthodes requises rendent l'API explicite
4. **Meilleurs tests** : Plus facile de tester avec des implémentations mock des types abstraits
5. **Consistance** : S'aligne avec les meilleures pratiques Julia pour la conception d'interfaces

---

## Approche d'Implémentation

### Phase 1 : Définir les types abstraits dans le module Data
- Créer `AbstractVectorField`, `AbstractHamiltonianVectorField`, `AbstractHamiltonian`
- Mettre à jour les types concrets pour hériter des types abstraits
- S'assurer que tous les tests passent

### Phase 2 : Définir les méthodes d'interface avec des stubs de contrat
- Définir `hamiltonian`, `backend`, `hamiltonian_vector_field` sur les types abstraits
- Ajouter des stubs `NotImplemented` pour les méthodes non implémentées
- Documenter les interfaces dans les docstrings

### Phase 3 : Déplacer les fonctions de construction pour accepter des types abstraits
- Mettre à jour `build_system` pour accepter `AbstractVectorField`
- Mettre à jour `build_system` pour accepter `AbstractHamiltonianVectorField`
- Mettre à jour `build_system` pour accepter `AbstractHamiltonian`
- Mettre à jour les tests

### Phase 4 : Déplacer les méthodes getter vers les types abstraits avec dispatch basé sur des traits
- Déplacer `hamiltonian_vector_field` vers `AbstractHamiltonianSystem`
- Déplacer `hamiltonian` et `backend` vers `AbstractHamiltonianSystem`
- Implémenter le dispatch basé sur `ad_trait`
- Mettre à jour les tests

### Phase 5 : Déplacer les constructeurs RHS vers les types abstraits
- Déplacer `build_rhs` vers `AbstractHamiltonianSystem`
- Déplacer `build_oop_rhs` vers `AbstractHamiltonianSystem`
- Déplacer `build_rhs_augmented` vers `AbstractHamiltonianSystem`
- Implémenter le dispatch basé sur les traits appropriés
- Mettre à jour les tests

### Phase 6 : Ajouter des annotations de types aux helpers internes
- Annoter `_make_oop_hvf` et `_make_ip_hvf` avec des types abstraits
- Vérifier la stabilité des types avec `@inferred`
- Mettre à jour les tests de stabilité des types

### Phase 7 : Mettre à jour les tests pour utiliser les interfaces abstraites
- Identifier les tests qui utilisent des types concrets inutilement
- Mettre à jour pour utiliser des types abstraits là où c'est approprié
- Ajouter des tests pour les interfaces abstraites

### Phase 8 : Mettre à jour la documentation pour refléter les interfaces abstraites
- Mettre à jour les docstrings pour documenter les interfaces abstraites
- Ajouter des exemples d'utilisation des interfaces abstraites
- Mettre à jour la documentation de l'API

---

## Travail Connex

Le module `Traits` démontre déjà bien ce pattern avec :

- **Types de traits abstraits** : `AbstractTrait`, `AbstractModeTrait`, `AbstractContentTrait`, `AbstractMutabilityTrait`, `AbstractADTrait`, `AbstractVariableCostateCapability`
- **Traits concrets** : `InPlace`, `OutOfPlace`, `WithAD`, `WithoutAD`, `SupportsVariableCostate`, `NoVariableCostate`
- **Getters de traits** : `ad_trait`, `variable_costate_trait`, `time_dependence`, `mutability`, `variable_dependence`

Cette refactorisation étendrait ce pattern réussi au reste de la base de code.

---

## Références

- Système de traits actuel : `src/Traits/Traits.jl`
- Fonctions de construction : `src/Systems/building.jl`
- Getters Hamiltonian : `src/Systems/hamiltonian_getter.jl`
- Système Hamiltonian : `src/Systems/hamiltonian_system.jl`
- Système VectorField : `src/Systems/vector_field_system.jl`
- GitHub Issue : [#251](https://github.com/control-toolbox/CTFlows.jl/issues/251)

---

## Questions à Discuter

1. Devrions-nous créer des types abstraits pour toutes les structures de données, ou seulement celles susceptibles d'être étendues ?
2. Quel est l'ordre de priorité des phases ci-dessus ?
3. Y a-t-il des préoccupations de performance avec le dispatch basé sur des traits que nous devrions benchmark ?
4. Faut-il créer des types abstraits intermédiaires (par exemple, `AbstractSystemWithAD`) pour capturer des contrats spécifiques ?

---

## Conclusion

Cette refactorisation représente un investissement architectural significatif qui améliorera l'extensibilité et la maintenabilité de CTFlows.jl à long terme. En tirant parti du système de traits existant et en étendant le pattern des interfaces abstraites, nous pouvons créer une base de code plus flexible et plus robuste tout en maintenant la stabilité des types et la performance.

L'approche par phases permet une migration progressive et contrôlée, minimisant les risques de régression tout en permettant des améliorations incrémentales.
