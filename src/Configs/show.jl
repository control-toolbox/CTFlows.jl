# =============================================================================
# Base.show
# =============================================================================

"""
$(TYPEDSIGNATURES)

Display the `StatePointConfig` in tree-style format.
"""
function Base.show(io::IO, c::StatePointConfig)
    println(io, "StatePointConfig")
    println(io, "  t0: ", c.t0)
    println(io, "  x0: ", c.x0)
    print(io, "  tf: ", c.tf)
end

"""
$(TYPEDSIGNATURES)

Display the `StatePointConfig` in REPL format.
"""
function Base.show(io::IO, ::MIME"text/plain", c::StatePointConfig)
    show(io, c)
end

"""
$(TYPEDSIGNATURES)

Display the `StateTrajectoryConfig` in tree-style format.
"""
function Base.show(io::IO, c::StateTrajectoryConfig)
    println(io, "StateTrajectoryConfig")
    println(io, "  tspan: ", c.tspan)
    print(io, "  x0: ", c.x0)
end

"""
$(TYPEDSIGNATURES)

Display the `StateTrajectoryConfig` in REPL format.
"""
function Base.show(io::IO, ::MIME"text/plain", c::StateTrajectoryConfig)
    show(io, c)
end

"""
$(TYPEDSIGNATURES)

Display the `HamiltonianPointConfig` in tree-style format.
"""
function Base.show(io::IO, c::HamiltonianPointConfig)
    println(io, "HamiltonianPointConfig")
    println(io, "  t0: ", c.t0)
    println(io, "  x0: ", c.x0)
    println(io, "  p0: ", c.p0)
    print(io, "  tf: ", c.tf)
end

"""
$(TYPEDSIGNATURES)

Display the `HamiltonianPointConfig` in REPL format.
"""
function Base.show(io::IO, ::MIME"text/plain", c::HamiltonianPointConfig)
    show(io, c)
end

"""
$(TYPEDSIGNATURES)

Display the `HamiltonianTrajectoryConfig` in tree-style format.
"""
function Base.show(io::IO, c::HamiltonianTrajectoryConfig)
    println(io, "HamiltonianTrajectoryConfig")
    println(io, "  tspan: ", c.tspan)
    println(io, "  x0: ", c.x0)
    print(io, "  p0: ", c.p0)
end

"""
$(TYPEDSIGNATURES)

Display the `HamiltonianTrajectoryConfig` in REPL format.
"""
function Base.show(io::IO, ::MIME"text/plain", c::HamiltonianTrajectoryConfig)
    show(io, c)
end

"""
$(TYPEDSIGNATURES)

Display the `AugmentedHamiltonianPointConfig` in tree-style format.
"""
function Base.show(io::IO, c::AugmentedHamiltonianPointConfig)
    println(io, "AugmentedHamiltonianPointConfig")
    println(io, "  t0: ", c.t0)
    println(io, "  x0: ", c.x0)
    println(io, "  p0: ", c.p0)
    println(io, "  pv0: ", c.pv0)
    print(io, "  tf: ", c.tf)
end

"""
$(TYPEDSIGNATURES)

Display the `AugmentedHamiltonianPointConfig` in REPL format.
"""
function Base.show(io::IO, ::MIME"text/plain", c::AugmentedHamiltonianPointConfig)
    show(io, c)
end
