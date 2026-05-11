"""
$(TYPEDEF)

Abstract tag type for dispatch-based extension architecture.

Tag types are used as dispatch markers to differentiate between implementations
provided by different package extensions. This pattern allows CTFlows to define
type stubs in the main package that are activated and implemented only when the
corresponding extension is loaded, avoiding direct dependencies while maintaining
extensibility.

# Interface Requirements

Concrete tag subtypes should:
- Be empty structs with no fields (pure markers)
- Be used as dispatch parameters in builder functions
- Correspond to a specific package extension (e.g., SciML, Plots)

# Example
\`\`\`julia-repl
julia> using CTFlows.Integrators

julia> SciMLTag <: Common.AbstractTag
true

julia> # The tag is used as a dispatch parameter:
julia> # build_sciml_integrator(SciMLTag; mode=:strict) routes to the
julia> # CTFlowsSciML implementation when the extension is loaded
\`\`\`

# Notes
- Tag types have no runtime cost (empty structs)
- They enable conditional compilation via Julia's extension system
- The pattern avoids hard dependencies on optional packages
"""
abstract type AbstractTag end

# =============================================================================
# Intermediate abstract tags for configuration traits
# =============================================================================

"""
$(TYPEDEF)

Abstract base type for mode tags (Point vs Trajectory).

Mode tags encode the integration mode in configuration types.
"""
abstract type AbstractModeTag <: AbstractTag end

"""
$(TYPEDEF)

Abstract base type for content tags (State vs Hamiltonian).

Content tags encode the content type in configuration types.
"""
abstract type AbstractContentTag <: AbstractTag end

# =============================================================================
# Concrete mode tags
# =============================================================================

"""
$(TYPEDEF)

Tag for point integration mode (single endpoint evaluation).

Used as a type parameter in `AbstractConfig` to indicate point integration.
"""
struct PointTag <: AbstractModeTag end

"""
$(TYPEDEF)

Tag for trajectory integration mode (full time evolution).

Used as a type parameter in `AbstractConfig` to indicate trajectory integration.
"""
struct TrajectoryTag <: AbstractModeTag end

# =============================================================================
# Concrete content tags
# =============================================================================

"""
$(TYPEDEF)

Tag for state content (no costate).

Used as a type parameter in `AbstractConfig` to indicate state-only configurations.
"""
struct StateTag <: AbstractContentTag end

"""
$(TYPEDEF)

Tag for Hamiltonian content (state + costate).

Used as a type parameter in `AbstractConfig` to indicate Hamiltonian configurations.
"""
struct HamiltonianTag <: AbstractContentTag end
