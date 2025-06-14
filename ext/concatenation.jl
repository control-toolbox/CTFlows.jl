"""
$(TYPEDSIGNATURES)

Concatenate the right-hand sides of two flows `F` and `G`, switching at time `t_switch`.

# Arguments
- `F`, `G`: Two flows of the same type.
- `t_switch::Time`: The switching time.

# Returns
- A function `rhs!` that dispatches to `F.rhs!` before `t_switch`, and to `G.rhs!` after.

# Example
```julia-repl
julia> rhs = __concat_rhs(F, G, 1.0)
julia> rhs!(du, u, p, 0.5)  # uses F.rhs!
julia> rhs!(du, u, p, 1.5)  # uses G.rhs!
```
"""
function __concat_rhs(
    F::AbstractFlow{D,U}, G::AbstractFlow{D,U}, t_switch::Time
) where {D,U}
    function rhs!(du::D, u::U, p::Variable, t::Time)
        return t < t_switch ? F.rhs!(du, u, p, t) : G.rhs!(du, u, p, t)
    end
    return rhs!
end

"""
$(TYPEDSIGNATURES)

Concatenate vector field right-hand sides with time-based switching.

# Arguments
- `F`, `G`: VectorFieldFlow instances.
- `t_switch::Time`: Switching time.

# Returns
- A function of the form `(x, v, t) -> ...`.

# Example
```julia-repl
julia> rhs = __concat_rhs(F, G, 2.0)
julia> rhs(x, v, 1.0)  # uses F.rhs
julia> rhs(x, v, 3.0)  # uses G.rhs
```
"""
function __concat_rhs(F::VectorFieldFlow, G::VectorFieldFlow, t_switch::Time)
    return (x::State, v::Variable, t::Time) ->
        (t < t_switch ? F.rhs(x, v, t) : G.rhs(x, v, t))
end

"""
$(TYPEDSIGNATURES)

Concatenate ODE right-hand sides with a switch at `t_switch`.

# Arguments
- `F`, `G`: ODEFlow instances.
- `t_switch::Time`: Time at which to switch between flows.

# Returns
- A function of the form `(x, v, t) -> ...`.

# Example
```julia-repl
julia> rhs = __concat_rhs(F, G, 0.5)
julia> rhs(x, v, 0.4)  # F.rhs
julia> rhs(x, v, 0.6)  # G.rhs
```
"""
function __concat_rhs(F::ODEFlow, G::ODEFlow, t_switch::Time)
    return (x, v, t::Time) -> (t < t_switch ? F.rhs(x, v, t) : G.rhs(x, v, t))
end

"""
$(TYPEDSIGNATURES)

Concatenate the `tstops` (discontinuity times) of two flows and add the switching time.

# Arguments
- `F`, `G`: Flows with `tstops` vectors.
- `t_switch::Time`: Switching time to include.

# Returns
- A sorted vector of unique `tstops`.

# Example
```julia-repl
julia> __concat_tstops(F, G, 1.0)
```
"""
function __concat_tstops(F::AbstractFlow, G::AbstractFlow, t_switch::Time)
    tstops = F.tstops
    append!(tstops, G.tstops)
    append!(tstops, t_switch)
    tstops = unique(sort(tstops))
    return tstops
end

"""
$(TYPEDSIGNATURES)

Concatenate feedback control laws of two optimal control flows.

# Arguments
- `F`, `G`: OptimalControlFlow instances.
- `t_switch::Time`: Switching time.

# Returns
- A `ControlLaw` that dispatches to `F` or `G` depending on `t`.

# Example
```julia-repl
julia> u = __concat_feedback_control(F, G, 2.0)
julia> u(1.5, x, u, v)  # from F
julia> u(2.5, x, u, v)  # from G
```
"""
function __concat_feedback_control(F::AbstractFlow, G::AbstractFlow, t_switch::Time)
    function _feedback_control(t, x, u, v)
        return if t < t_switch
            F.feedback_control(t, x, u, v)
        else
            G.feedback_control(t, x, u, v)
        end
    end
    feedback_control = CTFlows.ControlLaw(_feedback_control, CTFlows.NonAutonomous, CTFlows.NonFixed)
    return feedback_control
end

"""
$(TYPEDSIGNATURES)

Concatenate the `jumps` of two flows, with optional extra jump at `t_switch`.

# Arguments
- `F`, `G`: Flows with jump events.
- `jump`: Optional tuple `(t_switch, η_switch)` to insert.

# Returns
- Combined list of jumps.

# Example
```julia-repl
julia> __concat_jumps(F, G)
julia> __concat_jumps(F, G, (1.0, η))
```
"""
function __concat_jumps(
    F::AbstractFlow, G::AbstractFlow, jump::Union{Nothing,Tuple{Time,Any}}=nothing
)
    jumps = F.jumps
    append!(jumps, G.jumps)
    !isnothing(jump) && push!(jumps, jump)
    return jumps
end

