# ==============================================================================
# Removed accessors (control-toolbox/CTFlows.jl#544)
#
# The accessors of a flow lost their `get_` prefix, and the switching times and the phase
# labels are read with the functions that read them on a solution. The old names are kept
# only to say what replaces them.
# ==============================================================================

"""
$(TYPEDSIGNATURES)

Throw the error of a removed accessor of a multi-phase flow, naming its replacement.

# Throws
- [`CTBase.Exceptions.PreconditionError`](@extref): always.
"""
function _removed_accessor(old::AbstractString, new::AbstractString)
    return throw(
        Exceptions.PreconditionError(
            "`$old` is removed";
            reason="the accessors of a flow have no `get_` prefix, and a flow and its " *
                   "solution share switching_times and phase_labels",
            suggestion="use $new",
            context="$old — removed accessor (control-toolbox/CTFlows.jl#544)",
        ),
    )
end

"""
$(TYPEDSIGNATURES)

Removed: use `phase_flows(f)[i]`. Throws a `CTBase.Exceptions.PreconditionError`.
"""
get_flow(args...) = _removed_accessor("get_flow(f, i)", "phase_flows(f)[i]")

"""
$(TYPEDSIGNATURES)

Removed: use `switching_times(f)[i]`. Throws a `CTBase.Exceptions.PreconditionError`.
"""
function get_switching_time(args...)
    return _removed_accessor("get_switching_time(f, i)", "switching_times(f)[i]")
end

"""
$(TYPEDSIGNATURES)

Removed: use `jumps(f)[i]`. Throws a `CTBase.Exceptions.PreconditionError`.
"""
get_jump(args...) = _removed_accessor("get_jump(f, i)", "jumps(f)[i]")

"""
$(TYPEDSIGNATURES)

Removed: use `phase_flows(f)`. Throws a `CTBase.Exceptions.PreconditionError`.
"""
get_flows(args...) = _removed_accessor("get_flows(f)", "phase_flows(f)")

"""
$(TYPEDSIGNATURES)

Removed: use `switching_times(f)`. Throws a `CTBase.Exceptions.PreconditionError`.
"""
function get_switching_times(args...)
    return _removed_accessor("get_switching_times(f)", "switching_times(f)")
end

"""
$(TYPEDSIGNATURES)

Removed: use `jumps(f)`. Throws a `CTBase.Exceptions.PreconditionError`.
"""
get_jumps(args...) = _removed_accessor("get_jumps(f)", "jumps(f)")

"""
$(TYPEDSIGNATURES)

Removed: use `phase_labels(f)`. Throws a `CTBase.Exceptions.PreconditionError`.
"""
get_labels(args...) = _removed_accessor("get_labels(f)", "phase_labels(f)")
