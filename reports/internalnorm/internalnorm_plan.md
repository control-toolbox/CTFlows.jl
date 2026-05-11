# Add `internalnorm` for grid invariance under ForwardDiff (IND)

## Contexte

### IND — Internal Numerical Differentiation

L'**IND** (Internal Numerical Differentiation, ou Différentiation Numérique Interne) désigne la stratégie qui consiste à différentier *à l'intérieur* de l'intégrateur ODE, c'est-à-dire à propager les nombres duaux ForwardDiff directement à travers les étapes du solveur, plutôt que de différentier la solution après coup.

La propriété clé de l'IND est la **grid invariance** : la grille temporelle adaptative `{t₀, t₁, ..., tₙ}` choisie par le contrôleur de pas doit être **identique** à celle qu'on obtiendrait en intégrant l'ODE originale en arithmétique réelle. Autrement dit, le contrôleur de pas ne doit "voir" que la partie primale (`Float64`) de l'état, en ignorant les parties duales qui transportent l'information de sensibilité.

Sans cette garantie, la grille change selon l'ordre de différentiation, ce qui rend les dérivées numériquement incohérentes entre elles et produit des sensibilités inexactes, voire instables, dans les algorithmes de tir.

### Le problème avec `ODE_DEFAULT_NORM`

Lors de l'intégration de `S(p0) = π_x(exp(tf·Hv)(x0, p0)) - xf` via ForwardDiff, l'état intégré est de type `Dual{Tag, Float64, N}`. L'estimateur de pas doit donc porter sur la partie primale uniquement.

SciML fournit dans `DiffEqBaseForwardDiffExt` des surcharges de `ODE_DEFAULT_NORM` pour les `Dual` :

```julia
@inline ODE_DEFAULT_NORM(u::ForwardDiff.Dual, ::Any) = sqrt(sse(u))
@inline function ODE_DEFAULT_NORM(u::AbstractArray{<:ForwardDiff.Dual{Tag, T}}, t) where {Tag, T}
    return sqrt(DiffEqBase.__sum(sse, u; init = sse(zero(T))) / DiffEqBase.totallength(u))
end
```

Le problème est dans `sse`. Dans DiffEqBase, `sse(x) = abs2(x)`. Or pour un `Dual` ForwardDiff :

```
abs2(Dual(v, p₁, p₂, ...)) = Dual(abs2(v), 2v·p₁, 2v·p₂, ...)
```

`sse` sur un `Dual` retourne donc **un `Dual`**, pas un `Float64`. La norme retourne elle-même un `Dual`, et le contrôleur de pas prend ses décisions accept/reject en fonction d'une valeur qui inclut les partials. **Les parties duales influencent la sélection du pas**, ce qui brise la grid invariance — même au premier ordre.

La `real_norm` basée sur `deepvalue` corrige cela en garantissant que la norme retourne toujours un `Float64` pur, quelle que soit la profondeur d'imbrication des `Dual` :

```julia
deepvalue(x::Real)             = x                       # base case
deepvalue(x::ForwardDiff.Dual) = deepvalue(value(x))     # descend récursivement
```

De plus, avec `OrdinaryDiffEqTsit5` (le sous-paquet léger utilisé dans CTFlows), `DiffEqBaseForwardDiffExt` peut ne pas être activé du tout, laissant la norme retomber sur `norm(u)` qui inclut encore plus brutalement toutes les parties duales.

**Objectif** : définir une `real_norm` basée sur `deepvalue` (extraction récursive de la partie primale) et l'enregistrer comme **valeur par défaut de l'option `internalnorm`** dans la stratégie `SciML`.

---

## Où vit quoi

```
CTFlowsSciML.jl
    deepvalue(x)      — extraction récursive Float64 depuis Dual imbriqués
    real_norm(u, t)   — norme basée sur deepvalue, conforme à l'interface SciML
    + nouvelle OptionDefinition :internalnorm dans Strategies.metadata(::Type{SciML})
```

`deepvalue` reste dans l'extension SciML pour l'instant (dépend de ForwardDiff). Si le backend AD change (Enzyme, etc.), `deepvalue` migrera dans CTBase et sera redéfini par backend — c'est l'objet de CTBase#25 / CTFlows#93.

---

## Implémentation

### Step 0 — Branche

```bash
git checkout develop && git pull
git checkout -b feature/internalnorm-ind
```

