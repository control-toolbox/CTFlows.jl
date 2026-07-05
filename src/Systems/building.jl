"""
$(TYPEDSIGNATURES)

Build a `VectorFieldSystem` from a `VectorField`.

Constructs a concrete system that wraps the vector field and pre-computes its
right-hand side function for integration. The resulting system is ready for use
with flow integration pipelines.

# Arguments
- `vf::Data.AbstractVectorField`: The vector field to wrap into a system.

# Returns
- `VectorFieldSystem`: A concrete system wrapping the vector field with a pre-computed RHS function.

# Example
\`\`\`julia-repl
julia> using CTFlows.Systems

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

See also: [`CTBase.Data.VectorField`](@extref), [`CTFlows.Systems.VectorFieldSystem`](@ref).
"""
function build_system(vf::Data.AbstractVectorField)
    return VectorFieldSystem(vf)
end

"""
$(TYPEDSIGNATURES)

Build a `HamiltonianVectorFieldSystem` from a `HamiltonianVectorField`.

Constructs a concrete Hamiltonian system that wraps the Hamiltonian vector field.
RHS closures are built lazily based on actual initial condition types during flow integration.

# Arguments
- `hvf::Data.AbstractHamiltonianVectorField`: The Hamiltonian vector field to wrap into a system.

# Returns
- `HamiltonianVectorFieldSystem`: A concrete Hamiltonian system.

# Example
```julia-repl
julia> using CTFlows.Systems

julia> hvf = HamiltonianVectorField((x, p) -> (x, -p); autonomous=true, variable=false)
HamiltonianVectorField
  time_dependence: Autonomous
  variable_dependence: Fixed
  function: var"#1"

julia> sys = build_system(hvf)
HamiltonianVectorFieldSystem
  time_dependence: Autonomous
  variable_dependence: Fixed
  hamiltonian_vector_field: HamiltonianVectorField{var"#1", Autonomous, Fixed}
```

See also: [`CTBase.Data.HamiltonianVectorField`](@extref), [`CTFlows.Systems.HamiltonianVectorFieldSystem`](@ref).
"""
function build_system(hvf::Data.AbstractHamiltonianVectorField)
    return HamiltonianVectorFieldSystem(hvf)
end

"""
$(TYPEDSIGNATURES)

Build a [`CTFlows.Systems.HamiltonianSystem`](@ref) from a scalar `Hamiltonian` function with automatic differentiation.

Constructs a concrete Hamiltonian system that wraps the scalar Hamiltonian function with an AD backend.
RHS closures are built lazily based on actual initial condition types during flow integration.

# Arguments
- `h::Data.AbstractHamiltonian`: The scalar Hamiltonian function to wrap into a system.
- `backend::Differentiation.AbstractADBackend`: The automatic differentiation backend (e.g., `AutoForwardDiff`, `AutoZygote`).

# Returns
- `HamiltonianSystem`: A concrete Hamiltonian system with automatic differentiation support.

# Example
\`\`\`julia-repl
julia> using CTFlows.Systems, CTBase.Data

julia> h = Hamiltonian((t, x, p, v) -> 0.5 * sum(x.^2) + sum(p.^2); autonomous=true, variable=false)
Hamiltonian{var"#1", Autonomous, Fixed}

julia> sys = build_system(h, AutoForwardDiff())
HamiltonianSystem
  time_dependence: Autonomous
  variable_dependence: Fixed
  hamiltonian: Hamiltonian{var"#1", Autonomous, Fixed}
  backend: AutoForwardDiff()
\`\`\`

# Notes
- The AD backend is used to compute Hamiltonian gradients `∂H/∂x` and `∂H/∂p` automatically during integration.
- This overload is for scalar Hamiltonian functions where gradients are computed via AD. For explicit vector fields, use [`CTFlows.Systems.HamiltonianVectorFieldSystem`](@ref) instead.

See also: [`CTBase.Data.Hamiltonian`](@extref), [`CTFlows.Systems.HamiltonianSystem`](@ref), [`CTFlows.Systems.HamiltonianVectorFieldSystem`](@ref), [`CTBase.Differentiation.AbstractADBackend`](@extref).
"""
function build_system(
    h::Data.AbstractHamiltonian,
    backend::Differentiation.AbstractADBackend,
)
    return HamiltonianSystem(h, backend)
end

"""
$(TYPEDSIGNATURES)

Build a [`CTFlows.Systems.PseudoHamiltonianSystem`](@ref) from a pseudo-Hamiltonian
`H̃(t,x,p,u,v)`, a dynamic closed-loop control law `u(t,x,p,v)`, and an AD backend.

The resulting system integrates `ẋ = ∂H̃/∂p`, `ṗ = -∂H̃/∂x` with the control held fixed
at the feedback value `u = u(t,x,p,v)` during differentiation (the `:partial` mode).

# Arguments
- `h̃::Data.PseudoHamiltonian`: the pseudo-Hamiltonian.
- `law::Data.ControlLaw`: the control law; must carry `DynClosedLoopFeedback`.
- `backend::Differentiation.AbstractADBackend`: the AD backend.

See also: [`CTFlows.Systems.PseudoHamiltonianSystem`](@ref),
[`CTBase.Data.PseudoHamiltonian`](@extref), [`CTBase.Data.ComposedHamiltonian`](@extref).
"""
function build_system(
    h̃::Data.PseudoHamiltonian,
    law::Data.ControlLaw{<:Function,Traits.DynClosedLoopFeedback},
    backend::Differentiation.AbstractADBackend,
)
    return PseudoHamiltonianSystem(h̃, law, backend)
end
