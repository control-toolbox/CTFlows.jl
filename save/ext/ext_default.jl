# --------------------------------------------------------------------------------------------
# Default options for CTFlowsExt
# --------------------------------------------------------------------------------------------
"""
$(TYPEDSIGNATURES)

Default algorithm for ODE solvers.

See `alg` from `DifferentialEquations`.
"""
__alg() = Tsit5()

"""
$(TYPEDSIGNATURES)

Default internal norm.
"""
__internalnorm() = (x, y) -> norm(x)

"""
$(TYPEDSIGNATURES)

Default variable from ocp.
"""
function __thevariable(t0, x0, p0, tf, ocp)
    # if tf is free and ocp has only one variable, then return tf
    CTModels.has_free_final_time(ocp) && CTModels.variable_dimension(ocp) == 1 && return tf

    # if t0 is free and ocp has only one variable, then return t0
    CTModels.has_free_initial_time(ocp) &&
        CTModels.variable_dimension(ocp) == 1 &&
        return t0

    # if t0 and tf are free and ocp has only two variables, then return [t0, tf]
    CTModels.has_free_final_time(ocp) &&
        CTModels.has_free_initial_time(ocp) &&
        CTModels.variable_dimension(ocp) == 2 &&
        return [t0, tf]

    # otherwise return an empty vector of right type to avoid warning performance message from OrdinaryDiffEq
    z0 = [x0; p0]
    T = eltype(z0)
    return Vector{T}()
end

"""
$(TYPEDSIGNATURES)

Default variable x0, p0.
"""
function __thevariable(x0, p0)
    z0 = [x0; p0]
    T = eltype(z0)
    return Vector{T}()
end

"""
$(TYPEDSIGNATURES)

Default variable from x0.
"""
function __thevariable(x0)
    T = eltype(x0)
    return Vector{T}()
end

"""
$(TYPEDSIGNATURES)

Default absolute tolerance for ODE solvers.

See `abstol` from `DifferentialEquations`.
"""
__abstol() = 1e-10

"""
$(TYPEDSIGNATURES)

Default relative tolerance for ODE solvers.

See `reltol` from `DifferentialEquations`.
"""
__reltol() = 1e-10

"""
$(TYPEDSIGNATURES)

See `saveat` from `DifferentialEquations`.
"""
__saveat() = []

"""
$(TYPEDSIGNATURES)

See `tstops` from `DifferentialEquations`.
"""
__tstops() = Vector{Time}()

"""
$(TYPEDSIGNATURES)

See `callback` from `DifferentialEquations`.
"""
__callback() = nothing
