"""
$(TYPEDSIGNATURES)

Build a `VectorFieldSystem` from a `VectorField`.

Constructs a concrete system that wraps the vector field and pre-computes its
right-hand side function for integration. The resulting system is ready for use
with flow integration pipelines.

# Arguments
- `vf::Data.VectorField`: The vector field to wrap into a system.

# Returns
- `VectorFieldSystem`: A concrete system wrapping the vector field with a pre-computed RHS function.

# Example
\`\`\`julia-repl
julia> using CTFlows.Systems, CTFlows.Common

julia> vf = VectorField(x -> -x; autonomous=true, variable=false)
VectorField
  time_dependence: Autonomous
  variable_dependence: Fixed
  function: var"#1"

julia> sys = build_system(vf)
VectorFieldSystem
  time_dependence: Autonomous
  variable_dependence: Fixed
  vector_field: VectorField{var"#1", Autonomous, Fixed}
\`\`\`

See also: [`CTFlows.Data.VectorField`](@ref), [`CTFlows.Systems.VectorFieldSystem`](@ref).
"""
function build_system(vf::Data.VectorField)
    return VectorFieldSystem(vf)
end

"""
$(TYPEDSIGNATURES)

Build a `HamiltonianVectorFieldSystem` from a `HamiltonianVectorField`.

Constructs a concrete Hamiltonian system that wraps the Hamiltonian vector field with
a pre-computed right-hand side function for integration. The state dimension can be
specified for type stability and performance, or left as `nothing` to be inferred at runtime.

# Arguments
- `hvf::Data.HamiltonianVectorField`: The Hamiltonian vector field to wrap into a system.
- `state_dimension::Union{Int, Nothing}`: The state dimension (number of state variables, not including costates). Defaults to `nothing`.

# Returns
- `HamiltonianVectorFieldSystem`: A concrete Hamiltonian system.

# Example
```julia-repl
julia> using CTFlows.Systems, CTFlows.Common

julia> hvf = HamiltonianVectorField((x, p) -> (x, -p); autonomous=true, variable=false)
HamiltonianVectorField
  time_dependence: Autonomous
  variable_dependence: Fixed
  function: var"#1"

julia> sys = build_system(hvf)
HamiltonianVectorFieldSystem
  time_dependence: Autonomous
  variable_dependence: Fixed
  state_dimension: unknown
  hamiltonian_vector_field: HamiltonianVectorField{var"#1", Autonomous, Fixed}

julia> sys = build_system(hvf; state_dimension=3)
HamiltonianVectorFieldSystem
  time_dependence: Autonomous
  variable_dependence: Fixed
  state_dimension: 3
  hamiltonian_vector_field: HamiltonianVectorField{var"#1", Autonomous, Fixed}
```

See also: [`CTFlows.Data.HamiltonianVectorField`](@ref), [`CTFlows.Systems.HamiltonianVectorFieldSystem`](@ref).
"""
function build_system(hvf::Data.HamiltonianVectorField; state_dimension::Union{Int, Nothing}=Common.__state_dimension())
    return HamiltonianVectorFieldSystem(hvf; state_dimension=state_dimension)
end

