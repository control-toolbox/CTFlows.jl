"""
$(TYPEDSIGNATURES)

Build an `AbstractSystem` from an input using a flow modeler and AD backend.

This function delegates to the modeler's business callable, passing both the input
and the AD backend. The modeler is responsible for assembling the system according
to its specific strategy.

# Arguments
- `input`: The input to build a system from (type varies by modeler).
- `modeler::Modelers.AbstractFlowModeler`: The modeler strategy to use.
- `ad_backend::ADBackends.AbstractADBackend`: The automatic differentiation backend.

# Returns
- `Systems.AbstractSystem`: The assembled system.

See also: [`Modelers.AbstractFlowModeler`](@ref), [`ADBackends.AbstractADBackend`](@ref).
"""
function build_system(input, modeler::Modelers.AbstractFlowModeler, ad_backend::ADBackends.AbstractADBackend)
    return modeler(input, ad_backend)
end
