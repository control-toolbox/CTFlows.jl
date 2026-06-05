# ==============================================================================
# WithActiveArg — argument-reslotting functor (pure, no backend)
# ==============================================================================

"""
$(TYPEDEF)

Functor that calls `f` by placing the *active* argument at slot `Slot` and filling
the remaining positions with the constant arguments passed as varargs, in order.

Replaces argument-reordering closures of the form `h_x(x, t, p, v) = h(t, x, p, v)`.

Call as `w(active, c₁, …, cₙ)` ⇒ `f(arg₁, …, argₙ₊₁)` with `active` at slot `Slot`
and `cᵢ` filling the remaining slots in order. `Slot` is a type parameter (integer),
so the reordering is resolved at compile time — no allocation, no world-age issues.

# Example
```julia
f(a, b, c) = (a, b, c)
w = WithActiveArg(f, Val(2))
w(10, 1, 3)  # ⟹ f(1, 10, 3) = (1, 10, 3)  — active `10` placed at slot 2
```
"""
struct WithActiveArg{F, Slot}
    f::F
    WithActiveArg{F, Slot}(f::F) where {F, Slot} = new{F, Slot}(f)
end

"""
    WithActiveArg(f, ::Val{Slot}) where {Slot}

Construct a `WithActiveArg` functor that places the active argument at slot `Slot`.
"""
WithActiveArg(f, ::Val{Slot}) where {Slot} = WithActiveArg{typeof(f), Slot}(f)

"""
    WithActiveArg(f, slot::Integer)

Construct a `WithActiveArg` functor from a runtime integer slot (converted to `Val`).
"""
WithActiveArg(f, slot::Integer) = WithActiveArg(f, Val(Int(slot)))

@generated function (w::WithActiveArg{F, Slot})(active, consts::Vararg{Any, N}) where {F, Slot, N}
    total = N + 1
    if !(1 ≤ Slot ≤ total)
        return :(throw(CTBase.Exceptions.IncorrectArgument(
            "slot must be in range [1, n] for n arguments";
            got = "slot = " * string($Slot),
            expected = "slot in [1, " * string($total) * "]",
            suggestion = "choose a slot index in the valid range",
            context = "WithActiveArg"
        )))
    end
    args = Vector{Any}(undef, total)
    args[Slot] = :active
    ci = 1
    for pos in 1:total
        pos == Slot && continue
        args[pos] = :(consts[$ci])
        ci += 1
    end
    return :(w.f($(args...)))
end
