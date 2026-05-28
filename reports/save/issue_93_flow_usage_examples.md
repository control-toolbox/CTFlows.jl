# CTFlows — exemples pratiques de construction et d'appel des flots

Version : CTFlows v0.9.2-beta

Ce guide montre comment créer des flots depuis des données (`VectorField`, `HamiltonianVectorField`) ou depuis des objets SciML (`ODEFunction`, `ODEProblem`), et comment les appeler.

## Imports (un seul `using CTFlows` + qualification)

```julia
using CTFlows
using OrdinaryDiffEq
using ADTypes  # pour ad_backend=ADTypes.AutoForwardDiff()
```

On qualifie ensuite explicitement avec `CTFlows.*` (`CTFlows.Flow`, `CTFlows.VectorField`, etc.).

---

## 1) `CTFlows.Flow(data::VectorField; opts...)`

Correspond à `src/Flows/building.jl` (L29-L34).

```julia
# x' = -x (autonome, sans paramètre variable)
vf = CTFlows.VectorField(
    x -> -x;
    is_autonomous=true,
    is_variable=false,
)

flow_vf = CTFlows.Flow(
    vf;
    alg=Tsit5(),
    abstol=1e-10,
    internalnorm=(u, t) -> sqrt(sum(abs2, u)),
)

# Appel "point" (StateFlow): flow(t0, x0, tf)
xf = flow_vf(0.0, [1.0], 1.0)

# Appel "trajectoire" (StateFlow): flow((t0, tf), x0)
sol_vf = flow_vf((0.0, 1.0), [1.0])
mid_vf = sol_vf(0.5)
```

**Version in-place** (avec `du` modifié en place) :

```julia
vf_ip = CTFlows.VectorField(
    (du, x) -> du .= -x;
    is_autonomous=true,
    is_variable=false,
)

flow_vf_ip = CTFlows.Flow(vf_ip; alg=Tsit5(), abstol=1e-10)
```

---

## 2) `CTFlows.Flow(data::HamiltonianVectorField; opts...)`

Correspond à `src/Flows/building.jl` (L63-L67).

```julia
# Système hamiltonien simple:
# x' = p, p' = -x
hvf = CTFlows.HamiltonianVectorField(
    (x, p) -> (p, -x);
    is_autonomous=true,
    is_variable=false,
)

flow_hvf = CTFlows.Flow(
    hvf;
    alg=Tsit5(),
    abstol=1e-10,
)

# Appel "point" (HamiltonianFlow): flow(t0, x0, p0, tf)
xf, pf = flow_hvf(0.0, [1.0], [0.0], 10.0)

# Appel "trajectoire" (HamiltonianFlow): flow((t0, tf), x0, p0)
sol_h_traj = flow_hvf((0.0, 10.0), [1.0], [0.0])
```

**Version in-place** (avec `dx, dp` modifiés en place) :

```julia
hvf_ip = CTFlows.HamiltonianVectorField(
    (dx, dp, x, p) -> (dx .= p, dp .= -x);
    is_autonomous=true,
    is_variable=false,
)

flow_hvf_ip = CTFlows.Flow(hvf_ip; alg=Tsit5(), abstol=1e-10)
```

---

## 3) `CTFlows.Flow(h::AbstractHamiltonian; opts...)`

Correspond à `src/Flows/building.jl` (L113-L118).

Ce constructeur permet de créer un flot hamiltonien directement depuis une fonction hamiltonienne scalaire. Le champ de vecteur hamiltonien est calculé automatiquement par différenciation automatique.

**Options spécifiques aux flots hamiltoniens :**

- `ad_backend` (ou `backend`, `ad`) : backend de différenciation automatique pour calculer ∂H/∂x et ∂H/∂p. Par défaut `AutoForwardDiff()`.
- `prepare_cache` : si `true`, prépare un cache de gradient une fois au début de l'intégration et le réutilise (plus performant). Si `false`, calcule les gradients à chaque pas sans préallocation (défaut: `false`). Voir [DifferentiationInterface.jl - Preparing for multiple gradients](https://juliadiff.org/DifferentiationInterface.jl/DifferentiationInterface/stable/tutorials/basic/#Preparing-for-multiple-gradients).

Les options d'intégrateur (`alg`, `abstol`, `reltol`, `internalnorm`, etc.) sont également acceptées.

```julia
# Oscillateur harmonique: H(x, p) = 0.5*(x^2 + p^2)
h = CTFlows.Hamiltonian(
    (x, p) -> 0.5 * (x[1]^2 + p[1]^2);
    is_autonomous=true,
    is_variable=false,
)

flow_h = CTFlows.Flow(
    h;
    ad_backend=ADTypes.AutoForwardDiff(),  # backend AD (défaut: AutoForwardDiff())
    prepare_cache=false,                   # cache de gradient (défaut: false)
    alg=Tsit5(),
    abstol=1e-10,
)

# Appel "point" (HamiltonianFlow): flow(t0, x0, p0, tf)
xf, pf = flow_h(0.0, [1.0], [0.0], 2π)

# Appel "trajectoire" (HamiltonianFlow): flow((t0, tf), x0, p0)
sol_h = flow_h((0.0, 2π), [1.0], [0.0])
mid_h = sol_h(π)
```

