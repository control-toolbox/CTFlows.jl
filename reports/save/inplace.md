on va ajouter la possibilité de fournir une fonction in-place dans @vector_field.jl#L35-38 @hamiltonian_vector_field.jl#L37-40 .

Il faudra ajouter un trait InPlaceTrait vs OutOfPlaceTrait sous types de @abstract_trait.jl#L51-52. Le trait doit apparaitre je pense dans @abstract_vector_field.jl#L36-37. On pourrait même d'abord créer un sous-types pour cette nouvelle notion de trait : AbstractFunctionPlaceTrait <: AbstractTrait, puis InPlaceTrait <: AbstractFunctionPlaceTrait, etc.

Attention, le nom AbstractFunctionPlaceTrait est moche, il faut trouver autre chose.

A la construction, on peut ajouter un kwarg : inplace = Common.__is_inplace() avec le défaut à false. Ou on peut détecter automatiquement, puisque l'on a dans @vector_field.jl#L71-72 @hamiltonian_vector_field.jl#L73-74 les deux autres traits : autonome et variable. A partir de ces deux traits, on sait quelle doit être la signature de la fonction passée en argument, cf. les signatures naturelles : @hamiltonian_vector_field.jl#L83-87 @vector_field.jl#L81-85. Du coup, on peut faire comme dans SciML et déduire de la signature si la fonction est in-place ou out-of-place.

Ensuite, une fois que l'on a ces nouveaux champs de vecteurs. Il faudra construire des systèmes. @abstract_system.jl#L34-35 : un système n'a pas le trait inplace vs outofplace. 

Remarque : on pourrait faire une vraie notion de trait comme @traits.jl#L1-395 et avoir une fonction has_function_place_trait comme @traits.jl#L87-88 qui renvoie une erreur par défaut, puis pour un VectorField et un HamiltonianVectorField, on crée la fonction qui renvoie true, puis il faut créer des fonctions pour récupérer le trait comme @traits.jl#L113-114 et enfin il faut faire des fonctions sur les types qui ont le trait qui sont générique comme @traits.jl#L201-202 : on aurait is_inplace, is_outofplace (à voir pour les noms).

Revenons aux systèmes. Que le champs de vecteurs soit inplace ou non, il faudra toujours construire un rhs et un rhs_oop@vector_field_system.jl#L33-47 @hamiltonian_vector_field_system.jl#L58-71. C'est juste la construction qui est différente.

Si on a f! inplace et que l'on veut construire rhs_oop, il faut utiliser cet exemple @convert.jl#L35-48 concernant le similar.

De plus, dans certains cas, on aura un u0 @CTFlowsSciML.jl#L571-588 qui ne sera pas mutable, donc quand on va faire @convert.jl#L40-41 , par exemple on va passer d'un SVector à un MVector. Dans ce cas, il faut revenir sur un SVector pour que tout fonctionne : @convert.jl#L43-44 avec @convert.jl#L33-34 . Pour ne pas faire if !ismutable(x) à chaque appel du rhs, on peut faire une version de rhs_oop classique mais on va remplacer le getter @hamiltonian_vector_field_system.jl#L232-235 @vector_field_system.jl#L126-129 en lui ajoutant un argument, is_u0_mutable, et nous on renvoie toujours rhs_oop classique sauf si le système est inplace et que le u0 est non mutable, dans ce cas là, on peut construire de manière lazy le rhs_oop_finalize qui fait en plus @convert.jl#L43-44 à la fin. Pour les deux systèmes bien sûr. Après lazy ou pas, à voir, mais ce n'est pas le cas favorable, car si c'est non mutable, il vaut mieux fournir un système out of place. On pourrait d'ailleurs ajouter un warning. 

Grâce à tout ça, on aura la possiblilité de faire de l'inplace que ce soit avec du mutable ou non, et donc dans les tests, on pourra ajouter des appels de flots (pour les tests d'intégration) sur vecteur, matrice, complexe, StaticArrays, static matrices, etc. Pour les scalaires, ça ne devrait pas marcher mais c'est pas grave car ça n'a pas de sens de donner un f! implace si on fait du scalaire.

Je pense qu'il n'y a pas à toucher au reste du code pour que ça marche.

