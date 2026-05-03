# Rapport critique — CTFlows.jl (branche `develop`)

---

## Points 1 & 2 — Indirection des callables et couplage de la couche Solutions *(points liés)*

Ces deux points forment un seul problème de conception et doivent être traités ensemble.

### Problème 1 — Callables redondants dans l'intégrateur

`calling.jl` définit bien trois fonctions nommées distinctes, mais chacune n'est qu'un relais vers un callable surchargé sur l'intégrateur :

```julia
# calling.jl — trois wrappers qui délèguent aux callables
build_problem(sys, config, int; variable) = int(sys, config; variable=variable)
solve_problem(prob, int)                  = int(prob)
build_solution(ode_sol, sys, config, int) = int(ode_sol, sys, config)
```

```julia
# CTFlowsSciMLExt.jl — trois callables sur le même struct SciML
(int::SciML)(sys, config; variable) = ODEProblem(...)   # construire
(int::SciML)(prob::AbstractODEProblem) = solve(...)      # résoudre
(int::SciML)(ode_sol, sys, config) = build_solution(...) # emballer
```

On a deux niveaux pour la même chose. Le callable `(int::SciML)(args...)` est surchargé trois fois avec des comportements radicalement différents selon les types d'arguments — inhabituel en Julia et opaque à la lecture.

### Problème 2 — La couche Solutions connaît les types SciML

Dans `Solutions/building.jl`, `build_solution` reçoit directement une `SciMLBase.AbstractODESolution` et accède à `ode_sol.u[end]` :

```julia
function build_solution(ode_sol::SciMLBase.AbstractODESolution,
                        sys::Systems.VectorFieldSystem, config::PointConfig)
    final = ode_sol.u[end]   # connaissance directe de la structure SciML
    return config.x0 isa Number ? final[1] : final
end
```

Supprimer l'intégrateur de `build_solution` ne suffit pas à régler ce couplage : si `calling.jl` appelle `Solutions.build_solution(ode_sol, sys, config)` directement, Solutions doit quand même connaître la structure interne de SciML. **L'intégrateur n'a pas à connaître Solutions, mais Solutions ne doit pas non plus connaître SciML.**

### Proposition unifiée : `AbstractIntegrationResult` avec accesseurs sémantiques

**Étape 1 — Définir `AbstractIntegrationResult` et ses accesseurs dans `Common/` ou `Solutions/` :**

```julia
abstract type AbstractIntegrationResult end

# Contrat minimal : trois accesseurs sémantiques
final_state(r::AbstractIntegrationResult)    = throw(NotImplemented(...))
times(r::AbstractIntegrationResult)          = throw(NotImplemented(...))
evaluate_at(r::AbstractIntegrationResult, t) = throw(NotImplemented(...))
```

**Étape 2 — Implémenter le type concret dans l'extension SciML :**

```julia
# CTFlowsSciMLExt.jl — le seul endroit qui connaît ode_sol.u, ode_sol.t, etc.
struct SciMLIntegrationResult{S<:SciMLBase.AbstractODESolution} <: AbstractIntegrationResult
    ode_sol::S
end

final_state(r::SciMLIntegrationResult)     = r.ode_sol.u[end]
times(r::SciMLIntegrationResult)           = r.ode_sol.t
evaluate_at(r::SciMLIntegrationResult, t)  = r.ode_sol(t)
```

**Étape 3 — `solve_problem` retourne un `AbstractIntegrationResult`, pas une solution brute :**

```julia
function Flows.solve_problem(int::SciML, prob)
    ode_sol = SciMLBase.solve(prob; Strategies.options_dict(int)...)
    return SciMLIntegrationResult(ode_sol)
end
```

**Étape 4 — `Solutions/building.jl` n'utilise que les accesseurs, sans dépendance SciML :**

```julia
function build_solution(result::AbstractIntegrationResult,
                        sys::VectorFieldSystem, config::PointConfig)
    return final_state(result)
end

function build_solution(result::AbstractIntegrationResult,
                        sys::VectorFieldSystem, config::TrajectoryConfig)
    return VectorFieldSolution(result)
end
```

