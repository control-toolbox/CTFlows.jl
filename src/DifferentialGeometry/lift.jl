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
