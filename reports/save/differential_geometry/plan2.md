# DifferentialGeometry — Plan complet auto-suffisant

Implémentation du sous-module `DifferentialGeometry` dans CTFlows — contient tout le code, toutes les conventions de workflow, et les tests nécessaires pour chaque phase, sans référence externe.

**Branche active : `feat/differential-geometry`**

---

## État actuel (au démarrage de ce plan)

✅ Phase 1 — `__ad_backend` déplacé dans `Common/default.jl`
✅ Phase 2 — `AbstractHamiltonianVectorField`, constructeurs typés, `Data.jl` mis à jour
✅ Phase 3 — stubs `gradient`/`derivative` dans `Differentiation`, implémentés dans l'extension
✅ Phase 4 source — `default.jl`, `prefix.jl`, `ad.jl`, `ad_types.jl`, `DifferentialGeometry.jl`, `CTFlows.jl`
🔴 Phase 4 tests — `test_ad_dg.jl` : **échec `LinearAlgebra`** (voir fix ci-dessous)

---

## Conventions transverses (à appliquer à chaque phase)

### 🏗️ Modules workflow — manifest pattern

Chaque fichier manifeste `<Name>.jl` suit cet ordre strict :

```
1. Docstring module (module-level)
2. module Name
3. Imports externes qualifiés (import X: X ou using X: X)
4. Imports sibling internes (import ..Sibling: Sibling)
5. include(joinpath(@__DIR__, "file.jl"))  ← dans l'ordre des dépendances
6. export symboles publics
7. end # module Name
```

Règles imports :
- `import DocStringExtensions: TYPEDEF, TYPEDSIGNATURES` — macros docstring
- `import CTBase.Exceptions` — exceptions qualifiées comme `Exceptions.NotImplemented(...)`
- `using ADTypes: ADTypes` — qualifié : `ADTypes.AbstractADType`
- `import ..Traits: Traits`, `import ..Common: Common`, etc. — siblings qualifiés
- **Jamais** `using PackageName` (bare) — toujours qualifié

### 🏗️ Architecture workflow — principes

- **Single Responsibility** : chaque fichier = une responsabilité
- **Pure functions** : les couches internes `_ad`, `_Lift`, `_Poisson`, `_∂ₜ_*` ne modifient pas d'état global
- **Typed dispatch** : l'API publique kwargs → résout TD/VD → appelle l'interne typed
- **`Any` dans les internes** : `_ad(X, foo, ...)` n'annote pas `X`/`foo` pour supporter les callables `AbstractVectorField`
- **Guards en amont** : `_check_outofplace`, `_check_not_hvf` avant tout calcul

### ⚠️ Exceptions workflow

```julia
# NotImplemented : méthode non implémentée (InPlace, HVF)
throw(Exceptions.NotImplemented(
    "message",
    required_method = "...",
    suggestion      = "...",
    context         = "...",
))

# IncorrectArgument : argument invalide (TD/VD mismatch)
throw(Exceptions.IncorrectArgument(
    "message",
    got      = "...",
    expected = "...",
    context  = "...",
))
```

### 🔬 Type-stability workflow

- `_ad` retourne une closure typed par TD/VD (4 méthodes spécialisées)
- `_ad_result` dispatche sur `Number` (Lie derivative) vs `AbstractVector` (Lie bracket)
- `ad(VF, VF)` retourne `Data.VectorField(closure, TD, VD, Traits.OutOfPlace)` — constructeur typé
- `Poisson(H, G)` retourne `Data.Hamiltonian(closure, TD, VD)` — constructeur typé

### 🧪 Testing-creation workflow — pattern obligatoire

```julia
module TestXxx

import Test
import CTBase.Exceptions
import CTFlows: CTFlows
import CTFlows.Traits: Traits
import CTFlows.Common: Common
import CTFlows.Data: Data
import CTFlows.Differentiation: Differentiation
import CTFlows.DifferentialGeometry: DifferentialGeometry

const VERBOSE    = isdefined(Main, :TestOptions) ? Main.TestOptions.VERBOSE    : true
const SHOWTIMING = isdefined(Main, :TestOptions) ? Main.TestOptions.SHOWTIMING : true

# Fakes définis à niveau module (jamais dans les fonctions de test)
# struct FakeXxx ...

function test_xxx()
    Test.@testset "..." verbose=VERBOSE showtiming=SHOWTIMING begin
        Test.@test ...
        Test.@test_throws SomeException ...
    end
end

end # module TestXxx

# CRITIQUE : redéfinir dans le scope extérieur pour TestRunner
test_xxx() = TestXxx.test_xxx()
```

**⚠️ `LinearAlgebra` ne s'importe PAS via `import` ou `using` dans les tests** (non disponible dans l'env de test). Utiliser `isapprox(a, b; atol=atol)` (Base) à la place de `norm`.

### Commandes de test (MCP)

**Procédure obligatoire** pour chaque test file :

1. Appeler le tool MCP `mcp0_get_test_command` avec `test_args=["test/suite/differential_geometry/test_xxx.jl"]`
2. Exécuter la commande Julia retournée **depuis le dossier CTFlows** (`Cwd=/Users/ocots/Research/logiciels/dev/control-toolbox/CTFlows`)
3. En cas d'erreur, utiliser `mcp0_generate_report` avec le fichier log généré pour analyser l'échec

Exemple :
```bash
# 1. Obtenir la commande via MCP
mcp0_get_test_command(test_args=["test/suite/differential_geometry/test_ad_dg.jl"])
# → retourne : julia --project ... TestRunner.jl ... test_ad_dg.jl

# 2. Exécuter depuis CTFlows
julia --project -e 'using Pkg; Pkg.test(;test_args=["suite/differential_geometry/test_ad_dg.jl"])'

# 3. En cas d'erreur, générer le rapport
mcp0_generate_report(log_file="/tmp/ctflows_test/test_ad_dg.log")
```

### Source d'exemples de tests

**Fichier de référence** : `reports/differential_geometry/v2/test_differential_geometry.jl`

