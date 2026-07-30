"""
    Flows

Flow types and contracts for CTFlows.

This module defines the `AbstractFlow` type and its required methods:
- `(flow)(t0, x0, tf)`: callable interface for state integration
- `(flow)(t0, x0, p0, tf)`: callable interface for state + costate integration
- `system`: returns the system associated with the flow
- `integrator`: returns the integrator used by the flow
"""
module Flows

# 1. External-package imports (qualified, pollution-free)
using DocStringExtensions: TYPEDEF, TYPEDSIGNATURES
using CTBase: Core
using CTBase: Data
using CTBase: Descriptions
using CTBase: Differentiation
using CTBase: Exceptions
using CTBase: Strategies
using CTBase: Options
using CTBase: Orchestration
using CTBase: Traits
using CTModels: CTModels
using CommonSolve: CommonSolve

# ==============================================================================
# Internal sibling-submodule imports
# ==============================================================================

using ..Display: Display
using ..Configs: Configs
using ..Systems: Systems, hamiltonian, hamiltonian_vector_field, vector_field
using ..Integrators: Integrators
using ..Trajectories: Trajectories

# ==============================================================================
# Include files
# ==============================================================================

include(joinpath(@__DIR__, "defaults.jl"))
include(joinpath(@__DIR__, "abstract_flow.jl"))
include(joinpath(@__DIR__, "flow.jl"))
include(joinpath(@__DIR__, "registry.jl"))
include(joinpath(@__DIR__, "flow_routing.jl"))
include(joinpath(@__DIR__, "ocp_readouts.jl"))
include(joinpath(@__DIR__, "optimal_control_flow.jl"))
include(joinpath(@__DIR__, "controlled_flow.jl"))
include(joinpath(@__DIR__, "building.jl"))
include(joinpath(@__DIR__, "calling.jl"))

# ==============================================================================
# Module exports
# ==============================================================================

export __variable, __unsafe, __variable_costate
export AbstractFlow,
    AbstractStateFlow, AbstractHamiltonianFlow, Flow, StateFlow, HamiltonianFlow
export OptimalControlFlow, ControlledFlow
export system, integrator
export build_flow
export hamiltonian, hamiltonian_vector_field, vector_field
export flow_registry

end # module Flows
