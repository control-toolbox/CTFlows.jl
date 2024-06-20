# --------------------------------------------------------------------------------------------
# Default options for flows
# --------------------------------------------------------------------------------------------
__variable() = Real[]

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

Default algorithm for ODE solvers.

See `alg` from `DifferentialEquations`.
"""
__alg() = default_algorithm #Tsit5()

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