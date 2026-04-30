"""
    Systems

System types and contracts for CTFlows.

This module defines the `AbstractSystem` type and its required methods:
- `rhs!`: returns the right-hand side function for integration
- `dimensions`: returns dimensional information (state, costate, control, variable)
"""
module Systems

# 1. External-package imports (qualified, pollution-free)
import DocStringExtensions: TYPEDEF, TYPEDSIGNATURES
import CTBase.Exceptions
import RecipesBase

# ==============================================================================
# Internal sibling-submodule imports
# ==============================================================================

using ..Common

# ==============================================================================
# Include files
# ==============================================================================

include(joinpath(@__DIR__, "abstract_system.jl"))
include(joinpath(@__DIR__, "vector_field.jl"))
include(joinpath(@__DIR__, "vector_field_system.jl"))
include(joinpath(@__DIR__, "solution.jl"))
include(joinpath(@__DIR__, "build_solution.jl"))

# ==============================================================================
# Module exports
# ==============================================================================

export AbstractSystem, VectorField, VectorFieldSystem, VectorFieldSolution
export rhs!, build_solution, ode_problem, variable_dependence
export is_autonomous, is_nonautonomous, is_variable, has_variable, is_nonvariable

end # module Systems