Ce fichier contient des tests complets pour :
- `ad()` — Lie derivative, Lie bracket, intrinsic definition `[X,Y]·f = X·(Yf) - Y·(Xf)`
- `Lift()` — Function → Hamiltonian, autonomous/non-autonomous
- `Poisson()` — anticommutativité, correctness, scalar case
- Variable dependence (`is_variable=true`)
- Backend parameter (`ad_backend=`)
- Nested brackets (Jacobi identity)
- Prefix system (`diffgeo_prefix!`)
- `∂ₜ` time derivative
- **Type-Based API** — tests pour les 4 combos (TD×VD) de `ad`, `Lift`, `Poisson`

**⚠️ IMPORTANT** : Les tests dans ce fichier utilisent l'ancienne API (`autonomous=`/`variable=` au lieu de `is_autonomous=`/`is_variable=`). Adapter les kwargs lors de la réécriture.

---

## Phase 4 — Refactoring `ad.jl` + fix tests

### Bugs identifiés

**Bug #1 — `_ad_result` vecteur avec `args...`** : Le pattern `foo(x, args...)` met les extra-args APRÈS `x`, mais pour `NonAutonomous` l'appel correct est `foo(t, x)` — `t` doit venir EN PREMIER. Idem pour `X(x + s*Y, args...)` → `X(t, x + s*Y)` incorrect.

**Bug #2 — Test `≈ 9.0`** : Mon test a été adapté à tort à la valeur incorrecte. Après la correction de l'utilisateur dans `_ad` NonAutonomous (`g(s) = foo(t, x + s*X_x)`), la valeur correcte est `8.0`.

### Fix : closures dans `_ad`, suppression de `args...`

Chaque variant `_ad` crée des closures `X̂` et `f̂` à un seul argument `x_` qui fixent `t`/`v`. `_ad_result` ne reçoit que des fonctions `x_ -> ...`.

**Refactoring complet de `src/DifferentialGeometry/ad.jl`** :

```julia
# Public API — kwargs (plain Functions ; AbstractVectorField géré dans ad_types.jl)
function ad(
    X::Function, foo::Function;
    ad_backend::Union{ADTypes.AbstractADType, Common.NotProvided} = __dg_ad_backend(),
    is_autonomous::Bool = Common.__is_autonomous(),
    is_variable::Bool   = Common.__is_variable(),
)
    TD      = is_autonomous ? Traits.Autonomous    : Traits.NonAutonomous
    VD      = is_variable   ? Traits.NonFixed       : Traits.Fixed
    backend = _resolve_backend(ad_backend)
    return _ad(X, foo, backend, TD, VD)
end

# Public API — typed entry point
function ad(
    X::Function, foo::Function,
    ::Type{TD}, ::Type{VD};
    ad_backend::Union{ADTypes.AbstractADType, Common.NotProvided} = __dg_ad_backend(),
) where {TD <: Traits.TimeDependence, VD <: Traits.VariableDependence}
    backend = _resolve_backend(ad_backend)
    return _ad(X, foo, backend, TD, VD)
end

# Internal — X/foo unannotés pour accepter AbstractVectorField callables (via ad_types.jl)
function _ad(X, foo, backend::Differentiation.AbstractADBackend, ::Type{Traits.Autonomous}, ::Type{Traits.Fixed})
    return function (x)
        X_x  = X(x)
        X̂    = x_ -> X(x_)
        f̂    = x_ -> foo(x_)
        g(s) = f̂(x + s * X_x)
        dfoo = Differentiation.derivative(backend, g, 0.0)
        return _ad_result(X̂, f̂, dfoo, x, X_x, backend)
    end
end

function _ad(X, foo, backend::Differentiation.AbstractADBackend, ::Type{Traits.NonAutonomous}, ::Type{Traits.Fixed})
    return function (t, x)
        X_x  = X(t, x)
        X̂    = x_ -> X(t, x_)
        f̂    = x_ -> foo(t, x_)
        g(s) = f̂(x + s * X_x)
        dfoo = Differentiation.derivative(backend, g, 0.0)
        return _ad_result(X̂, f̂, dfoo, x, X_x, backend)
    end
end

function _ad(X, foo, backend::Differentiation.AbstractADBackend, ::Type{Traits.Autonomous}, ::Type{Traits.NonFixed})
    return function (x, v)
        X_x  = X(x, v)
        X̂    = x_ -> X(x_, v)
        f̂    = x_ -> foo(x_, v)
        g(s) = f̂(x + s * X_x)
        dfoo = Differentiation.derivative(backend, g, 0.0)
        return _ad_result(X̂, f̂, dfoo, x, X_x, backend)
    end
end

function _ad(X, foo, backend::Differentiation.AbstractADBackend, ::Type{Traits.NonAutonomous}, ::Type{Traits.NonFixed})
    return function (t, x, v)
        X_x  = X(t, x, v)
        X̂    = x_ -> X(t, x_, v)
        f̂    = x_ -> foo(t, x_, v)
        g(s) = f̂(x + s * X_x)
        dfoo = Differentiation.derivative(backend, g, 0.0)
        return _ad_result(X̂, f̂, dfoo, x, X_x, backend)
    end
end

# Lie derivative (scalar): ∇f(x)'*X(x) — directional derivative déjà calculé
_ad_result(X̂::Function, f̂::Function, dfoo::Number, x, X_x, backend::Differentiation.AbstractADBackend) = dfoo

# Lie bracket (vector): J_Y(x)*X(x) - J_X(x)*Y(x)
function _ad_result(X̂::Function, f̂::Function, dfoo::AbstractVector, x, X_x, backend::Differentiation.AbstractADBackend)
    Y_x  = f̂(x)
    h(s) = X̂(x + s * Y_x)
    dX   = Differentiation.derivative(backend, h, 0.0)
    return dfoo - dX
end
```

### Fix dans `test_ad_dg.jl`

- Corriger `≈ 9.0` → `≈ 8.0` dans le testset `ad() - Lie Derivative` (NonAutonomous)

