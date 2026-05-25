# Synthèse design : gestion des formes et construction des RHS

## Objectifs

1. **Cohérence des formes** : si l'utilisateur passe un scalaire, il récupère un scalaire ; un vecteur de taille 1 → vecteur de taille 1 ; etc.
2. **Économie de closures** : ne construire que la closure effectivement utilisée lors d'un appel de flot.
3. **Découplage construction / appel** : la construction du flot ne nécessite aucune information sur les conditions initiales.
4. **Centralisation de la décision** : c'est `build_problem` qui choisit quelle closure construire, en fonction de `ismutable(u0)`.

---

## Les trois systèmes

| Système | Split `u → (x, p)` ? | Coerce scalaire ? | Quand construire le RHS |
|---|---|---|---|
| `VectorFieldSystem` | Non — `u = x` | Non nécessaire | À la construction (pas de split ni de coerce) |
| `HamiltonianVectorFieldSystem` | Oui — `u = [x; p]` | Oui | Paresseux dans `build_problem` |
| `HamiltonianSystem` (AD) | Oui — `u = [x; p]` (ou `[x; p; pv]`) | Oui | Paresseux dans `build_problem` |

---

## Helpers communs aux systèmes hamiltoniens

### `_state_dim(x0)`
```
Number         → 1
AbstractVector → length(x0)
AbstractMatrix → size(x0, 1)
```

### `_make_coerce(x0)` — appliqué aux vues **en entrée** du HVF uniquement
```
Number         → only    # 1-element SubArray → scalaire
AbstractVector → identity
AbstractMatrix → identity
```

### `_ham_split(u, N)` — toujours des vues, N toujours Int
```julia
_ham_split(u::AbstractVector, N::Int) = @view(u[1:N]),    @view(u[N+1:2N])
_ham_split(u::AbstractMatrix, N::Int) = @view(u[1:N, :]), @view(u[N+1:2N, :])
```
`N = nothing` disparaît : il est toujours connu à la construction paresseuse.

---

## Règle d'asymétrie : entrées vs sorties (cas HamiltonianVectorFieldSystem)

| | Entrées HVF (`x`, `p`) | Sorties HVF (`dx`, `dp`) |
|---|---|---|
| OOP HVF | coercées (scalaire si N=1) | retournées telles quelles |
| IP HVF, `u0` mutable | coercées | **jamais coercées** — vues mutables 1D |
| IP HVF, `u0` immutable | coercées | buffers alloués, résultat converti via `typeof(u)(...)` |

Pour `HamiltonianSystem` (AD), la sortie du gradient est toujours un vecteur : pas de cas IP.

---

## Arbre de décision dans `build_problem`

```
ismutable(u0) ?
│
├─ oui ──→ build_rhs(sys, x0, p0)       →  ODEProblem(f!, u0, tspan, λ)
│          (closure in-place)
│
└─ non ──→ build_oop_rhs(sys, x0, p0)   →  ODEProblem(f, u0, tspan, λ)
           (closure out-of-place)
```

Pour `VectorFieldSystem` (RHS précompilés) :
```
ismutable(u0) ?
├─ oui ──→ rhs(sys)              → ODEProblem(f!, u0, tspan, λ)
└─ non ──→ rhs_oop(sys, false)   → ODEProblem(f,  u0, tspan, λ)
```

---

## VectorFieldSystem — pourquoi pas lazy ?

Pas de split `u → (x, p)`, pas de coerce : le RHS ne dépend pas de la forme de `x0`.
Les trois closures (in-place, oop, oop-finalize) sont construites une fois à la
construction et le coût est négligeable.

La gestion scalaire est naturelle :
- `x0 :: Number` → `ismutable = false` → chemin oop → `vf(t, u, v)` retourne un scalaire ✓
- `x0 :: SVector` → `ismutable = false` → `rhs_oop_finalize` → `typeof(u)(dx)` ✓
- `x0 :: Vector` → chemin in-place ✓

⚠️ Combinaison non supportée : VF **in-place** + `x0 :: Number`.
`similar(::Number)` échoue. Doit être détectée à la construction avec un `@warn` clair.

---

## HamiltonianVectorFieldSystem — lazy obligatoire

Le split et le coerce dépendent de la forme de `x0`/`p0`.
Une seule closure construite par appel de flot ; recompilée une fois par combinaison
de types `(typeof(x0), typeof(p0))` grâce au dispatch Julia.

---

## HamiltonianSystem (AD) — lazy, cas augmenté

Pour le cas non-augmenté, même logique que `HamiltonianVectorFieldSystem`.

Pour le cas augmenté (`u = [x; p; pv]`) :
- `pv` est la costate de la variable `v`
- `u0 = vcat(x0, p0, pv0)` est toujours un `Vector` mutable (pas de SVector)
- **Cas matriciel non supporté** : si `x0` est une matrice (batch), la signification
  de `pv` devient ambiguë (un `pv` par colonne ?). Ce cas est bloqué explicitement
  avec une `Exceptions.NotImplemented`.

---

## Résumé des fonctions publiques par système

| Système | Fonctions exposées |
|---|---|
| `VectorFieldSystem` | `rhs(sys)`, `rhs_oop(sys, is_mutable)` |
| `HamiltonianVectorFieldSystem` | `build_rhs(sys, x0, p0)`, `build_oop_rhs(sys, x0, p0)` |
| `HamiltonianSystem` | `build_rhs(sys, x0, p0)`, `build_oop_rhs(sys, x0, p0)`, `build_rhs_augmented(sys, n_x, n_v)` |

---

## Ce qui change dans `build_problem`

**Avant** : `sys` stocke 3 closures ; `build_problem` appelle `rhs(sys)` ou `rhs_oop(sys, bool)`.
`bool` est un flag indirect qui encode la mutabilité de `u0` sans y avoir accès.

**Après** : `build_problem` reçoit `config` (donc `x0`, `p0`, `u0`) et décide lui-même
de construire la seule closure nécessaire. Le flag `is_u0_mutable` disparaît de l'API.