Fais un plan très détaillé en suivant @plan.md .

---

# In-Place Vector Field Support

Ajouter le support des fonctions in-place (`f!`) dans `VectorField` et `HamiltonianVectorField` via un nouveau trait `AbstractMutabilityTrait` (`InPlace` / `OutOfPlace`), avec détection automatique depuis l'arité de la fonction, puis propager le changement jusqu'aux systèmes et à l'extension SciML.

---

## Ce qui change et pourquoi

**Ajouté :**
- `AbstractMutabilityTrait <: AbstractTrait`, `InPlace`, `OutOfPlace` dans `Common`
- Trait accessors `has_mutability_trait`, `mutability_trait`, `is_inplace`, `is_outofplace`
- Troisième paramètre de type `MD <: AbstractMutabilityTrait` dans `AbstractVectorField`, `VectorField`, `HamiltonianVectorField`
- Signatures naturelles et uniformes **in-place** pour les deux types de champs de vecteurs
- Champ `rhs_oop_finalize` dans `VectorFieldSystem` et `HamiltonianVectorFieldSystem`
- Signature `rhs_oop(sys, is_u0_mutable::Bool = true)`

**Modifié :**
- Constructeurs `VectorField`/`HamiltonianVectorField` : auto-détection du trait via `first(methods(f)).nargs - 1`
- Constructeurs des systèmes : deux branches de construction selon `InPlace` ou `OutOfPlace`
- `CTFlowsSciML.build_problem` : passe `rhs_oop(system, false)` quand `u0` est non-mutable

**Invariant :**
- `AbstractSystem` ne porte pas le trait mutabilité (le système expose toujours `rhs` + `rhs_oop`)
- Toutes les APIs existantes restent compatibles (kwarg `is_u0_mutable` default = `true`)

---

## Signatures in-place de référence

### VectorField (`f!` avec dx en premier, arity = oop_arity + 1)

| TD / VD | OOP (existant) | InPlace (nouveau) | Uniforme IP |
|---|---|---|---|
| Aut, Fixed | `f(x)` | `f!(dx, x)` | `f!(dx, t, x, v)` |
| NonAut, Fixed | `f(t, x)` | `f!(dx, t, x)` | `f!(dx, t, x, v)` |
| Aut, NonFixed | `f(x, v)` | `f!(dx, x, v)` | `f!(dx, t, x, v)` |
| NonAut, NonFixed | `f(t, x, v)` | `f!(dx, t, x, v)` | (identique au naturel) |

### HamiltonianVectorField (`f!` avec (dx, dp) séparés, arity = oop_arity + 2)

| TD / VD | OOP (existant) | InPlace (nouveau) | Uniforme IP |
|---|---|---|---|
| Aut, Fixed | `f(x, p)` | `f!(dx, dp, x, p)` | `f!(dx, dp, t, x, p, v)` |
| NonAut, Fixed | `f(t, x, p)` | `f!(dx, dp, t, x, p)` | `f!(dx, dp, t, x, p, v)` |
| Aut, NonFixed | `f(x, p, v)` | `f!(dx, dp, x, p, v)` | `f!(dx, dp, t, x, p, v)` |
| NonAut, NonFixed | `f(t, x, p, v)` | `f!(dx, dp, t, x, p, v)` | (identique au naturel) |

---

## Graphe de dépendances

```
Common  (AbstractMutabilityTrait, InPlace, OutOfPlace)
  └── Data  (AbstractVectorField{TD,VD,MD}, VectorField{F,TD,VD,MD}, HamiltonianVectorField{F,TD,VD,MD})
        └── Systems  (VectorFieldSystem + rhs_oop_finalize, HamiltonianVectorFieldSystem)
              └── ext/CTFlowsSciML  (build_problem: rhs_oop(system, false))
```

---

## Step 0 — Branche

```bash
git checkout develop && git pull
git checkout -b feat/inplace-vector-field
```

---

## Phase 1 — Common : nouveau trait

### Step 1 — `src/Common/abstract_trait.jl` (modifié)

> 🏗️ Follow `modules.md` — ajouter après `AbstractContentTrait`, avant les structs concrètes de config
> 📋 Follow `architecture.md` — SRP : la seule responsabilité est la déclaration de l'abstraction

