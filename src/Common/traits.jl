"""
$(TYPEDEF)

Abstract supertype for time-dependence traits.

# Trait Pattern

Objects that have a time-dependence trait must implement two methods:
- `has_time_dependence_trait(obj::MyType) = true`: Indicates the type has this trait
- `time_dependence(obj::MyType)`: Returns the specific trait value (`Autonomous` or `NonAutonomous`)

Once these are implemented, the object automatically gains:
- `is_autonomous(obj)`: Returns true if `time_dependence(obj)` is `Autonomous`
- `is_nonautonomous(obj)`: Returns true if `time_dependence(obj)` is `NonAutonomous`

If `has_time_dependence_trait` is not implemented or returns `false`,
calling `is_autonomous`, `is_nonautonomous`, or `time_dependence` will throw an error
indicating the object does not support time-dependence queries.
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

# Trait Pattern

Objects that have a variable-dependence trait must implement two methods:
- `has_variable_dependence_trait(obj::MyType) = true`: Indicates the type has this trait
- `variable_dependence(obj::MyType)`: Returns the specific trait value (`Fixed` or `NonFixed`)

Once these are implemented, the object automatically gains:
- `is_variable(obj)`: Returns true if `variable_dependence(obj)` is `NonFixed`
- `is_nonvariable(obj)`: Returns true if `variable_dependence(obj)` is `Fixed`
- `has_variable(obj)`: Alias for `is_variable` (CTModels compatibility)

If `has_variable_dependence_trait` is not implemented or returns `false`,
calling `is_variable`, `is_nonvariable`, `has_variable`, or `variable_dependence` will throw an error
indicating the object does not support variable-dependence queries.
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

# =============================================================================
# Check has trait
# =============================================================================

"""
    _caller_function_name() -> Symbol

Return the name of the calling function by inspecting the stacktrace.

This is used to provide better error messages in trait check functions
without requiring an explicit `source_method` argument.

# Returns
- `Symbol`: The name of the calling function, or `:unknown` if it cannot be determined.
"""
function _caller_function_name()
    stack = stacktrace()
    for frame in stack
        func_name = frame.func
        func_str = string(func_name)
        if func_str != "_caller_function_name" &&
           !startswith(func_str, "#") &&
           func_str != "has_time_dependence_trait" &&
           func_str != "has_variable_dependence_trait"
            return func_name
        end
    end
    return :unknown
end

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

See also: [`CTFlows.Common.TimeDependence`](@ref), [`CTFlows.Common.time_dependence`](@ref).
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

See also: [`CTFlows.Common.TimeDependence`](@ref), [`CTFlows.Common.has_time_dependence_trait`](@ref).
"""
function time_dependence(obj::Any)
    throw(Exceptions.NotImplemented(
        "time_dependence not implemented for $(typeof(obj))";
        required_method = "time_dependence(obj::$(typeof(obj)))",
        suggestion = "Implement time_dependence for your concrete object type to return the specific time-dependence trait (Autonomous or NonAutonomous).",
        context = "Time-dependence trait - required method implementation",
    ))
end

"""
$(TYPEDSIGNATURES)

Check if the object has the variable-dependence trait.

This fallback method throws an error indicating the object does not support
variable-dependence queries. Concrete types that have the trait should implement
`has_variable_dependence_trait(obj::MyType) = true`.

The calling function name is automatically detected from the stacktrace
for better error messages.

# Arguments
- `obj::Any`: The object to check.

# Throws
- [`CTBase.Exceptions.IncorrectArgument`](@extref): Always, indicating the object does not have the trait.

See also: [`CTFlows.Common.VariableDependence`](@ref), [`CTFlows.Common.variable_dependence`](@ref).
"""
function has_variable_dependence_trait(obj::Any)
    source_method = _caller_function_name()
    throw(Exceptions.IncorrectArgument(
        "Cannot call $(source_method) on object of type $(typeof(obj)): no variable-dependence trait";
        suggestion = "Implement has_variable_dependence_trait(obj::$(typeof(obj))) = true and variable_dependence(obj::$(typeof(obj))) to enable variable-dependence trait support.",
        context = "Variable-dependence trait not available",
    ))
end

"""
$(TYPEDSIGNATURES)

Return the variable-dependence trait value for the object.

This fallback method throws an error indicating the method is not implemented.
Concrete types that have the trait should implement `variable_dependence(obj::MyType)`
to return the specific trait value (`Fixed` or `NonFixed`).

# Arguments
- `obj::Any`: The object to query.

# Throws
- [`CTBase.Exceptions.NotImplemented`](@extref): Always, indicating the method must be implemented.

See also: [`CTFlows.Common.VariableDependence`](@ref), [`CTFlows.Common.has_variable_dependence_trait`](@ref).
"""
function variable_dependence(obj::Any)
    throw(Exceptions.NotImplemented(
        "variable_dependence not implemented for $(typeof(obj))";
        required_method = "variable_dependence(obj::$(typeof(obj)))",
        suggestion = "Implement variable_dependence for your concrete object type to return the specific variable-dependence trait (Fixed or NonFixed).",
        context = "Variable-dependence trait - required method implementation",
    ))
end

