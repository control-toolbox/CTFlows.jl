# --------------------------------------------------------------------------------------------
# Default options for flows
# --------------------------------------------------------------------------------------------
__abstol() = 1e-10
__reltol() = 1e-10
__saveat() = []
__alg() = Tsit5()
__tstops() = Vector{Time}()