### Valeurs attendues vérifiées

**Lie Derivative, NonAutonomous** `f(t,x) = t + x[1]^2`, `X(t,x) = [t*x[2], -x[1]]`, `t=2, x=[1,2]` :
`∇x f · X = [2x[1], 0] · [t*x[2], -x[1]] = 2*1*2*2 = 8.0` ✓

**Lie Bracket, VectorField/VectorField** `X(x)=[x[2],-x[1]]`, `Y(x)=[x[1],x[2]]`, `x=[1,2]` :
`J_Y·X - J_X·Y = I·[2,-1] - [[0,1],[-1,0]]·[1,2] = [2,-1] - [2,-1] = [0,0]` ✓

### Vérification MCP

```bash
mcp0_get_test_command(["test/suite/differential_geometry/test_ad_dg.jl"])
# puis exécuter la commande, puis mcp0_generate_report si erreur
```

> ⛔ **ARRÊT** — tests verts, demander permission avant tout commit.

---

## Phase 5 — `Lift` + `Poisson`

### 5.1 — `src/DifferentialGeometry/lift.jl` (nouveau fichier)

> 🏗️ Architecture : deux points d'entrée publics (kwargs + typed), internes `_Lift` avec `Any`
> 🔬 Type-stability : `Lift(VF)` retourne `Data.Hamiltonian{TD,VD}` via constructeur typé

```julia
# kwargs entry point — algebraic, no AD backend needed
function Lift(
    f::Function;
    is_autonomous::Bool = Common.__is_autonomous(),
    is_variable::Bool   = Common.__is_variable(),
)
    TD = is_autonomous ? Traits.Autonomous : Traits.NonAutonomous
    VD = is_variable   ? Traits.NonFixed   : Traits.Fixed
    return Lift(f, TD, VD)
end

# typed entry point (used by @Lie macro)
function Lift(f::Function, ::Type{TD}, ::Type{VD}) where {TD, VD}
    return _Lift(f, TD, VD)
end

# Internal: 4 closures — first arg typed Any so AbstractVectorField callables work
_Lift(f, ::Type{Traits.Autonomous},    ::Type{Traits.Fixed})    = (x, p)       -> p' * f(x)
_Lift(f, ::Type{Traits.Autonomous},    ::Type{Traits.NonFixed}) = (x, p, v)    -> p' * f(x, v)
_Lift(f, ::Type{Traits.NonAutonomous}, ::Type{Traits.Fixed})    = (t, x, p)    -> p' * f(t, x)
_Lift(f, ::Type{Traits.NonAutonomous}, ::Type{Traits.NonFixed}) = (t, x, p, v) -> p' * f(t, x, v)

# AbstractVectorField → Data.Hamiltonian (reuse _Lift, X is callable)
function Lift(X::Data.AbstractVectorField{TD, VD}) where {TD, VD}
    _check_not_hvf(X)   # guard from ad_types.jl
    closure = _Lift(X, TD, VD)
    return Data.Hamiltonian(closure, TD, VD)   # typed constructor (no MD param)
end
```

> ⛔ Pas de docstrings dans cette étape.

---

### 5.2 — `src/DifferentialGeometry/poisson.jl` (nouveau fichier)

> 🏗️ Architecture : même pattern kwargs/typed que `ad`
> ⚠️ Exceptions : mismatch TD/VD → `IncorrectArgument`
> 🔬 Type-stability : `Poisson(H, G)` typé retourne `Data.Hamiltonian{TD,VD}`

```julia
# kwargs entry point
function Poisson(
    H::Function, G::Function;
    ad_backend::Union{ADTypes.AbstractADType, Common.NotProvided} = __dg_ad_backend(),
    is_autonomous::Bool = Common.__is_autonomous(),
    is_variable::Bool   = Common.__is_variable(),
)
    TD      = is_autonomous ? Traits.Autonomous : Traits.NonAutonomous
    VD      = is_variable   ? Traits.NonFixed   : Traits.Fixed
    backend = _resolve_backend(ad_backend)
    return _Poisson(H, G, backend, TD, VD)
end

# typed entry point (used by @Lie macro)
function Poisson(
    H::Function, G::Function,
    ::Type{TD}, ::Type{VD};
    ad_backend::Union{ADTypes.AbstractADType, Common.NotProvided} = __dg_ad_backend(),
) where {TD, VD}
    backend = _resolve_backend(ad_backend)
    return _Poisson(H, G, backend, TD, VD)
end

# Internal: Differentiation.gradient — 4 variants
function _Poisson(H, G, backend, ::Type{Traits.Autonomous}, ::Type{Traits.Fixed})
    return function (x, p)
        gxH = Differentiation.gradient(backend, y -> H(y, p), x)
        gpH = Differentiation.gradient(backend, q -> H(x, q), p)
        gxG = Differentiation.gradient(backend, y -> G(y, p), x)
        gpG = Differentiation.gradient(backend, q -> G(x, q), p)
        return gpH' * gxG - gxH' * gpG
    end
end

function _Poisson(H, G, backend, ::Type{Traits.NonAutonomous}, ::Type{Traits.Fixed})
    return function (t, x, p)
        gxH = Differentiation.gradient(backend, y -> H(t, y, p), x)
        gpH = Differentiation.gradient(backend, q -> H(t, x, q), p)
        gxG = Differentiation.gradient(backend, y -> G(t, y, p), x)
        gpG = Differentiation.gradient(backend, q -> G(t, x, q), p)
        return gpH' * gxG - gxH' * gpG
    end
end

function _Poisson(H, G, backend, ::Type{Traits.Autonomous}, ::Type{Traits.NonFixed})
    return function (x, p, v)
        gxH = Differentiation.gradient(backend, y -> H(y, p, v), x)
        gpH = Differentiation.gradient(backend, q -> H(x, q, v), p)
        gxG = Differentiation.gradient(backend, y -> G(y, p, v), x)
        gpG = Differentiation.gradient(backend, q -> G(x, q, v), p)
        return gpH' * gxG - gxH' * gpG
    end
end

function _Poisson(H, G, backend, ::Type{Traits.NonAutonomous}, ::Type{Traits.NonFixed})
    return function (t, x, p, v)
        gxH = Differentiation.gradient(backend, y -> H(t, y, p, v), x)
        gpH = Differentiation.gradient(backend, q -> H(t, x, q, v), p)
        gxG = Differentiation.gradient(backend, y -> G(t, y, p, v), x)
        gpG = Differentiation.gradient(backend, q -> G(t, x, q, v), p)
        return gpH' * gxG - gxH' * gpG
    end
end

# Typed overload: AbstractHamiltonian → Data.Hamiltonian
function Poisson(
    H::Data.AbstractHamiltonian{TD, VD},
    G::Data.AbstractHamiltonian{TD, VD};
    ad_backend::Union{ADTypes.AbstractADType, Common.NotProvided} = __dg_ad_backend(),
) where {TD, VD}
    backend = _resolve_backend(ad_backend)
    closure = _Poisson(H, G, backend, TD, VD)
    return Data.Hamiltonian(closure, TD, VD)
end

# TD/VD mismatch → IncorrectArgument
function Poisson(
    H::Data.AbstractHamiltonian{TD1, VD1},
    G::Data.AbstractHamiltonian{TD2, VD2};
    ad_backend::Union{ADTypes.AbstractADType, Common.NotProvided} = __dg_ad_backend(),
) where {TD1, VD1, TD2, VD2}
    throw(Exceptions.IncorrectArgument(
        "Poisson: TD/VD mismatch between H and G",
        got      = "H: $(TD1)/$(VD1), G: $(TD2)/$(VD2)",
        expected = "Both Hamiltonians must share the same TimeDependence and VariableDependence",
        context  = "Poisson on AbstractHamiltonian",
    ))
end
```

