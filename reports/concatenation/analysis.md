# Concaténation de Flots — Analyse et Proposition

## Résumé Exécutif

Ce document analyse les différentes approches de concaténation de flots et propose une architecture adaptée à CTFlows v1. La proposition repose sur :

- une **intégration séquentielle exacte** au niveau des flots (pas des systèmes)
- une **hiérarchie de types** distinguant les flots état-seul (`AbstractStateFlow`) des flots hamiltoniens (`AbstractHamiltonianFlow`)
- une **contrainte compile-time** garantissant que seuls des flots de même type de système peuvent être concaténés
- une **fusion progressive** des résultats pour minimiser la mémoire utilisée

---

## 1. Ancienne Approche (save/ext/concatenation.jl + ext_utils.jl)

### Principe

Concaténation "à la volée" pendant l'intégration continue : on construit un nouveau `rhs!` qui dispatche selon `t < t_switch`, puis on intègre le tout en une seule passe ODE.

### API

```julia
F * (t_switch, G)        # F jusqu'à t_switch, puis G, sans saut
F * (t_switch, η, G)     # avec saut η à t_switch
```

### Implémentation Interne

```julia
function __concat_rhs(F, G, t_switch)
    return (du, u, p, t) -> t < t_switch ? F.rhs!(du, u, p, t) : G.rhs!(du, u, p, t)
end

function __concat_tstops(F, G, t_switch)
    tstops = [F.tstops; G.tstops; t_switch]
    return unique(sort(tstops))
end
```

### Gestion des Sauts (Callbacks SciML)

Les sauts d'état étaient gérés via `VectorContinuousCallback` :

```julia
function condition(out, u, t, integrator)
    out[:] = t_jumps .- t  # Zéro-crossing aux temps de saut
end

function affect!(integrator, event_index)
    integrator.u += η_jumps[event_index]  # Appliquer le saut
end

cbjumps = VectorContinuousCallback(condition, affect!, length(jumps))
cb = CallbackSet(cbjumps, user_callback)
```

Les `tstops` (temps de switching inclus) étaient ensuite passés à l'intégrateur pour forcer une évaluation exacte aux discontinuités.

### Problème Identifié : Non-Équivalence avec la Concaténation Exacte

OptimalControl.jl a documenté le même problème avec leur approche similaire :

```julia
# Deux façons de calculer "f de t0 à t/2 puis g de t/2 à t"
φ(t) = (f * (t/2, g))(0, x0, t)      # approche "à la volée" : une seule intégration
ψ(t) = g(t/2, f(0, x0, t/2), t)     # approche exacte : deux intégrations séquentielles

# Résultat : φ(t) ≠ ψ(t)
# L'erreur |φ(t) - ψ(t)| croît avec t
```

**Cause profonde** : Même avec `tstops`, le solveur ne démarre pas une nouvelle intégration à `t_switch`. Il continue l'intégration courante avec un nouveau `rhs!`. Les états internes du solveur (step-size history, Jacobian approché, etc.) ne sont pas réinitialisés. La précision locale autour de `t_switch` est donc dégradée.

---

## 2. Approche OptimalControl.jl

### Principe

Même opérateur `*`, même mécanisme interne (intégration continue avec `rhs!` qui switch).

```julia
f0 = Flow(ocp, (x, p) -> 0)    # off arc : u = 0
f1 = Flow(ocp, (x, p) -> 1)    # positive bang arc : u = 1
f  = f0 * (t1, f1)             # concaténation
sol = f((t0, tf), x0, p0)
```

### Limitation Documentée

> "For the moment, this concatenation is not equivalent to an exact concatenation."
>
> — Documentation OptimalControl.jl

Le graphique de leur exemple montre des erreurs numériques croissant avec `t`, confirmant la non-équivalence.

---

## 3. Ancienne Réflexion (Discussion GitHub #144) — Intégration Séquentielle

### Principe

Intégrer chaque phase séparément, puis fusionner les résultats. La concaténation se fait au **niveau des systèmes** (`MultiPhaseSystem`).

### Architecture Proposée

```julia
struct PhaseTransition
    time::Float64
    jump::Tuple{Vector, Vector}  # (Δx, Δp)
end

struct MultiPhaseSystem{S<:AbstractSystem} <: AbstractSystem
    phases::Vector{S}
    transitions::Vector{PhaseTransition}
end
```

### Flux pour Évaluation Point

