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

### 3.1 `hamiltonian_vector_field(h::Hamiltonian; ad_backend, inplace)` — entrée directe

Un `Hamiltonian` seul ne porte pas de backend AD, mais grâce à
`build_ad_backend()` et `DifferentiationInterface`, on peut en construire un
directement dans le getter.

**Signature proposée :**

```julia
function hamiltonian_vector_field(
    h::Data.Hamiltonian{F, TD, VD};
    ad_backend = __ad_backend(),
    inplace = __hvf_inplace()
) where {F, TD, VD}
    backend = build_ad_backend(; ad_backend=ad_backend, prepare_cache=false)
    # ... construction de la closure via _make_oop_hvf / _make_ip_hvf
end
```

**Valeurs par défaut (définies dans `src/Common/default.jl`) :**

- `__ad_backend() = ADTypes.AutoForwardDiff()` — backend AD par défaut
- `__hvf_inplace() = false` — mode out-of-place par défaut

**Comportement :** construit la closure via `_make_oop_hvf` / `_make_ip_hvf`
directement depuis `h` et `backend`, sans passer par un `HamiltonianSystem`
intermédiaire. C'est équivalent à `hamiltonian_vector_field(HamiltonianSystem(h, backend); inplace)`,
mais sans allouer ni `rhs` ni `rhs_oop` qui ne servent pas ici.

**Pourquoi `prepare_cache=false` hardcodé ?** Le cache préparé est conçu pour
l'intégration ODE répétée. Dans le contexte du getter (appels ponctuels :
débogage, visualisation, tests), le cache n'apporte aucun bénéfice et
serait une surcharge inutile. Pour des appels répétés, l'utilisateur doit
passer par `HamiltonianFlow` qui gère le cache correctement.

**Exemples d'usage :**

```julia
# Cas le plus simple — backend par défaut (AutoForwardDiff)
h  = Hamiltonian((x, p) -> 0.5 * sum(p.^2))
Xh = hamiltonian_vector_field(h)

# Backend explicite
Xh = hamiltonian_vector_field(h; ad_backend = AutoZygote())

# In-place
Xh = hamiltonian_vector_field(h; inplace = true)
```

**Justification de ce choix vs erreur :** exposer un backend par défaut
fonctionnel est plus ergonomique et cohérent avec le reste de l'API
(e.g., `HamiltonianSystem` a aussi un backend par défaut implicite dans son
constructeur). L'erreur n'apporte rien quand un défaut sensé existe.

### 3.2 `hamiltonian_vector_field(sys::HamiltonianSystem; inplace=__hvf_inplace())` — surcharge système

Délègue simplement à la surcharge sur `Hamiltonian` en passant le backend AD du système.

**Accès aux options d'une stratégie :** Les backends AD sont des stratégies CTSolvers.
Pour accéder à leurs options, on utilise le pattern en deux étapes :

```julia
opts = CTSolvers.Strategies.options(backend)
ad_backend = opts[:ad_backend]
```

```julia
function hamiltonian_vector_field(sys::HamiltonianSystem{N,F,TD,VD}; inplace=__hvf_inplace()) where {N,F,TD,VD}
    opts = CTSolvers.Strategies.options(sys.backend)
    ad_backend = opts[:ad_backend]
    return hamiltonian_vector_field(sys.h; ad_backend=ad_backend, inplace=inplace)
end
```

Toute la logique de construction des closures reste dans la surcharge `Hamiltonian`,
qui devient le **point d'entrée canonique**. La surcharge `HamiltonianSystem` n'est
qu'une façade qui extrait le backend AD via l'API des stratégies et délègue.

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

**Hiérarchie d'appel finale :**

