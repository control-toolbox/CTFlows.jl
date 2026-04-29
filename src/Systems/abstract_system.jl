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
function rhs!(system::AbstractSystem)
    throw(
        Exceptions.NotImplemented(
            "AbstractSystem rhs! method not implemented";
            required_method = "rhs!(system::$(typeof(system)))",
            suggestion = "Return a function (du, u, p, t) -> nothing that fills du in place.",
            context = "AbstractSystem.rhs! - required method implementation",
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

This ensures that systems must implement their own solution building logic.
"""
function build_solution(sys::AbstractSystem, ode_sol, flow, config)
    throw(Exceptions.NotImplemented("build_solution"))
end

"""
$(TYPEDSIGNATURES)

Build an `ODEProblem` for the given system and integration config.

# Throws
- `CTBase.Exceptions.NotImplemented`: If not implemented by the concrete type.
"""
function ode_problem(system::AbstractSystem, config; kwargs...)
    throw(Exceptions.NotImplemented(
        "AbstractSystem ode_problem method not implemented";
        required_method = "ode_problem(system::$(typeof(system)), config::$(typeof(config)); kwargs...)",
        suggestion = "Implementation for VectorFieldSystem is provided by the CTFlowsSciMLExt package extension. Load OrdinaryDiffEqTsit5 (or a superset) to activate it.",
        context = "AbstractSystem.ode_problem - required method implementation",
    ))
end

"""
$(TYPEDSIGNATURES)

Return the variable-dependence trait (`Fixed` or `NonFixed`) of the system.

By default systems are `Fixed`. Subtypes that depend on a variable (e.g.
`VectorFieldSystem` parameterised on `NonFixed`) must override this method.
"""
variable_dependence(::Type{<:AbstractSystem}) = Fixed
variable_dependence(system::AbstractSystem) = variable_dependence(typeof(system))

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
