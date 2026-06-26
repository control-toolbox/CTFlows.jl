# =============================================================================
# real_norm overload for SciML
# =============================================================================

"""
$(TYPEDSIGNATURES)

Compute the internal norm for adaptive step-size control using only the primal
parts of dual numbers.

This function ensures grid invariance (IND) when integrating ODEs with ForwardDiff
dual numbers: the adaptive time grid chosen by the solver is identical whether
integrating with real numbers or dual numbers. Without this, the step-size
controller would make decisions based on dual values, breaking grid invariance.

This implementation uses `Common.deepvalue` to extract primal parts and
`DiffEqBase.ODE_DEFAULT_NORM` to compute the norm. When ForwardDiff is loaded,
`Common.deepvalue` is extended to handle dual numbers via `CTFlowsForwardDiff`.

# Arguments
- `u::AbstractArray`: State vector (may contain dual numbers).
- `t`: Time parameter (unused but required by SciML interface).

# Returns
- `Real`: The norm computed on the primal parts only.

# Example
```julia
julia> using ForwardDiff

julia> u_real = [1.0, 2.0, 3.0]
julia> u_dual = ForwardDiff.Dual{:T}.(u_real, ones(3))

julia> CTFlowsSciMLIntegrator.real_norm(u_real, 0.0) ≈ CTFlowsSciMLIntegrator.real_norm(u_dual, 0.0)
true
```

See also: [`CTFlows.Common.deepvalue`](@ref), [`CTFlows.Common.real_norm`](@ref).
"""
Common.real_norm(u::AbstractArray, t) = DiffEqBase.ODE_DEFAULT_NORM(Common.deepvalue.(u), t)
