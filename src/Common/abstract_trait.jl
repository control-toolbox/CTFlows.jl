"""
$(TYPEDEF)

Abstract base type for trait markers in CTFlows.

Traits are empty marker types used as type parameters to encode configuration
properties at compile time. Unlike tags (which mark extension implementations),
traits encode semantic properties of the configuration itself (e.g., integration
mode, content type, mutability).

# Trait Pattern

Traits are used as type parameters in abstract configuration types to enable
compile-time dispatch without runtime type checks. For example, `AbstractConfig`
uses `PointTrait` vs `TrajectoryTrait` to distinguish integration modes, and
`StateTrait` vs `HamiltonianTrait` to distinguish content types.

All concrete trait types are empty structs with no fields, making them zero-cost
at runtime.

# Interface Requirements

Concrete trait subtypes should:
- Be empty structs with no fields (pure markers)
- Subtype an intermediate abstract trait category (e.g., `AbstractModeTrait`)
- Be used as type parameters in configuration types

# Example
\`\`\`julia-repl
julia> using CTFlows.Common

julia> PointTrait <: Common.AbstractTrait
true

julia> PointTrait <: Common.AbstractModeTrait
true

julia> # Used as type parameters in configs:
julia> StatePointConfig <: Common.AbstractConfig{<:Any, PointTrait, StateTrait}
true
\`\`\`

# Notes
- Traits are distinct from tags: tags mark extension implementations (e.g., `SciMLTag`),
  while traits encode configuration semantics (e.g., `PointTrait`)
- All trait types have zero runtime overhead (empty structs)
- The trait pattern enables static dispatch on configuration properties

See also: [`CTFlows.Common.VariableDependence`](@ref), [`CTFlows.Common.AbstractModeTrait`](@ref), [`CTFlows.Common.AbstractContentTrait`](@ref), [`CTFlows.Common.AbstractMutabilityTrait`](@ref).
"""
abstract type AbstractTrait end

# =============================================================================
# Intermediate abstract tags for configuration traits
# =============================================================================

"""
$(TYPEDEF)

Abstract base type for mode traits (Point vs Trajectory).

Mode traits encode the integration mode in configuration types, distinguishing
between point-to-point integration (single endpoint evaluation) and trajectory
integration (full time evolution).

# Example
\`\`\`julia-repl
julia> using CTFlows.Common

julia> PointTrait <: Common.AbstractModeTrait
true

julia> TrajectoryTrait <: Common.AbstractModeTrait
true

julia> # Used in configuration type parameters:
julia> StatePointConfig <: Common.AbstractConfig{<:Any, PointTrait, <:Common.AbstractContentTrait}
true
\`\`\`

# Notes
- Mode traits are used as the second type parameter in `AbstractConfigWithMaC`
- Point mode indicates integration from a single initial condition to a specific final time
- Trajectory mode indicates integration over a continuous time interval

See also: [`CTFlows.Common.PointTrait`](@ref), [`CTFlows.Common.TrajectoryTrait`](@ref), [`CTFlows.Common.AbstractConfig`](@ref).
"""
abstract type AbstractModeTrait <: AbstractTrait end

"""
$(TYPEDEF)

Abstract base type for content traits (State vs Hamiltonian).

Content traits encode the content type in configuration types, distinguishing
between state-only configurations (no costate) and Hamiltonian configurations
(state + costate).

# Example
\`\`\`julia-repl
julia> using CTFlows.Common

julia> StateTrait <: Common.AbstractContentTrait
true

julia> HamiltonianTrait <: Common.AbstractContentTrait
true

julia> # Used in configuration type parameters:
julia> StatePointConfig <: Common.AbstractConfig{<:Any, <:Common.AbstractModeTrait, StateTrait}
true
\`\`\`

# Notes
- Content traits are used as the third type parameter in `AbstractConfigWithMaC`
- State trait indicates configurations with only state variables (no costate)
- Hamiltonian trait indicates configurations with both state and costate variables

See also: [`CTFlows.Common.StateTrait`](@ref), [`CTFlows.Common.HamiltonianTrait`](@ref), [`CTFlows.Common.AbstractConfig`](@ref).
"""
abstract type AbstractContentTrait <: AbstractTrait end

