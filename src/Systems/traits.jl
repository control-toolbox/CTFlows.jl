"""
$(TYPEDEF)

Abstract supertype for time-dependence traits of vector fields and related objects.
"""
abstract type TimeDependence end

"""
$(TYPEDEF)

Trait indicating the function does not depend explicitly on time (`f(x, ...)`).
"""
struct Autonomous <: TimeDependence end

"""
$(TYPEDEF)

Trait indicating the function depends explicitly on time (`f(t, x, ...)`).
"""
struct NonAutonomous <: TimeDependence end

"""
$(TYPEDEF)

Abstract supertype for variable-dependence traits.
"""
abstract type VariableDependence end

"""
$(TYPEDEF)

Trait indicating the function has no extra variable argument.
"""
struct Fixed <: VariableDependence end

"""
$(TYPEDEF)

Trait indicating the function takes an extra variable argument `v`.
"""
struct NonFixed <: VariableDependence end