> ⛔ Pas de docstrings dans cette étape.

---

### 5.3 — Mise à jour `src/DifferentialGeometry/DifferentialGeometry.jl`

Ajouter dans les includes (après `ad_types.jl`) et dans les exports :

```julia
# Dans les includes :
include("lift.jl")
include("poisson.jl")

# Dans les exports :
export Lift
export Poisson
```

---

### Checkpoint 5 — Tests

#### `test/suite/differential_geometry/test_lift_dg.jl`

```julia
module TestLiftDG

import Test
import CTBase.Exceptions
import CTFlows: CTFlows
import CTFlows.Traits: Traits
import CTFlows.Common: Common
import CTFlows.Data: Data
import CTFlows.DifferentialGeometry: DifferentialGeometry

const VERBOSE    = isdefined(Main, :TestOptions) ? Main.TestOptions.VERBOSE    : true
const SHOWTIMING = isdefined(Main, :TestOptions) ? Main.TestOptions.SHOWTIMING : true

function test_lift_dg()
    Test.@testset "Lift() - Function → Function" verbose=VERBOSE showtiming=SHOWTIMING begin
        f(x) = x[1]^2 + x[2]^2
        H = DifferentialGeometry.Lift(f)   # defaults: autonomous, fixed
        # H(x,p) = p' * f(x) ... mais Lift retourne une Function (p' * f(x) = scalaire)
        # Pour f scalaire → Lift(f)(x,p) = p[1] * f(x) ... non, p'*[f(x)] = p[1]*f(x)
        # f renvoie un scalaire → on ne peut pas faire p'*scalar ; f doit renvoyer un vecteur
        # Utiliser un vrai champ de vecteur
        F(x) = [x[2], -x[1]]
        H2 = DifferentialGeometry.Lift(F)
        x0 = [1.0, 2.0]; p0 = [3.0, 4.0]
        # H2(x,p) = p' * F(x) = [3,4]·[2,-1] = 6-4 = 2
        Test.@test H2(x0, p0) ≈ 2.0 atol=1e-10

        # Non-autonomous
        F_na(t, x) = [t * x[2], -x[1]]
        H_na = DifferentialGeometry.Lift(F_na; is_autonomous=false)
        Test.@test H_na isa Function
        # H_na(t,x,p) = p' * F_na(t,x) = [3,4]·[2*2,-1] = 12-4 = 8 (t=2)
        Test.@test H_na(2.0, x0, p0) ≈ 8.0 atol=1e-10
    end

    Test.@testset "Lift() - typed API cohérent avec kwargs" verbose=VERBOSE showtiming=SHOWTIMING begin
        F(x) = [x[2], -x[1]]
        H_kw    = DifferentialGeometry.Lift(F; is_autonomous=true, is_variable=false)
        H_typed = DifferentialGeometry.Lift(F, Traits.Autonomous, Traits.Fixed)
        x0 = [1.0, 2.0]; p0 = [3.0, 4.0]
        Test.@test H_kw(x0, p0) ≈ H_typed(x0, p0) atol=1e-10
    end

    Test.@testset "Lift() - VectorField → Data.Hamiltonian" verbose=VERBOSE showtiming=SHOWTIMING begin
        X = Data.VectorField(x -> [x[2], -x[1]]; is_autonomous=true, is_variable=false)
        H = DifferentialGeometry.Lift(X)

        # Check return type
        Test.@test H isa Data.Hamiltonian
        Test.@test H isa Data.AbstractHamiltonian{Traits.Autonomous, Traits.Fixed}

        # Check correctness
        x0 = [1.0, 2.0]; p0 = [3.0, 4.0]
        # H(x,p) = p'*X(x) = [3,4]·[2,-1] = 6-4 = 2
        Test.@test H(x0, p0) ≈ 2.0 atol=1e-10
    end

    Test.@testset "Lift() - HVF guard → NotImplemented" verbose=VERBOSE showtiming=SHOWTIMING begin
        hvf = Data.HamiltonianVectorField((x, p) -> (x, -p); is_autonomous=true, is_variable=false)
        Test.@test_throws Exceptions.NotImplemented DifferentialGeometry.Lift(hvf)
    end
end

end # module TestLiftDG

test_lift_dg() = TestLiftDG.test_lift_dg()
```