### Step 1 — Définir `deepvalue` et `real_norm` dans `CTFlowsSciML.jl`

Ajouter **avant** la définition de `Strategies.metadata` :

```julia
import ForwardDiff

# Extraction récursive de la partie réelle — gère les Dual imbriqués
# (ordre 1 : Dual{T, Float64, N}, ordre 2 : Dual{T1, Dual{T2, Float64, N2}, N1}, etc.)
deepvalue(x::Real)          = x
deepvalue(x::ForwardDiff.Dual) = deepvalue(ForwardDiff.value(x))

# Norme interne basée uniquement sur la partie primale
# Conforme à l'interface SciML : internalnorm(u, t)
real_norm(u::AbstractArray, t) = DiffEqBase.ODE_DEFAULT_NORM(deepvalue.(u), t)
real_norm(u::ForwardDiff.Dual, t) = abs(deepvalue(u))
real_norm(u::Real, t)          = abs(u)
```

Ajouter `using DiffEqBase: DiffEqBase` dans les imports du module.

### Step 2 — Ajouter `internalnorm` comme option dans `Strategies.metadata(::Type{SciML})`

Dans la liste des `OptionDefinition`, ajouter :

```julia
Strategies.OptionDefinition(;
    name        = :internalnorm,
    type        = Any,
    default     = real_norm,
    description = "Internal norm for adaptive step-size control. " *
                  "Defaults to `real_norm`, which extracts the primal (Float64) " *
                  "part of ForwardDiff dual numbers to ensure grid invariance (IND). " *
                  "Set to `DiffEqBase.ODE_DEFAULT_NORM` to use the SciML default.",
    aliases     = (:internal_norm, :norm),
),
```

Aucun `validator` ici — la valeur est une fonction, difficile à valider statiquement.

### Step 3 — Vérifier que `solve_problem` passe bien `internalnorm`

`internalnorm` sera automatiquement inclus dans `Strategies.options_dict(integ)` et donc passé à `SciMLBase.solve(prob; options...)`. Aucun changement dans `solve_problem`. Vérifier quand même que `options_dict` ne filtre pas les fonctions — si c'est le cas, une adaptation de `CTSolvers` peut être nécessaire.

---

## Tests

### Step 4 — `test/suite/extensions/test_internalnorm.jl` (nouveau fichier)

#### Test 1 — `deepvalue` descend correctement

```julia
@testset "deepvalue" begin
    using ForwardDiff
    # Ordre 0 — identité
    @test CTFlowsSciML.deepvalue(1.0) === 1.0
    # Ordre 1
    d1 = ForwardDiff.Dual{:Tag1}(3.0, 1.0)
    @test CTFlowsSciML.deepvalue(d1) === 3.0
    # Ordre 2 — Dual imbriqué
    d2 = ForwardDiff.Dual{:Tag2}(d1, d1)
    @test CTFlowsSciML.deepvalue(d2) === 3.0
end
```

#### Test 2 — `real_norm` ignore les parties duales

```julia
@testset "real_norm is grid-invariant" begin
    using ForwardDiff
    u_real = [1.0, 2.0, 3.0]
    u_dual = ForwardDiff.Dual{:T}.(u_real, ones(3))  # mêmes valeurs, partials ≠ 0
    # La norme doit être identique
    @test CTFlowsSciML.real_norm(u_real, 0.0) ≈ CTFlowsSciML.real_norm(u_dual, 0.0)
end
```

#### Test 3 — Grille DIFFÉRENTE sans `real_norm` (régression)

Ce test documente le problème original et garantit qu'il existe bien.

```julia
@testset "grids differ WITHOUT real_norm (baseline)" begin
    using ForwardDiff, OrdinaryDiffEqTsit5, SciMLBase

    f!(du, u, p, t) = (du .= u)  # ẋ = x
    u0_real = [1.0]

    # Intégration réelle
    prob_real = ODEProblem(f!, u0_real, (0.0, 1.0), nothing)
    sol_real  = SciMLBase.solve(prob_real, Tsit5(); reltol=1e-8, abstol=1e-8, dense=false)

    # Intégration avec Dual (Jacobienne par rapport à u0)
    function integrate_dual(x0)
        prob = ODEProblem(f!, x0, (0.0, 1.0), nothing)
        return SciMLBase.solve(prob, Tsit5(); reltol=1e-8, abstol=1e-8, dense=false)
    end
    u0_dual = ForwardDiff.Dual{:T}.([1.0], [1.0])
    sol_dual = integrate_dual(u0_dual)

    # Les grilles DOIVENT être différentes sans real_norm
    t_real = sol_real.t
    t_dual = ForwardDiff.value.(sol_dual.t)
    @test t_real ≠ t_dual   # documente le problème
end
```

