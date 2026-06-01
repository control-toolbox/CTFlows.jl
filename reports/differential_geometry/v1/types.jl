"""Base scalar type used in continuous-time models, e.g. Float64 or Dual numbers."""
const ctNumber = CTModels.ctNumber

"""Scalar or vector type used in continuous-time models (scalar or vector-valued)."""
const ctVector = Union{ctNumber,CTModels.ctVector}

"""Alias for scalar time variables."""
const Time = ctNumber

"""Alias for a vector of time points."""
const Times = AbstractVector{<:Time}

"""Alias for the system state (scalar or vector)."""
const State = ctVector

"""Alias for the costate (adjoint) variable (scalar or vector)."""
const Costate = ctVector

"""Alias for control input variables (scalar or vector)."""
const Control = ctVector

"""Alias for generic variables (scalar or vector)."""
const Variable = ctVector

"""Alias for derivatives of the state (scalar or vector)."""
const DState = ctVector

"""Alias for derivatives of the costate (scalar or vector)."""
const DCostate = ctVector

# --------------------------------------------------------------------------------------------------
"""
$(TYPEDEF)

Base abstract type representing the dependence of a function on time.

Used as a trait to distinguish autonomous vs. non-autonomous functions."""
abstract type TimeDependence end

"""
$(TYPEDEF)

Indicates the function is autonomous: it does not explicitly depend on time `t`.

For example, dynamics of the form `f(x, u, p)`."""
abstract type Autonomous <: TimeDependence end

"""
$(TYPEDEF)

Indicates the function is non-autonomous: it explicitly depends on time `t`.

For example, dynamics of the form `f(t, x, u, p)`."""
abstract type NonAutonomous <: TimeDependence end

"""
$(TYPEDEF)

Base abstract type representing whether a function depends on an additional variable argument.

Used to distinguish fixed-argument functions from those with auxiliary parameters."""
abstract type VariableDependence end

"""
$(TYPEDEF)

Indicates the function has an additional variable argument `v`.

For example, functions of the form `f(t, x, p, v)` where `v` is a multiplier or auxiliary parameter."""
abstract type NonFixed <: VariableDependence end

"""
$(TYPEDEF)

Indicates the function has fixed standard arguments only.

For example, functions of the form `f(t, x, p)` without any extra variable argument."""
abstract type Fixed <: VariableDependence end

# --------------------------------------------------------------------------------------------------
"""
$(TYPEDEF)

Encodes the Mayer cost function in optimal control problems.

This terminal cost term is usually of the form `φ(x(tf))` or `φ(t, x(tf), v)`, depending on whether it's autonomous and/or variable-dependent.

# Fields
- `f`: a callable of the form:
    - `f(x)`
    - `f(x, v)`
    - `f(t, x)`
    - `f(t, x, v)` depending on time and variable dependency.

# Example
```julia-repl
julia> φ(x) = norm(x)^2
julia> m = Mayer{typeof(φ), Fixed}(φ)
julia> m([1.0, 2.0])
```
"""
struct Mayer{TF<:Function,VD<:VariableDependence}
    f::TF
end

"""
$(TYPEDEF)
"""
abstract type AbstractHamiltonian{TD<:TimeDependence,VD<:VariableDependence} end

"""
$(TYPEDEF)
"""
abstract type AbstractVectorField{TD<:TimeDependence,VD<:VariableDependence} end

"""
$(TYPEDEF)

Encodes the Hamiltonian function `H = ⟨p, f⟩ + L` in optimal control.

# Fields
- `f`: a callable of the form:
    - `f(x, p)`
    - `f(t, x, p)`
    - `f(x, p, v)`
    - `f(t, x, p, v)`

# Type Parameters
- `TD`: `Autonomous` or `NonAutonomous`
- `VD`: `Fixed` or `NonFixed`

# Example
```julia-repl
julia> Hf(x, p) = dot(p, [x[2], -x[1]])
julia> H = Hamiltonian{typeof(Hf), Autonomous, Fixed}(Hf)
julia> H([1.0, 0.0], [1.0, 1.0])
```
"""
struct Hamiltonian{TF<:Function,TD<:TimeDependence,VD<:VariableDependence} <:
       AbstractHamiltonian{TD,VD}
    f::TF
end

"""
$(TYPEDEF)

Represents a dynamical system `dx/dt = f(...)` as a vector field.

# Fields
- `f`: a callable of the form:
    - `f(x)`
    - `f(t, x)`
    - `f(x, v)`
    - `f(t, x, v)`

# Example
```julia-repl
f(x) = [x[2], -x[1]]
vf = VectorField{typeof(f), Autonomous, Fixed}(f)
vf([1.0, 0.0])
```
"""
struct VectorField{TF<:Function,TD<:TimeDependence,VD<:VariableDependence} <:
       AbstractVectorField{TD,VD}
    f::TF
end