```julia
function evaluate_point(mps::MultiPhaseSystem, t0, z0, tf, v)
    phase_idx = find_phase(mps, t0)
    z_current = z0
    t_current = t0

    for k in phase_idx:length(mps.phases)
        t_end = k < length(mps.phases) ? mps.transitions[k].time : tf
        t_end = min(t_end, tf)

        problem = _ode_problem(mps.phases[k], (t_current, t_end), z_current, v)
        raw_sol  = _solve(problem, get_alg(mps), get_options(mps))

        z_current = raw_sol[end]

        if t_end < tf && k < length(mps.phases)
            Δx, Δp    = mps.transitions[k].jump
            z_current = apply_jump(z_current, Δx, Δp)
        end

        t_current = t_end
        t_current >= tf && break
    end

    return split_state_costate(z_current)
end
```

### Flux pour Solution Complète

```julia
function evaluate_solution(mps::MultiPhaseSystem, tspan, z0, v)
    solutions = []
    z_current = z0
    t_current = tspan[1]

    for k in 1:length(mps.phases)
        t_end = k < length(mps.phases) ? mps.transitions[k].time : tspan[2]
        t_end = min(t_end, tspan[2])

        phase_sol = _solve(mps.phases[k], (t_current, t_end), z_current)
        push!(solutions, phase_sol)

        if t_end < tspan[2] && k < length(mps.phases)
            z_current = phase_sol[end]
            Δx, Δp    = mps.transitions[k].jump
            z_current = apply_jump(z_current, Δx, Δp)
        end

        t_current = t_end
        t_current >= tspan[2] && break
    end

    return _merge_solutions(solutions, mps)
end
```

### Fusion des Solutions (Extension SciML)

```julia
function _merge_solutions(solutions::Vector, mps::MultiPhaseSystem)
    u = [uc for (k, sol) in enumerate(solutions) for uc in sol.u[1:end-1]]
    t = [tc for (k, sol) in enumerate(solutions) for tc in sol.t[1:end-1]]

    push!(u, solutions[end].u[end])
    push!(t, solutions[end].t[end])

    return SciMLBase.build_solution(solutions[1].prob, solutions[1].alg, t, u; retcode=:Success)
end
```

### Limitations