#### `test/suite/differential_geometry/test_poisson_dg.jl`

```julia
module TestPoissonDG

import Test
import CTBase.Exceptions
import CTFlows: CTFlows
import CTFlows.Traits: Traits
import CTFlows.Common: Common
import CTFlows.Data: Data
import CTFlows.DifferentialGeometry: DifferentialGeometry

const VERBOSE    = isdefined(Main, :TestOptions) ? Main.TestOptions.VERBOSE    : true
const SHOWTIMING = isdefined(Main, :TestOptions) ? Main.TestOptions.SHOWTIMING : true

function test_poisson_dg()
    Test.@testset "Poisson() - anticommutativité" verbose=VERBOSE showtiming=SHOWTIMING begin
        # {H, G} = -{G, H}
        H(x, p) = p[1]^2 / 2 + x[1]
        G(x, p) = p[2]^2 / 2 + x[2]
        PH = DifferentialGeometry.Poisson(H, G)
        PG = DifferentialGeometry.Poisson(G, H)
        x0 = [1.0, 2.0]; p0 = [0.5, 1.0]
        Test.@test PH(x0, p0) ≈ -PG(x0, p0) atol=1e-6
    end

    Test.@testset "Poisson() - correctness" verbose=VERBOSE showtiming=SHOWTIMING begin
        # {x1, p1} = 1, {x1, x2} = 0
        H(x, p) = x[1]   # ∇pH = 0, ∇xH = [1,0]
        G(x, p) = p[1]   # ∇pG = [1,0], ∇xG = 0
        # {H,G} = ∇pH · ∇xG - ∇xH · ∇pG = 0·0 - [1,0]·[1,0] = -1
        PB = DifferentialGeometry.Poisson(H, G)
        x0 = [1.0, 2.0]; p0 = [0.5, 1.0]
        Test.@test PB(x0, p0) ≈ -1.0 atol=1e-6
    end

    Test.@testset "Poisson() - AbstractHamiltonian → Data.Hamiltonian" verbose=VERBOSE showtiming=SHOWTIMING begin
        H = Data.Hamiltonian((x, p) -> p[1]^2 / 2; is_autonomous=true, is_variable=false)
        G = Data.Hamiltonian((x, p) -> x[1]; is_autonomous=true, is_variable=false)
        PB = DifferentialGeometry.Poisson(H, G)

        Test.@test PB isa Data.Hamiltonian
        Test.@test PB isa Data.AbstractHamiltonian{Traits.Autonomous, Traits.Fixed}
    end

    Test.@testset "Poisson() - TD/VD mismatch → IncorrectArgument" verbose=VERBOSE showtiming=SHOWTIMING begin
        H = Data.Hamiltonian((x, p) -> p[1]^2; is_autonomous=true, is_variable=false)
        G = Data.Hamiltonian((t, x, p) -> x[1]; is_autonomous=false, is_variable=false)
        Test.@test_throws Exceptions.IncorrectArgument DifferentialGeometry.Poisson(H, G)
    end

    Test.@testset "Poisson() - composition Lift" verbose=VERBOSE showtiming=SHOWTIMING begin
        # {Lift(f), Lift(g)} où f(x)=[x2,-x1], g(x)=[x1,x2]
        F(x) = [x[2], -x[1]]
        G_fn(x) = [x[1],  x[2]]
        HF = DifferentialGeometry.Lift(F)
        HG = DifferentialGeometry.Lift(G_fn)
        PB = DifferentialGeometry.Poisson(HF, HG)
        Test.@test PB isa Function
        x0 = [1.0, 2.0]; p0 = [1.0, 0.0]
        # Should be computable without error
        val = PB(x0, p0)
        Test.@test val isa Number
    end
end

end # module TestPoissonDG

test_poisson_dg() = TestPoissonDG.test_poisson_dg()
```

> ⛔ **ARRÊT** — tests verts pour Lift et Poisson, demander permission avant tout commit.

---

## Phase 6 — `∂ₜ` + macro `@Lie`

### Prérequis — `MacroTools` dans `Project.toml`

Avant d'écrire `lie_macro.jl`, vérifier que `MacroTools` est dans `Project.toml`.
S'il est absent, l'ajouter :

```toml
# Dans [deps] :
MacroTools = "1914dd2f-81c6-5fcd-8719-6d5c9610ff09"

# Dans [compat] :
MacroTools = "0.5"
```

Puis `Pkg.resolve()`.

---

### 6.1 — `src/DifferentialGeometry/time_derivative.jl` (nouveau fichier)

> 🏗️ Architecture : HVF overload **avant** VF (dispatch plus spécifique — Julia préfère le plus spécifique)
> 🔬 Type-stability : retourne `Data.VectorField(closure, NonAutonomous, VD, OutOfPlace)` ou `Data.Hamiltonian(closure, NonAutonomous, VD)`
> Note : `∂ₜ` sur Autonomous retourne la dérivée d'une constante = 0 (fermeture qui ignore `s`)