"""
$(TYPEDEF)

Represents the Hamiltonian vector field associated to a Hamiltonian function,
typically defined as `(∂H/∂p, -∂H/∂x)`.

# Fields
- `f`: a callable implementing the Hamiltonian vector field.

# Example
```julia-repl
julia> f(x, p) = [p[2], -p[1], -x[1], -x[2]]
julia> XH = HamiltonianVectorField{typeof(f), Autonomous, Fixed}(f)
julia> XH([1.0, 0.0], [0.5, 0.5])
```
"""
struct HamiltonianVectorField{TF<:Function,TD<:TimeDependence,VD<:VariableDependence} <:
       AbstractVectorField{TD,VD}
    f::TF
end

"""
$(TYPEDEF)

Lifts a vector field `X` into a Hamiltonian function using the canonical symplectic structure.

This is useful to convert a vector field into a Hamiltonian via the identity:
`H(x, p) = ⟨p, X(x)⟩`.

# Constructor
Use `HamiltonianLift(X::VectorField)` where `X` is a `VectorField{...}`.

# Example
```julia-repl
f(x) = [x[2], -x[1]]
julia> X = VectorField{typeof(f), Autonomous, Fixed}(f)
julia> H = HamiltonianLift(X)
julia> H([1.0, 0.0], [0.5, 0.5])
```
"""
struct HamiltonianLift{TV<:VectorField,TD<:TimeDependence,VD<:VariableDependence} <:
       AbstractHamiltonian{TD,VD}
    X::TV
    function HamiltonianLift(
        X::VectorField{<:Function,TD,VD}
    ) where {TD<:TimeDependence,VD<:VariableDependence}
        return new{typeof(X),TD,VD}(X)
    end
end

"""
$(TYPEDEF)

Encodes the integrand `L(t, x, u, ...)` of the cost functional in Bolza optimal control problems.

# Fields
- `f`: a callable such as:
    - `f(x, u)`
    - `f(t, x, u)`
    - `f(x, u, v)`
    - `f(t, x, u, v)`

# Example
```julia-repl
julia> L(x, u) = dot(x, x) + dot(u, u)
julia> lag = Lagrange{typeof(L), Autonomous, Fixed}(L)
julia> lag([1.0, 2.0], [0.5, 0.5])
```
"""
struct Lagrange{TF<:Function,TD<:TimeDependence,VD<:VariableDependence}
    f::TF
end

"""
$(TYPEDEF)

Represents the system dynamics `dx/dt = f(...)`.

# Fields
- `f`: a callable of the form:
    - `f(x, u)`
    - `f(t, x, u)`
    - `f(x, u, v)`
    - `f(t, x, u, v)`

# Example
```julia-repl
julia> f(x, u) = x + u
julia> dyn = Dynamics{typeof(f), Autonomous, Fixed}(f)
julia> dyn([1.0], [2.0])
```
"""
struct Dynamics{TF<:Function,TD<:TimeDependence,VD<:VariableDependence}
    f::TF
end

"""
$(TYPEDEF)

Encodes a pure state constraint `g(x) = 0` or `g(t, x) = 0`.

# Fields
- `f`: a callable depending on time or not, with or without variable dependency.

# Example
```julia-repl
julia> g(x) = x[1]^2 + x[2]^2 - 1
julia> c = StateConstraint{typeof(g), Autonomous, Fixed}(g)
julia> c([1.0, 0.0])
```
"""
struct StateConstraint{TF<:Function,TD<:TimeDependence,VD<:VariableDependence}
    f::TF
end

"""
$(TYPEDEF)

Encodes a constraint on both state and control: `g(x, u) = 0` or `g(t, x, u) = 0`.

# Example
```julia-repl
julia> g(x, u) = x[1] + u[1] - 1
julia> mc = MixedConstraint{typeof(g), Autonomous, Fixed}(g)
julia> mc([0.3], [0.7])
```
"""
struct MixedConstraint{TF<:Function,TD<:TimeDependence,VD<:VariableDependence}
    f::TF
end

"""
$(TYPEDEF)

Represents a feedback control law: `u = f(x)` or `u = f(t, x)`.

# Example
```julia-repl
julia> f(x) = -x
julia> u = FeedbackControl{typeof(f), Autonomous, Fixed}(f)
julia> u([1.0, -1.0])
```
"""
struct FeedbackControl{TF<:Function,TD<:TimeDependence,VD<:VariableDependence}
    f::TF
end

"""
$(TYPEDEF)

Represents a generic open-loop or closed-loop control law.

# Example
```julia-repl
julia> f(t, x) = -x * exp(-t)
julia> u = ControlLaw{typeof(f), NonAutonomous, Fixed}(f)
julia> u(1.0, [2.0])
```
"""
struct ControlLaw{TF<:Function,TD<:TimeDependence,VD<:VariableDependence}
    f::TF
end

"""
$(TYPEDEF)

Encodes a Lagrange multiplier associated with a constraint.

# Example
```julia-repl
julia> λ(t) = [sin(t), cos(t)]
julia> μ = Multiplier{typeof(λ), NonAutonomous, Fixed}(λ)
julia> μ(π / 2)
```
"""
struct Multiplier{TF<:Function,TD<:TimeDependence,VD<:VariableDependence}
    f::TF