**Note sur `Flow(H)`** : contrairement à `Flow(VF)` et `Flow(HVF)`, l'hamiltonien est toujours out-of-place (fonction scalaire). Le système `HamiltonianSystem` peut construire des RHS in-place ou out-of-place pour l'intégration ODE, mais l'hamiltonien lui-même reste out-of-place.

---

## 4) `CTFlows.Flow(f::AbstractODEFunction; opts...)`

Correspond à `ext/CTFlowsSciML/flow_constructors.jl` (L31-L36).

```julia
# u' = -p*u (non autonome en paramètre p)
f = ODEFunction((du, u, p, t) -> du .= -p .* u)

flow_fun = CTFlows.Flow(
    f;
    alg=Tsit5(),
    abstol=1e-12,
    internalnorm=(u, t) -> maximum(abs, u),
)

# Appel "point" (StateFlow) avec variable=p
xf_fun = flow_fun(0.0, [1.0], 1.0; variable=2.0)

# Appel "trajectoire" (StateFlow) avec variable=p
sol_fun = flow_fun((0.0, 1.0), [1.0]; variable=2.0)
mid_fun = sol_fun(0.5)
```

**Version in-place** (déjà in-place dans l'exemple ci-dessus, signature `(du, u, p, t)`)

---

## 5) `CTFlows.Flow(prob::AbstractODEProblem; opts...)`

Correspond à `ext/CTFlowsSciML/flow_constructors.jl` (L65-L69).

```julia
prob = ODEProblem(
    (du, u, p, t) -> du .= -p .* u,
    [1.0],
    (0.0, 1.0),
    2.0,
)

flow_prob = CTFlows.Flow(
    prob;
    alg=Tsit5(),
    abstol=1e-12,
)

# 5.a) Appel sans argument (résout le problème tel quel)
# unsafe=false : vérifie le code de retour du solveur et lance une erreur si l'intégration échoue
# unsafe=true : ignore les erreurs d'intégration (utile pour le débogage)
# Note: unsafe peut être utilisé sur tous les appels de flots (point/trajectoire, StateFlow/HamiltonianFlow/SciMLProblemFlow)
res0 = flow_prob(; unsafe=false)

# 5.b) Appel remake "point" : (t0, x0, tf; variable=...)
res1 = flow_prob(0.2, [2.0], 1.5; variable=3.0, unsafe=false)

# 5.c) Appel remake "trajectoire" : ((t0, tf), x0; variable=...)
sol2 = flow_prob((0.0, 1.0), [1.0]; variable=2.0, unsafe=false)
mid2 = sol2(0.5)
```

---

## Options à passer au constructeur du flot

Dans les 5 constructeurs ci-dessus, les options se passent au moment de `CTFlows.Flow(...)`.

### Valeurs par défaut

- `alg`: par défaut `Tsit5()` (nécessite `OrdinaryDiffEqTsit5` ou un autre algorithme SciML chargé).
- `abstol`: par défaut `1e-8`.
- `internalnorm`: par défaut `Common.real_norm`, qui extrait la partie primale (Float64) des nombres duaux ForwardDiff via `deepvalue` pour garantir l’invariance de grille (IND) lors de l’intégration avec ForwardDiff.

### Explication sur `internalnorm` et ForwardDiff

Le défaut `internalnorm = Common.real_norm` est conçu pour supporter les nombres duaux ForwardDiff :

- Pour des nombres réels `u`, `real_norm(u, t)` retourne `abs(u)` (scalaire) ou `norm(u)` (vecteur).
- Pour des nombres duaux `ForwardDiff.Dual`, `real_norm(u, t)` appelle d’abord `deepvalue(u)` qui extrait récursivement la valeur primale (Float64) du dual, puis calcule la norme sur cette valeur primale.

Cela garantit que le contrôle de pas adaptatif du solveur SciML utilise uniquement la partie primale pour évaluer les erreurs, ce qui préserve l’invariance de grille (IND) lors de la différenciation automatique avec ForwardDiff. Sans ce comportement, les dérivées seraient incluses dans le calcul de la norme, ce qui pourrait entraîner des grilles de pas différentes pour des valeurs proches en primale mais différentes en dérivée.

### Exemples d’utilisation

```julia
flow = CTFlows.Flow(
    vf_or_hvf_or_fun_or_prob;
    alg=Tsit5(),                           # choix de l'algorithme SciML
    abstol=1e-11,                          # tolérance absolue (défaut: 1e-8)
    internalnorm=(u, t) -> norm(u),        # norme interne custom (défaut: Common.real_norm)
)
```

Pour utiliser la norme d'origine de SciML (qui ne préserve pas l'IND avec ForwardDiff) :

