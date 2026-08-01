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
julia> using CTFlows: Systems

julia> vf = VectorField(x -> -x; autonomous=true, variable=false)
VectorField
  time_dependence: Autonomous
  variable_dependence: Fixed
  function: var"#1"

julia> sys = Systems.build_system(vf)
VectorFieldSystem
  time_dependence: Autonomous
  variable_dependence: Fixed
  vector_field: VectorField{var"#1", Autonomous, Fixed}
\`\`\`

See also: [`CTBase.Data.VectorField`](@extref), [`CTFlows.Systems.VectorFieldSystem`](@extref).
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
julia> using CTFlows: Systems

julia> hvf = HamiltonianVectorField((x, p) -> (x, -p); autonomous=true, variable=false)
HamiltonianVectorField
  time_dependence: Autonomous
  variable_dependence: Fixed
  function: var"#1"

julia> sys = Systems.build_system(hvf)
HamiltonianVectorFieldSystem
  time_dependence: Autonomous
  variable_dependence: Fixed
  hamiltonian_vector_field: HamiltonianVectorField{var"#1", Autonomous, Fixed}
```

See also: [`CTBase.Data.HamiltonianVectorField`](@extref), [`CTFlows.Systems.HamiltonianVectorFieldSystem`](@extref).
"""
function build_system(hvf::Data.AbstractHamiltonianVectorField)
    return HamiltonianVectorFieldSystem(hvf)
end

"""
$(TYPEDSIGNATURES)

Build a [`CTFlows.Systems.HamiltonianSystem`](@extref) from a scalar `Hamiltonian` function with automatic differentiation.

Constructs a concrete Hamiltonian system that wraps the scalar Hamiltonian function with an AD backend.
RHS closures are built lazily based on actual initial condition types during flow integration.

# Arguments
- `h::Data.AbstractHamiltonian`: The scalar Hamiltonian function to wrap into a system.
- `backend::Differentiation.AbstractADBackend`: The automatic differentiation backend (e.g., `AutoForwardDiff`, `AutoZygote`).

# Returns
- `HamiltonianSystem`: A concrete Hamiltonian system with automatic differentiation support.

