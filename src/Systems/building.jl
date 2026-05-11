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

Build a `HamiltonianVectorFieldSystem` from a `HamiltonianVectorField` without known state dimension.

Constructs a concrete Hamiltonian system that wraps the Hamiltonian vector field with
a pre-computed right-hand side function for integration. The state dimension is not
specified and will be inferred at runtime.

# Arguments
- `hvf::Data.HamiltonianVectorField`: The Hamiltonian vector field to wrap into a system.

# Returns
- `HamiltonianVectorFieldSystem`: A concrete Hamiltonian system with unknown dimension.

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
  n_state: unknown
  hamiltonian_vector_field: HamiltonianVectorField{var"#1", Autonomous, Fixed}
```

See also: [`CTFlows.Data.HamiltonianVectorField`](@ref), [`CTFlows.Systems.HamiltonianVectorFieldSystem`](@ref).
"""
function build_system(hvf::Data.HamiltonianVectorField)
    return HamiltonianVectorFieldSystem(hvf)
end

"""
$(TYPEDSIGNATURES)

Build a `HamiltonianVectorFieldSystem` from a `HamiltonianVectorField` with known state dimension.

Constructs a concrete Hamiltonian system that wraps the Hamiltonian vector field with
a pre-computed right-hand side function for integration. The state dimension `n_state`
is stored as a type parameter for compile-time validation and performance.

# Arguments
- `hvf::Data.HamiltonianVectorField`: The Hamiltonian vector field to wrap into a system.
- `n_state::Int`: The state dimension (number of state variables, not including costates).

# Returns
- `HamiltonianVectorFieldSystem`: A concrete Hamiltonian system with known dimension.

# Example
```julia-repl
julia> using CTFlows.Systems, CTFlows.Common

julia> hvf = HamiltonianVectorField((x, p) -> (x, -p); autonomous=true, variable=false)
HamiltonianVectorField
  time_dependence: Autonomous
  variable_dependence: Fixed
  function: var"#1"

julia> sys = build_system(hvf, 3)
HamiltonianVectorFieldSystem
  time_dependence: Autonomous
  variable_dependence: Fixed
  n_state: 3
  hamiltonian_vector_field: HamiltonianVectorField{var"#1", Autonomous, Fixed}
```

See also: [`CTFlows.Data.HamiltonianVectorField`](@ref), [`CTFlows.Systems.HamiltonianVectorFieldSystem`](@ref).
"""
function build_system(hvf::Data.HamiltonianVectorField, n_state::Int)
    return HamiltonianVectorFieldSystem(hvf, n_state)
end