- Concaténation au niveau des **systèmes**, pas des **flots** (contraire à l'usage utilisateur)
- Chaque phase partage le même intégrateur (celui du `MultiPhaseSystem`)
- Types de sauts limités aux vecteurs

---

## 4. Proposition pour CTFlows v1

### Principe Central

**L'utilisateur construit des flots et concatène des flots.** Il ne manipule pas directement les systèmes. La concaténation produit un nouveau flot qui s'utilise exactement comme un flot simple.

```julia
# Construction
f1 = Flow(sys, integrator_opts)
f2 = Flow(sys, integrator_opts)

# Concaténation : produit un MultiPhaseStateFlow ou MultiPhaseHamiltonianFlow
f  = f1 * (t_switch, f2)

# Usage identique à un flot simple
xf       = f(t0, x0, tf)           # StatePointConfig
sol      = f((t0, tf), x0)         # StateTrajectoryConfig
```

La concaténation est **associative** et peut être chaînée :

```julia
f = f1 * (t1, f2) * (t2, f3) * (t3, f4)  # 4 phases
```

### Contrainte de Type

**Seuls des flots de même type de système peuvent être concaténés.** Cette contrainte est vérifiée à la **compilation** par le paramètre de type `S` dans les sous-types d'`AbstractFlow`, pas à l'exécution.

```julia
# OK : même type de système (VectorFieldSystem)
f1 = Flow(VectorFieldSystem(vf1), opts)
f2 = Flow(VectorFieldSystem(vf2), opts)
f  = f1 * (1.0, f2)    # ✓ MultiPhaseStateFlow

# ERREUR à la compilation : types S différents
f1 = Flow(VectorFieldSystem(vf), opts)
f2 = Flow(HamiltonianSystem(H), opts)
f  = f1 * (1.0, f2)    # ✗ MethodError : aucune méthode * ne correspond
```

### Hiérarchie de Types

#### AbstractFlow — type parent

`AbstractFlow` reste identique à aujourd'hui (sans paramètre de système) :

```julia
abstract type AbstractFlow{TD<:Common.TimeDependence, VD<:Common.VariableDependence} end
```

#### Sous-types abstraits — portent le paramètre S

```julia
# Flots sur l'espace d'état seul (x)
# - VectorField, Hamiltonian réduit, etc.
# - Les sauts ne concernent que Δx
abstract type AbstractStateFlow{
    TD <: Common.TimeDependence,
    VD <: Common.VariableDependence,
    S  <: AbstractSystem{TD, VD}
} <: AbstractFlow{TD, VD} end

# Flots sur l'espace étendu (x, p) — systèmes hamiltoniens
# - Les sauts peuvent porter sur Δp seul, ou (Δx, Δp)
abstract type AbstractHamiltonianFlow{
    TD <: Common.TimeDependence,
    VD <: Common.VariableDependence,
    S  <: AbstractSystem{TD, VD}
} <: AbstractFlow{TD, VD} end
```

`AbstractStateFlow` et `AbstractHamiltonianFlow` ne sont pas reliés entre eux : on ne peut pas concaténer un flot de chaque sous-type.

#### Flow concret — rattaché à un sous-type

Le type `Flow` existant devient un sous-type de l'un ou l'autre selon le système :

```julia
struct Flow{
    TD <: Common.TimeDependence,
    VD <: Common.VariableDependence,
    S  <: AbstractSystem{TD, VD},
    I  <: Integrators.AbstractIntegrator
} <: AbstractStateFlow{TD, VD, S}    # ou AbstractHamiltonianFlow selon S
    sys :: S
    int :: I
end
```

### Sémantique des Sauts

#### AbstractStateFlow

Un seul saut possible : `Δx` (de n'importe quel type supportant `+`).

```julia
f1 * (t_switch, f2)          # pas de saut
f1 * (t_switch, Δx, f2)     # saut Δx sur l'état
```

`Δx` peut être :
- un scalaire (`Float64`, `Int`, nombre dual)
- un vecteur
- une matrice
- tout type pour lequel `+` est défini avec l'état

#### AbstractHamiltonianFlow

L'espace d'état est `(x, p)`. Convention : **si un seul saut est fourni, c'est Δp** (le cas le plus courant en contrôle optimal).

```julia
f1 * (t_switch, f2)              # pas de saut
f1 * (t_switch, Δp, f2)         # saut Δp seul sur le costate
f1 * (t_switch, Δx, Δp, f2)    # sauts Δx et Δp
```

### Types MultiPhase

#### MultiPhaseStateFlow

```julia
struct MultiPhaseStateFlow{
    TD <: Common.TimeDependence,
    VD <: Common.VariableDependence,
    F  <: AbstractStateFlow{TD, VD, S},
    S  <: AbstractSystem{TD, VD}
} <: AbstractStateFlow{TD, VD, S}
    phases          :: Vector{F}
    switching_times :: Vector{<:Real}     # temps absolus, longueur = length(phases) - 1
    jumps           :: Vector{Union{Nothing, Any}}  # Δx ou nothing, même longueur
end
```

Invariant : `length(switching_times) == length(jumps) == length(phases) - 1`

#### MultiPhaseHamiltonianFlow

```julia
struct MultiPhaseHamiltonianFlow{
    TD <: Common.TimeDependence,
    VD <: Common.VariableDependence,
    F  <: AbstractHamiltonianFlow{TD, VD, S},
    S  <: AbstractSystem{TD, VD}
} <: AbstractHamiltonianFlow{TD, VD, S}
    phases          :: Vector{F}
    switching_times :: Vector{<:Real}
    jumps           :: Vector{Union{Nothing, Tuple{Union{Nothing,Any}, Union{Nothing,Any}}}}
    # jumps[k] = nothing          → pas de saut à la transition k
    # jumps[k] = (nothing, Δp)   → saut Δp seul
    # jumps[k] = (Δx, nothing)   → saut Δx seul
    # jumps[k] = (Δx, Δp)        → sauts Δx et Δp
end
```

### Opérateurs de Concaténation

#### Pour AbstractStateFlow

```julia
# Sans saut
function Base.:*(
    f1 :: AbstractStateFlow{TD, VD, S},
    g  :: Tuple{<:Real, <:AbstractStateFlow{TD, VD, S}}
) where {TD, VD, S}
    t_switch, f2 = g
    # Propager : si f1 est déjà un MultiPhaseStateFlow, étendre les phases
    phases          = _flatten_phases(f1, f2)
    switching_times = _flatten_times(f1, t_switch, f2)
    jumps           = _flatten_jumps(f1, nothing, f2)
    return MultiPhaseStateFlow(phases, switching_times, jumps)
end

# Avec saut Δx
function Base.:*(
    f1 :: AbstractStateFlow{TD, VD, S},
    g  :: Tuple{<:Real, Any, <:AbstractStateFlow{TD, VD, S}}
) where {TD, VD, S}
    t_switch, Δx, f2 = g
    phases          = _flatten_phases(f1, f2)
    switching_times = _flatten_times(f1, t_switch, f2)
    jumps           = _flatten_jumps(f1, Δx, f2)
    return MultiPhaseStateFlow(phases, switching_times, jumps)
end
```

#### Pour AbstractHamiltonianFlow

```julia
# Sans saut
function Base.:*(
    f1 :: AbstractHamiltonianFlow{TD, VD, S},
    g  :: Tuple{<:Real, <:AbstractHamiltonianFlow{TD, VD, S}}
) where {TD, VD, S}
    t_switch, f2 = g
    return MultiPhaseHamiltonianFlow(
        _flatten_phases(f1, f2),
        _flatten_times(f1, t_switch, f2),
        _flatten_jumps(f1, nothing, f2)
    )
end

# Saut Δp seul (convention : un seul saut = Δp)
function Base.:*(
    f1 :: AbstractHamiltonianFlow{TD, VD, S},
    g  :: Tuple{<:Real, Any, <:AbstractHamiltonianFlow{TD, VD, S}}
) where {TD, VD, S}
    t_switch, Δp, f2 = g
    return MultiPhaseHamiltonianFlow(
        _flatten_phases(f1, f2),
        _flatten_times(f1, t_switch, f2),
        _flatten_jumps(f1, (nothing, Δp), f2)
    )
end

# Sauts Δx et Δp
function Base.:*(
    f1 :: AbstractHamiltonianFlow{TD, VD, S},
    g  :: Tuple{<:Real, Any, Any, <:AbstractHamiltonianFlow{TD, VD, S}}
) where {TD, VD, S}
    t_switch, Δx, Δp, f2 = g
    return MultiPhaseHamiltonianFlow(
        _flatten_phases(f1, f2),
        _flatten_times(f1, t_switch, f2),
        _flatten_jumps(f1, (Δx, Δp), f2)
    )
end
```

#### Aplatissement (chaînage associatif)

Pour que `f1 * (t1, f2) * (t2, f3)` produise un `MultiPhaseStateFlow` à 3 phases (et non un `MultiPhaseStateFlow` contenant un autre `MultiPhaseStateFlow`) :

```julia
# Si f1 est déjà un MultiPhaseStateFlow, extraire ses phases
function _flatten_phases(f1::MultiPhaseStateFlow, f2::AbstractStateFlow)
    return [f1.phases; f2]
end
function _flatten_phases(f1::AbstractStateFlow, f2::AbstractStateFlow)
    return [f1, f2]
end

function _flatten_times(f1::MultiPhaseStateFlow, t_switch, f2)
    return [f1.switching_times; t_switch]
end
function _flatten_times(f1::AbstractStateFlow, t_switch, f2)
    return [t_switch]
end

function _flatten_jumps(f1::MultiPhaseStateFlow, jump, f2)
    return [f1.jumps; jump]
end
function _flatten_jumps(f1::AbstractStateFlow, jump, f2)
    return [jump]
end
# Idem pour AbstractHamiltonianFlow / MultiPhaseHamiltonianFlow
```

### Intégration Séquentielle dans call()

Deux méthodes distinctes selon `StatePointConfig` (pas de fusion) et `StateTrajectoryConfig` (fusion progressive).

#### StatePointConfig — pas de stockage intermédiaire

```julia
function call(
    flow   :: Union{MultiPhaseStateFlow, MultiPhaseHamiltonianFlow},
    config :: Common.StatePointConfig;
    variable, unsafe
)
    t0, tf    = Common.tspan(config)
    z_current = Common.initial_condition(config)
    t_current = t0

    for (k, phase_flow) in enumerate(flow.phases)
        t_end = k < length(flow.phases) ? flow.switching_times[k] : tf
        t_end = min(t_end, tf)

        phase_config  = _make_phase_config(t_current, t_end, z_current, config)
        phase_result  = call(phase_flow, phase_config; variable, unsafe)
        z_current     = _extract_final_state(phase_result)

        # Appliquer saut si présent (uniquement entre deux phases, pas après la dernière)
        if k < length(flow.phases) && !isnothing(flow.jumps[k])
            z_current = _apply_jump(flow, z_current, flow.jumps[k])
        end

        t_current = t_end
        t_current >= tf && break
    end

    return z_current
end
```

#### StateTrajectoryConfig — fusion progressive en mémoire O(N_points)

```julia
function call(
    flow   :: Union{MultiPhaseStateFlow, MultiPhaseHamiltonianFlow},
    config :: Common.StateTrajectoryConfig;
    variable, unsafe
)
    t0, tf    = Common.tspan(config)
    z_current = Common.initial_condition(config)
    t_current = t0

    # Vecteurs accumulateurs : une seule copie des données
    t_all = eltype(flow.switching_times)[]
    u_all = typeof(z_current)[]

    for (k, phase_flow) in enumerate(flow.phases)
        t_end = k < length(flow.phases) ? flow.switching_times[k] : tf
        t_end = min(t_end, tf)

        phase_config = _make_phase_config(t_current, t_end, z_current, config)
        phase_result = call(phase_flow, phase_config; variable, unsafe)

        # Inclure tous les points sauf le dernier des phases intermédiaires
        # (le premier point de la phase suivante coïncide avec le dernier de celle-ci)
        n_pts = k < length(flow.phases) && t_end < tf ? length(phase_result.t) - 1 : length(phase_result.t)
        append!(t_all, phase_result.t[1:n_pts])
        append!(u_all, phase_result.u[1:n_pts])

        z_current = _extract_final_state(phase_result)

        if k < length(flow.phases) && !isnothing(flow.jumps[k])
            z_current = _apply_jump(flow, z_current, flow.jumps[k])
        end

        t_current = t_end
        t_current >= tf && break
    end

    return _build_merged_solution(t_all, u_all, flow)
end
```

### Fonctions Auxiliaires

#### _make_phase_config

Construit une configuration pour une phase individuelle. Le type de config est préservé.

```julia
function _make_phase_config(t_start, t_end, z0, ::Common.StatePointConfig)
    return Common.StatePointConfig(t_start, z0, t_end)
end

function _make_phase_config(t_start, t_end, z0, ::Common.StateTrajectoryConfig)
    return Common.StateTrajectoryConfig((t_start, t_end), z0)
end
```

#### _extract_final_state

Extrait l'état final du résultat d'une phase.
Pour `StatePointConfig`, le résultat **est** déjà l'état final.
Pour `StateTrajectoryConfig`, l'état final est le dernier point de la trajectoire.

```julia
_extract_final_state(result::AbstractVector) = result       # StatePointConfig → déjà l'état
_extract_final_state(result::VectorFieldSolution) = result.u[end]  # StateTrajectoryConfig
```

#### _apply_jump

Dispatch sur le type de flot pour appliquer le saut correctement.

```julia
# Pour MultiPhaseStateFlow : saut Δx direct (scalaire, vecteur, dual, etc.)
function _apply_jump(::MultiPhaseStateFlow, z, Δx)
    return z + Δx
end

# Pour MultiPhaseHamiltonianFlow : saut (Δx, Δp) avec composantes optionnelles
function _apply_jump(::MultiPhaseHamiltonianFlow, z::Tuple, jump::Tuple)
    Δx, Δp = jump
    x_new = isnothing(Δx) ? z[1] : z[1] + Δx
    p_new = isnothing(Δp) ? z[2] : z[2] + Δp
    return (x_new, p_new)
end
```

#### _build_merged_solution

Délégué à l'extension `CTFlowsSciML`, qui construit un `ODESolution` à partir des vecteurs accumulés.

```julia
# Dans src/ : stub délégué à l'extension
function _build_merged_solution(t, u, flow)
    throw(Exceptions.ExtensionError(
        "CTFlowsSciML is required to build merged solutions";
        extension = "CTFlowsSciML",
    ))
end

# Dans ext/CTFlowsSciML.jl : implémentation réelle
function CTFlows._build_merged_solution(t, u, flow)
    # On utilise le prob/alg de la première phase comme template
    first_phase = flow.phases[1]
    prob = Integrators.last_prob(first_phase)   # prob SciML de la dernière intégration
    alg  = Integrators.last_alg(first_phase)
    return SciMLBase.build_solution(prob, alg, t, u; retcode=:Success)
end
```

### Contrat AbstractFlow pour les Types Multi-phase

Les types multi-phase doivent implémenter le contrat `AbstractFlow`. Les méthodes `system()` et `integrator()` n'ont pas de réponse unique (il y a N systèmes et N intégrateurs). Trois options sont possibles.

#### Option A — Convention "première phase" (simple, discutable)

```julia
function Flows.system(flow::MultiPhaseStateFlow)
    return Flows.system(flow.phases[1])
end

function Flows.integrator(flow::MultiPhaseStateFlow)
    return Flows.integrator(flow.phases[1])
end
```

Inconvénient : retourner le système de la première phase est arbitraire et peut induire en erreur.

#### Option B — Retourner un vecteur

```julia
function Flows.system(flow::MultiPhaseStateFlow)
    return [Flows.system(phase) for phase in flow.phases]
end

function Flows.integrator(flow::MultiPhaseStateFlow)
    return [Flows.integrator(phase) for phase in flow.phases]
end
```

Inconvénient : rompt le contrat `system(flow)::AbstractSystem` (retourne un `Vector` au lieu d'un `AbstractSystem`). Nécessite de changer la signature du contrat.

#### Option C — Wrappers MultiPhaseSystem et MultiPhaseIntegrator (recommandée)

Créer deux types enveloppes qui agrègent les N composantes et exposent une interface unifiée, y compris pour l'affichage :

```julia
# Dans MultiPhase/multiphase_system.jl
struct MultiPhaseSystem{
    TD <: Common.TimeDependence,
    VD <: Common.VariableDependence,
    S  <: Systems.AbstractSystem{TD, VD}
} <: Systems.AbstractSystem{TD, VD}
    phases          :: Vector{S}
    switching_times :: Vector{<:Real}
end

# Dans MultiPhase/multiphase_integrator.jl
struct MultiPhaseIntegrator{I <: Integrators.AbstractIntegrator}
    phases :: Vector{I}
end
```

Le contrat `AbstractFlow` est alors satisfait proprement :

```julia
function Flows.system(flow::MultiPhaseStateFlow)
    return MultiPhaseSystem(
        [Flows.system(p) for p in flow.phases],
        flow.switching_times
    )
end

function Flows.integrator(flow::MultiPhaseStateFlow)
    return MultiPhaseIntegrator([Flows.integrator(p) for p in flow.phases])
end
```

Ces wrappers permettent en plus d'implémenter un `show` informatif :

```julia
function Base.show(io::IO, sys::MultiPhaseSystem)
    println(io, "MultiPhaseSystem with $(length(sys.phases)) phases:")
    for (k, (s, t)) in enumerate(zip(sys.phases, [sys.switching_times; Inf]))
        println(io, "  Phase $k : $(typeof(s)), until t = $t")
    end
end

function Base.show(io::IO, int::MultiPhaseIntegrator)
    println(io, "MultiPhaseIntegrator with $(length(int.phases)) integrators:")
    for (k, i) in enumerate(int.phases)
        println(io, "  Phase $k : $(typeof(i))")
    end
end
```

Note : `MultiPhaseSystem` ici n'est **pas** le `MultiPhaseSystem` de la discussion #144 (qui portait la logique d'intégration). C'est un wrapper passif pour satisfaire le contrat et l'affichage.

Les méthodes appelables (l'API publique) se comportent comme un flot simple :

```julia
# Évaluation point (délègue à call avec StatePointConfig)
function (f::MultiPhaseStateFlow)(t0, x0, tf; variable=nothing, unsafe=false)
    config = Common.StatePointConfig(t0, x0, tf)
    return Flows.call(f, config; variable, unsafe)
end

# Évaluation trajectoire (délègue à call avec StateTrajectoryConfig)
function (f::MultiPhaseStateFlow)(tspan::Tuple, x0; variable=nothing, unsafe=false)
    config = Common.StateTrajectoryConfig(tspan, x0)
    return Flows.call(f, config; variable, unsafe)
end
```

---

## 5. Points Techniques à Résoudre

### 5.1 Temps de Switching : Absolus vs Relatifs

**Décision : temps absolus.**

- Cohérent avec l'API OptimalControl.jl (`f * (t1, g)`)
- Évite l'ambiguïté sur l'origine des temps (t0 du premier flot ? t0 de l'appel ?)
- Permet de raisonner directement sur la timeline physique du problème

```julia
# Temps absolus (recommandé)
f = f1 * (1.0, f2) * (2.5, f3)
sol = f((0.0, 4.0), x0)
# Phase 1 : [0.0, 1.0], Phase 2 : [1.0, 2.5], Phase 3 : [2.5, 4.0]
```

**Validation à la construction** : vérifier que les temps de switching sont strictement croissants.

```julia
function _validate_switching_times(times)
    for k in 2:length(times)
        times[k] > times[k-1] || throw(Exceptions.IncorrectArgument(
            "Switching times must be strictly increasing; got $(times[k-1]) ≥ $(times[k]) at index $k"
        ))
    end
end
```

### 5.2 Fusion des Résultats

#### StatePointConfig

Pas de fusion : on propage seulement l'état final d'une phase à l'autre. Résultat final = état final de la dernière phase.

#### StateTrajectoryConfig — Fusion Progressive

La fusion se fait pendant la boucle, en accumulant deux vecteurs `t_all` et `u_all`. Le dernier point de chaque phase intermédiaire est exclu pour éviter les doublons aux points de switching :

```text
Phase 1 : t = [0.0, 0.3, 0.7, 1.0]   →  on prend [0.0, 0.3, 0.7]  (sans 1.0)
Phase 2 : t = [1.0, 1.4, 2.0]         →  on prend [1.0, 1.4, 2.0]  (tous, c'est la dernière)
Résultat: t = [0.0, 0.3, 0.7, 1.0, 1.4, 2.0]
```

Note : après l'application d'un saut, `u_all` contient l'état **avant saut** au temps de switching et l'état **après saut** au même temps n'est pas stocké (il devient la condition initiale de la phase suivante). Cela peut être discuté selon le besoin de l'utilisateur.

### 5.3 Flexibilité des Types de Sauts

Les sauts ne sont pas limités aux vecteurs. Tout type pour lequel `+` est défini est accepté :

| Type de saut | Exemple | Cas d'usage |
| --- | --- | --- |
| `Float64` | `0.5` | État scalaire |
| `Vector{Float64}` | `[1.0, 0.0]` | État vectoriel classique |
| `Matrix{Float64}` | `Matrix(I, n, n)` | Transformation linéaire |
| `Dual` | `Dual(1.0, 1.0)` | Différentiation automatique |

La contrainte est vérifiée à l'exécution par Julia : si `z + Δx` n'est pas défini, une `MethodError` est levée.

### 5.4 Localisation dans l'Architecture v1 : Submodule MultiPhase

Plutôt que de surcharger le submodule `Flows`, la concaténation et tous ses types associés vivent dans un **submodule dédié `MultiPhase`**, chargé en dernier (après `Flows`).

#### Justification

- `Flows` reste focalisé sur un flot simple (`AbstractFlow`, `Flow`, `call`)
- `MultiPhase` a ses propres responsabilités (wrappers, concaténation, intégration multi-phase)
- La séparation facilite les tests et la maintenance
- Cohérent avec le principe SRP (Single Responsibility)

#### Nouveau Layout

```text
src/
├── CTFlows.jl                         # top-level manifest
├── Common/Common.jl
├── Data/Data.jl
├── Systems/Systems.jl
├── Integrators/Integrators.jl
├── Solutions/Solutions.jl
├── Flows/
│   ├── Flows.jl                       # manifest Flows (inchangé dans ses responsabilités)
│   ├── abstract_flow.jl               # AbstractFlow + AbstractStateFlow + AbstractHamiltonianFlow
│   ├── flow.jl                        # Flow <: AbstractStateFlow ou AbstractHamiltonianFlow
│   ├── building.jl
│   └── calling.jl
└── MultiPhase/
    ├── MultiPhase.jl                  # manifest du submodule
    ├── multiphase_system.jl           # MultiPhaseSystem (wrapper passif)
    ├── multiphase_integrator.jl       # MultiPhaseIntegrator (wrapper passif)
    ├── multiphase_flow.jl             # MultiPhaseStateFlow, MultiPhaseHamiltonianFlow
    ├── concatenation.jl               # opérateurs *, fonctions _flatten_*
    └── calling.jl                     # call() pour les types multi-phase
```

#### Manifest MultiPhase/MultiPhase.jl

```julia
"""
Submodule handling multi-phase flows and flow concatenation.

Provides:
- `MultiPhaseSystem`, `MultiPhaseIntegrator` : passive wrappers for the `AbstractFlow` contract
- `MultiPhaseStateFlow`, `MultiPhaseHamiltonianFlow` : concatenated flow types
- `*` operator for building multi-phase flows
"""
module MultiPhase

import DocStringExtensions: TYPEDEF, TYPEDSIGNATURES
import CTBase.Exceptions
using ..Common
using ..Systems
using ..Integrators
using ..Flows

include(joinpath(@__DIR__, "multiphase_system.jl"))
include(joinpath(@__DIR__, "multiphase_integrator.jl"))
include(joinpath(@__DIR__, "multiphase_flow.jl"))
include(joinpath(@__DIR__, "concatenation.jl"))
include(joinpath(@__DIR__, "calling.jl"))

export MultiPhaseSystem, MultiPhaseIntegrator
export MultiPhaseStateFlow, MultiPhaseHamiltonianFlow

end # module MultiPhase
```

#### Modification de CTFlows.jl

```julia
module CTFlows

include(joinpath(@__DIR__, "Common",       "Common.jl"));       using .Common
include(joinpath(@__DIR__, "Data",         "Data.jl"));          using .Data
include(joinpath(@__DIR__, "Systems",      "Systems.jl"));       using .Systems
include(joinpath(@__DIR__, "Integrators",  "Integrators.jl"));   using .Integrators
include(joinpath(@__DIR__, "Solutions",    "Solutions.jl"));     using .Solutions
include(joinpath(@__DIR__, "Flows",        "Flows.jl"));          using .Flows
include(joinpath(@__DIR__, "MultiPhase",   "MultiPhase.jl"));    using .MultiPhase  # après Flows

end # module CTFlows
```

L'ordre topologique est respecté : `MultiPhase` dépend de `Flows`, `Systems`, `Integrators`.

#### Modification de Flows/abstract_flow.jl

Seuls `AbstractStateFlow` et `AbstractHamiltonianFlow` s'ajoutent ici. `Flow` hérite de l'un des deux :

```julia
# Dans src/Flows/abstract_flow.jl
abstract type AbstractStateFlow{TD, VD, S <: Systems.AbstractSystem{TD,VD}} <: AbstractFlow{TD, VD} end
abstract type AbstractHamiltonianFlow{TD, VD, S <: Systems.AbstractSystem{TD,VD}} <: AbstractFlow{TD, VD} end
```

```julia
# Dans src/Flows/Flows.jl — exports à ajouter
export AbstractStateFlow, AbstractHamiltonianFlow
```

#### Extension CTFlowsSciML

`_build_merged_solution` reste un stub dans `MultiPhase/calling.jl` et son implémentation réelle va dans l'extension :

```julia
# Dans ext/CTFlowsSciML.jl
function CTFlows.MultiPhase._build_merged_solution(t, u, flow)
    first_phase = flow.phases[1]
    prob = Integrators.last_prob(first_phase)
    alg  = Integrators.last_alg(first_phase)
    return SciMLBase.build_solution(prob, alg, t, u; retcode=:Success)
end
```

---

## 6. Comparaison des Approches

| Critère | Ancienne (à la volée) | OptimalControl.jl | Proposition (séquentielle) |
| --- | --- | --- | --- |
| Exactitude numérique | ❌ Non exacte | ❌ Non exacte | ✅ Exacte |
| Stabilité numérique | ❌ Erreurs croissantes | ❌ Erreurs croissantes | ✅ Stable |
| Complexité implémentation | ✅ Simple | ✅ Simple | ⚠️ Modérée |
| Un intégrateur par phase | ❌ Non | ❌ Non | ✅ Oui |
| API utilisateur | ✅ `*` | ✅ `*` | ✅ `*` |
| Niveau d'API | Flots | Flots | Flots |
| Type safety | ❌ Runtime | ❌ Runtime | ✅ Compile-time |
| Gestion mémoire | ✅ O(1) | ✅ O(1) | ✅ O(N_points) |
| Sauts flexibles | ⚠️ Vecteurs | ⚠️ Vecteurs | ✅ Tout type + |
| Sauts hamiltoniens (Δp) | ❌ Uniquement η | ❌ Via jump | ✅ (Δp) ou (Δx, Δp) |
| Chaînage associatif | ⚠️ Emboîtement | ⚠️ Emboîtement | ✅ Aplatissement |

---

## 7. Recommandation Finale

**Adopter l'approche séquentielle au niveau des flots avec hiérarchie de types et contrainte compile-time.**

### Justification

1. **Exactitude** : seule approche garantissant une intégration exacte (chaque phase démarre proprement)
2. **Type safety** : la compatibilité des flots est garantie par le compilateur via le paramètre `S`
3. **Flexibilité** : chaque phase peut avoir son propre intégrateur et ses propres options
4. **API naturelle** : opérateur `*` cohérent avec OptimalControl.jl, chaînable
5. **Distinction hamiltonien/état** : convention de saut claire selon le sous-type

### Ordre d'Implémentation

1. `AbstractStateFlow` et `AbstractHamiltonianFlow` dans `abstract_flow.jl`
2. `Flow` hérite du bon sous-type abstrait selon son système
3. `MultiPhaseStateFlow` et `MultiPhaseHamiltonianFlow` avec leurs invariants
4. Opérateurs `*` avec `_flatten_*` pour le chaînage associatif
5. `call()` pour `StatePointConfig` (simple)
6. `call()` pour `StateTrajectoryConfig` (fusion progressive)
7. Stub `_build_merged_solution` dans `src/` + implémentation dans `CTFlowsSciML`
8. Tests : contrats, sauts, chaînage, exactitude vs approche à la volée
