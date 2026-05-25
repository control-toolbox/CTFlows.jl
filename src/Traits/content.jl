"""
$(TYPEDEF)

Abstract base type for content traits (State vs Hamiltonian).

Content traits encode the content type in configuration types, distinguishing
between state-only configurations (no costate) and Hamiltonian configurations
(state + costate).

# Example
\`\`\`julia-repl
julia> using CTFlows.Traits

julia> StateTrait <: Traits.AbstractContentTrait
true

julia> HamiltonianTrait <: Traits.AbstractContentTrait
true

julia> # Used in configuration type parameters:
julia> StatePointConfig <: CTFlows.Configs.AbstractConfig{<:Any, <:Traits.AbstractModeTrait, StateTrait}
true
\`\`\`

# Notes
- Content traits are used as the third type parameter in `AbstractConfigWithMaC`
- State trait indicates configurations with only state variables (no costate)
- Hamiltonian trait indicates configurations with both state and costate variables

See also: [`CTFlows.Traits.StateTrait`](@ref), [`CTFlows.Traits.HamiltonianTrait`](@ref), [`CTFlows.Configs.AbstractConfig`](@ref).
"""
abstract type AbstractContentTrait <: AbstractTrait end

"""
$(TYPEDEF)

Trait for state content (no costate).

Used as a type parameter in `AbstractConfig` to indicate state-only configurations,
which contain only state variables without associated costate variables.

# Example
\`\`\`julia-repl
julia> using CTFlows.Traits

julia> st = StateTrait()
StateTrait()

julia> st isa Traits.AbstractContentTrait
true

julia> # Used in state-only configurations:
julia> StatePointConfig <: CTFlows.Configs.AbstractConfig{<:Any, <:Traits.AbstractModeTrait, StateTrait}
true
\`\`\`

# Notes
- State configurations store only `x0` (initial state)
- The `initial_costate` accessor throws a `PreconditionError` for state configurations
- This mode is suitable for standard ODE integration without adjoint variables

See also: [`CTFlows.Traits.HamiltonianTrait`](@ref), [`CTFlows.Traits.AbstractContentTrait`](@ref), [`CTFlows.Configs.StatePointConfig`](@ref).
"""
struct StateTrait <: AbstractContentTrait end

"""
$(TYPEDEF)

Trait for Hamiltonian content (state + costate).

Used as a type parameter in `AbstractConfig` to indicate Hamiltonian configurations,
which contain both state variables and associated costate (adjoint) variables.

# Example
\`\`\`julia-repl
julia> using CTFlows.Traits

julia> ham = HamiltonianTrait()
HamiltonianTrait()

julia> ham isa Traits.AbstractContentTrait
true

julia> # Used in Hamiltonian configurations:
julia> HamiltonianPointConfig <: CTFlows.Configs.AbstractConfig{<:Any, <:Traits.AbstractModeTrait, HamiltonianTrait}
true
\`\`\`

# Notes
- Hamiltonian configurations store both `x0` (initial state) and `p0` (initial costate)
- The `initial_condition` accessor returns `vcat(x0, p0)` for Hamiltonian configurations
- This mode is suitable for optimal control problems with Pontryagin's maximum principle

See also: [`CTFlows.Traits.StateTrait`](@ref), [`CTFlows.Traits.AbstractContentTrait`](@ref), [`CTFlows.Configs.HamiltonianPointConfig`](@ref).
"""
struct HamiltonianTrait <: AbstractContentTrait end

"""
$(TYPEDEF)

Trait marker for augmented Hamiltonian systems, where the Hamiltonian includes an augmented variable (e.g., a parameter or control variable) in addition to state and costate variables.

# Notes
- Used in conjunction with [`CTFlows.Configs.AbstractAugmentedHamiltonianConfig`](@ref) to specify that a configuration is for an augmented Hamiltonian system.
- Subtypes [`CTFlows.Traits.AbstractContentTrait`](@ref).
- Used to distinguish augmented Hamiltonian systems from standard Hamiltonian systems in trait-based dispatch.

See also: [`CTFlows.Traits.HamiltonianTrait`](@ref), [`CTFlows.Configs.AbstractAugmentedHamiltonianConfig`](@ref), [`CTFlows.Traits.AbstractContentTrait`](@ref).
"""
struct AugmentedHamiltonianTrait <: AbstractContentTrait end