```julia
using DiffEqBase
flow = CTFlows.Flow(
    vf_or_hvf_or_fun_or_prob;
    internalnorm=DiffEqBase.ODE_DEFAULT_NORM,  # norme SciML par défaut
)
```

En pratique, pour un collègue qui veut juste tester:

1. construire un `flow` via `CTFlows.Flow(...)`;
2. appeler en mode point (`t0, x0[, p0], tf`) ou trajectoire (`(t0, tf), x0[, p0]`) selon le type de flot;
3. si c'est un `SciMLProblemFlow`, utiliser soit l'appel sans argument, soit l'appel remake point.

---

## Tableau de compatibilité

Le tableau suivant résume ce qui est supporté pour chaque constructeur selon le type d'état, le type scalaire et les fonctionnalités avancées. Les cases ✓ correspondent à des cas **testés** dans la suite de tests ; ⚠ indique un support conditionnel ou non encore validé.

| Fonctionnalité | `Flow(VF)` | `Flow(HVF)` | `Flow(H)` | `Flow(ODEFun)` / `Flow(ODEProb)` |
| --- | :---: | :---: | :---: | :---: |
| État scalaire | ✓ | ✓ | ✓ | ✓ |
| État vecteur | ✓ | ✓ | ✓ | ✓ |
| État matrice (batch) | ✓ | ✓ | ✓ (a) | ✓ |
| Réels | ✓ | ✓ | ✓ | ✓ |
| Complexes | ✓ | ✓ | ✗ (b) | ✓ |
| ForwardDiff Dual (état) | ✓ | ✓ | ⚠ (c) | ✓ |
| `SVector` (StaticArrays) | ✓ OOP / ⚠ IP | ✓ OOP / ⚠ IP | ✓ OOP | ✓ |
| `SMatrix` (StaticArrays) | ✓ OOP | ✓ OOP | ⚠ (d) | ✓ OOP |
| Coétat de v (`variable_costate=true`) | ✗ | ✗ (f) | ✓ (e) | ✗ |

**Légende :**

- **(a)** `Flow(H)` + matrice : fonctionne si H retourne un scalaire pour des entrées matricielles (ex. via `sum`, broadcasting). `DI.gradient` renvoie alors le gradient élément par élément, ce qui donne la dynamique correcte pour des hamiltoniens séparables (batch de trajectoires indépendantes). Testé avec `H = 0.5*(sum(abs2, x) + sum(abs2, p))` et `AutoForwardDiff()`.
- **(b)** Non supporté avec le backend par défaut `AutoForwardDiff()` — ForwardDiff ne supporte pas les entrées complexes lors du calcul du gradient. Fonctionne avec un backend AD custom retournant des gradients analytiques (testé via `FakeHarmonicADBackend` dans `test_flow_callables_sciml_hamiltonian_system.jl`).
- **(c)** Testé avec un backend AD custom. Avec `AutoForwardDiff()`, l'état dual crée du ForwardDiff imbriqué (dual-dans-dual) — théoriquement fonctionnel avec `prepare_cache=false` (tags distincts), mais non validé (tests commentés dans `test_flow_callables_sciml_hamiltonian_system_di.jl`). Peut avoir des problèmes avec `prepare_cache=true`.
- **(d)** Non testé pour `Flow(H)`. L'extension `CTFlowsStaticArrays` fournit `_ham_split` pour `SMatrix`, et ForwardDiff devrait calculer le gradient sur `SMatrix` — mais non validé. Testé uniquement pour `Flow(HVF)` (où `vcat(SMatrix, SMatrix)` → `Matrix` pendant l'intégration ODE).
- **(e)** Uniquement pour `Flow(H)` avec `is_variable=true`. Appel point uniquement (pas trajectoire) : `flow(t0, x0, p0, tf; variable=v, variable_costate=true)` retourne `(xf, pf, pvf)` où `pvf` est la solution de `ṗv = -∂H/∂v`. Voir `src/Flows/calling.jl`.
- **(f)** `HamiltonianVectorField` accepte `variable_costate=true` dans ses signatures d'appel pour les cas `NonFixed` (voir `src/Data/hamiltonian_vector_field.jl`), mais `HamiltonianVectorFieldSystem` n'implémente pas `variable_costate_trait` → retourne `NoVariableCostate` par défaut. Le dispatch dans `calling.jl` lève donc une erreur. Le support est donc limité au niveau du constructeur `Flow(H)`.

**StaticArrays** : nécessite `using StaticArrays` (charge `CTFlowsStaticArrays` qui fournit `_ham_split` type-stable pour `SVector` et `SMatrix`). ⚠ IP = avertissement émis si la fonction est in-place avec un état immutable (`SVector`) ; utiliser `MVector` (mutable) pour éviter l'avertissement avec les flows in-place.

> **Note** : Ce tableau est basé sur l'analyse des tests existants et du code source. Il pourrait contenir des erreurs ou omissions. Une analyse approfondie systématique (par exemple en créant des tests pour chaque combinaison type × constructeur) serait nécessaire pour vérifier exhaustivement ce qui fonctionne réellement.