end

# --------------------------------------------------------------------------------------------------
"""
$(TYPEDSIGNATURES)

Construct a Mayer cost functional wrapper.

- `f`: a function representing the Mayer cost.
- `variable`: whether the function depends on an extra variable argument (default via `__variable()`).

Returns a `Mayer{TF, VD}` callable struct where:
- `TF` is the function type
- `VD` is either `Fixed` or `NonFixed` depending on `variable`.
"""
function Mayer(f::Function; variable::Bool=__variable())
    VD = variable ? NonFixed : Fixed
    return Mayer{typeof(f),VD}(f)
end

"""
$(TYPEDSIGNATURES)

Construct a Mayer cost functional wrapper with explicit variable dependence type `VD`.
"""
function Mayer(f::Function, VD::Type{<:VariableDependence})
    return Mayer{typeof(f),VD}(f)
end

function (F::Mayer{<:Function,Fixed})(x0::State, xf::State)::ctNumber
    return F.f(x0, xf)
end

function (F::Mayer{<:Function,Fixed})(x0::State, xf::State, v::Variable)::ctNumber
    return F.f(x0, xf)
end

function (F::Mayer{<:Function,NonFixed})(x0::State, xf::State, v::Variable)::ctNumber
    return F.f(x0, xf, v)
end

# --------------------------------------------------------------------------------------------------
"""
$(TYPEDSIGNATURES)

Construct a Hamiltonian function wrapper.

- `f`: a function representing the Hamiltonian.
- `autonomous`: whether `f` is autonomous (default via `__autonomous()`).
- `variable`: whether `f` depends on an extra variable argument (default via `__variable()`).

Returns a `Hamiltonian{TF, TD, VD}` callable struct.
"""
function Hamiltonian(
    f::Function; autonomous::Bool=__autonomous(), variable::Bool=__variable()
)
    TD = autonomous ? Autonomous : NonAutonomous
    VD = variable ? NonFixed : Fixed
    return Hamiltonian{typeof(f),TD,VD}(f)
end

"""
$(TYPEDSIGNATURES)

Construct a Hamiltonian function wrapper with explicit time and variable dependence types.
"""
function Hamiltonian(
    f::Function, TD::Type{<:TimeDependence}, VD::Type{<:VariableDependence}
)
    return Hamiltonian{typeof(f),TD,VD}(f)
end

function (F::Hamiltonian{<:Function,Autonomous,Fixed})(x::State, p::Costate)::ctNumber
    return F.f(x, p)
end

function (F::Hamiltonian{<:Function,Autonomous,Fixed})(
    t::Time, x::State, p::Costate, v::Variable
)::ctNumber
    return F.f(x, p)
end

function (F::Hamiltonian{<:Function,Autonomous,NonFixed})(
    x::State, p::Costate, v::Variable
)::ctNumber
    return F.f(x, p, v)
end

function (F::Hamiltonian{<:Function,Autonomous,NonFixed})(
    t::Time, x::State, p::Costate, v::Variable
)::ctNumber
    return F.f(x, p, v)
end

function (F::Hamiltonian{<:Function,NonAutonomous,Fixed})(
    t::Time, x::State, p::Costate
)::ctNumber
    return F.f(t, x, p)
end

function (F::Hamiltonian{<:Function,NonAutonomous,Fixed})(
    t::Time, x::State, p::Costate, v::Variable
)::ctNumber
    return F.f(t, x, p)
end

function (F::Hamiltonian{<:Function,NonAutonomous,NonFixed})(
    t::Time, x::State, p::Costate, v::Variable
)::ctNumber
    return F.f(t, x, p, v)
end

# ---------------------------------------------------------------------------
"""
$(TYPEDSIGNATURES)

Construct a HamiltonianLift from a vector field function.

- `f`: function defining the vector field.
- `autonomous`: whether `f` is autonomous.
- `variable`: whether `f` depends on an extra variable argument.

Returns a `HamiltonianLift` wrapping the vector field.
"""
function HamiltonianLift(
    f::Function; autonomous::Bool=__autonomous(), variable::Bool=__variable()
)
    TD = autonomous ? Autonomous : NonAutonomous
    VD = variable ? NonFixed : Fixed
    return HamiltonianLift(VectorField(f, TD, VD))
end

"""
$(TYPEDSIGNATURES)

Construct a HamiltonianLift with explicit time and variable dependence types.
"""
function HamiltonianLift(
    f::Function, TD::Type{<:TimeDependence}, VD::Type{<:VariableDependence}
)
    return HamiltonianLift(VectorField(f, TD, VD))
end

function (H::HamiltonianLift{<:VectorField,Autonomous,Fixed})(
    x::State, p::Costate
)::ctNumber
    return p' * H.X(x)
end

function (H::HamiltonianLift{<:VectorField,Autonomous,Fixed})(
    t::Time, x::State, p::Costate, v::Variable
)::ctNumber
    return p' * H.X(x)
end

function (H::HamiltonianLift{<:VectorField,Autonomous,NonFixed})(
    x::State, p::Costate, v::Variable
)::ctNumber
    return p' * H.X(x, v)
