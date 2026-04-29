"""
$(TYPEDEF)

Container for the raw SciML ODE solution from a TrajectoryConfig integration.

This type wraps the raw ODE solution returned by SciML solvers. For now,
it simply stores the solution without providing any accessor methods.

# Fields
- `raw`: The raw ODE solution object (typically from SciML's solve function).

# Notes
- No accessor methods are provided at this time.
- The raw solution typically contains `.t` (time points) and `.u` (state values).
- Future versions may add convenience methods for accessing solution data.
"""
struct VectorFieldSolution
    raw::Any
end
