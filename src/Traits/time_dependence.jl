"""
$(TYPEDSIGNATURES)

Check if the object has the time-dependence trait.

This fallback method throws an error indicating the object does not support
time-dependence queries. Concrete types that have the trait should implement
`has_time_dependence_trait(obj::MyType) = true`.

The calling function name is automatically detected from the stacktrace
for better error messages.

# Arguments
- `obj::Any`: The object to check.

# Throws
- [`CTBase.Exceptions.IncorrectArgument`](@extref): Always, indicating the object does not have the trait.

See also: [`CTModels.OCP.TimeDependence`](@extref), [`CTFlows.Traits.time_dependence`](@ref).
"""
function has_time_dependence_trait(obj::Any)
    source_method = _caller_function_name()
    throw(Exceptions.IncorrectArgument(
        "Cannot call $(source_method) on object of type $(typeof(obj)): no time-dependence trait";
        suggestion = "Implement has_time_dependence_trait(obj::$(typeof(obj))) = true and time_dependence(obj::$(typeof(obj))) to enable time-dependence trait support.",
        context = "Time-dependence trait not available",
    ))
end

"""
$(TYPEDSIGNATURES)

Return the time-dependence trait value for the object.

This fallback method throws an error indicating the method is not implemented.
Concrete types that have the trait should implement `time_dependence(obj::MyType)`
to return the specific trait value (`Autonomous` or `NonAutonomous`).

# Arguments
- `obj::Any`: The object to query.

# Throws
- [`CTBase.Exceptions.NotImplemented`](@extref): Always, indicating the method must be implemented.

See also: [`CTModels.OCP.TimeDependence`](@extref), [`CTFlows.Traits.has_time_dependence_trait`](@ref).
"""
function time_dependence(obj::Any)
    has_time_dependence_trait(obj)
    throw(Exceptions.NotImplemented(
        "time_dependence not implemented for $(typeof(obj))";
        required_method = "time_dependence(obj::$(typeof(obj)))",
        suggestion = "Implement time_dependence for your concrete object type to return the specific time-dependence trait (Autonomous or NonAutonomous).",
        context = "Time-dependence trait - required method implementation",
    ))
end

"""
$(TYPEDSIGNATURES)

Return true if the object is autonomous (time-independent).

Checks that the object has the time-dependence trait, then returns true
if `time_dependence(obj)` is `Autonomous`.

# Arguments
- `obj::Any`: The object to check.

# Returns
- `Bool`: true if the object is autonomous.

# Throws
- [`CTBase.Exceptions.IncorrectArgument`](@extref): If the object does not support time-dependence queries.
- [`CTBase.Exceptions.NotImplemented`](@extref): If `time_dependence` is not implemented for the object type.

See also: [`CTModels.OCP.TimeDependence`](@extref), [`CTFlows.Traits.time_dependence`](@ref).
"""
function OCP.is_autonomous(obj::Any)
    has_time_dependence_trait(obj)
    return time_dependence(obj) === OCP.Autonomous
end

"""
$(TYPEDSIGNATURES)

Return true if the object is non-autonomous (time-dependent).

Checks that the object has the time-dependence trait, then returns true
if `time_dependence(obj)` is `NonAutonomous`.

# Arguments
- `obj::Any`: The object to check.

# Returns
- `Bool`: true if the object is non-autonomous.

# Throws
- [`CTBase.Exceptions.IncorrectArgument`](@extref): If the object does not support time-dependence queries.
- [`CTBase.Exceptions.NotImplemented`](@extref): If `time_dependence` is not implemented for the object type.

See also: [`CTModels.OCP.TimeDependence`](@extref), [`CTFlows.Traits.time_dependence`](@ref).
"""
function OCP.is_nonautonomous(obj::Any)
    has_time_dependence_trait(obj)
    return time_dependence(obj) === OCP.NonAutonomous
end