end

function (H::HamiltonianLift{<:VectorField,Autonomous,NonFixed})(
    t::Time, x::State, p::Costate, v::Variable
)::ctNumber
    return p' * H.X(x, v)
end

function (H::HamiltonianLift{<:VectorField,NonAutonomous,Fixed})(
    t::Time, x::State, p::Costate
)::ctNumber
    return p' * H.X(t, x)
end

function (H::HamiltonianLift{<:VectorField,NonAutonomous,Fixed})(
    t::Time, x::State, p::Costate, v::Variable
)::ctNumber
    return p' * H.X(t, x)
end

function (H::HamiltonianLift{<:VectorField,NonAutonomous,NonFixed})(
    t::Time, x::State, p::Costate, v::Variable
)::ctNumber
    return p' * H.X(t, x, v)
end

# --------------------------------------------------------------------------------------------------
"""
$(TYPEDSIGNATURES)

Construct a Hamiltonian vector field from a function `f`.

- `autonomous`: whether `f` is autonomous.
- `variable`: whether `f` depends on an extra variable argument.

Returns a `HamiltonianVectorField{TF, TD, VD}` callable struct.
"""
function HamiltonianVectorField(
    f::Function; autonomous::Bool=__autonomous(), variable::Bool=__variable()
)
    TD = autonomous ? Autonomous : NonAutonomous
    VD = variable ? NonFixed : Fixed
    return HamiltonianVectorField{typeof(f),TD,VD}(f)
end

"""
$(TYPEDSIGNATURES)

Construct a Hamiltonian vector field with explicit time and variable dependence.
"""
function HamiltonianVectorField(
    f::Function, TD::Type{<:TimeDependence}, VD::Type{<:VariableDependence}
)
    return HamiltonianVectorField{typeof(f),TD,VD}(f)
end

function (F::HamiltonianVectorField{<:Function,Autonomous,Fixed})(
    x::State, p::Costate
)::Tuple{DState,DCostate}
    return F.f(x, p)
end

function (F::HamiltonianVectorField{<:Function,Autonomous,Fixed})(
    t::Time, x::State, p::Costate, v::Variable
)::Tuple{DState,DCostate}
    return F.f(x, p)
end

function (F::HamiltonianVectorField{<:Function,Autonomous,NonFixed})(
    x::State, p::Costate, v::Variable
)::Tuple{DState,DCostate}
    return F.f(x, p, v)
end

function (F::HamiltonianVectorField{<:Function,Autonomous,NonFixed})(
    t::Time, x::State, p::Costate, v::Variable
)::Tuple{DState,DCostate}
    return F.f(x, p, v)
end

function (F::HamiltonianVectorField{<:Function,NonAutonomous,Fixed})(
    t::Time, x::State, p::Costate
)::Tuple{DState,DCostate}
    return F.f(t, x, p)
end

function (F::HamiltonianVectorField{<:Function,NonAutonomous,Fixed})(
    t::Time, x::State, p::Costate, v::Variable
)::Tuple{DState,DCostate}
    return F.f(t, x, p)
end

function (F::HamiltonianVectorField{<:Function,NonAutonomous,NonFixed})(
    t::Time, x::State, p::Costate, v::Variable
)::Tuple{DState,DCostate}
    return F.f(t, x, p, v)
end

# --------------------------------------------------------------------------------------------------
"""
$(TYPEDSIGNATURES)

Create a `VectorField` object wrapping the function `f`.

# Arguments
- `f::Function`: The vector field function.
- `autonomous::Bool` (optional): If `true`, the vector field is autonomous (time-independent). Defaults to `__autonomous()`.
- `variable::Bool` (optional): If `true`, the vector field depends on control or decision variables (non-fixed). Defaults to `__variable()`.

# Returns
- A `VectorField{typeof(f),TD,VD}` object where `TD` encodes time dependence and `VD` encodes variable dependence.

# Details
The `VectorField` object can be called with different argument signatures depending on the time and variable dependence.

# Examples
```julia-repl
julia> f(x) = [-x[2], x[1]]
julia> vf = VectorField(f, autonomous=true, variable=false)
julia> vf([1.0, 0.0])  # returns [-0.0, 1.0]
```
"""
function VectorField(
    f::Function; autonomous::Bool=__autonomous(), variable::Bool=__variable()
)
    TD = autonomous ? Autonomous : NonAutonomous
    VD = variable ? NonFixed : Fixed
    return VectorField{typeof(f),TD,VD}(f)
end

"""
$(TYPEDSIGNATURES)

Create a `VectorField` object with explicit time and variable dependence types.

# Arguments
- `f::Function`: The vector field function.
- `TD`: Type indicating time dependence (`Autonomous` or `NonAutonomous`).
- `VD`: Type indicating variable dependence (`Fixed` or `NonFixed`).

# Returns
- A `VectorField{typeof(f),TD,VD}` object.
"""
function VectorField(
    f::Function, TD::Type{<:TimeDependence}, VD::Type{<:VariableDependence}
)
    return VectorField{typeof(f),TD,VD}(f)