- Ajouter `abstract type AbstractMutabilityTrait <: AbstractTrait end`
- Ajouter `struct InPlace <: AbstractMutabilityTrait end`
- Ajouter `struct OutOfPlace <: AbstractMutabilityTrait end`
- Mettre à jour le docstring de `AbstractTrait` pour mentionner `AbstractMutabilityTrait`

> ⛔ Pas de docstrings complets — `# TODO: docstring` uniquement sur les nouvelles déclarations.

---

### Step 2 — `src/Common/traits.jl` (modifié)

> 🏗️ Follow `modules.md` — même style que `VariableDependence` / `Fixed` / `NonFixed`
> ⚠️ Follow `exceptions.md` — fallbacks → `IncorrectArgument` / `NotImplemented`

- Mettre à jour `_caller_function_name` : ajouter `"has_mutability_trait"` dans la liste des noms à ignorer (comme `has_time_dependence_trait` et `has_variable_dependence_trait`)
- Ajouter `has_mutability_trait(obj::Any)` → `Exceptions.IncorrectArgument` (fallback, même patron que `has_time_dependence_trait`)
- Ajouter `mutability_trait(obj::Any)` → `Exceptions.NotImplemented` (fallback)
- Ajouter `is_inplace(obj::Any)` : appelle `has_mutability_trait(obj)`, puis `mutability_trait(obj) === InPlace`
- Ajouter `is_outofplace(obj::Any)` : appelle `has_mutability_trait(obj)`, puis `mutability_trait(obj) === OutOfPlace`
- Ajouter `is_inplace(::Type{InPlace}) = true`, `is_inplace(::Type{OutOfPlace}) = false`
- Ajouter `is_outofplace(::Type{InPlace}) = false`, `is_outofplace(::Type{OutOfPlace}) = true`

> ⛔ Pas de docstrings complets.

---

### Step 3 — `src/Common/Common.jl` (modifié)

> 🏗️ Follow `modules.md` — exports en fin de manifest, dans la section `export`

- Exporter `AbstractMutabilityTrait`, `InPlace`, `OutOfPlace`
- Exporter `has_mutability_trait`, `mutability_trait`
- Exporter `is_inplace`, `is_outofplace`

---

### Step 4 — Test Checkpoint : Common mutability trait

> 🧪 Follow `testing-creation.md` — structs fakes au top-level, séparation unit/contract/error
> ▶️ Follow `testing-execution.md`

Modifier `test/suite/common/test_traits.jl` :

- Au top-level : `struct FakeInPlace end`, `struct FakeOutOfPlace end`, `struct FakeNoMutability end`
- Implémenter `Common.has_mutability_trait(::FakeInPlace) = true`, `Common.mutability_trait(::FakeInPlace) = Common.InPlace` (et idem pour `FakeOutOfPlace`)
- `@testset "Mutability Trait"` :
  - `InPlace <: Common.AbstractMutabilityTrait` → true
  - `OutOfPlace <: Common.AbstractMutabilityTrait` → true
  - `Common.is_inplace(FakeInPlace())` → true
  - `Common.is_outofplace(FakeInPlace())` → false
  - `Common.is_inplace(FakeOutOfPlace())` → false
  - `Common.is_inplace(FakeNoMutability())` → throws `IncorrectArgument`
  - `Common.mutability_trait(FakeNoMutability())` → throws `NotImplemented`

Modifier `test/suite/common/test_abstract_trait.jl` :
- Vérifier `AbstractMutabilityTrait <: Common.AbstractTrait`
- Vérifier `InPlace <: Common.AbstractMutabilityTrait`
- Vérifier `OutOfPlace <: Common.AbstractMutabilityTrait`

```bash
julia --project -e 'using Pkg; Pkg.test("CTFlows"; test_args=["suite/common/test_traits"])' \
  2>&1 | tee /tmp/ctflows_trait.log
grep -E "Error|Fail|Test Summary" /tmp/ctflows_trait.log
```

---

## Phase 2 — Data : nouveau paramètre de type MD

### Step 5 — `src/Data/abstract_vector_field.jl` (modifié)

