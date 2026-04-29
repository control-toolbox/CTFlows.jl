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
julia> # CTFlowsSciMLExt implementation when the extension is loaded
\`\`\`

# Notes
- Tag types have no runtime cost (empty structs)
- They enable conditional compilation via Julia's extension system
- The pattern avoids hard dependencies on optional packages
"""
abstract type AbstractTag end
