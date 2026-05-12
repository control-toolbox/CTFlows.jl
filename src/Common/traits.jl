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
abstract type VariableDependence <: AbstractTrait end

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
           func_str != "has_variable_dependence_trait" &&
           func_str != "has_mutability_trait"
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

See also: [`CTModels.OCP.TimeDependence`](@extref), [`CTFlows.Common.time_dependence`](@ref).
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

See also: [`CTModels.OCP.TimeDependence`](@extref), [`CTFlows.Common.has_time_dependence_trait`](@ref).
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
# Mutability trait functions
# =============================================================================

"""
$(TYPEDSIGNATURES)

Check if the object has the mutability trait.

This fallback method throws an error indicating the object does not support
mutability queries. Concrete types that have the trait should implement
`has_mutability_trait(obj::MyType) = true`.

The calling function name is automatically detected from the stacktrace
for better error messages.

# Arguments
- `obj::Any`: The object to check.

# Throws
- [`CTBase.Exceptions.IncorrectArgument`](@extref): Always, indicating the object does not have the trait.

See also: [`CTFlows.Common.AbstractMutabilityTrait`](@ref), [`CTFlows.Common.mutability_trait`](@ref).
"""
function has_mutability_trait(obj::Any)
    source_method = _caller_function_name()
    throw(Exceptions.IncorrectArgument(
        "Cannot call $(source_method) on object of type $(typeof(obj)): no mutability trait";
        suggestion = "Implement has_mutability_trait(obj::$(typeof(obj))) = true and mutability_trait(obj::$(typeof(obj))) to enable mutability trait support.",
        context = "Mutability trait not available",
    ))
end

"""
$(TYPEDSIGNATURES)

Return the mutability trait value for the object.

This fallback method throws an error indicating the method is not implemented.
Concrete types that have the trait should implement `mutability_trait(obj::MyType)`
to return the specific trait value (`InPlace` or `OutOfPlace`).

# Arguments
- `obj::Any`: The object to query.

# Throws
- [`CTBase.Exceptions.NotImplemented`](@extref): Always, indicating the method must be implemented.

See also: [`CTFlows.Common.AbstractMutabilityTrait`](@ref), [`CTFlows.Common.has_mutability_trait`](@ref).
"""
function mutability_trait(obj::Any)
    throw(Exceptions.NotImplemented(
        "mutability_trait not implemented for $(typeof(obj))";
        required_method = "mutability_trait(obj::$(typeof(obj)))",
        suggestion = "Implement mutability_trait for your concrete object type to return the specific mutability trait (InPlace or OutOfPlace).",
        context = "Mutability trait - required method implementation",
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

See also: [`CTModels.OCP.TimeDependence`](@extref), [`CTFlows.Common.time_dependence`](@ref).
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

See also: [`CTModels.OCP.TimeDependence`](@extref), [`CTFlows.Common.time_dependence`](@ref).
"""
function OCP.is_nonautonomous(obj::Any)
    has_time_dependence_trait(obj)
    return time_dependence(obj) === OCP.NonAutonomous
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
function OCP.is_variable(obj::Any)
    has_variable_dependence_trait(obj)
    return variable_dependence(obj) === NonFixed
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
function OCP.is_nonvariable(obj::Any)
    has_variable_dependence_trait(obj)
    return variable_dependence(obj) === Fixed
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
function OCP.has_variable(obj::Any)
    has_variable_dependence_trait(obj)
    return variable_dependence(obj) === NonFixed
end

# =============================================================================
# Mutability trait accessors
# =============================================================================

"""
$(TYPEDSIGNATURES)

Return true if the object uses in-place function evaluation.

Checks that the object has the mutability trait, then returns true
if `mutability_trait(obj)` is `InPlace`.

# Arguments
- `obj::Any`: The object to check.

# Returns
- `Bool`: true if the object uses in-place evaluation.

# Throws
- [`CTBase.Exceptions.IncorrectArgument`](@extref): If the object does not support mutability queries.
- [`CTBase.Exceptions.NotImplemented`](@extref): If `mutability_trait` is not implemented for the object type.

See also: [`CTFlows.Common.AbstractMutabilityTrait`](@ref), [`CTFlows.Common.mutability_trait`](@ref).
"""
function is_inplace(obj::Any)
    has_mutability_trait(obj)
    return mutability_trait(obj) === InPlace
end

"""
$(TYPEDSIGNATURES)

Return true if the object uses out-of-place function evaluation.

Checks that the object has the mutability trait, then returns true
if `mutability_trait(obj)` is `OutOfPlace`.

# Arguments
- `obj::Any`: The object to check.

# Returns
- `Bool`: true if the object uses out-of-place evaluation.

# Throws
- [`CTBase.Exceptions.IncorrectArgument`](@extref): If the object does not support mutability queries.
- [`CTBase.Exceptions.NotImplemented`](@extref): If `mutability_trait` is not implemented for the object type.

See also: [`CTFlows.Common.AbstractMutabilityTrait`](@ref), [`CTFlows.Common.mutability_trait`](@ref).
"""
function is_outofplace(obj::Any)
    has_mutability_trait(obj)
    return mutability_trait(obj) === OutOfPlace
end