end

# Dispatch for autonomous fixed variable dependence: f(x)
function (F::VectorField{<:Function,Autonomous,Fixed})(x::State)::ctVector
    return F.f(x)
end

# Dispatch for autonomous fixed variable dependence with unused args: f(x)
function (F::VectorField{<:Function,Autonomous,Fixed})(
    t::Time, x::State, v::Variable
)::ctVector
    return F.f(x)
end

# Dispatch for autonomous non-fixed variable dependence: f(x, v)
function (F::VectorField{<:Function,Autonomous,NonFixed})(x::State, v::Variable)::ctVector
    return F.f(x, v)
end

# Dispatch for autonomous non-fixed variable dependence with time arg: f(x, v)
function (F::VectorField{<:Function,Autonomous,NonFixed})(
    t::Time, x::State, v::Variable
)::ctVector
    return F.f(x, v)
end

# Dispatch for non-autonomous fixed variable dependence: f(t, x)
function (F::VectorField{<:Function,NonAutonomous,Fixed})(t::Time, x::State)::ctVector
    return F.f(t, x)
end

# Dispatch for non-autonomous fixed variable dependence with unused variable: f(t, x)
function (F::VectorField{<:Function,NonAutonomous,Fixed})(
    t::Time, x::State, v::Variable
)::ctVector
    return F.f(t, x)
end

# Dispatch for non-autonomous non-fixed variable dependence: f(t, x, v)
function (F::VectorField{<:Function,NonAutonomous,NonFixed})(
    t::Time, x::State, v::Variable
)::ctVector
    return F.f(t, x, v)
end

# --------------------------------------------------------------------------------------------------
"""
$(TYPEDSIGNATURES)

Create a `Lagrange` object representing a Lagrangian cost function.

# Arguments
- `f::Function`: The Lagrangian function.
- `autonomous::Bool` (optional): Whether `f` is autonomous (time-independent). Defaults to `__autonomous()`.
- `variable::Bool` (optional): Whether `f` depends on variables (non-fixed). Defaults to `__variable()`.

# Returns
- A `Lagrange{typeof(f),TD,VD}` object.

# Details
The `Lagrange` object can be called with different argument signatures depending on the time and variable dependence.

# Examples
```julia-repl
julia> f(x, u) = sum(abs2, x) + sum(abs2, u)
julia> lag = Lagrange(f, autonomous=true, variable=false)
julia> lag([1.0, 2.0], [0.5, 0.5])  # returns 5.25
```
"""
function Lagrange(f::Function; autonomous::Bool=__autonomous(), variable::Bool=__variable())
    TD = autonomous ? Autonomous : NonAutonomous
    VD = variable ? NonFixed : Fixed
    return Lagrange{typeof(f),TD,VD}(f)
end

"""
$(TYPEDSIGNATURES)

Create a `Lagrange` object with explicit time and variable dependence.

# Arguments
- `f::Function`: The Lagrangian function.
- `TD`: Type indicating time dependence.
- `VD`: Type indicating variable dependence.

# Returns
- A `Lagrange{typeof(f),TD,VD}` object.
"""
function Lagrange(f::Function, TD::Type{<:TimeDependence}, VD::Type{<:VariableDependence})
    return Lagrange{typeof(f),TD,VD}(f)
end

# Autonomous fixed variable: f(x,u)
function (F::Lagrange{<:Function,Autonomous,Fixed})(x::State, u::Control)::ctNumber
    return F.f(x, u)
end

# Autonomous fixed variable with unused args: f(x,u)
function (F::Lagrange{<:Function,Autonomous,Fixed})(
    t::Time, x::State, u::Control, v::Variable
)::ctNumber
    return F.f(x, u)
end

# Autonomous non-fixed variable: f(x,u,v)
function (F::Lagrange{<:Function,Autonomous,NonFixed})(
    x::State, u::Control, v::Variable
)::ctNumber
    return F.f(x, u, v)
end

# Autonomous non-fixed variable with time: f(x,u,v)
function (F::Lagrange{<:Function,Autonomous,NonFixed})(
    t::Time, x::State, u::Control, v::Variable
)::ctNumber
    return F.f(x, u, v)
end

# Non-autonomous fixed variable: f(t,x,u)
function (F::Lagrange{<:Function,NonAutonomous,Fixed})(
    t::Time, x::State, u::Control
)::ctNumber
    return F.f(t, x, u)
end

# Non-autonomous fixed variable with unused variable: f(t,x,u)
function (F::Lagrange{<:Function,NonAutonomous,Fixed})(
    t::Time, x::State, u::Control, v::Variable
)::ctNumber
    return F.f(t, x, u)
end

# Non-autonomous non-fixed variable: f(t,x,u,v)
function (F::Lagrange{<:Function,NonAutonomous,NonFixed})(
    t::Time, x::State, u::Control, v::Variable
)::ctNumber
    return F.f(t, x, u, v)
end

