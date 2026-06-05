# Rapport sur les closures dans le module DifferentialGeometry

Ce rapport liste toutes les closures identifiées dans le module `src/DifferentialGeometry/`.

---

## Résumé

**Total de closures identifiées : 21**

- `ad.jl` : 8 closures (4 principales + 4 imbriquées)
- `lift.jl` : 4 closures
- `poisson.jl` : 4 closures
- `time_derivative.jl` : 5 closures

---

## Détail par fichier

### 1. `ad.jl` (8 closures)

#### Closures principales dans `_ad` (4)

**Ligne 115-122** - Autonomous/Fixed :
```julia
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
```
- Closure principale : `(x) -> ...`
- Closures imbriquées : `X̂`, `f̂`, `g`

**Ligne 139-146** - NonAutonomous/Fixed :
```julia
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
```
- Closure principale : `(t, x) -> ...`
- Closures imbriquées : `X̂`, `f̂`, `g`

**Ligne 163-170** - Autonomous/NonFixed :
```julia
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
```
- Closure principale : `(x, v) -> ...`
- Closures imbriquées : `X̂`, `f̂`, `g`

**Ligne 187-194** - NonAutonomous/NonFixed :
```julia
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
```
- Closure principale : `(t, x, v) -> ...`
- Closures imbriquées : `X̂`, `f̂`, `g`

#### Closures imbriquées dans `_ad_result` (1)

**Ligne 231-236** - Vector Lie bracket :
```julia
function _ad_result(X̂::Function, f̂::Function, dfoo::AbstractVector, x, X_x, backend::Differentiation.AbstractADBackend)
    Y_x  = f̂(x)
    h(s) = X̂(x + s * Y_x)
    dX   = Differentiation.derivative(backend, h, 0.0)
    return dfoo - dX
end
```
- Closure imbriquée : `h(s) = X̂(x + s * Y_x)`

---

### 2. `lift.jl` (4 closures)

**Ligne 90-93** - 4 variantes `_Lift` :
```julia
_Lift(f, ::Type{Traits.Autonomous},    ::Type{Traits.Fixed})    = (x, p)       -> p' * f(x)
_Lift(f, ::Type{Traits.Autonomous},    ::Type{Traits.NonFixed}) = (x, p, v)    -> p' * f(x, v)
_Lift(f, ::Type{Traits.NonAutonomous}, ::Type{Traits.Fixed})    = (t, x, p)    -> p' * f(t, x)
_Lift(f, ::Type{Traits.NonAutonomous}, ::Type{Traits.NonFixed}) = (t, x, p, v) -> p' * f(t, x, v)
```
- 4 closures simples (une par combinaison TD×VD)

---

### 3. `poisson.jl` (4 closures)

**Ligne 106-113** - Autonomous/Fixed :
```julia
function _Poisson(H, G, backend::Differentiation.AbstractADBackend, ::Type{Traits.Autonomous}, ::Type{Traits.Fixed})
    return function (x, p)
        gxH = Differentiation.gradient(backend, y -> H(y, p), x)
        gpH = Differentiation.gradient(backend, q -> H(x, q), p)
        gxG = Differentiation.gradient(backend, y -> G(y, p), x)
        gpG = Differentiation.gradient(backend, q -> G(x, q), p)
        return gpH' * gxG - gxH' * gpG
    end
end
```
- Closure principale : `(x, p) -> ...`
- Closures imbriquées : `y -> H(y, p)`, `q -> H(x, q)`, `y -> G(y, p)`, `q -> G(x, q)`

**Ligne 129-136** - NonAutonomous/Fixed :
```julia
function _Poisson(H, G, backend::Differentiation.AbstractADBackend, ::Type{Traits.NonAutonomous}, ::Type{Traits.Fixed})
    return function (t, x, p)
        gxH = Differentiation.gradient(backend, y -> H(t, y, p), x)
        gpH = Differentiation.gradient(backend, q -> H(t, x, q), p)
        gxG = Differentiation.gradient(backend, y -> G(t, y, p), x)
        gpG = Differentiation.gradient(backend, q -> G(t, x, q), p)
        return gpH' * gxG - gxH' * gpG
    end
end
```
- Closure principale : `(t, x, p) -> ...`
- Closures imbriquées : 4 closures pour les gradients

**Ligne 152-159** - Autonomous/NonFixed :
```julia
function _Poisson(H, G, backend::Differentiation.AbstractADBackend, ::Type{Traits.Autonomous}, ::Type{Traits.NonFixed})
    return function (x, p, v)
        gxH = Differentiation.gradient(backend, y -> H(y, p, v), x)
        gpH = Differentiation.gradient(backend, q -> H(x, q, v), p)
        gxG = Differentiation.gradient(backend, y -> G(y, p, v), x)
        gpG = Differentiation.gradient(backend, q -> G(x, q, v), p)
        return gpH' * gxG - gxH' * gpG
    end
end
```
- Closure principale : `(x, p, v) -> ...`
- Closures imbriquées : 4 closures pour les gradients

