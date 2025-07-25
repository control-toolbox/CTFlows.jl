module CTFlowsODE

using CTBase
using CTFlows
using CTModels
using OrdinaryDiffEq
using DocStringExtensions
using LinearAlgebra
using MLStyle
#
import CTFlows: Flow, CTFlows
import Base: *
import CTModels: Solution, CTModels

# --------------------------------------------------------------------------------------------------
"""
Alias for `CTFlows.ctVector`, representing cotangent vectors in continuous-time systems.

Used for denoting adjoint states or costates in optimal control formulations.
"""
const CoTangent = CTFlows.ctVector

"""
Alias for `CTFlows.ctVector`, representing derivative cotangent vectors.

Useful in contexts where second-order information or directional derivatives of costates are required.
"""
const DCoTangent = CTFlows.ctVector

"""
Alias for `CTFlows.ctgradient`, a method to compute the gradient of a scalar function with respect to a state.

It dispatches appropriately depending on whether the input is a scalar or a vector, and uses `ForwardDiff.jl`.
"""
const ctgradient = CTFlows.ctgradient

# --------------------------------------------------------------------------------------------------
"""
Abstract supertype for continuous-time flows.

`AbstractFlow{D,U}` defines the interface for any flow system with:
- `D`: the type of the differential (typically a vector or matrix),
- `U`: the type of the state variable.

Subtypes should define at least a right-hand side function for the system's dynamics.
"""
abstract type AbstractFlow{D,U} end

# --------------------------------------------------------------------------------------------------
"""
Alias for `CTFlows.__create_hamiltonian`.

Constructs the Hamiltonian function for a given continuous-time optimal control problem.
This internal function typically takes an objective, dynamics, and control constraints.
"""
const __create_hamiltonian = CTFlows.__create_hamiltonian

# --------------------------------------------------------------------------------------------------
"""
Creates a range `i:j`, unless `i == j`, in which case returns `i` as an integer.

Useful when indexing or slicing arrays with optional single-element flexibility.
"""
rg(i::Int, j::Int) = i == j ? i : i:j

# --------------------------------------------------------------------------------------------------
"""
Alias for `CTFlows.__autonomous`, a tag indicating that a flow is autonomous.

Used internally to specify behavior in constructors or when composing flows.
"""
const __autonomous = CTFlows.__autonomous

"""
Alias for `CTFlows.__variable`, a tag indicating that a flow depends on external variables or is non-autonomous.

Used to distinguish time-dependent systems or flows with control/state parameterization.
"""
const __variable = CTFlows.__variable

# --------------------------------------------------------------------------------------------#
include("ext_default.jl")
include("ext_types.jl")
include("ext_utils.jl")
#
include("vector_field.jl")
include("hamiltonian.jl")
include("optimal_control_problem.jl")
include("function.jl")
include("concatenation.jl")

end
