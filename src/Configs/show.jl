# =============================================================================
# Base.show
# =============================================================================

"""
$(TYPEDSIGNATURES)

Display the `StateEndPointConfig` in tree-style format.
"""
function Base.show(io::IO, c::StateEndPointConfig)
    fmt = Display.format_codes(io)
    Display.print_header(io, "StateEndPointConfig"; fmt=fmt)
    Display.print_field(io, "t0", c.t0; fmt=fmt)
    Display.print_field(io, "x0", c.x0; fmt=fmt)
    return Display.print_field(io, "tf", c.tf; last=true, fmt=fmt)
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
    fmt = Display.format_codes(io)
    Display.print_header(io, "StateTrajectoryConfig"; fmt=fmt)
    Display.print_field(io, "tspan", c.tspan; fmt=fmt)
    return Display.print_field(io, "x0", c.x0; last=true, fmt=fmt)
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
    fmt = Display.format_codes(io)
    Display.print_header(io, "HamiltonianEndPointConfig"; fmt=fmt)
    Display.print_field(io, "t0", c.t0; fmt=fmt)
    Display.print_field(io, "x0", c.x0; fmt=fmt)
    Display.print_field(io, "p0", c.p0; fmt=fmt)
    return Display.print_field(io, "tf", c.tf; last=true, fmt=fmt)
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
    fmt = Display.format_codes(io)
    Display.print_header(io, "HamiltonianTrajectoryConfig"; fmt=fmt)
    Display.print_field(io, "tspan", c.tspan; fmt=fmt)
    Display.print_field(io, "x0", c.x0; fmt=fmt)
    return Display.print_field(io, "p0", c.p0; last=true, fmt=fmt)
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
    fmt = Display.format_codes(io)
    Display.print_header(io, "AugmentedHamiltonianEndPointConfig"; fmt=fmt)
    Display.print_field(io, "t0", c.t0; fmt=fmt)
    Display.print_field(io, "x0", c.x0; fmt=fmt)
    Display.print_field(io, "p0", c.p0; fmt=fmt)
    Display.print_field(io, "pv0", c.pv0; fmt=fmt)
    return Display.print_field(io, "tf", c.tf; last=true, fmt=fmt)
end

"""
$(TYPEDSIGNATURES)

Display the `AugmentedHamiltonianEndPointConfig` in REPL format.
"""
function Base.show(io::IO, ::MIME"text/plain", c::AugmentedHamiltonianEndPointConfig)
    return show(io, c)
end
