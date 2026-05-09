"""
    CTFlowsSciML

Package extension providing the SciML implementation for `SciML`
and `ode_problem` for `VectorFieldSystem`. Activated automatically when
`DiffEqBase` and `SciMLBase` are loaded together with `CTFlows`.
"""
module CTFlowsSciML

import DocStringExtensions: TYPEDEF, TYPEDSIGNATURES
import CTBase.Exceptions
import CTSolvers.Strategies
import CTSolvers.Options

using CTFlows: CTFlows
using CTFlows.Common: Common
using CTFlows.Systems: Systems
using CTFlows.Integrators: Integrators, SciML, SciMLTag, Tsit5Tag
using CTFlows.MultiPhase: MultiPhase
using DiffEqBase: DiffEqBase
using SciMLBase: SciMLBase, ODEProblem

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

julia> CTFlowsSciML.real_norm(u_real, 0.0) ≈ CTFlowsSciML.real_norm(u_dual, 0.0)
true
```

See also: [`Common.deepvalue`](@ref), [`Common.real_norm`](@ref)
"""
Common.real_norm(u::AbstractArray, t) = DiffEqBase.ODE_DEFAULT_NORM(Common.deepvalue.(u), t)

# =============================================================================
# Strategies.metadata — option definitions for SciML
# =============================================================================

"""
$(TYPEDSIGNATURES)

Return metadata defining `SciML` options and their specifications.

The `internalnorm` option defaults to `real_norm`, which extracts the primal (Float64)
part of ForwardDiff dual numbers to ensure grid invariance (IND) when ForwardDiff is loaded.
"""
function Strategies.metadata(::Type{SciML})
    return Strategies.StrategyMetadata(
        Strategies.OptionDefinition(;
            name = :alg,
            type = SciMLBase.AbstractDEAlgorithm,
            default = Integrators.__default_sciml_algorithm(Integrators.Tsit5Tag),
            description = "ODE algorithm (e.g. Tsit5(), Vern6()).",
            aliases = (:algorithm, :solver),
        ),
        Strategies.OptionDefinition(;
            name = :reltol,
            type = Real,
            default = 1e-8,
            description = "Relative tolerance for the ODE solver.",
            aliases = (:rtol, :rel_tol),
            validator = x ->
                x > 0 || throw(
                    Exceptions.IncorrectArgument(
                        "Invalid reltol value";
                        got = "reltol=$x",
                        expected = "positive real number (> 0)",
                        suggestion = "Provide a positive tolerance (e.g., 1e-8, 1e-10).",
                        context = "SciML reltol validation",
                    ),
                ),
        ),
        Strategies.OptionDefinition(;
            name = :abstol,
            type = Real,
            default = 1e-8,
            description = "Absolute tolerance for the ODE solver.",
            aliases = (:atol, :abs_tol),
            validator = x ->
                x > 0 || throw(
                    Exceptions.IncorrectArgument(
                        "Invalid abstol value";
                        got = "abstol=$x",
                        expected = "positive real number (> 0)",
                        suggestion = "Provide a positive tolerance (e.g., 1e-8, 1e-10).",
                        context = "SciML abstol validation",
                    ),
                ),
        ),
        Strategies.OptionDefinition(;
            name = :maxiters,
            type = Integer,
            default = Options.NotProvided,
            description = "Maximum number of solver iterations.",
            aliases=(:max_iters, :max_iter, :maxiter, :max_iterations, :maxit),
            validator = x ->
                x > 0 || throw(
                    Exceptions.IncorrectArgument(
                        "Invalid maxiters value";
                        got = "maxiters=$x",
                        expected = "positive integer (> 0)",
                        suggestion = "Provide a positive iteration count (e.g., 10^5).",
                        context = "SciML maxiters validation",
                    ),
                ),
        ),
        Strategies.OptionDefinition(;
            name = :dt,
            type = Real,
            default = Options.NotProvided,
            description = "Fixed step size (used when adaptive=false).",
            aliases = (:dt0, :timestep),
            validator = x ->
                x > 0 || throw(
                    Exceptions.IncorrectArgument(
                        "Invalid dt value";
                        got = "dt=$x",
                        expected = "positive real number (> 0)",
                        suggestion = "Provide a positive step size (e.g., 0.01).",
                        context = "SciML dt validation",
                    ),
                ),
        ),
        Strategies.OptionDefinition(;
            name = :adaptive,
            type = Bool,
            default = Options.NotProvided,
            description = "Whether to use adaptive step-size control.",
            aliases = (:adaptive_step, :adaptive_stepping),
        ),
        Strategies.OptionDefinition(;
            name = :save_everystep,
            type = Union{Bool, Symbol},
            default = :auto,
            description = "Save the solution at every solver step. Set `true`/`false` to force, or `:auto` to infer from call pattern (false for `flow(t0, x0[, p0], tf)`, true for `flow((t0, tf), x0[, p0])`).",
        ),
        Strategies.OptionDefinition(;
            name = :saveat,
            type = Union{Real, AbstractVector},
            default = Options.NotProvided,
            description = "Times at which to save the solution (Vector or range).",
            aliases = (:save_at, :save_times),
        ),
        Strategies.OptionDefinition(;
            name = :dense,
            type = Union{Bool, Symbol},
            default = :auto,
            description = "Dense output. Set `true`/`false` to force, or `:auto` to infer from call pattern (false for `flow(t0, x0[, p0], tf)`, true for `flow((t0, tf), x0[, p0])`).",
        ),
        Strategies.OptionDefinition(;
            name = :save_idxs,
            type = AbstractVector{<:Integer},
            default = Options.NotProvided,
            description = "Indices of components to save (Vector of integers).",
            aliases = (:saveindices, :save_indices),
        ),
        Strategies.OptionDefinition(;
            name = :tstops,
            type = AbstractVector{<:Real},
            default = Options.NotProvided,
            description = "Extra times the solver must step to (for discontinuities).",
            aliases = (:t_stops, :stop_times),
        ),
        Strategies.OptionDefinition(;
            name = :d_discontinuities,
            type = AbstractVector{<:Real},
            default = Options.NotProvided,
            description = "Locations of discontinuities in low-order derivatives.",
        ),
        Strategies.OptionDefinition(;
            name = :dtmax,
            type = Real,
            default = Options.NotProvided,
            description = "Maximum step size for adaptive timestepping.",
            aliases = (:max_dt, :dt_max),
            validator = x ->
                x > 0 || throw(
                    Exceptions.IncorrectArgument(
                        "Invalid dtmax value";
                        got = "dtmax=$x",
                        expected = "positive real number (> 0)",
                        suggestion = "Provide a positive maximum step size (e.g., 0.1).",
                        context = "SciML dtmax validation",
                    ),
                ),
        ),
        Strategies.OptionDefinition(;
            name = :dtmin,
            type = Real,
            default = Options.NotProvided,
            description = "Minimum step size for adaptive timestepping.",
            aliases = (:min_dt, :dt_min),
            validator = x ->
                x > 0 || throw(
                    Exceptions.IncorrectArgument(
                        "Invalid dtmin value";
                        got = "dtmin=$x",
                        expected = "positive real number (> 0)",
                        suggestion = "Provide a positive minimum step size (e.g., 1e-6).",
                        context = "SciML dtmin validation",
                    ),
                ),
        ),
        Strategies.OptionDefinition(;
            name = :force_dtmin,
            type = Bool,
            default = Options.NotProvided,
            description = "Whether to continue forcing minimum dt usage.",
        ),
        Strategies.OptionDefinition(;
            name = :callback,
            type = Any,
            default = Options.NotProvided,
            description = "Callback function for event handling.",
            aliases = (:callbacks, :cb),
        ),
        Strategies.OptionDefinition(;
            name = :progress,
            type = Bool,
            default = Options.NotProvided,
            description = "Whether to show progress bar.",
            aliases = (:verbose,),
        ),
        Strategies.OptionDefinition(;
            name = :save_start,
            type = Union{Bool, Symbol},
            default = :auto,
            description = "Save initial condition in solution. Set `true`/`false` to force, or `:auto` to infer from call pattern (false for `flow(t0, x0[, p0], tf)`, true for `flow((t0, tf), x0[, p0])`).",
        ),
        Strategies.OptionDefinition(;
            name = :save_end,
            type = Bool,
            default = Options.NotProvided,
            description = "Whether to force saving the final timepoint.",
        ),
        Strategies.OptionDefinition(;
            name = :internalnorm,
            type = Function,
            default = Common.real_norm,
            description = "Internal norm for adaptive step-size control. " *
                          "Defaults to `real_norm`, which extracts the primal (Float64) " *
                          "part of ForwardDiff dual numbers to ensure grid invariance (IND) " *
                          "when ForwardDiff is loaded. Set to `DiffEqBase.ODE_DEFAULT_NORM` to use the SciML default.",
            aliases = (:internal_norm, :norm),
        ),
    )
end

# =============================================================================
# build_sciml_integrator — actual implementation
# =============================================================================

# =============================================================================
# Config-dependent option resolution
# =============================================================================

"""
    _AUTO_OPTION_KEYS

Tuple of option keys that support automatic resolution based on configuration type.

These options use the `:auto` sentinel value in their metadata and are resolved
dynamically during integrator construction:
- For `PointConfig`: set to `false` (only final state needed)
- For `TrajectoryConfig`: set to `true` (full trajectory storage needed)

Users can override automatic resolution by providing explicit `true`/`false` values
when constructing the integrator.
"""
const _AUTO_OPTION_KEYS = (:dense, :save_everystep, :save_start)

"""
$(TYPEDSIGNATURES)

Build a `SciML` integrator with validated options and pre-computed config-specific options.

This function constructs a SciML integrator with automatic resolution of config-dependent
options. Options in `_AUTO_OPTION_KEYS` support the `:auto` sentinel value, which is
resolved based on the configuration type used during integration:
- For `PointConfig` (e.g., `flow(t0, x0, tf)`): options set to `false` to minimize memory
  since only the final state is needed
- For `TrajectoryConfig` (e.g., `flow((t0, tf), x0)`): options set to `true` to enable
  full trajectory storage and interpolation

The resolved options are pre-computed and cached in the integrator for performance,
avoiding repeated resolution during integration.

# Arguments
- `::Type{CTFlows.Integrators.SciMLTag}`: The SciML integrator tag type.
- `mode::Symbol`: Validation mode for strategy options (`:strict` or `:permissive`).
- `kwargs...`: User-provided option values. Explicit `true`/`false` values override
  automatic `:auto` resolution.

# Returns
- `CTFlows.Integrators.SciML`: Parametric SciML integrator with cached `options_point`
  and `options_trajectory` fields.

# Notes
- The `:auto` sentinel is defined in option metadata as `Union{Bool, Symbol}` with
  default `:auto`.
- Pre-computation happens at construction time, not during integration.
- Config-specific options are returned by `Integrators.build_options` based on dispatch
  on the configuration type.

See also: [`CTFlows.Integrators.build_options`](@ref), [`CTFlows.Integrators.SciML`](@ref),
[`CTFlows.Common.PointConfig`](@ref), [`CTFlows.Common.TrajectoryConfig`](@ref).
"""
function CTFlows.Integrators.build_sciml_integrator(
    ::Type{CTFlows.Integrators.SciMLTag}; mode::Symbol = :strict, kwargs...,
)
    opts = Strategies.build_strategy_options(SciML; mode = mode, kwargs...)
    raw = Strategies.options_dict(opts)
    
    # Check if algorithm is missing and raise PreconditionError
    alg_val = raw[:alg]
    if alg_val === missing
        throw(
            Exceptions.PreconditionError(
                "No ODE algorithm specified and OrdinaryDiffEqTsit5 is not loaded";
                reason = "alg is missing",
                suggestion = "Load OrdinaryDiffEqTsit5: using OrdinaryDiffEqTsit5\n" *
                            "Or specify an algorithm explicitly: SciML(alg=Vern6())\n" *
                            "Note: when specifying an algorithm, also load its package (e.g., using OrdinaryDiffEqVerner for Vern6)",
                context = "SciML integrator construction",
            ),
        )
    end
    
    # Pre-compute options for PointConfig
    options_point = copy(raw)
    for key in _AUTO_OPTION_KEYS
        get(options_point, key, :auto) === :auto && (options_point[key] = false)
    end
    
    # Pre-compute options for TrajectoryConfig
    options_trajectory = copy(raw)
    for key in _AUTO_OPTION_KEYS
        get(options_trajectory, key, :auto) === :auto && (options_trajectory[key] = true)
    end
    
    return CTFlows.Integrators.SciML{typeof(opts), typeof(options_point), typeof(options_trajectory)}(
        opts, options_point, options_trajectory
    )
end

# =============================================================================
# build_options — config-dependent option resolution
# =============================================================================

"""
$(TYPEDSIGNATURES)

Return pre-computed solver options for PointConfig.

For a PointConfig, options like `dense`, `save_everystep`, and `save_start`
are set to `false` to minimize memory since only the final state is needed.

# Arguments
- `integ::SciML`: The SciML integrator with pre-computed option caches.
- `config::Common.PointConfig`: The point configuration.

# Returns
- `Dict{Symbol,Any}`: Pre-computed options optimized for PointConfig.

See also: [`Integrators.build_options`](@ref), [`Integrators.SciML`](@ref).
"""
function Integrators.build_options(integ::SciML, config::Common.PointConfig)
    return integ.options_point
end

"""
$(TYPEDSIGNATURES)

Return pre-computed solver options for TrajectoryConfig.

For a TrajectoryConfig, options like `dense`, `save_everystep`, and `save_start`
are set to `true` to enable full trajectory storage and interpolation.

# Arguments
- `integ::SciML`: The SciML integrator with pre-computed option caches.
- `config::Common.TrajectoryConfig`: The trajectory configuration.

# Returns
- `Dict{Symbol,Any}`: Pre-computed options optimized for TrajectoryConfig.

See also: [`Integrators.build_options`](@ref), [`Integrators.SciML`](@ref).
"""
function Integrators.build_options(integ::SciML, config::Common.TrajectoryConfig)
    return integ.options_trajectory
end

"""
$(TYPEDSIGNATURES)

Return pre-computed solver options for fallback case (Nothing).

Defaults to TrajectoryConfig options when no configuration is provided.

# Arguments
- `integ::SciML`: The SciML integrator with pre-computed option caches.
- `config::Nothing`: No configuration provided (fallback).

# Returns
- `Dict{Symbol,Any}`: Pre-computed options for TrajectoryConfig (fallback).

See also: [`Integrators.build_options`](@ref), [`Integrators.SciML`](@ref).
"""
function Integrators.build_options(integ::SciML, config::Nothing)
    return integ.options_trajectory  # fallback vers Trajectory par défaut
end

# =============================================================================
# SciMLIntegrationResult
# =============================================================================

"""
$(TYPEDEF)

Integration result from a SciML solver.

Wraps a `SciMLBase.AbstractODESolution` and implements the `AbstractIntegrationResult`
interface required by the Solutions layer.

# Fields
- `ode_sol::S`: The raw SciML ODE solution.
"""
struct SciMLIntegrationResult{S<:SciMLBase.AbstractODESolution} <: Integrators.AbstractIntegrationResult
    ode_sol::S
end

"""
$(TYPEDSIGNATURES)

Return the final state vector from the SciML ODE solution.
"""
Integrators.final_state(r::SciMLIntegrationResult) = r.ode_sol.u[end]

"""
$(TYPEDSIGNATURES)

Return the vector of time points from the SciML ODE solution.
"""
Integrators.times(r::SciMLIntegrationResult) = r.ode_sol.t

"""
$(TYPEDSIGNATURES)

Evaluate the SciML ODE solution at a specific time `t` using its interpolation.
"""
Integrators.evaluate_at(r::SciMLIntegrationResult, t::Real) = r.ode_sol(t)

# =============================================================================
# SciML Segment Merging
# =============================================================================

"""
$(TYPEDSIGNATURES)

Merge a sequence of SciML ODE solutions into a single solution.
This allows concatenation of trajectories from multiple phases.
"""
function Integrators.merge(segments::AbstractVector{<:SciMLIntegrationResult})
    # Extract the raw ODESolution objects
    ode_sols = [r.ode_sol for r in segments]
    
    if isempty(ode_sols)
        throw(Exceptions.IncorrectArgument(
            "Cannot merge empty sequence of segments";
            got = "0 segments",
            expected = "at least 1 segment",
            context = "SciML merge",
        ))
    end
    
    if length(ode_sols) == 1
        return segments[1]
    end
    
    # Merge using DiffEqBase.EnsembleSolution (or custom concatenation if we want a single ODESolution)
    # The simplest robust way in SciML to represent concatenated trajectories over time
    # is often to reconstruct an ODESolution, but since times are strictly monotonic 
    # (except at jumps where they might be equal), we can concatenate `t`, `u` and `k`.
    # Let's concatenate them to form a continuous trajectory.
    
    t_merged = copy(ode_sols[1].t)
    u_merged = copy(ode_sols[1].u)
    
    for i in eachindex(ode_sols)[2:end]
        sol = ode_sols[i]
        # Append all points except the first one (which is the same time as previous last, but after jump)
        # Actually, keep it so we can have discontinuities properly represented.
        append!(t_merged, sol.t)
        append!(u_merged, sol.u)
    end
    
    # Create a new ODESolution (using the first one as template)
    # This is a bit of a hack, but SciML doesn't provide a clean `vcat` for ODESolutions yet.
    # Note: Interpolation might not work properly across the whole merged solution this way.
    sol1 = ode_sols[1]
    
    merged_sol = DiffEqBase.build_solution(
        sol1.prob, sol1.alg, t_merged, u_merged;
        retcode = SciMLBase.ReturnCode.Success,
        dense = false # Disable dense interpolation for merged as it requires k-arrays which are tricky to merge
    )
    
    return SciMLIntegrationResult(merged_sol)
end

# =============================================================================
# SciML problem building — actual implementation (generic)
# =============================================================================

"""
$(TYPEDSIGNATURES)

Build an `ODEProblem` from a system and configuration.
"""
function Integrators.build_problem(integ::SciML, system::Systems.AbstractSystem, config::Common.AbstractConfig; variable)
    f! = Systems.rhs(system)
    u0 = Common.initial_condition(config)
    p = Common.ODEParameters(variable)
    prob = ODEProblem(f!, u0, Common.tspan(config), p)
    return prob
end

# =============================================================================
# SciML solve — actual implementation (generic)
# =============================================================================

"""
$(TYPEDSIGNATURES)

Solve an `ODEProblem` using resolved options.
Returns a `SciMLIntegrationResult` wrapping the raw `ODESolution`.

# Arguments
- `integ::SciML`: The SciML integrator strategy.
- `prob::SciMLBase.AbstractODEProblem`: The ODE problem to solve.
- `options::Dict{Symbol,Any}`: Resolved solver options (typically from `build_options`).
- `unsafe=Common.__unsafe()`: If `true`, bypass ODE solver retcode checking; if `false`, throw `SolverFailure` on integration failure.

# Returns
- `SciMLIntegrationResult`: The integration result wrapping the SciML ODE solution.

# Throws
- `CTBase.Exceptions.SolverFailure`: If the ODE solver returns an unsuccessful retcode and `unsafe=false`.
"""
function Integrators.solve_problem(integ::SciML, prob::SciMLBase.AbstractODEProblem, options::Dict{Symbol,<:Any}; unsafe=Common.__unsafe())
    ode_sol = SciMLBase.solve(prob; options...)
    if !unsafe && !SciMLBase.successful_retcode(ode_sol.retcode)
        throw(Exceptions.SolverFailure(
            "ODE integration failed";
            retcode = string(ode_sol.retcode),
            suggestion = "Try tightening tolerances (reltol, abstol) or changing the solver algorithm.",
            context = "SciML solve_problem",
        ))
    end
    return SciMLIntegrationResult(ode_sol)
end

end # module CTFlowsSciML
