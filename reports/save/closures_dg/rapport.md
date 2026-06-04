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

**Ligne 209-213** - `_∂ₜ_ham` (4 variantes) :
```julia
_∂ₜ_ham(H, b::Differentiation.AbstractADBackend, ::Type{Traits.Autonomous},    ::Type{Traits.Fixed})    = (t, x, p)    -> Differentiation.derivative(b, s -> H(x, p),    t)
_∂ₜ_ham(H, b::Differentiation.AbstractADBackend, ::Type{Traits.Autonomous},    ::Type{Traits.NonFixed}) = (t, x, p, v) -> Differentiation.derivative(b, s -> H(x, p, v), t)
_∂ₜ_ham(H, b::Differentiation.AbstractADBackend, ::Type{Traits.NonAutonomous}, ::Type{Traits.Fixed})    = (t, x, p)    -> Differentiation.derivative(b, s -> H(s, x, p),    t)
_∂ₜ_ham(H, b::Differentiation.AbstractADBackend, ::Type{Traits.NonAutonomous}, ::Type{Traits.NonFixed}) = (t, x, p, v) -> Differentiation.derivative(b, s -> H(s, x, p, v), t)
```
- 4 closures (une par combinaison TD×VD)
- Chaque closure contient une closure imbriquée pour la dérivée

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