> 📋 Follow `architecture.md` — OCP : extension sans modification du patron de dispatch existant
> 🏗️ Follow `modules.md` — utiliser `Common.AbstractMutabilityTrait` qualifié

- Changer `AbstractVectorField{TD<:Common.TimeDependence, VD<:Common.VariableDependence}` en `AbstractVectorField{TD<:Common.TimeDependence, VD<:Common.VariableDependence, MD<:Common.AbstractMutabilityTrait}`
- Ajouter `Common.has_mutability_trait(::AbstractVectorField) = true`
- Ajouter `function Common.mutability_trait(vf::AbstractVectorField{<:Common.TimeDependence, <:Common.VariableDependence, MD}) where {MD} = MD`
- Mettre à jour les extracteurs existants `time_dependence`/`variable_dependence` (signature inchangée, juste le param MD ajouté comme wildcard)

> ⛔ Pas de docstrings complets.

---

### Step 6 — `src/Data/vector_field.jl` (modifié)

> 📋 Follow `architecture.md` — OCP : nouvelles méthodes par dispatch, pas de if/elseif sur le type
> 🏗️ Follow `modules.md` — imports qualifiés ; `Autonomous`, `NonAutonomous`, `Fixed`, `NonFixed` déjà en scope via `using ..Common`

- Changer `VectorField{F<:Function, TD<:TimeDependence, VD<:VariableDependence}` en `VectorField{F<:Function, TD<:TimeDependence, VD<:VariableDependence, MD<:Common.AbstractMutabilityTrait}`
- Ajouter les fonctions internes `_oop_arity_vf(::Type{Autonomous}, ::Type{Fixed}) = 1` etc. (4 méthodes)
- Ajouter `_detect_mutability_vf(f::Function, TD, VD)` : lit `first(methods(f)).nargs - 1`, compare à `oop_arity` et `oop_arity + 1`, lève `Exceptions.IncorrectArgument` si ambigu
- Mettre à jour le constructeur `VectorField(f; is_autonomous, is_variable)` : appelle `_detect_mutability_vf(f, TD, VD)` pour déterminer `MD`
- Ajouter les signatures naturelles **in-place** (`(dx, x)`, `(dx, t, x)`, `(dx, x, v)`, `(dx, t, x, v)`) sur `VectorField{<:Function, TD, VD, InPlace}`
- Ajouter le call **uniforme in-place** `(dx, t, x, v)` pour les 3 combinaisons non-triviales de `InPlace`
- Mettre à jour `Base.show` pour afficher `MD` (ex : `mutability: InPlace`)

> ⛔ Pas de docstrings complets.

---

### Step 7 — `src/Data/hamiltonian_vector_field.jl` (modifié)

> Même patrons que Step 6, avec les spécificités HVF

- Changer `HamiltonianVectorField{F, TD, VD}` en `HamiltonianVectorField{F, TD, VD, MD<:Common.AbstractMutabilityTrait}`
- Ajouter `_oop_arity_hvf(TD, VD)` (4 méthodes : oop_arity = 2, 3, 3, 4)
- Ajouter `_detect_mutability_hvf(f, TD, VD)` : compare à `oop_arity` (OOP) et `oop_arity + 2` (InPlace)
- Mettre à jour le constructeur `HamiltonianVectorField(f; is_autonomous, is_variable)`
- Ajouter les signatures naturelles in-place : `(dx, dp, x, p)`, `(dx, dp, t, x, p)`, `(dx, dp, x, p, v)`, `(dx, dp, t, x, p, v)`
- Ajouter le call uniforme in-place `(dx, dp, t, x, p, v)` pour les 3 combinaisons non-triviales
- Mettre à jour `Base.show` pour afficher `MD`

> ⛔ Pas de docstrings complets.

---

### Step 8 — Test Checkpoint : Data module

> 🧪 Follow `testing-creation.md` — structs fakes au top-level, isolation

Modifier `test/suite/data/test_vector_field.jl` :
- `@testset "InPlace VectorField"` :
  - Construire `VectorField((dx, x) -> (dx .= -x; nothing))` → `is_inplace(vf) == true`, `Common.mutability_trait(vf) === InPlace`
  - Construire `VectorField(x -> -x)` → `is_outofplace(vf) == true`
  - Tester le call naturel : `vf(dx, x)` remplit `dx` in-place
  - Tester le call uniforme : `vf(dx, 0.0, x, nothing)` remplit `dx`
  - Tester l'erreur sur arité incorrecte : `VectorField((a, b, c) -> nothing)` → `IncorrectArgument`
  - Tester pour les 4 combinaisons (TD, VD)

