"""
$(TYPEDEF)

Abstract type for all flows in CTFlows.

An `AbstractFlow` is a callable object that combines an `AbstractSystem` with an
`AbstractODEIntegrator`. It carries no business logic of its own — its job is
to expose the integration protocol.

# Contract

All subtypes must implement:
- `(flow)(config)`: Integrate according to the given config (e.g. `PointConfig`, `TrajectoryConfig`).
- `system(flow)`: Return the associated `AbstractSystem`.
- `integrator(flow)`: Return the associated `AbstractODEIntegrator`.

Convenience call signatures like `(flow)(t0, x0, tf)` or `(flow)((t0, tf), x0)`
are provided by concrete subtypes (see `Flow`).

See also: [`Flow`](@ref), [`AbstractSystem`](@ref), [`AbstractODEIntegrator`](@ref).
"""
abstract type AbstractFlow end

"""
$(TYPEDSIGNATURES)

Integrate the flow according to the given `config`.

# Throws
- `CTBase.Exceptions.NotImplemented`: If not implemented by the concrete type.

See also: [`AbstractFlow`](@ref).
"""
function (flow::AbstractFlow)(config)
    throw(Exceptions.NotImplemented(
        "AbstractFlow callable not implemented";
        required_method = "(flow::$(typeof(flow)))(config)",
        suggestion = "Implement (f::YourFlow)(config) returning the integrated trajectory.",
        context = "AbstractFlow call - required method implementation",
    ))
end

"""
$(TYPEDSIGNATURES)

Return the variable-dependence trait of the flow (delegates to its system).
"""
variable_dependence(flow::AbstractFlow) = Systems.variable_dependence(system(flow))

"""
$(TYPEDSIGNATURES)

Return the associated `AbstractSystem` for the flow.

# Throws
- `CTBase.Exceptions.NotImplemented`: If not implemented by the concrete type.

See also: [`AbstractFlow`](@ref), [`AbstractSystem`](@ref).
"""
function system(flow::AbstractFlow)
    throw(Exceptions.NotImplemented(
        "AbstractFlow system method not implemented";
        required_method = "system(flow::$(typeof(flow)))",
        suggestion = "Return the AbstractSystem associated with this flow.",
        context = "AbstractFlow.system - required method implementation",
    ))
end

"""
$(TYPEDSIGNATURES)

Return the associated `AbstractODEIntegrator` for the flow.

# Throws
- `CTBase.Exceptions.NotImplemented`: If not implemented by the concrete type.

See also: [`AbstractFlow`](@ref), [`AbstractODEIntegrator`](@ref).
"""
function integrator(flow::AbstractFlow)
    throw(Exceptions.NotImplemented(
        "AbstractFlow integrator method not implemented";
        required_method = "integrator(flow::$(typeof(flow)))",
        suggestion = "Return the AbstractODEIntegrator associated with this flow.",
        context = "AbstractFlow.integrator - required method implementation",
    ))
end

"""
$(TYPEDSIGNATURES)

Display the flow in tree-style format.

# Example
```julia-repl
julia> using CTFlows.Flows

julia> flow = Flow(system, integrator)
Flow
  system: FakeSystem(n_x=2, n_p=2)
  integrator: FakeIntegrator
```
"""
function Base.show(io::IO, ::MIME"text/plain", flow::AbstractFlow)
    print(io, typeof(flow).name)
    sys = try
        system(flow)
    catch
        nothing
    end
    integ = try
        integrator(flow)
    catch
        nothing
    end
    if !isnothing(sys)
        print(io, "\n  system: ", sys)
    end
    if !isnothing(integ)
        print(io, "\n  integrator: ", typeof(integ).name)
    end
end

"""
$(TYPEDSIGNATURES)

Compact display of the flow.

# Example
```julia-repl
julia> using CTFlows.Flows

julia> flow = Flow(system, integrator)
Flow(system=FakeSystem(n_x=2, n_p=2), integrator=FakeIntegrator)
```
"""
function Base.show(io::IO, flow::AbstractFlow)
    sys = try
        system(flow)
    catch
        nothing
    end
    integ = try
        integrator(flow)
    catch
        nothing
    end
    print(io, typeof(flow).name, "(")
    parts = String[]
    if !isnothing(sys)
        push!(parts, "system=$(sys)")
    end
    if !isnothing(integ)
        push!(parts, "integrator=$(typeof(integ).name)")
    end
    print(io, join(parts, ", "))
    print(io, ")")
end
