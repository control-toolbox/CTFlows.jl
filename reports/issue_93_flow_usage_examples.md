# CTFlows — exemples pratiques de construction et d'appel des flots

Ce guide montre comment créer des flots depuis des données (`VectorField`, `HamiltonianVectorField`) ou depuis des objets SciML (`ODEFunction`, `ODEProblem`), et comment les appeler.

## Imports (un seul `using CTFlows` + qualification)

```julia
using CTFlows
using OrdinaryDiffEq
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

---

## 2) `CTFlows.Flow(data::HamiltonianVectorField; state_dimension=..., opts...)`

Correspond à `src/Flows/building.jl` (L65-L70).

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
    state_dimension=1,
    alg=Tsit5(),
    abstol=1e-10,
)

# Appel "point" (HamiltonianFlow): flow(t0, x0, p0, tf)
xf, pf = flow_hvf(0.0, [1.0], [0.0], 10.0)

# Appel "trajectoire" (HamiltonianFlow): flow((t0, tf), x0, p0)
sol_h_traj = flow_hvf((0.0, 10.0), [1.0], [0.0])
```

---

## 3) `CTFlows.Flow(f::AbstractODEFunction; opts...)`

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

---

## 4) `CTFlows.Flow(prob::AbstractODEProblem; opts...)`

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

# 4.a) Appel sans argument (résout le problème tel quel)
# unsafe=false : vérifie le code de retour du solveur et lance une erreur si l'intégration échoue
# unsafe=true : ignore les erreurs d'intégration (utile pour le débogage)
# Note: unsafe peut être utilisé sur tous les appels de flots (point/trajectoire, StateFlow/HamiltonianFlow/SciMLProblemFlow)
res0 = flow_prob(; unsafe=false)
xf0 = CTFlows.final_state(res0)

# 4.b) Appel remake "point" : (t0, x0, tf; variable=...)
res1 = flow_prob(0.2, [2.0], 1.5; variable=3.0, unsafe=false)
xf1 = CTFlows.final_state(res1)
```

Remarque importante: il n'existe pas (encore) d'appel avec tuple `(t0, tf)` pour `SciMLProblemFlow`.

```julia
# Actuellement non implémenté pour SciMLProblemFlow:
# flow_prob((0.0, 1.0), [1.0])
```

---

## Options à passer au constructeur du flot

Dans les 4 constructeurs ci-dessus, les options se passent au moment de `CTFlows.Flow(...)`.

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
    alg=Tsit5(),                    # choix de l'algorithme SciML
    abstol=1e-11,                   # tolérance absolue (défaut: 1e-8)
    internalnorm=(u, t) -> norm(u), # norme interne custom (défaut: Common.real_norm)
)
```

En pratique, pour un collègue qui veut juste tester:

1. construire un `flow` via `CTFlows.Flow(...)`;
2. appeler en mode point (`t0, x0[, p0], tf`) ou trajectoire (`(t0, tf), x0[, p0]`) selon le type de flot;
3. si c'est un `SciMLProblemFlow`, utiliser soit l'appel sans argument, soit l'appel remake point.