# --------------------------------------------------------------------------------------------------
"""
$(TYPEDSIGNATURES)

Create a `Dynamics` object representing system dynamics.

# Arguments
- `f::Function`: The dynamics function.
- `autonomous::Bool` (optional): Whether the dynamics are autonomous (time-independent). Defaults to `__autonomous()`.
- `variable::Bool` (optional): Whether the dynamics depend on variables (non-fixed). Defaults to `__variable()`.

# Returns
- A `Dynamics{typeof(f),TD,VD}` object.

# Details
The `Dynamics` object can be called with various signatures depending on time and variable dependence.

# Examples
```julia-repl
julia> f(x, u) = [x[2], -x[1] + u[1]]
julia> dyn = Dynamics(f, autonomous=true, variable=false)
julia> dyn([1.0, 0.0], [0.0])  # returns [0.0, -1.0]
```
"""
function Dynamics(f::Function; autonomous::Bool=__autonomous(), variable::Bool=__variable())
    TD = autonomous ? Autonomous : NonAutonomous
    VD = variable ? NonFixed : Fixed
    return Dynamics{typeof(f),TD,VD}(f)
end

"""
$(TYPEDSIGNATURES)

Create a `Dynamics` object with explicit time and variable dependence.

# Arguments
- `f::Function`: The dynamics function.
- `TD`: Type indicating time dependence.
- `VD`: Type indicating variable dependence.

# Returns
- A `Dynamics{typeof(f),TD,VD}` object.
"""
function Dynamics(f::Function, TD::Type{<:TimeDependence}, VD::Type{<:VariableDependence})
    return Dynamics{typeof(f),TD,VD}(f)
end

# Autonomous fixed variable: f(x,u)
function (F::Dynamics{<:Function,Autonomous,Fixed})(x::State, u::Control)::ctVector
    return F.f(x, u)
end

# Autonomous fixed variable with unused args: f(x,u)
function (F::Dynamics{<:Function,Autonomous,Fixed})(
    t::Time, x::State, u::Control, v::Variable
)::ctVector
    return F.f(x, u)
end

# Autonomous non-fixed variable: f(x,u,v)
function (F::Dynamics{<:Function,Autonomous,NonFixed})(
    x::State, u::Control, v::Variable
)::ctVector
    return F.f(x, u, v)
end

# Autonomous non-fixed variable with time: f(x,u,v)
function (F::Dynamics{<:Function,Autonomous,NonFixed})(
    t::Time, x::State, u::Control, v::Variable
)::ctVector
    return F.f(x, u, v)
end

# Non-autonomous fixed variable: f(t,x,u)
function (F::Dynamics{<:Function,NonAutonomous,Fixed})(
    t::Time, x::State, u::Control
)::ctVector
    return F.f(t, x, u)
end

# Non-autonomous fixed variable with unused variable: f(t,x,u)
function (F::Dynamics{<:Function,NonAutonomous,Fixed})(
    t::Time, x::State, u::Control, v::Variable
)::ctVector
    return F.f(t, x, u)
end

# Non-autonomous non-fixed variable: f(t,x,u,v)
function (F::Dynamics{<:Function,NonAutonomous,NonFixed})(
    t::Time, x::State, u::Control, v::Variable
)::ctVector
    return F.f(t, x, u, v)
end

# --------------------------------------------------------------------------------------------------
"""
$(TYPEDSIGNATURES)

Construct a `StateConstraint` object wrapping the function `f`.

# Arguments
- `f::Function`: The function defining the state constraint.
- `autonomous::Bool`: Whether the system is autonomous (default uses `__autonomous()`).
- `variable::Bool`: Whether the function depends on additional variables (default uses `__variable()`).

# Returns
- A `StateConstraint` instance parameterized by the type of `f` and time/variable dependence.

# Example

```julia-repl
julia> sc = StateConstraint(x -> x .- 1)  # Autonomous, fixed variable by default
```
"""
function StateConstraint(
    f::Function; autonomous::Bool=__autonomous(), variable::Bool=__variable()
)
    TD = autonomous ? Autonomous : NonAutonomous
    VD = variable ? NonFixed : Fixed
    return StateConstraint{typeof(f),TD,VD}(f)
end

"""
$(TYPEDSIGNATURES)

Construct a `StateConstraint` specifying the time and variable dependence types explicitly.

# Arguments
- `f::Function`: The function defining the state constraint.
- `TD::Type`: The time dependence type (`Autonomous` or `NonAutonomous`).
- `VD::Type`: The variable dependence type (`Fixed` or `NonFixed`).

# Returns
- A `StateConstraint` instance parameterized accordingly.
"""
function StateConstraint(
    f::Function, TD::Type{<:TimeDependence}, VD::Type{<:VariableDependence}
)
    return StateConstraint{typeof(f),TD,VD}(f)
end

# Call overloads for various combinations of time and variable dependence:

function (F::StateConstraint{<:Function,Autonomous,Fixed})(x::State)::ctVector
    return F.f(x)
end

function (F::StateConstraint{<:Function,Autonomous,Fixed})(
    t::Time, x::State, v::Variable
)::ctVector
    return F.f(x)
end

