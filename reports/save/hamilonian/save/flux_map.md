# Carte des Flux CTFlows

## Vue d'ensemble des 3 couches

```text
┌─────────────────────────────────────────────────────────────────┐
│                     LAYER 1: DATA                               │
│  (Fonctions brutes avec traits de dépendance)                   │
└─────────────────────────────────────────────────────────────────┘
                              │
                        build_system()
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                     LAYER 2: SYSTEMS                            │
│  (RHS pré-calculé, prêt pour intégration)                       │
└─────────────────────────────────────────────────────────────────┘
                              │
                        build_flow()
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                     LAYER 3: FLOWS                              │
│  (System + Integrator, callable pour intégration)              │
└─────────────────────────────────────────────────────────────────┘
```

## Hiérarchie des Types

### Couche DATA

```text
AbstractVectorField{TD, VD, MD}
├── VectorField{F, TD, VD, MD}
│   └── f::Function  (retourne dx)
│
└── HamiltonianVectorField{F, TD, VD, MD}
    └── f::Function  (retourne (dx, dp))
```

**Traits:**

- `TD`: TimeDependence (Autonomous | NonAutonomous)
- `VD`: VariableDependence (Fixed | NonFixed)
- `MD`: MutabilityTrait (InPlace | OutOfPlace)

### Couche SYSTEMS

```text
AbstractSystem{TD, VD}
├── AbstractStateSystem{TD, VD}
│   └── StateSystem{F, TD, VD, MD, RHS, OOPROHS, FINRHS}
│       ├── vf::VectorField
│       ├── rhs::Function  (pré-calculé)
│       ├── rhs_oop::Function
│       └── rhs_oop_finalize::Function
│
└── AbstractHamiltonianSystem{TD, VD}
    └── HamiltonianSystem{N, F, TD, VD, MD, RHS, OOPROHS, FINRHS}
        ├── hvf::HamiltonianVectorField
        ├── rhs::Function  (pré-calculé, split x/p)
        ├── rhs_oop::Function
        └── rhs_oop_finalize::Function
```

### Couche FLOWS

```text
AbstractFlow{TD, VD}
├── AbstractStateFlow{TD, VD, S}
│   └── StateFlow{TD, VD, S, I}
│       ├── system::S  (StateSystem)
│       └── integrator::I
│
└── AbstractHamiltonianFlow{TD, VD, S}
    └── HamiltonianFlow{TD, VD, S, I}
        ├── system::S  (HamiltonianSystem)
        └── integrator::I
```

## Flux de Transformation

### Chemin 1: VectorField → StateSystem → StateFlow

```text
VectorField(f; is_autonomous, is_variable, is_inplace)
    │
    ├─ build_system(vf)
    │   └─> StateSystem(vf)
    │       ├── Construit rhs: (du, u, p, t) -> vf(t, u, p.variable)
    │       ├── Construit rhs_oop: (u, p, t) -> vf(t, u, p.variable)
    │       └── Stocke le VectorField
    │
    ├─ build_flow(system, integrator)
    │   └─> StateFlow(system, integrator)
    │       ├── Stocke le StateSystem
    │       ├── Stocke l'Integrator
    │       └─ Callable: flow(t0, x0, tf; variable)
    │
    └─> Résultat: Flow prêt pour intégration
```

### Chemin 2: HamiltonianVectorField → HamiltonianSystem → HamiltonianFlow

```text
HamiltonianVectorField(f; is_autonomous, is_variable, is_inplace)
    │
    ├─ build_system(hvf) [sans dimension]
    │   └─> HamiltonianSystem(hvf)  (N=nothing)
    │       ├── Construit rhs: split u en (x,p), appelle hvf, concatène (dx,dp)
    │       ├── Dimension inférée à l'exécution
    │       └── Stocke le HamiltonianVectorField
    │
    ├─ build_system(hvf, state_dimension) [avec dimension]
    │   └─> HamiltonianSystem(hvf, state_dimension)  (N=state_dimension)
    │       ├── Construit rhs avec N connu (type-stable)
    │       ├── Validation compile-time de la dimension
    │       └── Stocke le HamiltonianVectorField
    │
    ├─ build_flow(system, integrator)
    │   └─> HamiltonianFlow(system, integrator)
    │       ├── Stocke le HamiltonianSystem
    │       ├── Stocke l'Integrator
    │       └─ Callable: flow(t0, x0, p0, tf; variable)
    │
    └─> Résultat: Flow prêt pour intégration
```

## Constructeurs de Haut Niveau

Les constructeurs `Flow()` dans `Flows/building.jl` combinent toutes les étapes:

```julia
# Pour les systèmes d'état
Flow(vf::VectorField; opts...)
    = build_flow(build_system(vf), build_integrator(; opts...))

# Pour les systèmes hamiltoniens (sans dimension)
Flow(hvf::HamiltonianVectorField; opts...)
    = build_flow(build_system(hvf), build_integrator(; opts...))

# Pour les systèmes hamiltoniens (avec dimension)
Flow(hvf::HamiltonianVectorField, state_dimension::Int; opts...)
    = build_flow(build_system(hvf, state_dimension), build_integrator(; opts...))
```

## Résumé des Transformations

| Étape | Entrée | Fonction | Sortie | Ce qui se passe |
| ----- | ------ | --------- | ------ | ---------------- |
| 1 | `VectorField` | `build_system()` | `StateSystem` | Enveloppe le champ de vecteur, pré-calcule les RHS |
| 2 | `HamiltonianVectorField` | `build_system()` | `HamiltonianSystem` | Enveloppe, split x/p, pré-calcule les RHS |
| 3 | `StateSystem` + `Integrator` | `build_flow()` | `StateFlow` | Combine système et intégrateur en objet callable |
| 4 | `HamiltonianSystem` + `Integrator` | `build_flow()` | `HamiltonianFlow` | Combine système et intégrateur en objet callable |

**Key insight:** Les RHS sont pré-calculés à la construction du `System` pour performance. Le `Flow` ne fait que combiner le `System` avec un `Integrator` et exposer l'interface callable.