```
hamiltonian_vector_field(flow)   →   hamiltonian_vector_field(flow.system)
hamiltonian_vector_field(sys)    →   opts = CTSolvers.Strategies.options(sys.backend)
                                      ad_backend = opts[:ad_backend]
                                      hamiltonian_vector_field(sys.h; ad_backend=ad_backend, ...)
hamiltonian_vector_field(h; ad_backend, inplace)   ←   point d'entrée canonique
        ↓
backend = build_ad_backend(; ad_backend=ad_backend, prepare_cache=false)
        ↓
_make_oop_hvf / _make_ip_hvf(h, backend, TD, VD)
        ↓
HamiltonianVectorField(wrapped; is_autonomous, is_variable, is_inplace)
```

### 3.3 `hamiltonian_vector_field(flow::HamiltonianFlow; inplace=__hvf_inplace())` — délégation

Délègue à la surcharge sur `HamiltonianSystem` :

```julia
function hamiltonian_vector_field(flow::HamiltonianFlow; inplace=__hvf_inplace())
    return hamiltonian_vector_field(flow.system; inplace=inplace)
end
```

**Justification :** le `HamiltonianFlow` n'ajoute rien au calcul de `X_H` ;
l'intégrateur n'intervient pas. La délégation garde toute la logique dans
la surcharge `Hamiltonian`, sans dupliquer de code.

---

### 3.5 Extension : `variable_costate=true` sur un `HamiltonianVectorField`

**Contexte :** pour les systèmes `NonFixed`, le flux hamiltonien supporte
`variable_costate=true`, qui intègre l'équation augmentée `ṗᵥ = −∂H/∂v`.
Cette capacité est pilotée par le trait `SupportsVariableCostate` / `NoVariableCostate`
(cf. `Traits.variable_costate_trait`).