**Ligne 175-182** - NonAutonomous/NonFixed :
```julia
function _Poisson(H, G, backend::Differentiation.AbstractADBackend, ::Type{Traits.NonAutonomous}, ::Type{Traits.NonFixed})
    return function (t, x, p, v)
        gxH = Differentiation.gradient(backend, y -> H(t, y, p, v), x)
        gpH = Differentiation.gradient(backend, q -> H(t, x, q, v), p)
        gxG = Differentiation.gradient(backend, y -> G(t, y, p, v), x)
        gpG = Differentiation.gradient(backend, q -> G(t, x, q, v), p)
        return gpH' * gxG - gxH' * gpG
    end
end
```
- Closure principale : `(t, x, p, v) -> ...`
- Closures imbriquées : 4 closures pour les gradients

---

### 4. `time_derivative.jl` (5 closures)

**Ligne 33** - Fonction générique :
```julia
function ∂ₜ(f::Function; ad_backend::Union{ADTypes.AbstractADType, Common.NotProvided} = __dg_ad_backend())
    backend = _resolve_backend(ad_backend)
    return (t, args...) -> Differentiation.derivative(backend, s -> f(s, args...), t)
end
```
- Closure : `(t, args...) -> ...`
- Closure imbriquée : `s -> f(s, args...)`

**Ligne 91-95** - `_∂ₜ_hvf` (4 variantes) :
```julia
_∂ₜ_hvf(X, b::Differentiation.AbstractADBackend, ::Type{Traits.Autonomous},    ::Type{Traits.Fixed})    = (t, x, p)    -> Differentiation.derivative(b, s -> X(x, p),    t)
_∂ₜ_hvf(X, b::Differentiation.AbstractADBackend, ::Type{Traits.Autonomous},    ::Type{Traits.NonFixed}) = (t, x, p, v) -> Differentiation.derivative(b, s -> X(x, p, v), t)
_∂ₜ_hvf(X, b::Differentiation.AbstractADBackend, ::Type{Traits.NonAutonomous}, ::Type{Traits.Fixed})    = (t, x, p)    -> Differentiation.derivative(b, s -> X(s, x, p),    t)
_∂ₜ_hvf(X, b::Differentiation.AbstractADBackend, ::Type{Traits.NonAutonomous}, ::Type{Traits.NonFixed}) = (t, x, p, v) -> Differentiation.derivative(b, s -> X(s, x, p, v), t)
```
- 4 closures (une par combinaison TD×VD)
- Chaque closure contient une closure imbriquée pour la dérivée

**Ligne 152-156** - `_∂ₜ_vf` (4 variantes) :
```julia
_∂ₜ_vf(X, b::Differentiation.AbstractADBackend, ::Type{Traits.Autonomous},    ::Type{Traits.Fixed})    = (t, x)    -> Differentiation.derivative(b, s -> X(x),    t)
_∂ₜ_vf(X, b::Differentiation.AbstractADBackend, ::Type{Traits.Autonomous},    ::Type{Traits.NonFixed}) = (t, x, v) -> Differentiation.derivative(b, s -> X(x, v), t)
_∂ₜ_vf(X, b::Differentiation.AbstractADBackend, ::Type{Traits.NonAutonomous}, ::Type{Traits.Fixed})    = (t, x)    -> Differentiation.derivative(b, s -> X(s, x),    t)
_∂ₜ_vf(X, b::Differentiation.AbstractADBackend, ::Type{Traits.NonAutonomous}, ::Type{Traits.NonFixed}) = (t, x, v) -> Differentiation.derivative(b, s -> X(s, x, v), t)
```
- 4 closures (une par combinaison TD×VD)
- Chaque closure contient une closure imbriquée pour la dérivée

---

## 5. Closures remplacées par des functors (VectorFieldSystem)

**Fichier :** `src/Systems/vector_field_system.jl` → remplacé par `src/Systems/rhs_functors.jl`

Ces 5 closures pré-calculées ont été remplacées par des structs callables (functors) pour améliorer la performance et la type-stabilité.

### 5.1 `_build_rhs_vf_oop` → `IPVFOoPRHS`

**Ancienne closure (ligne ~107-109) :**
```julia
function _build_rhs_vf_oop(vf::Data.VectorField{F,TD,VD,Traits.OutOfPlace})
    return function (du, u, λ, t)
        du .= vf(t, u, Common.variable(λ))
        nothing
    end
end
```