Modifier `test/suite/data/test_hamiltonian_vector_field.jl` :
- `@testset "InPlace HamiltonianVectorField"` :
  - `HamiltonianVectorField((dx, dp, x, p) -> (dx .= x; dp .= -p; nothing))` → `is_inplace(hvf) == true`
  - Call naturel et uniforme
  - Arité incorrecte → `IncorrectArgument`
  - 4 combinaisons (TD, VD)

Modifier `test/suite/data/test_abstract_vector_field.jl` :
- `Common.has_mutability_trait(vf)` → true pour `VectorField` et `HamiltonianVectorField`
- `Common.mutability_trait(vf)` retourne le bon type

```bash
julia --project -e 'using Pkg; Pkg.test("CTFlows"; test_args=["suite/data"])' \
  2>&1 | tee /tmp/ctflows_data.log
grep -E "Error|Fail|Test Summary" /tmp/ctflows_data.log
```

---

## Phase 3 — Systems : rhs_oop_finalize

### Step 9 — `src/Systems/vector_field_system.jl` (modifié)

> 📋 Follow `architecture.md` — OCP : dispatch sur `MD` (OutOfPlace/InPlace), pas de if dans le constructeur
> 🏗️ Follow `modules.md` — `Common.InPlace`, `Common.OutOfPlace` qualifiés

**Design `rhs_oop_finalize` :**

