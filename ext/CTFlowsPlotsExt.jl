"""
    CTFlowsPlotsExt

Package extension providing plotting capabilities for `VectorFieldSolution`.
Activated automatically when `Plots` is loaded together with `CTFlows`.
"""
module CTFlowsPlotsExt

import DocStringExtensions: TYPEDSIGNATURES

using CTFlows: CTFlows
using CTFlows.Solutions: Solutions
using Plots: Plots

# =============================================================================
# Plots.plot — delegate to raw solution
# =============================================================================

"""
$(TYPEDSIGNATURES)

Plot a `VectorFieldSolution` by delegating to its raw SciML solution.
"""
function Plots.plot(sol::Solutions.VectorFieldSolution, args...; kwargs...)
    return Plots.plot(Solutions.raw(sol), args...; kwargs...)
end

"""
$(TYPEDSIGNATURES)

Plot into an existing plot by delegating to raw solution.
"""
function Plots.plot!(sol::Solutions.VectorFieldSolution, args...; kwargs...)
    return Plots.plot!(Solutions.raw(sol), args...; kwargs...)
end

"""
$(TYPEDSIGNATURES)

Plot into an existing plot by delegating to raw solution.
"""
function Plots.plot!(p, sol::Solutions.VectorFieldSolution, args...; kwargs...)
    return Plots.plot!(p, Solutions.raw(sol), args...; kwargs...)
end

end # module CTFlowsPlotsExt