```julia
# Function → Function (f doit prendre t comme premier argument)
function ∂ₜ(
    f::Function;
    ad_backend::Union{ADTypes.AbstractADType, Common.NotProvided} = __dg_ad_backend(),
)
    backend = _resolve_backend(ad_backend)
    return (t, args...) -> Differentiation.derivative(backend, s -> f(s, args...), t)
end

# AbstractHamiltonianVectorField{TD,VD,MD} → HamiltonianVectorField{NonAutonomous,VD,OutOfPlace}
# DOIT ÊTRE AVANT l'overload AbstractVectorField (plus spécifique dans la hiérarchie)
function ∂ₜ(
    X::Data.AbstractHamiltonianVectorField{TD, VD, MD};
    ad_backend::Union{ADTypes.AbstractADType, Common.NotProvided} = __dg_ad_backend(),
) where {TD, VD, MD}
    _check_outofplace(MD)
    backend = _resolve_backend(ad_backend)
    closure = _∂ₜ_hvf(X, backend, TD, VD)
    return Data.HamiltonianVectorField(closure, Traits.NonAutonomous, VD, Traits.OutOfPlace)
end

# Autonomous HVF: call signature (x,p) ou (x,p,v) — s ignoré → dérivée = 0
_∂ₜ_hvf(X, b::Differentiation.AbstractADBackend, ::Type{Traits.Autonomous},    ::Type{Traits.Fixed})    = (t, x, p)    -> Differentiation.derivative(b, s -> X(x, p),    t)
_∂ₜ_hvf(X, b::Differentiation.AbstractADBackend, ::Type{Traits.Autonomous},    ::Type{Traits.NonFixed}) = (t, x, p, v) -> Differentiation.derivative(b, s -> X(x, p, v), t)
# NonAutonomous HVF: call signature (t,x,p) ou (t,x,p,v)
_∂ₜ_hvf(X, b::Differentiation.AbstractADBackend, ::Type{Traits.NonAutonomous}, ::Type{Traits.Fixed})    = (t, x, p)    -> Differentiation.derivative(b, s -> X(s, x, p),    t)
_∂ₜ_hvf(X, b::Differentiation.AbstractADBackend, ::Type{Traits.NonAutonomous}, ::Type{Traits.NonFixed}) = (t, x, p, v) -> Differentiation.derivative(b, s -> X(s, x, p, v), t)

# AbstractVectorField{TD,VD,MD} → VectorField{NonAutonomous,VD,OutOfPlace}
# (attrape les VF simples ; HVF géré par l'overload ci-dessus)
function ∂ₜ(
    X::Data.AbstractVectorField{TD, VD, MD};
    ad_backend::Union{ADTypes.AbstractADType, Common.NotProvided} = __dg_ad_backend(),
) where {TD, VD, MD}
    _check_outofplace(MD)
    backend = _resolve_backend(ad_backend)
    closure = _∂ₜ_vf(X, backend, TD, VD)
    return Data.VectorField(closure, Traits.NonAutonomous, VD, Traits.OutOfPlace)
end

# Autonomous VF: call signature (x) ou (x,v) — s ignoré → dérivée = 0
_∂ₜ_vf(X, b::Differentiation.AbstractADBackend, ::Type{Traits.Autonomous},    ::Type{Traits.Fixed})    = (t, x)    -> Differentiation.derivative(b, s -> X(x),    t)
_∂ₜ_vf(X, b::Differentiation.AbstractADBackend, ::Type{Traits.Autonomous},    ::Type{Traits.NonFixed}) = (t, x, v) -> Differentiation.derivative(b, s -> X(x, v), t)
# NonAutonomous VF
_∂ₜ_vf(X, b::Differentiation.AbstractADBackend, ::Type{Traits.NonAutonomous}, ::Type{Traits.Fixed})    = (t, x)    -> Differentiation.derivative(b, s -> X(s, x),    t)
_∂ₜ_vf(X, b::Differentiation.AbstractADBackend, ::Type{Traits.NonAutonomous}, ::Type{Traits.NonFixed}) = (t, x, v) -> Differentiation.derivative(b, s -> X(s, x, v), t)

# AbstractHamiltonian{TD,VD} → Hamiltonian{NonAutonomous,VD}
function ∂ₜ(
    H::Data.AbstractHamiltonian{TD, VD};
    ad_backend::Union{ADTypes.AbstractADType, Common.NotProvided} = __dg_ad_backend(),
) where {TD, VD}
    backend = _resolve_backend(ad_backend)
    closure = _∂ₜ_ham(H, backend, TD, VD)
    return Data.Hamiltonian(closure, Traits.NonAutonomous, VD)
end

# Autonomous Ham: call signature (x,p) ou (x,p,v) — dérivée = 0
_∂ₜ_ham(H, b::Differentiation.AbstractADBackend, ::Type{Traits.Autonomous},    ::Type{Traits.Fixed})    = (t, x, p)    -> Differentiation.derivative(b, s -> H(x, p),    t)
_∂ₜ_ham(H, b::Differentiation.AbstractADBackend, ::Type{Traits.Autonomous},    ::Type{Traits.NonFixed}) = (t, x, p, v) -> Differentiation.derivative(b, s -> H(x, p, v), t)
# NonAutonomous Ham
_∂ₜ_ham(H, b::Differentiation.AbstractADBackend, ::Type{Traits.NonAutonomous}, ::Type{Traits.Fixed})    = (t, x, p)    -> Differentiation.derivative(b, s -> H(s, x, p),    t)
_∂ₜ_ham(H, b::Differentiation.AbstractADBackend, ::Type{Traits.NonAutonomous}, ::Type{Traits.NonFixed}) = (t, x, p, v) -> Differentiation.derivative(b, s -> H(s, x, p, v), t)
```

> ⛔ Pas de docstrings dans cette étape.

---

### 6.2 — `src/DifferentialGeometry/lie_macro.jl` (nouveau fichier)

> 🏗️ Modules : requiert `import MacroTools: postwalk, @capture` dans le manifest
> Architecture : deux catégories d'options :
> - **Compile-time** (`is_autonomous`, `is_variable`) : évalués à la macro-expansion → convertis en `TD`/`VD`
> - **Runtime** (`ad_backend`) : capturé comme expression AST → splicé comme kwarg dans l'appel généré

```julia
macro Lie(expr::Expr, args...)
    is_autonomous = Common.__is_autonomous()
    is_variable   = Common.__is_variable()
    ad_backend_kw = nothing   # nothing → pas de kwarg ad_backend dans l'appel généré

    for arg in args
        if @capture(arg, is_autonomous = val_)
            is_autonomous = val
        elseif @capture(arg, is_variable = val_)
            is_variable = val
        elseif @capture(arg, ad_backend = val_)
            ad_backend_kw = :(ad_backend = $val)
        end
    end

    TD = is_autonomous ? :Autonomous : :NonAutonomous
    VD = is_variable   ? :NonFixed   : :Fixed
    prefix = diffgeo_prefix()
    extra_kws = ad_backend_kw === nothing ? [] : [ad_backend_kw]

    function fun(x)
        is_lie     = @capture(x, [a_, b_])
        is_poisson = @capture(x, {c_, d_})
        if is_lie
            return :($prefix.ad($a, $b, $prefix.$TD, $prefix.$VD; $(extra_kws...)))
        elseif is_poisson
            return :($prefix.Poisson($c, $d, $prefix.$TD, $prefix.$VD; $(extra_kws...)))
        else
            return x
        end
    end
    return esc(postwalk(fun, expr))
end
```