**Étape 5 — `VectorFieldSolution` enveloppe `AbstractIntegrationResult`, pas une solution SciML :**

```julia
struct VectorFieldSolution{R<:AbstractIntegrationResult} <: AbstractVectorFieldSolution
    result::R
end

(sol::VectorFieldSolution)(t::Real) = evaluate_at(sol.result, t)
```

**Étape 6 — `calling.jl` appelle `Solutions.build_solution` directement, sans passer l'intégrateur. Le contrat de `AbstractIntegrator` se réduit à deux méthodes nommées :**

```julia
# abstract_integrator.jl
function build_problem(int::AbstractIntegrator, sys, config; variable)
    throw(NotImplemented(...))
end
function solve_problem(int::AbstractIntegrator, prob)
    throw(NotImplemented(...))
end

# calling.jl
function call(flow, config; variable=nothing)
    sys = system(flow); int = integrator(flow)
    prob   = build_problem(int, sys, config; variable)
    result = solve_problem(int, prob)                   # → AbstractIntegrationResult
    return Solutions.build_solution(result, sys, config) # plus d'intégrateur ici
end
```

Les callables `(int::SciML)(...)` disparaissent entièrement.

### Bilan des dépendances après refactorisation

```
calling.jl        →  Systems, Integrators, Solutions  (pas SciML)
Integrators/SciML →  Systems, SciML, Common           (produit AbstractIntegrationResult)
Solutions/        →  AbstractIntegrationResult via accesseurs (pas SciML)
CTFlowsSciMLExt   →  SciML  (seul endroit où .u, .t, l'interpolation sont accédés)
```

---

## Point 3 — `build_integrator` avec dispatch par `Symbol` inutilement complexe

### Contexte

La hiérarchie `AbstractIntegrator <: CTSolvers.Strategies.AbstractStrategy` est un bon choix et n'est **pas** de la sur-ingénierie : elle offre gratuitement la gestion des options typées et validées, la description de la méthode, et le système d'alias. Ce n'est pas là que le problème se situe.

### Problème ciblé

Le dispatch par `Symbol` dans `build_integrator` n'a de valeur que s'il y a plusieurs intégrateurs à distinguer. Aujourd'hui il ne fait que valider que l'utilisateur a bien écrit `:sciml`, ce qui est une friction sans bénéfice. L'`id` dans la signature de `Flow` est un détail d'implémentation exposé inutilement à l'utilisateur :

```julia
function build_integrator(id::Symbol; kwargs...)
    if id === :sciml
        return SciML(; kwargs...)
    else
        throw(IncorrectArgument(...))
    end
end

function Flow(data::Data.VectorField, id::Symbol=:sciml; opts...)
    ...
end
```

### Proposition

Supprimer l'`id` et simplifier les deux fonctions :

```julia
# Integrators/building.jl
function build_integrator(; kwargs...)
    return SciML(; kwargs...)
end

# Flows/building.jl
function Flow(data::Data.VectorField; opts...)
    system = Systems.build_system(data)
    integrator = Integrators.build_integrator(; opts...)
    return Flow(system, integrator)
end
```

L'API utilisateur devient plus propre :

```julia
flow = Flow(vf; reltol=1e-10, alg=Rodas4())   # avant : Flow(vf, :sciml; ...)
```

Si un second intégrateur arrive un jour, le dispatch par `Symbol` (ou mieux, par type) pourra être réintroduit avec un vrai cas d'usage pour le valider. En l'état, c'est du code défensif contre un besoin hypothétique.

---

## Point 4 — Le slot `p` de SciML comme canal de transmission implicite

### Problème

La variable d'un système `NonFixed` est transmise via le champ `p` de l'`ODEProblem` SciML. Ce contrat n'existe qu'en commentaire dans `vector_field_system.jl`, sans aucun type pour le formaliser. Quiconque lit l'extension SciML sans ce contexte ne comprend pas pourquoi `p` est tantôt `nothing`, tantôt une valeur métier. Si on veut ajouter des paramètres numériques réels en plus de la variable métier, ce contrat implicite se casse silencieusement.

### Proposition

Introduire un type wrapper explicite pour ce qui transite dans `p` :