# --------------------------------------------------------------------------------------------
"""
$(TYPEDSIGNATURES)

Concatenate two `AbstractFlow` instances with a prescribed switching time.

# Arguments
- `F::AbstractFlow`: First flow.
- `g::Tuple{ctNumber,AbstractFlow}`: Switching time and second flow.

# Returns
- A new flow that transitions from `F` to `G` at `t_switch`.

# Example
```julia-repl
julia> F * (1.0, G)
```
"""
function concatenate(F::TF, g::Tuple{ctNumber,TF})::TF where {TF<:AbstractFlow}
    t_switch, G = g
    rhs! = __concat_rhs(F, G, t_switch)       # concatenation of the right and sides
    tstops = __concat_tstops(F, G, t_switch)    # times to break integration
    jumps = __concat_jumps(F, G) # jumps
    return TF(F.f, rhs!, tstops, jumps)  # we choose default values and options of F
end

"""
$(TYPEDSIGNATURES)

Concatenate two `AbstractFlow`s and insert a jump at the switching time.

# Arguments
- `F::AbstractFlow`
- `g::Tuple{ctNumber,Any,AbstractFlow}`: `(t_switch, η_switch, G)`

# Returns
- A concatenated flow with the jump included.

# Example
```julia-repl
julia> F * (1.0, η, G)
```
"""
function concatenate(F::TF, g::Tuple{ctNumber,Any,TF})::TF where {TF<:AbstractFlow}
    t_switch, η_switch, G = g
    rhs! = __concat_rhs(F, G, t_switch)       # concatenation of the right and sides
    tstops = __concat_tstops(F, G, t_switch)    # times to break integration
    jumps = __concat_jumps(F, G, (t_switch, η_switch)) # jumps
    return TF(F.f, rhs!, tstops, jumps)  # we choose default values and options of F
end

# --------------------------------------------------------------------------------------------
"""
$(TYPEDSIGNATURES)

Concatenate two `OptimalControlFlow`s at a switching time.

# Arguments
- `F::OptimalControlFlow`
- `g::Tuple{ctNumber,OptimalControlFlow}`

# Returns
- A combined flow with switched dynamics and feedback control.

# Example
```julia-repl
julia> F * (1.0, G)
```
"""
function concatenate(F::TF, g::Tuple{ctNumber,TF})::TF where {TF<:OptimalControlFlow}
    t_switch, G = g
    rhs! = __concat_rhs(F, G, t_switch)               # concatenation of the right and sides
    tstops = __concat_tstops(F, G, t_switch)            # times to break integration
    feedback_u = __concat_feedback_control(F, G, t_switch)  # concatenation of the feedback control
    jumps = __concat_jumps(F, G) # jumps
    return OptimalControlFlow(F.f, rhs!, feedback_u, F.ocp, F.kwargs_Flow, tstops, jumps) # we choose default values and options of F
end

"""
$(TYPEDSIGNATURES)

Concatenate two `OptimalControlFlow`s and a jump at switching time.

# Arguments
- `F::OptimalControlFlow`
- `g::Tuple{ctNumber,Any,OptimalControlFlow}`

# Returns
- A combined flow with jump and control law switching.

# Example
```julia-repl
julia> F * (1.0, η, G)
```
"""
function concatenate(F::TF, g::Tuple{ctNumber,Any,TF})::TF where {TF<:OptimalControlFlow}
    t_switch, η_switch, G = g
    rhs! = __concat_rhs(F, G, t_switch)               # concatenation of the right and sides
    tstops = __concat_tstops(F, G, t_switch)            # times to break integration
    feedback_u = __concat_feedback_control(F, G, t_switch)  # concatenation of the feedback control
    jumps = __concat_jumps(F, G, (t_switch, η_switch)) # jumps
    return OptimalControlFlow(F.f, rhs!, feedback_u, F.ocp, F.kwargs_Flow, tstops, jumps)  # we choose default values and options of F
end

"""
$(TYPEDSIGNATURES)

Shorthand for `concatenate(F, g)` when `g` is a tuple `(t_switch, G)`.

# Arguments
- `F::AbstractFlow`: The first flow.
- `g::Tuple{ctNumber, AbstractFlow}`: Tuple containing the switching time and second flow.

# Returns
- A new flow that switches from `F` to `G` at `t_switch`.

# Example
```julia-repl
julia> F * (1.0, G)
```
"""
*(F::TF, g::Tuple{ctNumber,TF}) where {TF<:AbstractFlow} = concatenate(F, g)

"""
$(TYPEDSIGNATURES)

Shorthand for `concatenate(F, g)` when `g` is a tuple `(t_switch, η_switch, G)` including a jump.

# Arguments
- `F::AbstractFlow`: The first flow.
- `g::Tuple{ctNumber, Any, AbstractFlow}`: Tuple with switching time, jump value, and second flow.

# Returns
- A flow with a jump at `t_switch` and a switch from `F` to `G`.

# Example
```julia-repl
julia> F * (1.0, η, G)
```
"""
*(F::TF, g::Tuple{ctNumber,Any,TF}) where {TF<:AbstractFlow} = concatenate(F, g)