# Example
\`\`\`julia-repl
julia> using CTFlows: Systems

julia> using CTBase: Data

julia> h = Data.Hamiltonian((t, x, p, v) -> 0.5 * sum(x.^2) + sum(p.^2); autonomous=true, variable=false)
Hamiltonian{var"#1", Autonomous, Fixed}

julia> sys = Systems.build_system(h, AutoForwardDiff())
HamiltonianSystem
  time_dependence: Autonomous
  variable_dependence: Fixed
  hamiltonian: Hamiltonian{var"#1", Autonomous, Fixed}
  backend: AutoForwardDiff()
\`\`\`

# Notes
- The AD backend is used to compute Hamiltonian gradients `∂H/∂x` and `∂H/∂p` automatically during integration.
- This overload is for scalar Hamiltonian functions where gradients are computed via AD. For explicit vector fields, use [`CTFlows.Systems.HamiltonianVectorFieldSystem`](@extref) instead.

See also: [`CTBase.Data.Hamiltonian`](@extref), [`CTFlows.Systems.HamiltonianSystem`](@extref), [`CTFlows.Systems.HamiltonianVectorFieldSystem`](@extref), [`CTBase.Differentiation.AbstractADBackend`](@extref).
"""
function build_system(
    h::Data.AbstractHamiltonian, backend::Differentiation.AbstractADBackend
)
    return HamiltonianSystem(h, backend)
end

"""
$(TYPEDSIGNATURES)

Build a [`CTFlows.Systems.PseudoHamiltonianSystem`](@extref) from a pseudo-Hamiltonian
`H̃(t,x,p,u,v)`, a dynamic closed-loop control law `u(t,x,p,v)`, and an AD backend.

The resulting system integrates `ẋ = ∂H̃/∂p`, `ṗ = -∂H̃/∂x` with the control held fixed
at the feedback value `u = u(t,x,p,v)` during differentiation (the `:partial` mode).

# Arguments
- `h̃::Data.PseudoHamiltonian`: the pseudo-Hamiltonian.
- `law::Data.ControlLaw`: the control law; must carry `DynClosedLoopFeedback`.
- `backend::Differentiation.AbstractADBackend`: the AD backend.

See also: [`CTFlows.Systems.PseudoHamiltonianSystem`](@extref),
[`CTBase.Data.PseudoHamiltonian`](@extref), [`CTBase.Data.ComposedHamiltonian`](@extref).
"""
function build_system(
    h̃::Data.PseudoHamiltonian,
    law::Data.ControlLaw{<:Function,Traits.DynClosedLoopFeedback},
    backend::Differentiation.AbstractADBackend,
)
    return PseudoHamiltonianSystem(h̃, law, backend)
end

"""
$(TYPEDSIGNATURES)

Build a [`CTFlows.Systems.PseudoHamiltonianVectorFieldSystem`](@extref) from a
pseudo-Hamiltonian vector field `h̃vf(t,x,p,u,v) = (ẋ,ṗ)` (already differentiated by
the user, no AD) and a dynamic closed-loop control law `u(t,x,p,v)`.

Unlike [`CTFlows.Systems.build_system(h̃::CTBase.Data.PseudoHamiltonian, law::CTBase.Data.ControlLaw, backend::CTBase.Differentiation.AbstractADBackend)`](@extref),
no AD backend is needed: `h̃vf` already returns the derivatives directly, and the
feedback law is evaluated once per step to produce the control passed to `h̃vf`.

# Arguments
- `h̃vf::Data.AbstractPseudoHamiltonianVectorField`: the pseudo-Hamiltonian vector field.
- `law::Data.ControlLaw`: the control law; must carry `DynClosedLoopFeedback`.

See also: [`CTFlows.Systems.PseudoHamiltonianVectorFieldSystem`](@extref),
[`CTBase.Data.PseudoHamiltonianVectorField`](@extref).
"""
function build_system(
    h̃vf::Data.AbstractPseudoHamiltonianVectorField,
    law::Data.ControlLaw{<:Function,Traits.DynClosedLoopFeedback},
)
    return PseudoHamiltonianVectorFieldSystem(h̃vf, law)
end

"""
$(TYPEDSIGNATURES)

Build a [`CTFlows.Systems.ConstrainedPseudoHamiltonianSystem`](@extref) from a
pseudo-Hamiltonian `H̃(t,x,p,u,v)`, a dynamic closed-loop control law `u(t,x,p,v)`, a
path constraint `g(t,x,u,v)`, a multiplier `μ(t,x,p,v)`, and an AD backend.

The resulting system integrates the constrained Hamiltonian `H̃ + μ·g` in the `:partial`
mode: both the control `u = u(t,x,p,v)` and the multiplier value `μ = μ(t,x,p,v)` are
held fixed during differentiation (`g` is differentiated, `μ` is not).

# Arguments
- `h̃::Data.PseudoHamiltonian`: the base pseudo-Hamiltonian.
- `law::Data.ControlLaw`: the control law; must carry `DynClosedLoopFeedback`.
- `g`: the path constraint (uniform call `g(t,x,u,v)`), e.g. a `CTBase.Data.PathConstraint`.
- `μ`: the multiplier (uniform call `μ(t,x,p,v)`), e.g. a `CTBase.Data.Multiplier`.
- `backend::Differentiation.AbstractADBackend`: the AD backend.

See also: [`CTFlows.Systems.ConstrainedPseudoHamiltonianSystem`](@extref),
[`CTFlows.Systems.PseudoHamiltonianSystem`](@extref).
"""
function build_system(
    h̃::Data.PseudoHamiltonian,
    law::Data.ControlLaw{<:Function,Traits.DynClosedLoopFeedback},
    g,
    μ,
    backend::Differentiation.AbstractADBackend,
)
    return ConstrainedPseudoHamiltonianSystem(h̃, law, g, μ, backend)
end
