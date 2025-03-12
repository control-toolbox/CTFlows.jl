const ctNumber = CTModels.ctNumber
const ctVector = Union{ctNumber,CTModels.ctVector}
const Time     = ctNumber
const Times    = AbstractVector{<:Time}
const State    = ctVector
const Costate  = ctVector
const Control  = ctVector
const Variable = ctVector
const DState   = ctVector
const DCostate = ctVector

# --------------------------------------------------------------------------------------------------
abstract type TimeDependence end
abstract type Autonomous <: TimeDependence end
abstract type NonAutonomous <: TimeDependence end

abstract type VariableDependence end
abstract type NonFixed <: VariableDependence end
abstract type Fixed <: VariableDependence end

# --------------------------------------------------------------------------------------------------
# Callable types
struct Mayer{TF<:Function,VD<:VariableDependence}
    f::TF
end

abstract type AbstractHamiltonian{TD<:TimeDependence,VD<:VariableDependence} end
abstract type AbstractVectorField{TD<:TimeDependence,VD<:VariableDependence} end

struct Hamiltonian{TF<:Function,TD<:TimeDependence,VD<:VariableDependence} <:
       AbstractHamiltonian{TD,VD}
    f::TF
end

struct VectorField{TF<:Function,TD<:TimeDependence,VD<:VariableDependence} <:
       AbstractVectorField{TD,VD}
    f::TF
end

struct HamiltonianVectorField{TF<:Function,TD<:TimeDependence,VD<:VariableDependence} <:
       AbstractVectorField{TD,VD}
    f::TF
end

struct HamiltonianLift{TV<:VectorField,TD<:TimeDependence,VD<:VariableDependence} <:
       AbstractHamiltonian{TD,VD}
    X::TV
    function HamiltonianLift(
        X::VectorField{<:Function,TD,VD}
    ) where {TD<:TimeDependence,VD<:VariableDependence}
        return new{typeof(X),TD,VD}(X)
    end
end

struct Lagrange{TF<:Function,TD<:TimeDependence,VD<:VariableDependence}
    f::TF
end

struct Dynamics{TF<:Function,TD<:TimeDependence,VD<:VariableDependence}
    f::TF
end

struct StateConstraint{TF<:Function,TD<:TimeDependence,VD<:VariableDependence}
    f::TF
end

struct MixedConstraint{TF<:Function,TD<:TimeDependence,VD<:VariableDependence}
    f::TF
end

struct FeedbackControl{TF<:Function,TD<:TimeDependence,VD<:VariableDependence}
    f::TF
end

struct ControlLaw{TF<:Function,TD<:TimeDependence,VD<:VariableDependence}
    f::TF
end

struct Multiplier{TF<:Function,TD<:TimeDependence,VD<:VariableDependence}
    f::TF
end

# --------------------------------------------------------------------------------------------------
# --------------------------------------------------------------------------------------------------
# Mayer
function Mayer(f::Function; variable::Bool=__variable())
    VD = variable ? NonFixed : Fixed
    return Mayer{typeof(f),VD}(f)
end

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
# Hamiltonian
function Hamiltonian(f::Function; autonomous::Bool=__autonomous(), variable::Bool=__variable())
    TD = autonomous ? Autonomous : NonAutonomous
    VD = variable ? NonFixed : Fixed
    return Hamiltonian{typeof(f),TD,VD}(f)
end

function Hamiltonian(f::Function, TD::Type{<:TimeDependence}, VD::Type{<:VariableDependence})
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
# HamiltonianLift
function HamiltonianLift(f::Function; autonomous::Bool=__autonomous(), variable::Bool=__variable())
    TD = autonomous ? Autonomous : NonAutonomous
    VD = variable ? NonFixed : Fixed
    return HamiltonianLift(VectorField(f, TD, VD))
end