```julia
# Dans Common/ ou Systems/
struct ODEParameters{V}
    variable::V   # nothing pour Fixed, valeur pour NonFixed
end
```

La construction du problème devient :

```julia
p = ODEParameters(variable)
ODEProblem(rhs!(sys), u0, tspan, p)
```

Et la closure RHS lit explicitement `p.variable` :

```julia
rhs = (du, u, p, t) -> begin
    du .= vf(t, u, p.variable)
    nothing
end
```

Le contrat est maintenant dans le type. Si on ajoute un jour d'autres paramètres (callbacks, données supplémentaires...), `ODEParameters` s'étend naturellement sans casser le reste.

---

## Point 5 — `VectorFieldSolution` sans accesseurs sémantiques

### Problème

`VectorFieldSolution` n'expose que `sol(t)` (délégation à SciML) et `raw(sol)`. L'extension Plots délègue elle-même directement à `raw(sol)`. Le wrapper n'apporte donc pas encore de valeur concrète à l'utilisateur, et le force à connaître la structure interne de SciML pour accéder aux données de sa trajectoire.

### Proposition

Maintenant que `VectorFieldSolution` enveloppe un `AbstractIntegrationResult` (voir Points 1 & 2), les accesseurs s'appuient naturellement sur l'interface de ce type, sans aucune connaissance de SciML.

**Accès à la grille temporelle — deux noms, même sémantique :**

```julia
times(sol::VectorFieldSolution)     = times(sol.result)
time_grid(sol::VectorFieldSolution) = times(sol)          # alias
```

`times` et `time_grid` sont deux noms pour la même chose. `time_grid` est plus explicite dans un contexte numérique, `times` est plus court à l'usage courant.

**Accès à l'état comme fonction du temps :**

```julia
state(sol::VectorFieldSolution) = sol

(sol::VectorFieldSolution)(t::Real) = evaluate_at(sol.result, t)
```

`state(sol)` retourne `sol` elle-même, qui est déjà callable — pas d'allocation de closure supplémentaire. L'idiome utilisateur devient :

```julia
x = state(sol)    # x est une fonction du temps
x(0.0)            # état initial
x(0.5)            # état interpolé à t = 0.5
x.(0.0:0.1:1.0)   # broadcasting sur une grille
```

`state` est un **accesseur sémantique** : l'utilisateur travaille avec une fonction trajectoire sans savoir qu'il manipule un `VectorFieldSolution` callable. C'est la fondation naturelle d'une interface cohérente pour le contrôle optimal — on pourra écrire `x = state(sol)`, `p = costate(sol)`, `u = control(sol)` de façon uniforme si la solution est étendue aux systèmes hamiltoniens.

**Ce que ça donne côté `CTFlowsPlotsExt` :**

L'extension Plots peut désormais utiliser `times` et `state` au lieu de `raw`, ce qui la rend indépendante de SciML :

```julia
function _sol_to_arrays(sol::Solutions.VectorFieldSolution)
    ts     = Solutions.times(sol)
    x      = Solutions.state(sol)
    states = reduce(hcat, x.(ts))'
    return ts, states
end
```

---

## Point 6 — Test `isa Number` fragile dans `Solutions/building.jl`

### Problème

```julia
return config.x0 isa Number ? final[1] : final
```

Ce test détecte indirectement qu'une promotion scalaire a eu lieu lors de la construction de l'`ODEProblem`. C'est un couplage implicite entre deux couches éloignées : si l'extension SciML cesse de promouvoir les scalaires en vecteurs, ce code retourne silencieusement le mauvais type sans aucune erreur.

### Proposition

Rendre le contrat explicite via deux sous-types de config :

```julia
struct ScalarPointConfig <: AbstractConfig ... end
struct VectorPointConfig <: AbstractConfig ... end

build_solution(result, sys, ::ScalarPointConfig) = final_state(result)[1]
build_solution(result, sys, ::VectorPointConfig) = final_state(result)
```

La sémantique est encodée dans le type, visible à la compilation, sans test `isa` dynamique. Le constructeur de `Flow` ou de la config choisit le bon sous-type selon le type de `x0` à la création, une seule fois, au bon endroit.

---