**Nouveau functor :**
```julia
struct IPVFOoPRHS{F,TD,VD} <: AbstractIPRHS
    vf::Data.VectorField{F,TD,VD,Traits.OutOfPlace}
end

function (f::IPVFOoPRHS)(du, u, λ, t)
    du .= f.vf(t, u, Common.variable(λ))
    nothing
end
```

### 5.2 `_build_rhs_vf_ip` → `IPVFIpRHS`

**Ancienne closure (ligne ~126-128) :**
```julia
function _build_rhs_vf_ip(vf::Data.VectorField{F,TD,VD,Traits.InPlace})
    return function (du, u, λ, t)
        vf(du, t, u, Common.variable(λ))
        nothing
    end
end
```

**Nouveau functor :**
```julia
struct IPVFIpRHS{F,TD,VD} <: AbstractIPRHS
    vf::Data.VectorField{F,TD,VD,Traits.InPlace}
end

function (f::IPVFIpRHS)(du, u, λ, t)
    f.vf(du, t, u, Common.variable(λ))
    nothing
end
```

### 5.3 `_build_oop_rhs_vf_oop` → `OoPVFOoPRHS`

**Ancienne closure (ligne ~144-146) :**
```julia
function _build_oop_rhs_vf_oop(vf::Data.VectorField{F,TD,VD,Traits.OutOfPlace})
    return function (u, λ, t)
        vf(t, u, Common.variable(λ))
    end
end
```

**Nouveau functor :**
```julia
struct OoPVFOoPRHS{F,TD,VD} <: AbstractOoPRHS
    vf::Data.VectorField{F,TD,VD,Traits.OutOfPlace}
end

function (f::OoPVFOoPRHS)(u, λ, t)
    f.vf(t, u, Common.variable(λ))
end
```

### 5.4 `_build_oop_rhs_vf_ip` → `OoPVFIpRHS`

**Ancienne closure (ligne ~163-169) :**
```julia
function _build_oop_rhs_vf_ip(vf::Data.VectorField{F,TD,VD,Traits.InPlace})
    return function (u, λ, t)
        dx = similar(u)
        vf(dx, t, u, Common.variable(λ))
        dx
    end
end
```

**Nouveau functor :**
```julia
struct OoPVFIpRHS{F,TD,VD} <: AbstractOoPRHS
    vf::Data.VectorField{F,TD,VD,Traits.InPlace}
end

function (f::OoPVFIpRHS)(u, λ, t)
    dx = similar(u)
    f.vf(dx, t, u, Common.variable(λ))
    dx
end
```

### 5.5 `_build_finalize_rhs_vf_ip` → `OoPVFIpFinalizeRHS`

**Ancienne closure (ligne ~187-193) :**
```julia
function _build_finalize_rhs_vf_ip(vf::Data.VectorField{F,TD,VD,Traits.InPlace})
    return function (u, λ, t)
        dx = similar(u)
        vf(dx, t, u, Common.variable(λ))
        typeof(u)(dx)
    end
end
```

**Nouveau functor :**
```julia
struct OoPVFIpFinalizeRHS{F,TD,VD} <: AbstractOoPRHS
    vf::Data.VectorField{F,TD,VD,Traits.InPlace}
end

function (f::OoPVFIpFinalizeRHS)(u, λ, t)
    dx = similar(u)
    f.vf(dx, t, u, Common.variable(λ))
    typeof(u)(dx)
end
```

---

## Résumé des closures remplacées

**Total de closures remplacées par des functors : 5**

- `src/Systems/vector_field_system.jl` : 5 closures → 5 functors dans `src/Systems/rhs_functors.jl`
  - 2 in-place (IPVFOoPRHS, IPVFIpRHS)
  - 2 out-of-place (OoPVFOoPRHS, OoPVFIpRHS)
  - 1 finalize (OoPVFIpFinalizeRHS)

**Avantages du refactor :**
- Type-stabilité améliorée (les structs sont paramétrés par TD, VD)
- Meilleure performance (pas de capture de variables dans les closures)
- Code plus explicite et maintenable
- Display helpers intégrés pour le débogage

---

## Fichiers sans closures

- `default.jl` : Aucune closure
- `prefix.jl` : Aucune closure
- `exception_prefix.jl` : Aucune closure
- `ad_types.jl` : Aucune closure
- `lie_macro.jl` : Aucune closure (que du code de macro)

---

## Pattern observé

Les closures suivent un pattern régulier basé sur les combinaisons de traits :
- **TimeDependence** : Autonomous vs NonAutonomous
- **VariableDependence** : Fixed vs NonFixed

Chaque opération (`ad`, `Lift`, `Poisson`, `∂ₜ`) a 4 variantes de closures correspondant aux 4 combinaisons TD×VD possibles.
