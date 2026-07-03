"""
    Systems

System types and contracts for CTFlows.

This module defines the `AbstractSystem` type and its required methods:
- `get_ip_rhs`: returns the in-place right-hand side function for integration
- `get_oop_rhs`: returns the out-of-place right-hand side function for integration
- `get_ip_rhs_augmented`: returns the augmented in-place right-hand side for Hamiltonian systems
- `dimensions`: returns dimensional information (state, costate, control, variable)
"""
module Systems

# 1. External-package imports (qualified, pollution-free)
import DocStringExtensions: TYPEDEF, TYPEDSIGNATURES
import CTBase.Core
import CTBase.Data
import CTBase.Differentiation
import CTBase.Exceptions
import CTBase.Traits

# ==============================================================================
# Internal sibling-submodule imports
# ==============================================================================

import ..Display: Display
import ..Configs: Configs

# ==============================================================================
# Include files
# ==============================================================================

include(joinpath(@__DIR__, "ode_parameters.jl"))
include(joinpath(@__DIR__, "defaults.jl"))
include(joinpath(@__DIR__, "abstract_system.jl"))
include(joinpath(@__DIR__, "rhs_functors.jl"))
include(joinpath(@__DIR__, "hvf_rhs_functors.jl"))
include(joinpath(@__DIR__, "hamiltonian_rhs_functors.jl"))
include(joinpath(@__DIR__, "vector_field_system.jl"))
include(joinpath(@__DIR__, "hamiltonian_vector_field_system.jl"))
include(joinpath(@__DIR__, "hamiltonian_system.jl"))
include(joinpath(@__DIR__, "building.jl"))
include(joinpath(@__DIR__, "hamiltonian_getter.jl"))

# ==============================================================================
# Module exports
# ==============================================================================

export ODEParameters, variable, __hvf_inplace
export AbstractSystem, AbstractStateSystem, AbstractHamiltonianSystem
export AbstractRHS, AbstractIPRHS, AbstractOoPRHS
export AbstractHVFRHS, AbstractIPHVFRHS, AbstractOoPHVFRHS
export AbstractHamRHS, AbstractIPHamRHS, AbstractOoPHamRHS
export get_ip_rhs
export get_oop_rhs
export get_ip_rhs_augmented
export hamiltonian_vector_field
export VectorFieldSystem
export HamiltonianVectorFieldSystem
export HamiltonianSystem
export build_system
export hamiltonian, backend

end # module Systems