# =============================================================================
# Mutability traits (in-place vs out-of-place function evaluation)
# =============================================================================

"""
$(TYPEDEF)

Abstract trait for mutability characteristics of function evaluation.

Distinguishes between in-place functions (which modify a pre-allocated buffer)
and out-of-place functions (which allocate and return new results).

Subtypes must implement:
- `InPlace`: For functions that write to a mutable buffer
- `OutOfPlace`: For functions that return newly allocated results

# Example
\`\`\`julia-repl
julia> using CTFlows.Common

julia> InPlace() isa AbstractMutabilityTrait
true

julia> OutOfPlace() isa AbstractMutabilityTrait
true
\`\`\`

See also: [`CTFlows.Common.InPlace`](@ref), [`CTFlows.Common.OutOfPlace`](@ref).
"""
abstract type AbstractMutabilityTrait <: AbstractTrait end

"""
$(TYPEDEF)

Trait for in-place function evaluation.

Indicates that a function modifies a pre-allocated buffer passed as an argument,
rather than allocating and returning a new result. This pattern is used for
performance-critical code where avoiding allocations is important.

# Example
\`\`\`julia-repl
julia> using CTFlows.Common

julia> ip = InPlace()
InPlace()

julia> ip isa AbstractMutabilityTrait
true
\`\`\`

See also: [`CTFlows.Common.AbstractMutabilityTrait`](@ref), [`CTFlows.Common.OutOfPlace`](@ref).
"""
struct InPlace <: AbstractMutabilityTrait end

"""
$(TYPEDEF)

Trait for out-of-place function evaluation.

Indicates that a function allocates and returns a new result, rather than
modifying a pre-allocated buffer. This is the default pattern in Julia and
is suitable for most use cases.

# Example
\`\`\`julia-repl
julia> using CTFlows.Common

julia> oop = OutOfPlace()
OutOfPlace()

julia> oop isa AbstractMutabilityTrait
true
\`\`\`

See also: [`CTFlows.Common.AbstractMutabilityTrait`](@ref), [`CTFlows.Common.InPlace`](@ref).
"""
struct OutOfPlace <: AbstractMutabilityTrait end

# =============================================================================
# Concrete mode tags
# =============================================================================

"""
$(TYPEDEF)

Trait for point integration mode (single endpoint evaluation).

Used as a type parameter in `AbstractConfig` to indicate point integration,
which computes the solution at a specific final time from a single initial condition.

# Example
\`\`\`julia-repl
julia> using CTFlows.Common

julia> pt = PointTrait()
PointTrait()

julia> pt isa Common.AbstractModeTrait
true

julia> # Used in point-to-point configurations:
julia> StatePointConfig <: Common.AbstractConfig{<:Any, PointTrait, <:Common.AbstractContentTrait}
true
\`\`\`

# Notes
- Point mode configurations store `t0` and `tf` as separate fields
- This mode is suitable for boundary value problems and shooting methods
- The `tspan` accessor returns `(c.t0, c.tf)` for point configurations

See also: [`CTFlows.Common.TrajectoryTrait`](@ref), [`CTFlows.Common.AbstractModeTrait`](@ref), [`CTFlows.Common.StatePointConfig`](@ref).
"""
struct PointTrait <: AbstractModeTrait end