function HamiltonianLift(f::Function, TD::Type{<:TimeDependence}, VD::Type{<:VariableDependence})
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
function HamiltonianVectorField(f::Function; autonomous::Bool=__autonomous(), variable::Bool=__variable())
    TD = autonomous ? Autonomous : NonAutonomous
    VD = variable ? NonFixed : Fixed
    return HamiltonianVectorField{typeof(f),TD,VD}(f)
end

function HamiltonianVectorField(f::Function, TD::Type{<:TimeDependence}, VD::Type{<:VariableDependence})
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
function VectorField(f::Function; autonomous::Bool=__autonomous(), variable::Bool=__variable())
    TD = autonomous ? Autonomous : NonAutonomous
    VD = variable ? NonFixed : Fixed
    return VectorField{typeof(f),TD,VD}(f)
end

function VectorField(f::Function, TD::Type{<:TimeDependence}, VD::Type{<:VariableDependence})
    return VectorField{typeof(f),TD,VD}(f)
end

function (F::VectorField{<:Function,Autonomous,Fixed})(x::State)::ctVector
    return F.f(x)
end

function (F::VectorField{<:Function,Autonomous,Fixed})(
    t::Time, x::State, v::Variable
)::ctVector
    return F.f(x)
end

function (F::VectorField{<:Function,Autonomous,NonFixed})(x::State, v::Variable)::ctVector
    return F.f(x, v)
end

function (F::VectorField{<:Function,Autonomous,NonFixed})(
    t::Time, x::State, v::Variable
)::ctVector
    return F.f(x, v)
end

function (F::VectorField{<:Function,NonAutonomous,Fixed})(t::Time, x::State)::ctVector
    return F.f(t, x)
end

function (F::VectorField{<:Function,NonAutonomous,Fixed})(
    t::Time, x::State, v::Variable
)::ctVector
    return F.f(t, x)
end

function (F::VectorField{<:Function,NonAutonomous,NonFixed})(
    t::Time, x::State, v::Variable
)::ctVector
    return F.f(t, x, v)
end

# --------------------------------------------------------------------------------------------------
function Lagrange(f::Function; autonomous::Bool=__autonomous(), variable::Bool=__variable())
    TD = autonomous ? Autonomous : NonAutonomous
    VD = variable ? NonFixed : Fixed
    return Lagrange{typeof(f),TD,VD}(f)
end

function Lagrange(f::Function, TD::Type{<:TimeDependence}, VD::Type{<:VariableDependence})
    return Lagrange{typeof(f),TD,VD}(f)
end

function (F::Lagrange{<:Function,Autonomous,Fixed})(x::State, u::Control)::ctNumber
    return F.f(x, u)
end

function (F::Lagrange{<:Function,Autonomous,Fixed})(
    t::Time, x::State, u::Control, v::Variable
)::ctNumber
    return F.f(x, u)
end

function (F::Lagrange{<:Function,Autonomous,NonFixed})(
    x::State, u::Control, v::Variable
)::ctNumber
    return F.f(x, u, v)
end

function (F::Lagrange{<:Function,Autonomous,NonFixed})(
    t::Time, x::State, u::Control, v::Variable
)::ctNumber
    return F.f(x, u, v)
end

function (F::Lagrange{<:Function,NonAutonomous,Fixed})(
    t::Time, x::State, u::Control
)::ctNumber
    return F.f(t, x, u)
end

function (F::Lagrange{<:Function,NonAutonomous,Fixed})(
    t::Time, x::State, u::Control, v::Variable
)::ctNumber
    return F.f(t, x, u)
end

function (F::Lagrange{<:Function,NonAutonomous,NonFixed})(
    t::Time, x::State, u::Control, v::Variable
)::ctNumber
    return F.f(t, x, u, v)
end

# --------------------------------------------------------------------------------------------------
function Dynamics(f::Function; autonomous::Bool=__autonomous(), variable::Bool=__variable())
    TD = autonomous ? Autonomous : NonAutonomous
    VD = variable ? NonFixed : Fixed
    return Dynamics{typeof(f),TD,VD}(f)
