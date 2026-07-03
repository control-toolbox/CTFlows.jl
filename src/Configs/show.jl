# =============================================================================
# Base.show
# =============================================================================

"""
$(TYPEDSIGNATURES)

Display the `StateEndPointConfig` in tree-style format.
"""
function Base.show(io::IO, c::StateEndPointConfig)
    println(io, "StateEndPointConfig")
    println(io, "  t0: ", c.t0)
    println(io, "  x0: ", c.x0)
    return print(io, "  tf: ", c.tf)
end

"""
$(TYPEDSIGNATURES)

Display the `StateEndPointConfig` in REPL format.
"""
function Base.show(io::IO, ::MIME"text/plain", c::StateEndPointConfig)
    return show(io, c)
end

"""
$(TYPEDSIGNATURES)

Display the `StateTrajectoryConfig` in tree-style format.
"""
function Base.show(io::IO, c::StateTrajectoryConfig)
    println(io, "StateTrajectoryConfig")
    println(io, "  tspan: ", c.tspan)
    return print(io, "  x0: ", c.x0)
end

"""
$(TYPEDSIGNATURES)

Display the `StateTrajectoryConfig` in REPL format.
"""
function Base.show(io::IO, ::MIME"text/plain", c::StateTrajectoryConfig)
    return show(io, c)
end

"""
$(TYPEDSIGNATURES)

Display the `HamiltonianEndPointConfig` in tree-style format.
"""
function Base.show(io::IO, c::HamiltonianEndPointConfig)
    println(io, "HamiltonianEndPointConfig")
    println(io, "  t0: ", c.t0)
    println(io, "  x0: ", c.x0)
    println(io, "  p0: ", c.p0)
    return print(io, "  tf: ", c.tf)
end

"""
$(TYPEDSIGNATURES)

Display the `HamiltonianEndPointConfig` in REPL format.
"""
function Base.show(io::IO, ::MIME"text/plain", c::HamiltonianEndPointConfig)
    return show(io, c)
end

"""
$(TYPEDSIGNATURES)

Display the `HamiltonianTrajectoryConfig` in tree-style format.
"""
function Base.show(io::IO, c::HamiltonianTrajectoryConfig)
    println(io, "HamiltonianTrajectoryConfig")
    println(io, "  tspan: ", c.tspan)
    println(io, "  x0: ", c.x0)
    return print(io, "  p0: ", c.p0)
end

"""
$(TYPEDSIGNATURES)

Display the `HamiltonianTrajectoryConfig` in REPL format.
"""
function Base.show(io::IO, ::MIME"text/plain", c::HamiltonianTrajectoryConfig)
    return show(io, c)
end

"""
$(TYPEDSIGNATURES)

Display the `AugmentedHamiltonianEndPointConfig` in tree-style format.
"""
function Base.show(io::IO, c::AugmentedHamiltonianEndPointConfig)
    println(io, "AugmentedHamiltonianEndPointConfig")
    println(io, "  t0: ", c.t0)
    println(io, "  x0: ", c.x0)
    println(io, "  p0: ", c.p0)
    println(io, "  pv0: ", c.pv0)
    return print(io, "  tf: ", c.tf)
end

"""
$(TYPEDSIGNATURES)

Display the `AugmentedHamiltonianEndPointConfig` in REPL format.
"""
function Base.show(io::IO, ::MIME"text/plain", c::AugmentedHamiltonianEndPointConfig)
    return show(io, c)
end
