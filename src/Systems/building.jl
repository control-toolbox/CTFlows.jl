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

"""
$(TYPEDSIGNATURES)

Build a [`CTFlows.Systems.HamiltonianSystem`](@ref) from a scalar `Hamiltonian` function with automatic differentiation.

Constructs a concrete Hamiltonian system that wraps the scalar Hamiltonian function with an AD backend to compute gradients on-the-fly. The resulting system is ready for use with flow integration pipelines.

# Arguments
- `h::Data.Hamiltonian`: The scalar Hamiltonian function to wrap into a system.
- `backend::Differentiation.AbstractADBackend`: The automatic differentiation backend (e.g., `AutoForwardDiff`, `AutoZygote`).
- `state_dimension::Union{Int, Nothing}`: The state dimension (number of state variables, not including costates). Defaults to `nothing` (inferred at runtime).

# Returns
- `HamiltonianSystem`: A concrete Hamiltonian system with automatic differentiation support.

# Example
\`\`\`julia-repl
julia> using CTFlows.Systems, CTFlows.Common, CTFlows.Data

julia> h = Hamiltonian((t, x, p, v) -> 0.5 * sum(x.^2) + sum(p.^2); autonomous=true, variable=false)
Hamiltonian{var"#1", Autonomous, Fixed}

julia> sys = build_system(h, AutoForwardDiff())
HamiltonianSystem
  time_dependence: Autonomous
  variable_dependence: Fixed
  state_dimension: unknown
  hamiltonian: Hamiltonian{var"#1", Autonomous, Fixed}
  backend: AutoForwardDiff()

julia> sys = build_system(h, AutoForwardDiff(); state_dimension=3)
HamiltonianSystem
  time_dependence: Autonomous
  variable_dependence: Fixed
  state_dimension: 3
  hamiltonian: Hamiltonian{var"#1", Autonomous, Fixed}
  backend: AutoForwardDiff()
\`\`\`

# Notes
- The AD backend is used to compute Hamiltonian gradients `∂H/∂x` and `∂H/∂p` automatically during integration.
- Specifying `state_dimension` improves type stability and performance by closing dimensions in the pre-computed RHS closures.
- This overload is for scalar Hamiltonian functions where gradients are computed via AD. For explicit vector fields, use [`CTFlows.Systems.HamiltonianVectorFieldSystem`](@ref) instead.

See also: [`CTFlows.Data.Hamiltonian`](@ref), [`CTFlows.Systems.HamiltonianSystem`](@ref), [`CTFlows.Systems.HamiltonianVectorFieldSystem`](@ref), [`CTFlows.Differentiation.AbstractADBackend`](@ref).
"""
function build_system(h::Data.Hamiltonian, backend::Differentiation.AbstractADBackend;
                      state_dimension::Union{Int,Nothing}=Common.__state_dimension())
    return HamiltonianSystem(h, backend; state_dimension=state_dimension)
end