## Point 7 — Aucune vérification du `retcode` de la solution ODE

### Problème

Après `solve(prob, ...)`, la solution est emballée sans aucun contrôle. Si SciML produit un `retcode` de type `Unstable`, `MaxIters` ou `DtLessThanMin`, l'utilisateur reçoit silencieusement des `NaN` ou des valeurs absurdes. C'est un défaut critique pour un usage en contrôle optimal où une intégration ratée peut propager des erreurs sans avertissement dans un algorithme de tir.

### Proposition

Vérifier le `retcode` dans la construction de `SciMLIntegrationResult`, au plus près de la source :

```julia
function Flows.solve_problem(int::SciML, prob)
    ode_sol = SciMLBase.solve(prob; Strategies.options_dict(int)...)
    if !SciMLBase.successful_retcode(ode_sol.retcode)
        throw(Exceptions.NumericalError(
            "ODE integration failed";
            retcode   = string(ode_sol.retcode),
            suggestion = "Try tightening tolerances (reltol, abstol) or changing the solver algorithm.",
            context   = "SciML solve_problem",
        ))
    end
    return SciMLIntegrationResult(ode_sol)
end
```

Pour les utilisateurs avancés qui veulent inspecter les solutions échouées :

```julia
function Flows.solve_problem(int::SciML, prob; unsafe=false)
    ode_sol = SciMLBase.solve(prob; Strategies.options_dict(int)...)
    if !unsafe && !SciMLBase.successful_retcode(ode_sol.retcode)
        throw(...)
    end
    return SciMLIntegrationResult(ode_sol)
end
```

### Ajouter SolverFailure dans CTBase.

Ce n'est pas une exception propre à CTFlows — c'est une catégorie d'erreur qui va se retrouver partout dans la toolbox : intégration ODE ratée ici, solveur d'optimisation qui ne converge pas dans CTDirect, système linéaire mal conditionné ailleurs. Autant la définir une fois au bon niveau. Ce serait :

```julia
juliastruct SolverFailure <: CTException
    msg::String
    retcode::Union{String, Nothing}   # statut retourné par le solveur
    suggestion::Union{String, Nothing}
    context::Union{String, Nothing}

    function SolverFailure(
        msg::String;
        retcode::Union{String, Nothing}=nothing,
        suggestion::Union{String, Nothing}=nothing,
        context::Union{String, Nothing}=nothing,
    )
        new(msg, retcode, suggestion, context)
    end
end
```

Et dans CTFlows :

```julia
throw(Exceptions.SolverFailure(
    "ODE integration failed";
    retcode    = string(ode_sol.retcode),
    suggestion = "Try tightening tolerances (reltol, abstol) or changing the solver algorithm.",
    context    = "SciML solve_problem",
))
```

Le champ `retcode` est générique et peut contenir n'importe quelle valeur selon le type de solveur utilisé.

---

## Point 8 — Naming `rhs!` trompeur vis-à-vis des conventions Julia

### Problème

En Julia, `!` signifie que la fonction modifie un de ses arguments. Or `rhs!(system)` ne modifie rien : elle retourne une closure. Un développeur Julia expérimenté s'attend à ce que `rhs!(system)` modifie `system` en place.

### Proposition

Renommer en supprimant le `!` :

```julia
rhs(system)       # retourne la closure (du, u, p, t) -> nothing
```

`ode_rhs` ou `vector_field_rhs` rendraient la sémantique encore plus explicite si le contexte l'exige.

---

## Synthèse et priorités

| # | Problème | Sévérité | Effort |
|---|----------|----------|--------|
| 7 | Absence de vérification du `retcode` | **Critique** | Faible |
| 1 & 2 | Callables redondants + couplage Solutions/SciML | Élevée | Moyen |
| 4 | Slot `p` SciML comme canal implicite | Élevée | Faible |
| 6 | Test `isa Number` fragile | Moyenne | Faible |
| 3 | Dispatch par `Symbol` inutile dans `build_integrator` | Moyenne | Faible |
| 5 | `VectorFieldSolution` sans accesseurs sémantiques | Faible | Faible |
| 8 | Naming `rhs!` trompeur | Faible | Trivial |
