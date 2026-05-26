# Spécification : getter `hamiltonian_vector_field` — CTFlows.jl

## 1. Contexte et motivation

### 1.1 Architecture existante

CTFlows.jl organise la construction d'un flot hamiltonien en trois niveaux :

```
Hamiltonian          (données pures : H(t, x, p[, v]) → ℝ)
      ↓
HamiltonianSystem    (Hamiltonian + backend AD → RHS ODE)
      ↓
HamiltonianFlow      (HamiltonianSystem + intégrateur → flot)
```

À chaque niveau, les traits de type `TD ∈ {Autonomous, NonAutonomous}` et
`VD ∈ {Fixed, NonFixed}` encodent statiquement la dépendance temporelle et
paramétrée du système.

### 1.2 Problème

Le champ de vecteurs hamiltonien

```
X_H : (t, x, p[, v])  ↦  (ẋ, ṗ) = (∂H/∂p, −∂H/∂x)
```

est déjà **calculé en interne** lors de l'intégration ODE (via `rhs` et
`rhs_oop` de `HamiltonianSystem`), mais il n'est pas exposé à l'utilisateur
sous une forme directement exploitable.

Un utilisateur souhaitant évaluer `X_H` ponctuellement (pour du débogage,
de la visualisation, un test unitaire, ou une composition avec d'autres
outils) doit actuellement accéder aux internals du système, ce qui est fragile
et non documenté.

### 1.3 Objectif

Exposer `X_H` via un **getter public `hamiltonian_vector_field`** à trois
niveaux de la hiérarchie, retournant un `HamiltonianVectorField` — type
déjà existant dans `CTFlows.Data` — portant les bons traits et les bonnes
signatures d'appel.

---

## 2. Type de retour : `HamiltonianVectorField`

Le type `HamiltonianVectorField{F, TD, VD, MD}` existe déjà dans `CTFlows.Data`.
Il porte :

| Paramètre | Rôle |
|:----------|:-----|
| `F <: Function` | type concret de la closure wrappée |
| `TD <: TimeDependence` | `Autonomous` ou `NonAutonomous` |
| `VD <: VariableDependence` | `Fixed` ou `NonFixed` |
| `MD <: AbstractMutabilityTrait` | `InPlace` ou `OutOfPlace` |

Il expose deux familles de signatures d'appel :

**Out-of-place (OOP)**

| Traits | Signature naturelle | Signature uniforme |
|:-------|:--------------------|:-------------------|
| Autonomous / Fixed | `Xh(x, p)` | `Xh(t, x, p, v)` |
| NonAutonomous / Fixed | `Xh(t, x, p)` | `Xh(t, x, p, v)` |
| Autonomous / NonFixed | `Xh(x, p, v)` | `Xh(t, x, p, v)` |
| NonAutonomous / NonFixed | `Xh(t, x, p, v)` | `Xh(t, x, p, v)` |

**In-place (IP)**

| Traits | Signature naturelle | Signature uniforme |
|:-------|:--------------------|:-------------------|
| Autonomous / Fixed | `Xh(dx, dp, x, p)` | `Xh(dx, dp, t, x, p, v)` |
| NonAutonomous / Fixed | `Xh(dx, dp, t, x, p)` | `Xh(dx, dp, t, x, p, v)` |
| Autonomous / NonFixed | `Xh(dx, dp, x, p, v)` | `Xh(dx, dp, t, x, p, v)` |
| NonAutonomous / NonFixed | `Xh(dx, dp, t, x, p, v)` | `Xh(dx, dp, t, x, p, v)` |

Le getter produit la **closure appropriée** puis l'enveloppe dans un
`HamiltonianVectorField` en passant `is_autonomous`, `is_variable` et
`is_inplace` déduits des traits du système source.

---

## 3. Trois surcharges du getter

### 3.1 `hamiltonian_vector_field(h::Hamiltonian)` — erreur explicite

Un `Hamiltonian` seul est une fonction scalaire pure. Il ne porte **aucun
backend AD**, donc il est impossible de calculer `∂H/∂x` et `∂H/∂p`.

**Comportement :** lève une `NotImplemented` avec un message guidant
l'utilisateur vers `HamiltonianSystem`.

**Justification :** une erreur explicite et informative est préférable au
silence ou à un dispatch ambigu. Elle documente aussi implicitement la
contrainte d'architecture (backend requis).