Exemples de ce que le macro génère :
- `@Lie [X, Y]` → `CTFlows.ad(X, Y, CTFlows.Autonomous, CTFlows.Fixed)`
- `@Lie {H, G}` → `CTFlows.Poisson(H, G, CTFlows.Autonomous, CTFlows.Fixed)`
- `@Lie [X, Y] ad_backend=b` → `CTFlows.ad(X, Y, CTFlows.Autonomous, CTFlows.Fixed; ad_backend=b)`
- `@Lie {H, G} is_autonomous=false` → `CTFlows.Poisson(H, G, CTFlows.NonAutonomous, CTFlows.Fixed)`

> ⛔ Pas de docstrings dans cette étape.

---

### 6.3 — Mise à jour `src/DifferentialGeometry/DifferentialGeometry.jl` (version finale)

```julia
"""
    DifferentialGeometry

Differential geometry operations on vector fields and Hamiltonians: Lie derivatives,
Lie brackets, Poisson brackets, and time derivatives.
"""
module DifferentialGeometry

# ==============================================================================
# External-package imports
# ==============================================================================

import DocStringExtensions: TYPEDEF, TYPEDSIGNATURES
import CTBase.Exceptions
using ADTypes: ADTypes
import MacroTools: postwalk, @capture

# ==============================================================================
# Internal sibling-submodule imports
# ==============================================================================

import ..Traits: Traits
import ..Common: Common
import ..Data: Data
import ..Differentiation: Differentiation

# ==============================================================================
# Include files (dependency order)
# ==============================================================================

include("default.jl")
include("prefix.jl")
include("ad.jl")
include("ad_types.jl")
include("lift.jl")
include("poisson.jl")
include("time_derivative.jl")
include("lie_macro.jl")

# ==============================================================================
# Public API — exports
# ==============================================================================

export ad
export Lift
export Poisson
export ∂ₜ
export dg_ad_backend, dg_ad_backend!
export diffgeo_prefix, diffgeo_prefix!
export var"@Lie"

end # module DifferentialGeometry
```

---

### Checkpoint 6 — Tests

#### `test/suite/differential_geometry/test_time_derivative_dg.jl`

```julia
module TestTimeDerivativeDG

import Test
import CTBase.Exceptions
import CTFlows: CTFlows
import CTFlows.Traits: Traits
import CTFlows.Common: Common
import CTFlows.Data: Data
import CTFlows.DifferentialGeometry: DifferentialGeometry

const VERBOSE    = isdefined(Main, :TestOptions) ? Main.TestOptions.VERBOSE    : true
const SHOWTIMING = isdefined(Main, :TestOptions) ? Main.TestOptions.SHOWTIMING : true

function test_time_derivative_dg()
    Test.@testset "∂ₜ() - Function" verbose=VERBOSE showtiming=SHOWTIMING begin
        f(t, x) = t^2 + x[1]
        df = DifferentialGeometry.∂ₜ(f)
        # ∂f/∂t = 2t → at t=3, x=[1,2]: 6.0
        Test.@test df(3.0, [1.0, 2.0]) ≈ 6.0 atol=1e-6
    end

    Test.@testset "∂ₜ() - NonAutonomous VectorField → VectorField{NonAutonomous}" verbose=VERBOSE showtiming=SHOWTIMING begin
        X = Data.VectorField((t, x) -> [t * x[2], -t * x[1]]; is_autonomous=false, is_variable=false)
        dX = DifferentialGeometry.∂ₜ(X)

        # Check return type
        Test.@test dX isa Data.VectorField
        Test.@test dX isa Data.AbstractVectorField{Traits.NonAutonomous, Traits.Fixed, Traits.OutOfPlace}

        # ∂/∂t [t*x2, -t*x1] = [x2, -x1] at any t
        t0 = 2.0; x0 = [1.0, 2.0]
        Test.@test isapprox(dX(t0, x0), [x0[2], -x0[1]]; atol=1e-6)
    end

    Test.@testset "∂ₜ() - Autonomous VectorField → derivative = 0" verbose=VERBOSE showtiming=SHOWTIMING begin
        X = Data.VectorField(x -> [x[2], -x[1]]; is_autonomous=true, is_variable=false)
        dX = DifferentialGeometry.∂ₜ(X)

        Test.@test dX isa Data.AbstractVectorField{Traits.NonAutonomous, Traits.Fixed, Traits.OutOfPlace}
        # ∂/∂t of autonomous = 0
        Test.@test isapprox(dX(1.0, [1.0, 2.0]), [0.0, 0.0]; atol=1e-6)
    end

    Test.@testset "∂ₜ() - NonAutonomous Hamiltonian → Hamiltonian{NonAutonomous}" verbose=VERBOSE showtiming=SHOWTIMING begin
        H = Data.Hamiltonian((t, x, p) -> t * (p' * x); is_autonomous=false, is_variable=false)
        dH = DifferentialGeometry.∂ₜ(H)

        Test.@test dH isa Data.Hamiltonian
        Test.@test dH isa Data.AbstractHamiltonian{Traits.NonAutonomous, Traits.Fixed}

        # ∂/∂t [t * p'x] = p'x
        x0 = [1.0, 2.0]; p0 = [3.0, 4.0]
        Test.@test dH(2.0, x0, p0) ≈ p0' * x0 atol=1e-6
    end

    Test.@testset "∂ₜ() - InPlace guard → NotImplemented" verbose=VERBOSE showtiming=SHOWTIMING begin
        ip_vf = Data.VectorField((dx, x) -> (dx .= x); is_autonomous=true, is_inplace=true)
        Test.@test_throws Exceptions.NotImplemented DifferentialGeometry.∂ₜ(ip_vf)
    end
end

end # module TestTimeDerivativeDG

test_time_derivative_dg() = TestTimeDerivativeDG.test_time_derivative_dg()
```

