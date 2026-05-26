# Inventaire complet des closures dans CTFlows.jl

## Résumé

- **Total closures actives:** 17
- **Closures pré-calculées:** 10 (5 VectorField + 5 SciMLFunctionSystem)
- **Closures lazy:** 7 (4 HamiltonianVectorField + 3 HamiltonianSystem)
- **Fonctions utilisateur:** jumps dans MultiPhase (non comptées comme closures du package)

---

## 1. VectorFieldSystem — closures pré-calculées (construction)

**Fichier:** `src/Systems/vector_field_system.jl`

| Builder | Ligne | Signature | Capture | Notes |
| --- | --- | --- | --- | --- |
| `_build_rhs_vf_oop` | 107-109 | `(du, u, λ, t) -> nothing` | `vf` | OutOfPlace vector field |
| `_build_rhs_vf_ip` | 126-128 | `(du, u, λ, t) -> nothing` | `vf` | InPlace vector field |
| `_build_oop_rhs_vf_oop` | 144-146 | `(u, λ, t) -> du` | `vf` | OutOfPlace vector field |
| `_build_oop_rhs_vf_ip` | 163-169 | `(u, λ, t) -> du` | `vf` | InPlace vector field, alloue `similar(u)` à chaque appel |
| `_build_finalize_rhs_vf_ip` | 187-193 | `(u, λ, t) -> du` | `vf` | InPlace vector field, convertit avec `typeof(u)(dx)` |

**Stockage:** Champs `rhs`, `rhs_oop`, `rhs_oop_finalize` dans le struct.

---

## 2. HamiltonianVectorFieldSystem — closures lazy (build_problem)

**Fichier:** `src/Systems/hamiltonian_vector_field_system.jl`

| Builder | Ligne | Signature | Capture | Notes |
| --- | --- | --- | --- | --- |
| `build_rhs` (OutOfPlace) | 150-161 | `(du, u, λ, t) -> nothing` | `hvf`, `N`, `cx`, `cp` | Lazy, construit à l'appel de `build_problem` |
| `build_rhs` (InPlace) | 163-174 | `(du, u, λ, t) -> nothing` | `hvf`, `N`, `cx`, `cp` | Lazy, construit à l'appel de `build_problem` |
| `build_oop_rhs` (OutOfPlace) | 192-202 | `(u, λ, t) -> du` | `hvf`, `N`, `cx`, `cp` | Lazy, construit à l'appel de `build_problem` |
| `build_oop_rhs` (InPlace) | 204-223 | `(u, λ, t) -> du` | `hvf`, `N`, `cx`, `cp`, `is_u0_mutable` | Lazy, alloue `dx`, `dp` à chaque appel |

**Construction lazy:** Appelées via `build_problem` avec `x0`, `p0` concrets.

---

## 3. HamiltonianSystem — closures lazy avec AD

**Fichier:** `src/Systems/hamiltonian_system.jl`

| Builder | Ligne | Signature | Capture | Notes |
| --- | --- | --- | --- | --- |
| `build_rhs` | 106-117 | `(du, u, λ, t) -> nothing` | `h`, `backend`, `N`, `cx`, `cp` | Lazy, utilise `hamiltonian_gradient` |
| `build_oop_rhs` | 135-145 | `(u, λ, t) -> du` | `h`, `backend`, `N`, `cx`, `cp` | Lazy, utilise `hamiltonian_gradient` |
| `build_rhs_augmented` | 168-179 | `(du, u, λ, t) -> nothing` | `h`, `backend`, `n_x`, `n_v` | Lazy, pour systèmes augmentés avec coûtate variable |

**Construction lazy:** Appelées via `build_problem` ou `build_rhs_augmented(sys, n_x, n_v)`.

---

## 4. SciMLFunctionSystem — closures pré-calculées (extension)

**Fichier:** `ext/CTFlowsSciML/sciml_function_system.jl`

