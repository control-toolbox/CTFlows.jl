"""
$(TYPEDSIGNATURES)

High-level constructor for `Flow` from vector field data and integrator identifier.

This constructor builds a complete flow by:
1. Building a `VectorFieldSystem` from the vector field data
2. Building an integrator by identifier (default `:sciml`)
3. Routing options through the integrator's CTSolvers strategy
4. Combining them into a callable `Flow`

# Arguments
- `data::Data.VectorField`: The vector field defining the system dynamics.
- `id::Symbol`: The integrator identifier (default `:sciml`).
- `opts...`: Keyword options passed to the integrator's strategy.

# Returns
- `Flows.Flow`: The complete flow ready for integration.

# Example
\`\`\`julia-repl
julia> using CTFlows.Pipelines, CTFlows.Data

julia> vf = Data.VectorField((t, x, v) -> x, Common.Autonomous(), Common.Fixed())
VectorField(...)

julia> flow = Pipelines.Flow(vf, :sciml; reltol=1e-8)
Flow(system=..., integrator=...)

julia> sol = flow(0.0, [1.0, 0.0], 1.0)
...
\`\`\`

See also: [`Flows.Flow`](@ref), [`build_system`](@ref), [`build_flow`](@ref), [`build_integrator`](@ref).
"""
function Flows.Flow(data::Data.VectorField, id::Symbol=:sciml; opts...)
    system = build_system(data)
    integrator = build_integrator(id; opts...)
    return build_flow(system, integrator)
end