function (F::StateConstraint{<:Function,Autonomous,NonFixed})(
    x::State, v::Variable
)::ctVector
    return F.f(x, v)
end

function (F::StateConstraint{<:Function,Autonomous,NonFixed})(
    t::Time, x::State, v::Variable
)::ctVector
    return F.f(x, v)
end

function (F::StateConstraint{<:Function,NonAutonomous,Fixed})(t::Time, x::State)::ctVector
    return F.f(t, x)
end

function (F::StateConstraint{<:Function,NonAutonomous,Fixed})(
    t::Time, x::State, v::Variable
)::ctVector
    return F.f(t, x)
end

function (F::StateConstraint{<:Function,NonAutonomous,NonFixed})(
    t::Time, x::State, v::Variable
)::ctVector
    return F.f(t, x, v)
end

# --------------------------------------------------------------------------------------------------
"""
$(TYPEDSIGNATURES)

Construct a `MixedConstraint` object wrapping the function `f`.

# Arguments
- `f::Function`: The function defining the mixed constraint.
- `autonomous::Bool`: Whether the system is autonomous.
- `variable::Bool`: Whether the function depends on additional variables.

# Returns
- A `MixedConstraint` instance parameterized by the type of `f` and time/variable dependence.

# Example

```julia-repl
julia> mc = MixedConstraint((x, u) -> x + u)
```
"""
function MixedConstraint(
    f::Function; autonomous::Bool=__autonomous(), variable::Bool=__variable()
)
    TD = autonomous ? Autonomous : NonAutonomous
    VD = variable ? NonFixed : Fixed
    return MixedConstraint{typeof(f),TD,VD}(f)
end

"""
$(TYPEDSIGNATURES)

Construct a `MixedConstraint` specifying the time and variable dependence types explicitly.
"""
function MixedConstraint(
    f::Function, TD::Type{<:TimeDependence}, VD::Type{<:VariableDependence}
)
    return MixedConstraint{typeof(f),TD,VD}(f)
end

# Call overloads:

function (F::MixedConstraint{<:Function,Autonomous,Fixed})(x::State, u::Control)::ctVector
    return F.f(x, u)
end

function (F::MixedConstraint{<:Function,Autonomous,Fixed})(
    t::Time, x::State, u::Control, v::Variable
)::ctVector
    return F.f(x, u)
end

function (F::MixedConstraint{<:Function,Autonomous,NonFixed})(
    x::State, u::Control, v::Variable
)::ctVector
    return F.f(x, u, v)
end

function (F::MixedConstraint{<:Function,Autonomous,NonFixed})(
    t::Time, x::State, u::Control, v::Variable
)::ctVector
    return F.f(x, u, v)
end

function (F::MixedConstraint{<:Function,NonAutonomous,Fixed})(
    t::Time, x::State, u::Control
)::ctVector
    return F.f(t, x, u)
end

function (F::MixedConstraint{<:Function,NonAutonomous,Fixed})(
    t::Time, x::State, u::Control, v::Variable
)::ctVector
    return F.f(t, x, u)
end

function (F::MixedConstraint{<:Function,NonAutonomous,NonFixed})(
    t::Time, x::State, u::Control, v::Variable
)::ctVector
    return F.f(t, x, u, v)
end

# --------------------------------------------------------------------------------------------------
"""
$(TYPEDSIGNATURES)

Construct a `FeedbackControl` wrapping the function `f`.

# Arguments
- `f::Function`: The function defining the feedback control.
- `autonomous::Bool`: Whether the system is autonomous.
- `variable::Bool`: Whether the function depends on additional variables.

# Returns
- A `FeedbackControl` instance parameterized accordingly.

# Example

```julia-repl
julia> fb = FeedbackControl(x -> -x)
```
"""
function FeedbackControl(
    f::Function; autonomous::Bool=__autonomous(), variable::Bool=__variable()
)
    TD = autonomous ? Autonomous : NonAutonomous
    VD = variable ? NonFixed : Fixed
    return FeedbackControl{typeof(f),TD,VD}(f)
end

"""
$(TYPEDSIGNATURES)

Construct a `FeedbackControl` specifying time and variable dependence types.
"""
function FeedbackControl(
    f::Function, TD::Type{<:TimeDependence}, VD::Type{<:VariableDependence}
)
    return FeedbackControl{typeof(f),TD,VD}(f)
end

# Call overloads:

function (F::FeedbackControl{<:Function,Autonomous,Fixed})(x::State)::ctVector
    return F.f(x)
end

function (F::FeedbackControl{<:Function,Autonomous,Fixed})(
    t::Time, x::State, v::Variable
)::ctVector
    return F.f(x)
end

function (F::FeedbackControl{<:Function,Autonomous,NonFixed})(
    x::State, v::Variable
)::ctVector
    return F.f(x, v)
end

function (F::FeedbackControl{<:Function,Autonomous,NonFixed})(
    t::Time, x::State, v::Variable
)::ctVector
    return F.f(x, v)
end

function (F::FeedbackControl{<:Function,NonAutonomous,Fixed})(t::Time, x::State)::ctVector
    return F.f(t, x)
