"""
$(TYPEDEF)

Abstract type for all systems in CTFlows.

An `AbstractSystem` represents a fully assembled object that can be integrated.
It embeds its own `rhs!`, dimensional metadata, and solution-building logic.

# Contract

All subtypes must implement:
- `rhs!(system::AbstractSystem)`: Returns a function `(du, u, p, t) -> nothing` that fills `du` in place.
- `dimensions(system::AbstractSystem)`: Returns a `NamedTuple` with dimension fields (e.g., `(n_x=n, n_p=n, n_u=m, n_v=k)`).
- `build_solution(system::AbstractSystem, ode_sol)`: Packages the raw ODE trajectory into the appropriate result.

See also: [`rhs!`](@ref), [`dimensions`](@ref), [`build_solution`](@ref).
"""
abstract type AbstractSystem end

"""
$(TYPEDSIGNATURES)

Return the right-hand side function for the system.

The returned function must have the signature `(du, u, p, t) -> nothing` and
fill `du` in place with the derivative at state `u`, parameters `p`, and time `t`.

# Throws
- `CTBase.Exceptions.NotImplemented`: If not implemented by the concrete type.

See also: [`AbstractSystem`](@ref).
"""
function rhs!(sys::AbstractSystem)
    throw(
        Exceptions.NotImplemented(
            "rhs! not implemented for $(typeof(sys))";
            required_method = "rhs!(sys::AbstractSystem)",
            suggestion = "Implement rhs! for $(typeof(sys)) to return the right-hand side function",
            context = "AbstractSystem - required method implementation",
        ),
    )
end

"""
$(TYPEDSIGNATURES)

Return the dimensional information for the system.

Returns a `NamedTuple` containing dimension fields such as:
- `n_x`: state dimension
- `n_p`: costate dimension
- `n_u`: control dimension
- `n_v`: variable dimension

# Throws
- `CTBase.Exceptions.NotImplemented`: If not implemented by the concrete type.

See also: [`AbstractSystem`](@ref).
"""
function dimensions(system::AbstractSystem)
    throw(Exceptions.NotImplemented(
        "AbstractSystem dimensions method not implemented";
        required_method = "dimensions(system::$(typeof(system)))",
        suggestion = "Return a NamedTuple, e.g. (n_x=n, n_p=n, n_u=m, n_v=k).",
        context = "AbstractSystem.dimensions - required method implementation",
    ))
end

"""
$(TYPEDSIGNATURES)

Package the raw ODE solution into the appropriate result type.

For raw systems (vector field), this returns the trajectory as-is.
For OCP systems, this integrates the Lagrange cost, reconstructs the control,
and returns a `CTModels.Solution`.

# Throws
- `CTBase.Exceptions.NotImplemented`: If not implemented by the concrete type.

See also: [`AbstractSystem`](@ref).
"""
function build_solution(system::AbstractSystem, ode_sol)
    throw(Exceptions.NotImplemented(
        "AbstractSystem build_solution method not implemented";
        required_method = "build_solution(system::$(typeof(system)), ode_sol)",
        suggestion = "Package the raw ODE trajectory into the appropriate result (raw trajectory or CTModels.Solution).",
        context = "AbstractSystem.build_solution - required method implementation",
    ))
end

"""
$(TYPEDSIGNATURES)

Display the system in tree-style format.

# Example
```julia-repl
julia> using CTFlows.Systems

julia> system = FakeSystem(2)
FakeSystem
  n_x: 2
  n_p: 2
```
"""
function Base.show(io::IO, ::MIME"text/plain", system::AbstractSystem)
    print(io, typeof(system).name)
    dims = try
        dimensions(system)
    catch
        nothing
    end
    if !isnothing(dims)
        for (k, v) in pairs(dims)
            print(io, "\n  ", k, ": ", v)
        end
    end
end

"""
$(TYPEDSIGNATURES)

Compact display of the system.

# Example
```julia-repl
julia> using CTFlows.Systems

julia> system = FakeSystem(2)
FakeSystem(n_x=2, n_p=2)
```
"""
function Base.show(io::IO, system::AbstractSystem)
    dims = try
        dimensions(system)
    catch
        nothing
    end
    if isnothing(dims)
        print(io, typeof(system).name, "(…)")
    else
        dim_str = join(["$k=$v" for (k, v) in pairs(dims)], ", ")
        print(io, typeof(system).name, "(", dim_str, ")")
    end
end
