"""
CTFlowsOrdinaryDiffEqTsit5

Package extension providing the default SciML ODE algorithm (Tsit5) via tag dispatch.
Activated automatically when OrdinaryDiffEqTsit5 is loaded together with CTFlows.
"""
module CTFlowsOrdinaryDiffEqTsit5

import DocStringExtensions: TYPEDSIGNATURES
import CTFlows.Integrators
using OrdinaryDiffEqTsit5: OrdinaryDiffEqTsit5, Tsit5

"""
$(TYPEDSIGNATURES)

Return the default SciML ODE algorithm (Tsit5) for Tsit5Tag type.

Overrides the stub implementation in src/Integrators/sciml.jl that returns missing.

# Returns
- `Tsit5`: The default Tsit5 algorithm.

# Notes
- This function is called by the SciML metadata when Tsit5Tag type is used.
- Users can override this by explicitly passing the `alg` option.

See also: [`CTFlows.Integrators.SciML`](@ref), [`CTFlows.Integrators.Tsit5Tag`](@ref).
"""
function Integrators.__default_sciml_algorithm(::Type{<:Integrators.Tsit5Tag})
    return Tsit5()
end

end # module CTFlowsOrdinaryDiffEqTsit5