### 3.2 `hamiltonian_vector_field(sys::HamiltonianSystem; inplace=false)` — cœur du getter

C'est ici que le travail est fait.

**Étapes :**

1. Extraire `h = sys.h` et `backend = sys.backend`.
2. Construire la closure via un helper interne `_make_oop_hvf` ou
   `_make_ip_hvf`, dispatché sur `(TD, VD)`.
3. À l'intérieur de chaque closure, appeler
   `Differentiation.hamiltonian_gradient(backend, h, t, x, p, v, nothing)`
   avec `cache = nothing`.
4. Envelopper la closure dans `HamiltonianVectorField(wrapped; is_autonomous,
   is_variable, is_inplace)`.

**Pourquoi appeler `hamiltonian_gradient` directement plutôt que `rhs_oop` ?**

`rhs_oop` a la signature ODE interne `(u, λ, t)` où `λ` est un
`ODEParameters` (portant variable + cache). Utiliser `rhs_oop` dans le getter
créerait une dépendance forte à `ODEParameters`, type interne à ne pas
exposer dans une API publique. En appelant `hamiltonian_gradient` directement,
la closure est autonome et ne suppose rien sur la structure interne des
paramètres ODE.

**Pourquoi `cache = nothing` ?**

Le cache préparé (`DifferentiationInterfaceCache`) est conçu pour
**l'intégration ODE répétée** : il pré-alloue les plans de différentiation
pour des appels successifs avec des `(x, p)` de même type et taille.

Dans le contexte du getter, on suppose des **appels ponctuels** (débogage,
visualisation, tests). Passer `cache = nothing` déclenche le fallback vers
`DI.gradient` sans plan préparé, ce qui est correct et sans surcoût notable
pour des appels isolés.

Pour des appels répétés en dehors du flow (cas avancé), l'utilisateur peut
toujours intégrer via `HamiltonianFlow` qui, lui, gère le cache.

**kwarg `inplace::Bool` (défaut `false`) :**

- `false` → closure OOP, retourne un tuple `(ẋ, ṗ)`.
- `true`  → closure IP, remplit `dx` et `dp` en place, retourne `nothing`.

Le défaut `false` est choisi car l'OOP est naturel pour les appels ponctuels
et correspond à la représentation mathématique `X_H(t, x, p) = (ẋ, ṗ)`.

### 3.3 `hamiltonian_vector_field(flow::HamiltonianFlow; inplace=false)` — délégation

Délègue simplement à la surcharge sur `HamiltonianSystem` :

```julia
hamiltonian_vector_field(flow.system; inplace)
```

**Justification :** le `HamiltonianFlow` n'ajoute rien au calcul de `X_H` ;
l'intégrateur n'intervient pas. La délégation garde l'implémentation dans
`Systems`, sans dupliquer de logique dans `Flows`.

---

## 4. Helpers internes `_make_oop_hvf` / `_make_ip_hvf`

Huit fonctions (4 combinaisons de traits × 2 variantes OOP/IP), toutes dans
`Systems`, non exportées.

Elles dispatché sur `(::Type{TD}, ::Type{VD})` — dispatch de type, pas de
valeur — pour que le compilateur génère du code spécialisé par combinaison de
traits sans branchement à l'exécution.

**Pattern OOP :**

```julia
_make_oop_hvf(h, backend, ::Type{Traits.Autonomous}, ::Type{Traits.Fixed}) =
    (x, p) -> begin
        ∂x, ∂p = Differentiation.hamiltonian_gradient(backend, h, 0.0, x, p, nothing, nothing)
        return (∂p, -∂x)
    end
```

**Note sur `0.0` pour les systèmes autonomes :** le `Hamiltonian` autonome
appelle `H.f(x, p)` via sa signature uniforme `H(_, x, p, _)` — `t` est
ignoré. Passer `0.0` (plutôt que `nothing`) garantit la stabilité de type
pour les backends AD, qui peuvent inspecter le type de tous les arguments
même si certains sont des `Constant`.

**Pattern IP :**

```julia
_make_ip_hvf(h, backend, ::Type{Traits.Autonomous}, ::Type{Traits.Fixed}) =
    (dx, dp, x, p) -> begin
        ∂x, ∂p = Differentiation.hamiltonian_gradient(backend, h, 0.0, x, p, nothing, nothing)
        dx .= ∂p;  dp .= .-∂x
        return nothing
    end
```