end

function Dynamics(f::Function, TD::Type{<:TimeDependence}, VD::Type{<:VariableDependence})
    return Dynamics{typeof(f),TD,VD}(f)
end

function (F::Dynamics{<:Function,Autonomous,Fixed})(x::State, u::Control)::ctVector
    return F.f(x, u)
end

function (F::Dynamics{<:Function,Autonomous,Fixed})(
    t::Time, x::State, u::Control, v::Variable
)::ctVector
    return F.f(x, u)
end

function (F::Dynamics{<:Function,Autonomous,NonFixed})(
    x::State, u::Control, v::Variable
)::ctVector
    return F.f(x, u, v)
end

function (F::Dynamics{<:Function,Autonomous,NonFixed})(
    t::Time, x::State, u::Control, v::Variable
)::ctVector
    return F.f(x, u, v)
end

function (F::Dynamics{<:Function,NonAutonomous,Fixed})(
    t::Time, x::State, u::Control
)::ctVector
    return F.f(t, x, u)
end

function (F::Dynamics{<:Function,NonAutonomous,Fixed})(
    t::Time, x::State, u::Control, v::Variable
)::ctVector
    return F.f(t, x, u)
end

function (F::Dynamics{<:Function,NonAutonomous,NonFixed})(
    t::Time, x::State, u::Control, v::Variable
)::ctVector
    return F.f(t, x, u, v)
end

# --------------------------------------------------------------------------------------------------
function StateConstraint(f::Function; autonomous::Bool=__autonomous(), variable::Bool=__variable())
    TD = autonomous ? Autonomous : NonAutonomous
    VD = variable ? NonFixed : Fixed
    return StateConstraint{typeof(f),TD,VD}(f)
end

function StateConstraint(f::Function, TD::Type{<:TimeDependence}, VD::Type{<:VariableDependence})
    return StateConstraint{typeof(f),TD,VD}(f)
end

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
function MixedConstraint(f::Function; autonomous::Bool=__autonomous(), variable::Bool=__variable())
    TD = autonomous ? Autonomous : NonAutonomous
    VD = variable ? NonFixed : Fixed
    return MixedConstraint{typeof(f),TD,VD}(f)
end

function MixedConstraint(f::Function, TD::Type{<:TimeDependence}, VD::Type{<:VariableDependence})
    return MixedConstraint{typeof(f),TD,VD}(f)
end

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
function FeedbackControl(f::Function; autonomous::Bool=__autonomous(), variable::Bool=__variable())
    TD = autonomous ? Autonomous : NonAutonomous
    VD = variable ? NonFixed : Fixed
    return FeedbackControl{typeof(f),TD,VD}(f)
end

function FeedbackControl(f::Function, TD::Type{<:TimeDependence}, VD::Type{<:VariableDependence})
    return FeedbackControl{typeof(f),TD,VD}(f)
end

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
function ControlLaw(f::Function; autonomous::Bool=__autonomous(), variable::Bool=__variable())
    TD = autonomous ? Autonomous : NonAutonomous
    VD = variable ? NonFixed : Fixed
    return ControlLaw{typeof(f),TD,VD}(f)
end

function ControlLaw(f::Function, TD::Type{<:TimeDependence}, VD::Type{<:VariableDependence})
    return ControlLaw{typeof(f),TD,VD}(f)
end

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
function Multiplier(f::Function; autonomous::Bool=__autonomous(), variable::Bool=__variable())
    TD = autonomous ? Autonomous : NonAutonomous
    VD = variable ? NonFixed : Fixed
    return Multiplier{typeof(f),TD,VD}(f)
end

function Multiplier(f::Function, TD::Type{<:TimeDependence}, VD::Type{<:VariableDependence})
    return Multiplier{typeof(f),TD,VD}(f)
end

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