| Builder | Ligne | Signature | Capture | Notes |
| --- | --- | --- | --- | --- |
| `rhs_fn` (in-place) | 62 | `(du, u, λ, t) -> nothing` | `f` (SciML ODEFunction) | Pour `AbstractODEFunction{true}` |
| `rhs_oop_fn` (in-place wrapper) | 65-69 | `(u, λ, t) -> du` | `f` (SciML ODEFunction) | Pour `AbstractODEFunction{true}`, alloue `similar(u)` |
| `rhs_oop_finalize_fn` (in-place finalize) | 72-76 | `(u, λ, t) -> du` | `f` (SciML ODEFunction) | Pour `AbstractODEFunction{true}`, convertit avec `typeof(u)(dx)` |
| `rhs_fn` (out-of-place) | 85 | `(du, u, λ, t) -> nothing` | `f` (SciML ODEFunction) | Pour `AbstractODEFunction{false}` |
| `rhs_oop_fn` (out-of-place direct) | 88 | `(u, λ, t) -> du` | `f` (SciML ODEFunction) | Pour `AbstractODEFunction{false}` |

**Stockage:** Champs `rhs_fn`, `rhs_oop_fn`, `rhs_oop_finalize_fn` dans le struct.

---

## 5. MultiPhase — jump functions (non-RHS)

**Fichiers:** `src/MultiPhase/concatenation.jl` et `src/MultiPhase/multiphase_flow.jl`

Les jumps sont des **fonctions utilisateur** stockées dans `jumps::Vector{<:Any}`, pas des closures construites par le package. Elles sont appliquées via `_apply_jump` (ligne 280-341 dans `calling.jl`).

**Exemples d'utilisation:**

- `jump = x -> 2 * x` (state flow)
- `jump_x = x -> 2 * x; jump_p = p -> 3 * p` (Hamiltonian flow)

Ces fonctions sont fournies par l'utilisateur et ne sont pas comptées comme closures du package.

---

## 6. AbstractSystem — stubs de documentation

**Fichier:** `src/Systems/abstract_system.jl`

Les lignes 28 et 257 contiennent des exemples de closures dans les docstrings (`(du, u, p, t) -> du .= sys.data .* u`), mais ce ne sont pas du code actif.

---

## Analyse par catégorie

### Closures pré-calculées (10)

- **VectorFieldSystem:** 5 closures
  - 2 in-place (oop/ip)
  - 2 out-of-place (oop/ip)
  - 1 finalize (ip)

- **SciMLFunctionSystem:** 5 closures
  - 3 pour in-place SciML functions
  - 2 pour out-of-place SciML functions

### Closures lazy (7)

- **HamiltonianVectorFieldSystem:** 4 closures
  - 2 in-place (oop/ip)
  - 2 out-of-place (oop/ip)

- **HamiltonianSystem:** 3 closures
  - 1 in-place standard
  - 1 out-of-place standard
  - 1 in-place augmenté

### Opportunités d'optimisation

**Buffer pré-allouable:**

- `_build_oop_rhs_vf_ip` (VectorFieldSystem) — alloue `similar(u)` à chaque appel
- `build_oop_rhs` (HamiltonianVectorFieldSystem InPlace) — alloue `dx`, `dp` à chaque appel
- `rhs_oop_fn` (SciMLFunctionSystem in-place) — alloue `similar(u)` à chaque appel

**Cache AD:**

- `build_rhs` et `build_oop_rhs` (HamiltonianSystem) — utilisent `Common.cache(λ)` passé à `hamiltonian_gradient`

---

## Comparaison avec le rapport callable_structs_report.md

Le rapport `callable_structs_report.md` documente:

- ✅ Les 5 closures de VectorFieldSystem
- ✅ Les 4 closures de HamiltonianVectorFieldSystem
- ✅ Les 3 closures de HamiltonianSystem
- ❌ **Manque:** Les 5 closures de SciMLFunctionSystem (extension CTFlowsSciML)

Ce rapport complète l'inventaire en ajoutant les closures de l'extension SciML.