`dx .= ∂p` et `dp .= .-∂x` utilisent la diffusion Julia pour remplir les
buffers en place sans allocation intermédiaire.

---

## 5. Localisation dans le dépôt

| Composant | Fichier suggéré |
|:----------|:----------------|
| Erreur sur `Hamiltonian` | `src/data/hamiltonian.jl` ou `src/systems/hamiltonian_system.jl` |
| `_make_oop_hvf` / `_make_ip_hvf` | `src/systems/hamiltonian_system.jl` (helpers privés) |
| `hamiltonian_vector_field(::HamiltonianSystem)` | `src/systems/hamiltonian_system.jl` |
| `hamiltonian_vector_field(::HamiltonianFlow)` | `src/flows/hamiltonian_flow.jl` |
| Export public | `src/CTFlows.jl` (ou module `Systems` / `Flows`) |

---

## 6. Tests à écrire

### 6.1 Sur `Hamiltonian` seul
- Vérifier que `hamiltonian_vector_field(h)` lève bien une `NotImplemented`.

### 6.2 Sur `HamiltonianSystem` — OOP
Pour chaque combinaison `(TD, VD)` :
- Construire un hamiltonien analytique dont les gradients sont connus.
- Appeler `Xh = hamiltonian_vector_field(sys)` et vérifier le retour avec la
  signature naturelle et la signature uniforme.
- Vérifier que `Xh` est bien un `HamiltonianVectorField{..., OutOfPlace}`.

**Exemple canonique** (`Autonomous/Fixed`, `H(x,p) = ½‖p‖²`) :
```
X_H(x, p) = (∂H/∂p, −∂H/∂x) = (p, 0)
```

### 6.3 Sur `HamiltonianSystem` — IP
- Idem, vérifier que les buffers sont correctement remplis.
- Vérifier le type `HamiltonianVectorField{..., InPlace}`.
- Vérifier que la valeur de retour est `nothing`.

### 6.4 Sur `HamiltonianFlow`
- Vérifier que `hamiltonian_vector_field(flow)` retourne le même objet
  (ou un objet équivalent) que `hamiltonian_vector_field(flow.system)`.

### 6.5 NonFixed
- Vérifier que pour `VD = NonFixed`, la closure accepte bien `v` et que
  `∂H/∂x` et `∂H/∂p` dépendent correctement de `v`.

### 6.6 Backends
- Tester avec au moins `AutoForwardDiff()` (ou l'équivalent disponible).
- Optionnel : tester que `cache = nothing` ne pose pas de problème de
  performance mesurable sur un appel unique.

---

## 7. Points d'attention et limites connues

| Point | Détail |
|:------|:-------|
| **Cache non utilisé** | Les appels via le getter sont sans cache. Pour des simulations intensives, passer par le flow. |
| **NonFixed et `variable_gradient`** | Le getter ne retourne pas `v̇ = −∂H/∂v`. Si le besoin émerge, prévoir une variante `augmented=true` retournant `(ẋ, ṗ, v̇)`. |
| **Type de `t` pour systèmes autonomes** | `0.0` est hardcodé. Si des backends exigent un type entier ou symbolique pour `t`, la closure devrait accepter `t` comme argument supplémentaire ignoré. |
| **Stabilité de type** | La closure doit être type-stable pour que `hamiltonian_gradient` le soit aussi. À vérifier avec `@code_warntype` sur les combinaisons OOP. |

---

## 8. Résumé décisionnel

| Question | Décision | Raison |
|:---------|:---------|:-------|
| Réutiliser `rhs_oop` ? | ✗ Non | Évite la dépendance à `ODEParameters` |
| Utiliser `hamiltonian_gradient` directement ? | ✓ Oui | API publique, stable, claire |
| `cache = nothing` ? | ✓ Oui | Getter = usage ponctuel hors intégration |
| Retour OOP = tuple `(ẋ, ṗ)` ? | ✓ Oui | Représentation mathématique naturelle |
| kwarg `inplace` ? | ✓ Oui, défaut `false` | OOP = cas par défaut ; IP disponible |
| Erreur sur `Hamiltonian` seul ? | ✓ Oui, `NotImplemented` | Explicit is better than silent failure |
| `v̇` dans le retour ? | ✗ Non (pour l'instant) | Hors scope ; prévoir extension future |