- `rhs_oop_finalize::FINRHS` où **`FINRHS = Nothing` pour OOP VF** (finalize n'a pas de sens), et **`FINRHS = <closure>` pour InPlace VF** (construit eagerly)
- La dispatch sur `MD` rend l'accessor `rhs_oop` type-stable sans `isnothing` au runtime

**Struct :**

```julia
struct VectorFieldSystem{F, TD, VD, MD, RHS, OOPROHS, FINRHS} <: AbstractStateSystem{TD, VD}
    vf::Data.VectorField{F, TD, VD, MD}
    rhs::RHS
    rhs_oop::OOPROHS          # correct pour u0 mutable (InPlace) ou tout u0 (OOP)
    rhs_oop_finalize::FINRHS  # nothing (OOP) ou closure avec typeof(u)(dx) (InPlace)
end
```

**Helpers internes :**
- `_build_ip_rhs_vf(vf)` → `(du, u, λ, t) -> (vf(du, t, u, λ.variable); nothing)` (uniform IP call)
- `_build_oop_rhs_vf_ip(vf)` → `(u, λ, t) -> (dx = similar(u); vf(dx, t, u, λ.variable); dx)` (retourne dx, correct pour mutable)
- `_build_finalize_rhs_vf_ip(vf)` → `(u, λ, t) -> (dx = similar(u); vf(dx, t, u, λ.variable); typeof(u)(dx))` (correct pour immutable)

**Deux constructeurs dispatching sur `MD` :**
- `VectorFieldSystem(vf::Data.VectorField{F, TD, VD, Common.OutOfPlace})` : `rhs` inchangé (OOP call), `rhs_oop` = OOP call, `rhs_oop_finalize = nothing`
- `VectorFieldSystem(vf::Data.VectorField{F, TD, VD, Common.InPlace})` : `rhs` via `_build_ip_rhs_vf`, `rhs_oop` via `_build_oop_rhs_vf_ip`, `rhs_oop_finalize` via `_build_finalize_rhs_vf_ip`

**Deux méthodes `rhs_oop` dispatching sur `MD` (type-stable) :**

```julia
# OOP VF : FINRHS = Nothing — rhs_oop est toujours correct, ignorer is_u0_mutable
function rhs_oop(sys::VectorFieldSystem{F,TD,VD,Common.OutOfPlace,RHS,OOPROHS,Nothing},
                 ::Bool = true) where {F,TD,VD,RHS,OOPROHS}
    return sys.rhs_oop
end

# InPlace VF : retourner finalize + warning si u0 immutable
function rhs_oop(sys::VectorFieldSystem{F,TD,VD,Common.InPlace,RHS,OOPROHS,FINRHS},
                 is_u0_mutable::Bool = true) where {F,TD,VD,RHS,OOPROHS,FINRHS}
    is_u0_mutable && return sys.rhs_oop
    @warn "InPlace VectorField with immutable u0 (e.g. SVector): consider using an out-of-place function for better performance." maxlog=1
    return sys.rhs_oop_finalize
end
```

- Mettre à jour `Base.show` pour afficher `MD` (mutability)
- Mettre à jour `src/Systems/abstract_system.jl` : changer la signature du fallback `rhs_oop(sys::AbstractSystem)` en `rhs_oop(sys::AbstractSystem, ::Bool = true)` pour cohérence avec la nouvelle API

> ⛔ Pas de docstrings complets.

---

### Step 10 — `src/Systems/hamiltonian_vector_field_system.jl` (modifié)

> Même design que Step 9 : `FINRHS = Nothing` pour OOP HVF, closure eagerly built pour InPlace HVF

**Helpers InPlace HVF :**
- `_build_rhs_hvf_ip(hvf, ::Val{N})` — splite `u` **et** `du` via `_ham_split`, passe les views à `hvf!(dx_view, dp_view, t, x, p, v)` :
  ```julia
  (du, u, λ, t) -> begin
      x, p   = _ham_split(u,  N)
      dx, dp = _ham_split(du, N)           # views mutables dans du
      hvf(dx, dp, t, x, p, λ.variable)    # uniform IP call, remplit dx et dp
      return nothing
  end
  ```
- `_build_oop_rhs_hvf_ip(hvf, ::Val{N})` — alloue dx/dp séparément, vcat final :
  ```julia
  (u, λ, t) -> begin
      x, p       = _ham_split(u, N)
      dx, dp     = similar(x), similar(p)
      hvf(dx, dp, t, x, p, λ.variable)
      return vcat(dx, dp)
  end
  ```
- `_build_finalize_rhs_hvf_ip(hvf, ::Val{N})` — idem + `typeof(u)` conversion :
  ```julia
  (u, λ, t) -> begin
      x, p       = _ham_split(u, N)
      dx, dp     = similar(x), similar(p)
      hvf(dx, dp, t, x, p, λ.variable)
      return typeof(u)(vcat(dx, dp))
  end
  ```

**Deux constructeurs** pour chaque dimension (`state_dimension::Int` et `nothing`), dispatching sur `OutOfPlace`/`InPlace`.

**Deux méthodes `rhs_oop`** avec la même logique que Step 9 (dispatch sur `Common.OutOfPlace`/`Common.InPlace`, warning dans la branche InPlace + `is_u0_mutable=false`).

Mise à jour de `Base.show`.

> ⛔ Pas de docstrings complets.

---

### Step 11 — Test Checkpoint : Systems module

> 🧪 Follow `testing-creation.md`

Modifier `test/suite/systems/test_vector_field_system.jl` :
- `@testset "InPlace VectorFieldSystem"` :
  - Construire `VectorFieldSystem(VectorField((dx, x) -> (dx .= -x; nothing)))` → sans erreur
  - `rhs` fonctionne : `rhs!(du, u, p, t)` remplit correctement `du`
  - `rhs_oop(sys)` fonctionne : retourne une valeur pour u mutable
  - `rhs_oop(sys, true)` (mutable) retourne `Vector`
  - `rhs_oop(sys, false)` (immutable) : appeler sur un `SVector` → retourne un `SVector`
  - 4 combinaisons (TD, VD)

Modifier `test/suite/systems/test_hamiltonian_vector_field_system.jl` :
- Analogues pour `HamiltonianVectorFieldSystem` avec InPlace HVF
- Tester `_ham_split` sur `du` pour les views mutables
- Tester `rhs_oop(sys, false)` avec un `SVector` combiné

```bash
julia --project -e 'using Pkg; Pkg.test("CTFlows"; test_args=["suite/systems"])' \
  2>&1 | tee /tmp/ctflows_systems.log
grep -E "Error|Fail|Test Summary" /tmp/ctflows_systems.log
```

---

## Phase 4 — Extension SciML

### Step 12 — `ext/CTFlowsSciML.jl` (modifié)

> 🏗️ Follow `modules.md` — appel qualifié `Systems.rhs_oop`

Dans `Integrators.build_problem`, branche `!ismutable(u0)` :
- Remplacer `f = Systems.rhs_oop(system)` par `f = Systems.rhs_oop(system, false)`

Cela suffit : pour OOP VF, `rhs_oop(system, false)` retourne `rhs_oop` (identique à l'ancien comportement). Pour InPlace VF + u0 immutable, retourne `rhs_oop_finalize` + émet le `@warn` (côté système, Step 9).

> ⛔ Pas de docstrings complets.

---

### Step 13 — Test Checkpoint : Extension SciML

> 🧪 Follow `testing-creation.md`

Modifier `test/suite/extensions/test_sciml_extension.jl` ou `test_flow_callables_sciml.jl` :
- `@testset "InPlace VF — SciML integration"` :
  - Intégration avec `VectorField((dx, x) -> dx .= -x)` (mutable `Vector{Float64}`) → même résultat que OOP
  - Intégration avec `VectorField((dx, x) -> dx .= -x)` + `u0 = @SVector [1.0, 2.0]` → résultat `SVector` correct
  - Analogues pour `HamiltonianVectorFieldSystem` avec InPlace HVF
- Vérifier la présence du warning `@test_logs (:warn, r"InPlace")` pour le cas SVector + InPlace

```bash
julia --project -e 'using Pkg; Pkg.test("CTFlows"; test_args=["suite/extensions/test_sciml_extension"])' \
  2>&1 | tee /tmp/ctflows_sciml.log
grep -E "Error|Fail|Test Summary" /tmp/ctflows_sciml.log
```

---

## Step 14 — Docstrings (tous les fichiers modifiés)

> 📚 Follow `docstrings.md` — `$(TYPEDEF)` / `$(TYPEDSIGNATURES)`, sections `# Arguments`, `# Returns`, `# Throws`, `# Example`, cross-refs `[@ref]`

Écrire ou mettre à jour les docstrings pour chaque symbole nouveau ou modifié.

### Localisation du design SciML (mutable/immutable u0)

La documentation du pattern `rhs` / `rhs_oop` / `rhs_oop_finalize` est répartie ainsi :

**`src/Systems/abstract_system.jl` — `AbstractSystem` (docstring du type)** : endroit central pour expliquer le contrat global :
- Pourquoi deux accesseurs coexistent : `rhs` pour u0 mutable (SciML in-place), `rhs_oop` pour u0 immutable (SciML OOP)
- Le pattern général : SciML choisit le callable selon `ismutable(u0)`
- La distinction InPlace/OutOfPlace VF et son impact sur `rhs_oop_finalize`

**`rhs_oop(sys, is_u0_mutable)` (méthodes concrètes sur `VectorFieldSystem` et `HamiltonianVectorFieldSystem`)** : docstring détaillée sur :
- Signification du paramètre `is_u0_mutable` (`true` = u0 mutable, `false` = u0 immutable)
- Comportement selon le trait : OOP VF ignore le paramètre ; InPlace VF retourne `rhs_oop_finalize` + warning si `false`
- Note de performance : InPlace VF + SVector est non-optimal, recommander OOP VF
- Cross-ref vers `rhs` et `AbstractSystem`

**`rhs(sys)` (méthodes concrètes)** : note brève — *"Returns the in-place callable for use with mutable initial conditions in SciML. For immutable u0 (e.g. SVector), use `rhs_oop`."*

### Liste complète des symboles à documenter

- `src/Common/abstract_trait.jl` — `AbstractMutabilityTrait`, `InPlace`, `OutOfPlace`
- `src/Common/traits.jl` — `has_mutability_trait`, `mutability_trait`, `is_inplace`, `is_outofplace` (toutes les surcharges)
- `src/Data/abstract_vector_field.jl` — `AbstractVectorField` (nouveau param), `has_mutability_trait`, `mutability_trait`
- `src/Data/vector_field.jl` — `VectorField` (nouveau param, nouvelles calls), constructeur, `_detect_mutability_vf`, calls IP, `Base.show`
- `src/Data/hamiltonian_vector_field.jl` — analogues
- `src/Systems/abstract_system.jl` — `AbstractSystem` : design global `rhs`/`rhs_oop`, pattern SciML mutable/immutable, InPlace/OOP VF
- `src/Systems/vector_field_system.jl` — `VectorFieldSystem` (nouveau champ), `rhs` (note SciML), `rhs_oop` (paramètre + finalize + warning), helpers internes
- `src/Systems/hamiltonian_vector_field_system.jl` — analogues
- `ext/CTFlowsSciML.jl` — `build_problem` (comportement étendu)

---

## Step 15 — Run all tests

> ▶️ Follow `testing-execution.md`

```bash
julia --project -e 'using Pkg; Pkg.test("CTFlows")' 2>&1 | tee /tmp/ctflows_inplace_final.log
grep -E "Error|Fail|Test Summary" /tmp/ctflows_inplace_final.log
```

**Attendu** : toutes les suites passent, zéro failure, zéro error.

---

## Files summary

**New :** aucun fichier créé.

**Modified :**
- `src/Common/abstract_trait.jl` — `AbstractMutabilityTrait`, `InPlace`, `OutOfPlace`  (`architecture.md`)
- `src/Common/traits.jl` — `has_mutability_trait`, `mutability_trait`, `is_inplace`, `is_outofplace`, update `_caller_function_name`  (`modules.md`, `exceptions.md`)
- `src/Common/Common.jl` — exports  (`modules.md`)
- `src/Data/abstract_vector_field.jl` — troisième param `MD`, accessors  (`architecture.md`)
- `src/Data/vector_field.jl` — param `MD`, auto-detect, calls IP  (`architecture.md`, `modules.md`)
- `src/Data/hamiltonian_vector_field.jl` — idem  (`architecture.md`, `modules.md`)
- `src/Systems/vector_field_system.jl` — champ `rhs_oop_finalize`, constructeurs IP/OOP, `rhs_oop(sys, bool)`  (`architecture.md`)
- `src/Systems/hamiltonian_vector_field_system.jl` — idem  (`architecture.md`)
- `ext/CTFlowsSciML.jl` — `rhs_oop(system, false)` + warning  (`modules.md`)
- `test/suite/common/test_abstract_trait.jl` — `AbstractMutabilityTrait` tests  (`testing-creation.md`)
- `test/suite/common/test_traits.jl` — mutability trait tests  (`testing-creation.md`)
- `test/suite/data/test_abstract_vector_field.jl` — mutability accessor tests  (`testing-creation.md`)
- `test/suite/data/test_vector_field.jl` — InPlace VF tests  (`testing-creation.md`)
- `test/suite/data/test_hamiltonian_vector_field.jl` — InPlace HVF tests  (`testing-creation.md`)
- `test/suite/systems/test_vector_field_system.jl` — InPlace system tests  (`testing-creation.md`)
- `test/suite/systems/test_hamiltonian_vector_field_system.jl` — InPlace system tests  (`testing-creation.md`)
- `test/suite/extensions/test_sciml_extension.jl` — intégration InPlace  (`testing-creation.md`)

**Deleted :** aucun.

---

## Notes de design

- **Détection auto** : `first(methods(f)).nargs - 1` donne l'arité positionnelle. Si `f` a plusieurs méthodes avec des arités différentes, `first` prend la plus récente/spécifique. Cas ambigu → `IncorrectArgument`.
- **HVF InPlace** : `f!(dx, dp, x, p, ...)` (sorties séparées, +2 args). Le RHS SciML splite `u` et `du` en views via `_ham_split`.
- **rhs_oop_finalize** : pour InPlace VF + u0 immutable (SVector), retourne `typeof(u)(dx)` pour convertir MVector → SVector. Pour OOP VF : `rhs_oop_finalize = rhs_oop` (même objet, pas de surcoût).
- **Warning** : émis dans `rhs_oop(sys, false)` quand le VF est InPlace, pour guider vers l'usage OOP.
- **Scalaires** : non supportés pour InPlace (pas de sens pour `similar(scalar)`). Aucune modification n'est nécessaire ; l'erreur viendra naturellement de `similar`.
