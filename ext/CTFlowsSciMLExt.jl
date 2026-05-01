"""
    CTFlowsSciMLExt

Package extension providing the SciML implementation for `SciML`
and `ode_problem` for `VectorFieldSystem`. Activated automatically when
`OrdinaryDiffEqTsit5` (or any superset such as `OrdinaryDiffEq` /
`DifferentialEquations`) is loaded together with `CTFlows`.
"""
module CTFlowsSciMLExt

import DocStringExtensions: TYPEDSIGNATURES
import CTBase.Exceptions
import CTSolvers.Strategies
import CTSolvers.Options

using CTFlows: CTFlows
using CTFlows.Common: Common
using CTFlows.Systems: Systems
using CTFlows.Integrators: Integrators, SciML, SciMLTag
using CTFlows.Solutions: Solutions
using OrdinaryDiffEqTsit5: OrdinaryDiffEqTsit5, ODEProblem, Tsit5
using SciMLBase: SciMLBase


# =============================================================================
# Strategies.metadata — option definitions for SciML
# =============================================================================

"""
$(TYPEDSIGNATURES)

Return metadata defining `SciML` options and their specifications.
"""
function Strategies.metadata(::Type{SciML})
    return Strategies.StrategyMetadata(
        Strategies.OptionDefinition(;
            name = :alg,
            type = SciMLBase.AbstractDEAlgorithm,
            default = Tsit5(),
            description = "ODE algorithm (e.g. Tsit5(), Rodas4()).",
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
            type = Bool,
            default = Options.NotProvided,
            description = "Save the solution at every solver step.",
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
            type = Bool,
            default = true,
            description = "Whether to save extra pieces for dense (continuous) output.",
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
            type = Bool,
            default = Options.NotProvided,
            description = "Whether to save the initial condition.",
        ),
        Strategies.OptionDefinition(;
            name = :save_end,
            type = Bool,
            default = Options.NotProvided,
            description = "Whether to force saving the final timepoint.",
        ),
    )
end

# =============================================================================
# build_sciml_integrator — actual implementation
# =============================================================================

"""
$(TYPEDSIGNATURES)

Build a `SciML` with validated options.
"""
function CTFlows.Integrators.build_sciml_integrator(
    ::Type{CTFlows.Integrators.SciMLTag}; mode::Symbol = :strict, kwargs...,
)
    opts = Strategies.build_strategy_options(SciML; mode = mode, kwargs...)
    return CTFlows.Integrators.SciML(opts)
end

# =============================================================================
# SciML problem building — actual implementation (generic)
# =============================================================================

"""
$(TYPEDSIGNATURES)

Build an `ODEProblem` from a system and configuration.
"""
function (integ::SciML)(system::Systems.AbstractSystem, config::Common.AbstractConfig; variable)
    f! = Systems.rhs!(system)
    u0 = Common.initial_condition(config)
    prob = ODEProblem(f!, u0, Common.tspan(config), variable)
    return prob
end

# =============================================================================
# SciML solve — actual implementation (generic)
# =============================================================================

"""
$(TYPEDSIGNATURES)

Solve an `ODEProblem` using the `SciML`'s configured options.
Returns the raw `ODESolution`.
"""
function (integ::SciML)(prob::SciMLBase.AbstractODEProblem)
    options = Strategies.options_dict(integ)
    return SciMLBase.solve(prob; options...)
end

# =============================================================================
# SciML solution building — actual implementation (generic)
# =============================================================================

"""
$(TYPEDSIGNATURES)

Build the flow solution from an ODE solution.
"""
function (integ::SciML)(ode_sol::SciMLBase.AbstractODESolution, sys::Systems.AbstractSystem, config::Common.AbstractConfig)
    return Solutions.build_solution(ode_sol, sys, config)
end

end # module CTFlowsSciMLExt
