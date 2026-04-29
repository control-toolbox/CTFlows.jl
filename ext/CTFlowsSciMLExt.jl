"""
    CTFlowsSciMLExt

Package extension providing the SciML implementation for `SciMLIntegrator`
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
using CTFlows.Integrators: Integrators, SciMLIntegrator, SciMLTag
using OrdinaryDiffEqTsit5: OrdinaryDiffEqTsit5, ODEProblem, Tsit5

# =============================================================================
# Strategies.metadata — option definitions for SciMLIntegrator
# =============================================================================

"""
$(TYPEDSIGNATURES)

Return metadata defining `SciMLIntegrator` options and their specifications.
"""
function Strategies.metadata(::Type{<:SciMLIntegrator})
    return Strategies.StrategyMetadata(
        Strategies.OptionDefinition(;
            name = :alg,
            type = Any,
            default = Tsit5(),
            description = "ODE algorithm (e.g. Tsit5(), Rodas4()).",
        ),
        Strategies.OptionDefinition(;
            name = :reltol,
            type = Real,
            default = 1e-10,
            description = "Relative tolerance for the ODE solver.",
            validator = x ->
                x > 0 || throw(
                    Exceptions.IncorrectArgument(
                        "Invalid reltol value";
                        got = "reltol=$x",
                        expected = "positive real number (> 0)",
                        suggestion = "Provide a positive tolerance (e.g., 1e-8, 1e-10).",
                        context = "SciMLIntegrator reltol validation",
                    ),
                ),
        ),
        Strategies.OptionDefinition(;
            name = :abstol,
            type = Real,
            default = 1e-10,
            description = "Absolute tolerance for the ODE solver.",
            validator = x ->
                x > 0 || throw(
                    Exceptions.IncorrectArgument(
                        "Invalid abstol value";
                        got = "abstol=$x",
                        expected = "positive real number (> 0)",
                        suggestion = "Provide a positive tolerance (e.g., 1e-10, 1e-12).",
                        context = "SciMLIntegrator abstol validation",
                    ),
                ),
        ),
        Strategies.OptionDefinition(;
            name = :maxiters,
            type = Integer,
            default = 10^5,
            description = "Maximum number of solver iterations.",
            validator = x ->
                x > 0 || throw(
                    Exceptions.IncorrectArgument(
                        "Invalid maxiters value";
                        got = "maxiters=$x",
                        expected = "positive integer (> 0)",
                        suggestion = "Provide a positive iteration count (e.g., 10^5).",
                        context = "SciMLIntegrator maxiters validation",
                    ),
                ),
        ),
        Strategies.OptionDefinition(;
            name = :dt,
            type = Real,
            default = Options.NotProvided,
            description = "Fixed step size (used when adaptive=false).",
        ),
        Strategies.OptionDefinition(;
            name = :adaptive,
            type = Bool,
            default = true,
            description = "Whether to use adaptive step-size control.",
        ),
        Strategies.OptionDefinition(;
            name = :save_everystep,
            type = Bool,
            default = true,
            description = "Save the solution at every solver step.",
        ),
        Strategies.OptionDefinition(;
            name = :saveat,
            type = Any,
            default = Options.NotProvided,
            description = "Times at which to save the solution (Vector or range).",
        ),
    )
end

# =============================================================================
# build_sciml_integrator — actual implementation
# =============================================================================

"""
$(TYPEDSIGNATURES)

Build a `SciMLIntegrator` with validated options.
"""
function CTFlows.Integrators.build_sciml_integrator(
    ::Type{SciMLTag}; mode::Symbol = :strict, kwargs...,
)
    opts = Strategies.build_strategy_options(SciMLIntegrator; mode = mode, kwargs...)
    return SciMLIntegrator(opts)
end

# =============================================================================
# SciMLIntegrator callable — actual implementation
# =============================================================================

"""
$(TYPEDSIGNATURES)

Solve an `ODEProblem` using the `SciMLIntegrator`'s configured options.
Returns the raw `ODESolution`.
"""
function (integ::SciMLIntegrator)(prob)
    options = Strategies.options_dict(integ)
    alg = pop!(options, :alg)
    return _solve_ode(prob, alg; options...)
end

function _solve_ode(prob, alg; kwargs...)
    return OrdinaryDiffEqTsit5.solve(prob, alg; kwargs...)
end

# =============================================================================
# Systems.ode_problem — VectorFieldSystem implementation
# =============================================================================

"""
$(TYPEDSIGNATURES)

Build an `ODEProblem` from a `VectorFieldSystem` and a `PointConfig` (Fixed).
"""
function CTFlows.Systems.ode_problem(
    sys::Systems.VectorFieldSystem{<:Any, <:Any, Systems.Fixed},
    config::Common.PointConfig,
)
    f! = Systems.rhs!(sys)
    u0 = config.x0 isa Number ? [config.x0] : config.x0
    return ODEProblem(f!, u0, (config.t0, config.tf), nothing)
end

"""
$(TYPEDSIGNATURES)

Build an `ODEProblem` from a `VectorFieldSystem` and a `TrajectoryConfig` (Fixed).
"""
function CTFlows.Systems.ode_problem(
    sys::Systems.VectorFieldSystem{<:Any, <:Any, Systems.Fixed},
    config::Common.TrajectoryConfig,
)
    f! = Systems.rhs!(sys)
    u0 = config.x0 isa Number ? [config.x0] : config.x0
    return ODEProblem(f!, u0, config.tspan, nothing)
end

"""
$(TYPEDSIGNATURES)

Build an `ODEProblem` from a `VectorFieldSystem` and a `PointConfig` (NonFixed).
"""
function CTFlows.Systems.ode_problem(
    sys::Systems.VectorFieldSystem{<:Any, <:Any, Systems.NonFixed},
    config::Common.PointConfig;
    variable,
)
    f! = Systems.rhs!(sys)
    u0 = config.x0 isa Number ? [config.x0] : config.x0
    return ODEProblem(f!, u0, (config.t0, config.tf), variable)
end

"""
$(TYPEDSIGNATURES)

Build an `ODEProblem` from a `VectorFieldSystem` and a `TrajectoryConfig` (NonFixed).
"""
function CTFlows.Systems.ode_problem(
    sys::Systems.VectorFieldSystem{<:Any, <:Any, Systems.NonFixed},
    config::Common.TrajectoryConfig;
    variable,
)
    f! = Systems.rhs!(sys)
    u0 = config.x0 isa Number ? [config.x0] : config.x0
    return ODEProblem(f!, u0, config.tspan, variable)
end

end # module CTFlowsSciMLExt