"""
$(TYPEDEF)

Trait for trajectory integration mode (full time evolution).

Used as a type parameter in `AbstractConfig` to indicate trajectory integration,
which computes the full solution trajectory over a continuous time interval.

# Example
\`\`\`julia-repl
julia> using CTFlows.Common

julia> traj = TrajectoryTrait()
TrajectoryTrait()

julia> traj isa Common.AbstractModeTrait
true

julia> # Used in trajectory configurations:
julia> StateTrajectoryConfig <: Common.AbstractConfig{<:Any, TrajectoryTrait, <:Common.AbstractContentTrait}
true
\`\`\`

# Notes
- Trajectory mode configurations store `tspan` as a tuple field
- This mode is suitable for generating full time evolution and visualization
- The `tspan` accessor returns `c.tspan` directly for trajectory configurations

See also: [`CTFlows.Common.PointTrait`](@ref), [`CTFlows.Common.AbstractModeTrait`](@ref), [`CTFlows.Common.StateTrajectoryConfig`](@ref).
"""
struct TrajectoryTrait <: AbstractModeTrait end

# =============================================================================
# Concrete content tags
# =============================================================================

"""
$(TYPEDEF)

Trait for state content (no costate).

Used as a type parameter in `AbstractConfig` to indicate state-only configurations,
which contain only state variables without associated costate variables.

# Example
\`\`\`julia-repl
julia> using CTFlows.Common

julia> st = StateTrait()
StateTrait()

julia> st isa Common.AbstractContentTrait
true

julia> # Used in state-only configurations:
julia> StatePointConfig <: Common.AbstractConfig{<:Any, <:Common.AbstractModeTrait, StateTrait}
true
\`\`\`

# Notes
- State configurations store only `x0` (initial state)
- The `initial_costate` accessor throws a `PreconditionError` for state configurations
- This mode is suitable for standard ODE integration without adjoint variables

See also: [`CTFlows.Common.HamiltonianTrait`](@ref), [`CTFlows.Common.AbstractContentTrait`](@ref), [`CTFlows.Common.StatePointConfig`](@ref).
"""
struct StateTrait <: AbstractContentTrait end

"""
$(TYPEDEF)

Trait for Hamiltonian content (state + costate).

Used as a type parameter in `AbstractConfig` to indicate Hamiltonian configurations,
which contain both state variables and associated costate (adjoint) variables.

# Example
\`\`\`julia-repl
julia> using CTFlows.Common

julia> ham = HamiltonianTrait()
HamiltonianTrait()

julia> ham isa Common.AbstractContentTrait
true

julia> # Used in Hamiltonian configurations:
julia> HamiltonianPointConfig <: Common.AbstractConfig{<:Any, <:Common.AbstractModeTrait, HamiltonianTrait}
true
\`\`\`

# Notes
- Hamiltonian configurations store both `x0` (initial state) and `p0` (initial costate)
- The `initial_condition` accessor returns `vcat(x0, p0)` for Hamiltonian configurations
- This mode is suitable for optimal control problems with Pontryagin's maximum principle

See also: [`CTFlows.Common.StateTrait`](@ref), [`CTFlows.Common.AbstractContentTrait`](@ref), [`CTFlows.Common.HamiltonianPointConfig`](@ref).
"""
struct HamiltonianTrait <: AbstractContentTrait end

"""
$(TYPEDEF)

Trait marker for augmented Hamiltonian systems, where the Hamiltonian includes an augmented variable (e.g., a parameter or control variable) in addition to state and costate variables.

# Notes
- Used in conjunction with [`CTFlows.Common.AbstractAugmentedHamiltonianConfig`](@ref) to specify that a configuration is for an augmented Hamiltonian system.
- Subtypes [`CTFlows.Common.AbstractContentTrait`](@ref).
- Used to distinguish augmented Hamiltonian systems from standard Hamiltonian systems in trait-based dispatch.

See also: [`CTFlows.Common.HamiltonianTrait`](@ref), [`CTFlows.Common.AbstractAugmentedHamiltonianConfig`](@ref), [`CTFlows.Common.AbstractContentTrait`](@ref).
"""
struct AugmentedHamiltonianTrait <: AbstractContentTrait end