end

function (F::FeedbackControl{<:Function,NonAutonomous,Fixed})(
    t::Time, x::State, v::Variable
)::ctVector
    return F.f(t, x)
end

function (F::FeedbackControl{<:Function,NonAutonomous,NonFixed})(
    t::Time, x::State, v::Variable
)::ctVector
    return F.f(t, x, v)
end

# --------------------------------------------------------------------------------------------------
"""
$(TYPEDSIGNATURES)

Construct a `ControlLaw` wrapping the function `f`.

# Arguments
- `f::Function`: The function defining the control law.
- `autonomous::Bool`: Whether the system is autonomous.
- `variable::Bool`: Whether the function depends on additional variables.

# Returns
- A `ControlLaw` instance parameterized accordingly.

# Example

```julia-repl
julia> cl = ControlLaw((x, p) -> -p)
```
"""
function ControlLaw(
    f::Function; autonomous::Bool=__autonomous(), variable::Bool=__variable()
)
    TD = autonomous ? Autonomous : NonAutonomous
    VD = variable ? NonFixed : Fixed
    return ControlLaw{typeof(f),TD,VD}(f)
end

"""
$(TYPEDSIGNATURES)

Construct a `ControlLaw` specifying time and variable dependence types.
"""
function ControlLaw(f::Function, TD::Type{<:TimeDependence}, VD::Type{<:VariableDependence})
    return ControlLaw{typeof(f),TD,VD}(f)
end

# Call overloads:

function (F::ControlLaw{<:Function,Autonomous,Fixed})(x::State, p::Costate)::ctVector
    return F.f(x, p)
end

function (F::ControlLaw{<:Function,Autonomous,Fixed})(
    t::Time, x::State, p::Costate, v::Variable
)::ctVector
    return F.f(x, p)
end

function (F::ControlLaw{<:Function,Autonomous,NonFixed})(
    x::State, p::Costate, v::Variable
)::ctVector
    return F.f(x, p, v)
end

function (F::ControlLaw{<:Function,Autonomous,NonFixed})(
    t::Time, x::State, p::Costate, v::Variable
)::ctVector
    return F.f(x, p, v)
end

function (F::ControlLaw{<:Function,NonAutonomous,Fixed})(
    t::Time, x::State, p::Costate
)::ctVector
    return F.f(t, x, p)
end

function (F::ControlLaw{<:Function,NonAutonomous,Fixed})(
    t::Time, x::State, p::Costate, v::Variable
)::ctVector
    return F.f(t, x, p)
end

function (F::ControlLaw{<:Function,NonAutonomous,NonFixed})(
    t::Time, x::State, p::Costate, v::Variable
)::ctVector
    return F.f(t, x, p, v)
end

# --------------------------------------------------------------------------------------------------
"""
$(TYPEDSIGNATURES)

Construct a `Multiplier` wrapping the function `f`.

# Arguments
- `f::Function`: The function defining the multiplier.
- `autonomous::Bool`: Whether the system is autonomous.
- `variable::Bool`: Whether the function depends on additional variables.

# Returns
- A `Multiplier` instance parameterized accordingly.

# Example

```julia-repl
julia> m = Multiplier((x, p) -> p .* x)
```
"""
function Multiplier(
    f::Function; autonomous::Bool=__autonomous(), variable::Bool=__variable()
)
    TD = autonomous ? Autonomous : NonAutonomous
    VD = variable ? NonFixed : Fixed
    return Multiplier{typeof(f),TD,VD}(f)
end

"""
$(TYPEDSIGNATURES)

Construct a `Multiplier` specifying time and variable dependence types.
"""
function Multiplier(f::Function, TD::Type{<:TimeDependence}, VD::Type{<:VariableDependence})
    return Multiplier{typeof(f),TD,VD}(f)
end

# Call overloads:

function (F::Multiplier{<:Function,Autonomous,Fixed})(x::State, p::Costate)::ctVector
    return F.f(x, p)
end

function (F::Multiplier{<:Function,Autonomous,Fixed})(
    t::Time, x::State, p::Costate, v::Variable
)::ctVector
    return F.f(x, p)
end

function (F::Multiplier{<:Function,Autonomous,NonFixed})(
    x::State, p::Costate, v::Variable
)::ctVector
    return F.f(x, p, v)
end

function (F::Multiplier{<:Function,Autonomous,NonFixed})(
    t::Time, x::State, p::Costate, v::Variable
)::ctVector
    return F.f(x, p, v)
end

function (F::Multiplier{<:Function,NonAutonomous,Fixed})(
    t::Time, x::State, p::Costate
)::ctVector
    return F.f(t, x, p)
end

function (F::Multiplier{<:Function,NonAutonomous,Fixed})(
    t::Time, x::State, p::Costate, v::Variable
)::ctVector
    return F.f(t, x, p)
end

function (F::Multiplier{<:Function,NonAutonomous,NonFixed})(
    t::Time, x::State, p::Costate, v::Variable
)::ctVector
    return F.f(t, x, p, v)
end