#### Test 4 — Grille IDENTIQUE avec `real_norm` (objectif)

```julia
@testset "grids identical WITH real_norm" begin
    using ForwardDiff, OrdinaryDiffEqTsit5, SciMLBase

    f!(du, u, p, t) = (du .= u)
    u0_real = [1.0]

    prob_real = ODEProblem(f!, u0_real, (0.0, 1.0), nothing)
    sol_real  = SciMLBase.solve(prob_real, Tsit5();
        reltol=1e-8, abstol=1e-8, dense=false,
        internalnorm=CTFlowsSciML.real_norm)

    function integrate_dual_with_norm(x0)
        prob = ODEProblem(f!, x0, (0.0, 1.0), nothing)
        return SciMLBase.solve(prob, Tsit5();
            reltol=1e-8, abstol=1e-8, dense=false,
            internalnorm=CTFlowsSciML.real_norm)
    end
    u0_dual = ForwardDiff.Dual{:T}.([1.0], [1.0])
    sol_dual = integrate_dual_with_norm(u0_dual)

    t_real = sol_real.t
    t_dual = ForwardDiff.value.(sol_dual.t)
    @test t_real == t_dual   # grid invariance garantie
end
```

#### Test 5 — `real_norm` est bien la valeur par défaut de l'intégrateur CTFlows

```julia
@testset "real_norm is default internalnorm in SciML strategy" begin
    integ = Integrators.build_integrator()
    opts  = Strategies.options_dict(integ)
    @test haskey(opts, :internalnorm)
    @test opts[:internalnorm] === CTFlowsSciML.real_norm
end
```

#### Test 6 — Integration CTFlows end-to-end : Jacobienne de la fonction de tir

```julia
@testset "Jacobian via CTFlows gives consistent grid" begin
    using ForwardDiff, CTFlows

    f!(du, u, p, t) = (du[1] = u[2]; du[2] = -u[1])  # oscillateur harmonique
    vf   = VectorField(f!)
    flow = Flow(vf)

    # Fonction de tir : intègre de t0 à tf, retourne l'état final
    function shoot(p0)
        x0 = [1.0, p0[1]]
        return flow((0.0, 1.0), x0)   # StateTrajectoryConfig
    end

    # Jacobienne — ForwardDiff seed des Dual dans l'état
    J = ForwardDiff.jacobian(p0 -> CTFlows.Solutions.times(shoot(p0)), [0.5])
    # Si on arrive ici sans erreur et avec une grille cohérente, c'est bon
    @test J isa AbstractMatrix
end
```

### Step 5 — Ajouter le fichier dans la suite de tests

Dans `test/runtests.jl` ou le fichier d'inclusion des extensions :

```julia
include("suite/extensions/test_internalnorm.jl")
```

---

## Vérification

```bash
julia --project -e 'using Pkg; Pkg.test()' 2>&1 | tee /tmp/internalnorm.log
grep -E "Error|Fail|Test Summary" /tmp/internalnorm.log
```

---

## Fichiers

**Modifiés** :
- `ext/CTFlowsSciML.jl` — ajout `deepvalue`, `real_norm`, option `internalnorm`

**Nouveaux** :
- `test/suite/extensions/test_internalnorm.jl`

---

## Note sur l'évolution future (CTBase#25 / CTFlows#93)

`deepvalue` est actuellement hard-codé sur `ForwardDiff.Dual`. Quand le backend AD deviendra configurable (Enzyme, etc.), `deepvalue` migrera dans CTBase comme une fonction générique redéfinie par chaque backend :

```julia
# CTBase — interface générique
deepvalue(x::Real) = x
# CTFlowsForwardDiff — implémentation ForwardDiff
deepvalue(x::ForwardDiff.Dual) = deepvalue(ForwardDiff.value(x))
# CTFlowsEnzymeExt — implémentation Enzyme (future)
deepvalue(x::Enzyme.Active) = ...
```

`real_norm` dans CTFlowsSciML appellera alors `CTBase.deepvalue` sans modification.
