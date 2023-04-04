# --------------------------------------------------------------------------------------------
# Default options for flows
# --------------------------------------------------------------------------------------------
"""
$(TYPEDSIGNATURES)

Default absolute tolerance for ODE solvers.

See `abstol` from `OrdinaryDiffEq`.
"""
__abstol() = 1e-10

"""
$(TYPEDSIGNATURES)

Default relative tolerance for ODE solvers.

See `reltol` from `OrdinaryDiffEq`.
"""
__reltol() = 1e-10

"""
$(TYPEDSIGNATURES)

See `saveat` from `OrdinaryDiffEq`.
"""
__saveat() = []

"""
$(TYPEDSIGNATURES)

Default algorithm for ODE solvers.

See `alg` from `OrdinaryDiffEq`.
"""
__alg() = Tsit5()

"""
$(TYPEDSIGNATURES)

See `tstops` from `OrdinaryDiffEq`.
"""
__tstops() = Vector{Time}()