# =============================================================================
# AD trait family (automatic differentiation capability)
# =============================================================================

"""
$(TYPEDEF)

Abstract base type for automatic differentiation capability traits.

AD traits encode whether a system carries a scalar Hamiltonian with an AD backend
(`WithAD`) or a pre-computed Hamiltonian vector field (`WithoutAD`). This distinction
enables compile-time dispatch for cache preparation and gradient computation.

# Example
\`\`\`julia-repl
julia> using CTFlows.Common

julia> WithAD() isa Common.AbstractADTrait
true

julia> WithoutAD() isa Common.AbstractADTrait
true
\`\`\`

# Notes
- AD traits are used as type parameters in system types to enable static dispatch
- `WithAD` indicates the system carries a `Hamiltonian` and an AD backend
- `WithoutAD` indicates the system carries a `HamiltonianVectorField` directly

See also: [`CTFlows.Common.WithAD`](@ref), [`CTFlows.Common.WithoutAD`](@ref), [`CTFlows.Common.AbstractCache`](@ref).
"""
abstract type AbstractADTrait <: AbstractTrait end

"""
$(TYPEDEF)

Trait for systems with automatic differentiation support.

Indicates that a system carries a scalar Hamiltonian function and an AD backend,
enabling automatic computation of the vector field via gradients. Such systems
require cache preparation before ODE integration.

# Example
\`\`\`julia-repl
julia> using CTFlows.Common

julia> with = WithAD()
WithAD()

julia> with isa Common.AbstractADTrait
true
\`\`\`

# Notes
- Used as a type parameter in `AbstractHamiltonianSystem` to enable AD-based gradient computation
- Systems with `WithAD` require cache preparation via the backend's `prepare_cache` method
- The cache is passed through `ODEParameters` during integration

See also: [`CTFlows.Common.AbstractADTrait`](@ref), [`CTFlows.Common.WithoutAD`](@ref), [`CTFlows.Common.AbstractCache`](@ref).
"""
struct WithAD <: AbstractADTrait end  # system carries H + AD backend

"""
$(TYPEDEF)

Trait for systems without automatic differentiation support.

Indicates that a system carries a pre-computed Hamiltonian vector field directly,
without requiring AD or cache preparation. This is the traditional mode where the
user provides the vector field manually.

# Example
\`\`\`julia-repl
julia> using CTFlows.Common

julia> without = WithoutAD()
WithoutAD()

julia> without isa Common.AbstractADTrait
true
\`\`\`

# Notes
- Used as a type parameter in `AbstractHamiltonianSystem` for vector field-based systems
- No cache preparation is required for `WithoutAD` systems
- This is the default mode for `HamiltonianVectorFieldSystem`

See also: [`CTFlows.Common.AbstractADTrait`](@ref), [`CTFlows.Common.WithAD`](@ref).
"""
struct WithoutAD <: AbstractADTrait end  # system carries HVF directly

# =============================================================================
# Common abstract cache (for runtime AD preparation results)
# =============================================================================

"""
$(TYPEDEF)

Abstract base type for automatic differentiation caches.

Caches store pre-allocated buffers and prepared differentiation plans to avoid
repeated allocation during ODE integration. Concrete cache types are extension-specific
(e.g., `DifferentiationInterfaceCache` from the `CTFlowsDifferentiationInterface` extension).

# Example
\`\`\`julia-repl
julia> using CTFlows.Common

julia> isabstracttype(Common.AbstractCache)
true
\`\`\`

# Notes
- Caches are passed through `ODEParameters` during ODE integration
- The cache field defaults to `nothing` for systems that don't require AD
- Concrete cache types are defined in extensions that provide AD backends
- The RHS closure reads `cache(p)` to access the prepared cache

See also: [`CTFlows.Common.ODEParameters`](@ref), [`CTFlows.Common.AbstractADTrait`](@ref).
"""
abstract type AbstractCache end
