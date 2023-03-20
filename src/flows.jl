# ---------------------------------------------------------------------------------------------------
#
struct ClassicalFlow{D, U, T}
    f::Function     # f(args..., rhs)
    rhs!::Function   # OrdinaryDiffEq rhs
    tstops::Times
    ClassicalFlow{D, U, T}(f, rhs!) where {D, U, T} = new{D, U, T}(f, rhs!, Vector{Time}())
    ClassicalFlow{D, U, T}(f, rhs!, tstops) where {D, U, T} = new{D, U, T}(f, rhs!, tstops)
end

# call F.f
(F::ClassicalFlow)(args...; kwargs...) = F.f(args...; _t_stops_interne=F.tstops, DiffEqRHS=F.rhs!, kwargs...)

# ---------------------------------------------------------------------------------------------------
#
# to specify D, U and T is useful to insure coherence for instance when concatenating two flows
struct OptimalControlFlow{D, U, T}
    # 
    f::Function      # the mere function which depends on the kind of flow (Hamiltonian or classical) 
                     # this function takes a right and side as input
    rhs!::Function   # the right and side of the form: rhs!(du::D, u::U, p, t::T)
    tstops::Times    # specific times where the integrator must stop
                     # useful when the rhs is not smooth at such times
    feedback_control::ControlFunction # the control law in feedback form, that is u(t, x, p)
    control_dimension::Dimension
    control_labels::Vector{String}
    state_dimension::Dimension
    state_labels::Vector{String}
    time_label::String

    # constructor
    function OptimalControlFlow{D, U, T}(f::Function, rhs!::Function, u::Function, m::Dimension, 
        u_labels::Vector{String}, n::Dimension, x_labels::Vector{String}, time_label::String,
        tstops::Times=Vector{Time}()) where {D, U, T} 
        return new{D, U, T}(f, rhs!, tstops, u, m, u_labels, n, x_labels, time_label)
    end

end

# call F.f
(F::OptimalControlFlow)(args...; kwargs...) = F.f(args...; _t_stops_interne=F.tstops, DiffEqRHS=F.rhs!, kwargs...)

# # call F.f and then, construct a solution which contains all the need information for plotting
function (F::OptimalControlFlow)(tspan::Tuple{Time,Time}, args...; kwargs...) 
    ode_sol = F.f(tspan, args...; _t_stops_interne=F.tstops, DiffEqRHS=F.rhs!, kwargs...)
    ocfs = OptimalControlFlowSolution(ode_sol, F.feedback_control, F.control_dimension,
            F.control_labels, F.state_dimension, F.state_labels, F.time_label)
    return ocfs
end