# =============================================================================
# Trait accessors
# =============================================================================

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

See also: [`CTFlows.Common.TimeDependence`](@ref), [`CTFlows.Common.time_dependence`](@ref).
"""
function is_autonomous(obj::Any)
    has_time_dependence_trait(obj)
    return is_autonomous(time_dependence(obj))
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

See also: [`CTFlows.Common.TimeDependence`](@ref), [`CTFlows.Common.time_dependence`](@ref).
"""
function is_nonautonomous(obj::Any)
    has_time_dependence_trait(obj)
    return is_nonautonomous(time_dependence(obj))
end

"""
$(TYPEDSIGNATURES)

Return true if the object depends on variable parameters.

Checks that the object has the variable-dependence trait, then returns true
if `variable_dependence(obj)` is `NonFixed`.

# Arguments
- `obj::Any`: The object to check.

# Returns
- `Bool`: true if the object depends on variable parameters.

# Throws
- [`CTBase.Exceptions.IncorrectArgument`](@extref): If the object does not support variable-dependence queries.
- [`CTBase.Exceptions.NotImplemented`](@extref): If `variable_dependence` is not implemented for the object type.

See also: [`CTFlows.Common.VariableDependence`](@ref), [`CTFlows.Common.variable_dependence`](@ref).
"""
function is_variable(obj::Any)
    has_variable_dependence_trait(obj)
    return is_variable(variable_dependence(obj))
end

"""
$(TYPEDSIGNATURES)

Return true if the object does not depend on variable parameters.

Checks that the object has the variable-dependence trait, then returns true
if `variable_dependence(obj)` is `Fixed`.

# Arguments
- `obj::Any`: The object to check.

# Returns
- `Bool`: true if the object does not depend on variable parameters.

# Throws
- [`CTBase.Exceptions.IncorrectArgument`](@extref): If the object does not support variable-dependence queries.
- [`CTBase.Exceptions.NotImplemented`](@extref): If `variable_dependence` is not implemented for the object type.

See also: [`CTFlows.Common.VariableDependence`](@ref), [`CTFlows.Common.variable_dependence`](@ref).
"""
function is_nonvariable(obj::Any)
    has_variable_dependence_trait(obj)
    return is_nonvariable(variable_dependence(obj))
end

"""
$(TYPEDSIGNATURES)

Return true if the object depends on variable parameters.

Checks that the object has the variable-dependence trait, then returns true
if `variable_dependence(obj)` is `NonFixed`.

# Arguments
- `obj::Any`: The object to check.

# Returns
- `Bool`: true if the object depends on variable parameters.

# Throws
- [`CTBase.Exceptions.IncorrectArgument`](@extref): If the object does not support variable-dependence queries.
- [`CTBase.Exceptions.NotImplemented`](@extref): If `variable_dependence` is not implemented for the object type.

See also: [`CTFlows.Common.is_variable`](@ref), [`CTFlows.Common.VariableDependence`](@ref).
"""
function has_variable(obj::Any)
    has_variable_dependence_trait(obj)
    return is_variable(variable_dependence(obj))
end

"""
$(TYPEDSIGNATURES)

Return true for the `Autonomous` trait type.

# Returns
- `Bool`: true for `Autonomous`, false for `NonAutonomous`.

See also: [`CTFlows.Common.Autonomous`](@ref), [`CTFlows.Common.NonAutonomous`](@ref).
"""
function is_autonomous(::Type{Autonomous})
    return true
end

function is_autonomous(::Type{NonAutonomous})
    return false
end

"""
$(TYPEDSIGNATURES)

Return true for the `NonAutonomous` trait type.

# Returns
- `Bool`: true for `NonAutonomous`, false for `Autonomous`.

See also: [`CTFlows.Common.NonAutonomous`](@ref), [`CTFlows.Common.Autonomous`](@ref).
"""
function is_nonautonomous(::Type{Autonomous})
    return false
end

function is_nonautonomous(::Type{NonAutonomous})
    return true
end

"""
$(TYPEDSIGNATURES)

Return true for the `NonFixed` trait type.

# Returns
- `Bool`: true for `NonFixed`, false for `Fixed`.

See also: [`CTFlows.Common.NonFixed`](@ref), [`CTFlows.Common.Fixed`](@ref).
"""
function is_variable(::Type{NonFixed})
    return true
end

function is_variable(::Type{Fixed})
    return false
end

"""
$(TYPEDSIGNATURES)

Return true for the `NonFixed` trait type (alias for `is_variable`).

# Returns
- `Bool`: true for `NonFixed`, false for `Fixed`.

See also: [`CTFlows.Common.is_variable`](@ref), [`CTFlows.Common.NonFixed`](@ref).
"""
has_variable(::Type{NonFixed}) = true
has_variable(::Type{Fixed}) = false

"""
$(TYPEDSIGNATURES)

Return true for the `Fixed` trait type.

# Returns
- `Bool`: true for `Fixed`, false for `NonFixed`.

See also: [`CTFlows.Common.Fixed`](@ref), [`CTFlows.Common.NonFixed`](@ref).
"""
function is_nonvariable(::Type{Fixed})
    return true
end

function is_nonvariable(::Type{NonFixed})
    return false
end