#### `test/suite/differential_geometry/test_macro_dg.jl`

```julia
module TestMacroDG

import Test
import CTBase.Exceptions
import CTFlows: CTFlows
import CTFlows.Traits: Traits
import CTFlows.Common: Common
import CTFlows.Data: Data
import CTFlows.DifferentialGeometry: DifferentialGeometry

const VERBOSE    = isdefined(Main, :TestOptions) ? Main.TestOptions.VERBOSE    : true
const SHOWTIMING = isdefined(Main, :TestOptions) ? Main.TestOptions.SHOWTIMING : true

function test_macro_dg()
    Test.@testset "@Lie [X, Y] — Lie bracket" verbose=VERBOSE showtiming=SHOWTIMING begin
        X(x) = [x[2], 0.0]
        Y(x) = [0.0, x[1]]
        XY = DifferentialGeometry.@Lie [X, Y]
        # [X,Y] = [-x1, x2]
        x0 = [1.0, 2.0]
        Test.@test isapprox(XY(x0), [-1.0, 2.0]; atol=1e-6)
    end

    Test.@testset "@Lie [X, [Y, Z]] — nested bracket" verbose=VERBOSE showtiming=SHOWTIMING begin
        X(x) = [x[2], 0.0]
        Y(x) = [0.0, x[1]]
        Z(x) = [x[1], x[2]]
        # @Lie [X, [Y, Z]] should expand to ad(X, ad(Y, Z))
        inner = DifferentialGeometry.@Lie [Y, Z]
        outer_ref = DifferentialGeometry.@Lie [X, inner]
        nested = DifferentialGeometry.@Lie [X, [Y, Z]]
        x0 = [1.0, 2.0]
        Test.@test isapprox(nested(x0), outer_ref(x0); atol=1e-6)
    end

    Test.@testset "@Lie {H, G} — Poisson bracket" verbose=VERBOSE showtiming=SHOWTIMING begin
        H(x, p) = p[1]^2 / 2
        G(x, p) = x[1]
        PB = DifferentialGeometry.@Lie {H, G}
        x0 = [1.0, 2.0]; p0 = [0.5, 1.0]
        # {H,G} = ∇pH · ∇xG - ∇xH · ∇pG = [p1,0]·[1,0] - [0,0]·[1,0] = p1
        Test.@test PB(x0, p0) ≈ p0[1] atol=1e-6
    end

    Test.@testset "@Lie is_autonomous=false" verbose=VERBOSE showtiming=SHOWTIMING begin
        X(t, x) = [t * x[2], 0.0]
        Y(t, x) = [0.0, t * x[1]]
        XY = DifferentialGeometry.@Lie [X, Y] is_autonomous=false
        t0 = 1.0; x0 = [1.0, 2.0]
        # Check callable
        val = XY(t0, x0)
        Test.@test val isa AbstractVector
    end

    Test.@testset "diffgeo_prefix! — prefix system" verbose=VERBOSE showtiming=SHOWTIMING begin
        original = DifferentialGeometry.diffgeo_prefix()
        Test.@test original isa Symbol

        DifferentialGeometry.diffgeo_prefix!(:MyPrefix)
        Test.@test DifferentialGeometry.diffgeo_prefix() == :MyPrefix

        # Restore
        DifferentialGeometry.diffgeo_prefix!(original)
        Test.@test DifferentialGeometry.diffgeo_prefix() == original
    end
end

end # module TestMacroDG

test_macro_dg() = TestMacroDG.test_macro_dg()
```

> ⛔ **ARRÊT** — tests verts pour ∂ₜ et @Lie, demander permission avant tout commit.

---

## Phase 7 — Docstrings

> 🔬 Workflow `docstrings` : utiliser `$(TYPEDEF)` pour les types, `$(TYPEDSIGNATURES)` pour les fonctions.
> Docstrings ajoutés **uniquement** après que tous les tests passent.

### Symboles à documenter

| Symbole | Fichier |
|---|---|
| `DifferentialGeometry.ad` (variante Function + typed + AbstractVectorField) | `ad.jl`, `ad_types.jl` |
| `DifferentialGeometry.Lift` (Function + AbstractVectorField) | `lift.jl` |
| `DifferentialGeometry.Poisson` (Function + AbstractHamiltonian + mismatch) | `poisson.jl` |
| `DifferentialGeometry.∂ₜ` (tous les overloads) | `time_derivative.jl` |
| `DifferentialGeometry.@Lie` | `lie_macro.jl` |
| `DifferentialGeometry.dg_ad_backend`, `dg_ad_backend!` | `default.jl` |
| `DifferentialGeometry.diffgeo_prefix`, `diffgeo_prefix!` | `prefix.jl` |

### Pattern docstring

```julia
"""
$(TYPEDSIGNATURES)

Courte description (1 phrase).

# Arguments
- `X` : ...
- `foo` : ...

# Keywords
- `is_autonomous` : ...
- `is_variable` : ...

# Returns
...

# Examples
```julia
X(x) = [x[2], -x[1]]
f(x) = x[1]^2 + x[2]^2
Lf = ad(X, f)       # Lie derivative
```
"""
```

### Checkpoint 7 — Régression complète

```bash
julia --project -e 'using Pkg; Pkg.test(;test_args=["suite/differential_geometry"])'
julia --project -e 'using Pkg; Pkg.test()'   # régression complète
```

> ⛔ **ARRÊT** — régression verte, demander permission avant tout commit.

---

## Protocole commit (permanent)

**⛔ NE JAMAIS committer sans demander la permission explicite à l'utilisateur.**
À la fin de chaque checkpoint (4, 5, 6, 7), s'arrêter et attendre la validation.