Actuellement, seul `HamiltonianSystem{..., NonFixed}` retourne `SupportsVariableCostate` ;
`HamiltonianVectorFieldSystem` retourne toujours `NoVariableCostate` (pas d'AD).

**Proposition :** étendre le getter pour que le `HamiltonianVectorField` retourné
(pour `VD = NonFixed`) supporte un appel avec `variable_costate=true` :

```julia
Xh(t, x, p, v; variable_costate=false) -> (ẋ, ṗ)          # défaut
Xh(t, x, p, v; variable_costate=true)  -> (ẋ, ṗ, v̇)       # augmenté
```

**Mécanisme pour les HVF issus du getter (depuis un `Hamiltonian`) :**

La closure produite par `_make_oop_hvf` pour `NonFixed` encapsule déjà `h` et
`backend`. Il suffit d'ajouter le kwarg et d'appeler `variable_gradient` si demandé :

```julia
_make_oop_hvf(h, backend, ::Type{Traits.Autonomous}, ::Type{Traits.NonFixed}) =
    (x, p, v; variable_costate=false) -> begin
        ∂x, ∂p = Differentiation.hamiltonian_gradient(backend, h, nothing, x, p, v, nothing)
        variable_costate || return (∂p, -∂x)
        ∂v = Differentiation.variable_gradient(backend, h, nothing, x, p, v, nothing)
        return (∂p, -∂x, -∂v)
    end
```

**Mécanisme pour les HVF fournis directement par l'utilisateur :**

Si le `HamiltonianVectorField` ne vient pas du getter, la closure sous-jacente peut
ou non supporter `variable_costate`. On utilise `hasmethod` (pas de try-catch) :

```julia
# Vérifier si la fonction sous-jacente accepte le kwarg variable_costate
hasmethod(hvf.f, Tuple{typeof(x), typeof(p), typeof(v)}, (:variable_costate,))
```

Si `hasmethod` retourne `false` et que le HVF n'est pas issu du getter, on lève
une `PreconditionError` avec suggestion d'utiliser `hamiltonian_vector_field(h; ...)`.

**Arité :** `variable_costate` est un kwarg, pas un argument positionnel. L'arité
de `hvf.f` est inchangée — la détection de mutabilité dans `_detect_mutability_hvf`
n'est pas affectée.

**Scope :** cette extension ne concerne que `VD = NonFixed`. Pour `Fixed`, appeler
avec `variable_costate=true` lève une erreur claire (`NoVariableCostate`).

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
        ∂x, ∂p = Differentiation.hamiltonian_gradient(backend, h, nothing, x, p, nothing, nothing)
        return (∂p, -∂x)
    end
```

**Note sur `nothing` pour les systèmes autonomes :** la signature uniforme
`H(_, x, p, _)` utilise `_` pour ignorer complètement `t` — aucune opération
arithmétique n'est effectuée sur `t`. Le backend AD reçoit `t` enveloppé dans
`DI.Constant(t)`, donc il ne l'inspecte pas non plus. Passer `nothing` est
donc cohérent avec la convention `v=nothing` pour les systèmes `Fixed`.

**Pattern IP :**

```julia
_make_ip_hvf(h, backend, ::Type{Traits.Autonomous}, ::Type{Traits.Fixed}) =
    (dx, dp, x, p) -> begin
        ∂x, ∂p = Differentiation.hamiltonian_gradient(backend, h, nothing, x, p, nothing, nothing)
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
| `hamiltonian_vector_field(::Hamiltonian)` — point d'entrée canonique | `src/data/hamiltonian.jl` ou `src/systems/hamiltonian_system.jl` |
| `_make_oop_hvf` / `_make_ip_hvf` | même fichier, helpers privés |
| `hamiltonian_vector_field(::HamiltonianSystem)` | `src/systems/hamiltonian_system.jl` |
| `hamiltonian_vector_field(::HamiltonianFlow)` | `src/flows/hamiltonian_flow.jl` |
| Export public | `src/CTFlows.jl` (ou module `Systems` / `Flows`) |

---

## 6. Tests à écrire

### 6.1 Sur `Hamiltonian` seul avec backend par défaut
- Vérifier que `hamiltonian_vector_field(h)` fonctionne sans rien spécifier
  (utilise `__ad_backend()` → `AutoForwardDiff`).
- Vérifier que `hamiltonian_vector_field(h; ad_backend=AutoZygote())`
  utilise bien le backend spécifié.
- Vérifier que le backend par défaut peut être surchargé globalement si
  `CTSolvers.Strategies` le permet.

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
- Vérifier que `Xh(x, p, v; variable_costate=true)` retourne un triplet `(ẋ, ṗ, v̇)`
  pour un hamiltonien analytique connu (e.g., `H(x, p, v) = v * ‖p‖²/2`, où `v̇ = −‖p‖²/2`).
- Vérifier que `variable_costate=true` sur un HVF `Fixed` lève une erreur.
- Vérifier que `hasmethod` détecte correctement la présence/absence du kwarg.

### 6.6 Backends
- Tester avec au moins `AutoForwardDiff()` (ou l'équivalent disponible).
- Optionnel : tester que `cache = nothing` ne pose pas de problème de
  performance mesurable sur un appel unique.

---

## 7. Points d'attention et limites connues

| Point | Détail |
|:------|:-------|
| **Cache non utilisé** | Les appels via le getter sont sans cache. Pour des simulations intensives, passer par le flow. |
| **NonFixed et `variable_costate`** | Pour `VD = NonFixed`, les closures issues du getter supportent `variable_costate=true` retournant `(ẋ, ṗ, v̇)`. Pour les HVF fournis directement par l'utilisateur, `hasmethod` détermine si le kwarg est supporté. |
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
| **Backend par défaut sur `Hamiltonian`** | `__ad_backend()` → `AutoForwardDiff`, `prepare_cache=false` hardcodé | Zéro config pour l'utilisateur |
| Erreur sur `Hamiltonian` seul ? | ✗ Non — backend par défaut | `build_ad_backend()` rend l'erreur inutile |
| `v̇` dans le retour (`variable_costate=true`) ? | ✓ Oui pour `NonFixed`, via kwarg | `hasmethod` pour HVF utilisateur ; `variable_gradient` pour HVF issus du getter |
