# =============================================================================
# Normalization helpers (OCP — pass-through or wrap)
# =============================================================================

"""
Normalize a function to a VectorField or pass through existing VectorField.

# Arguments
- `f::Function`: Function to wrap as VectorField.
- `::Type{TD}`: Time dependence type.
- `::Type{VD}`: Variable dependence type.

# Returns
- `Data.VectorField`: Wrapped function or original VectorField.
"""
_as_vf(f::Function, ::Type{TD}, ::Type{VD}) where {TD, VD} =
    Data.VectorField(f, TD, VD, Traits.OutOfPlace)
_as_vf(vf::Data.AbstractVectorField, ::Type, ::Type) = vf

"""
Normalize a function to a Hamiltonian or pass through existing Hamiltonian.

# Arguments
- `f::Function`: Function to wrap as Hamiltonian.
- `::Type{TD}`: Time dependence type.
- `::Type{VD}`: Variable dependence type.

# Returns
- `Data.Hamiltonian`: Wrapped function or original Hamiltonian.
"""
_as_ham(f::Function, ::Type{TD}, ::Type{VD}) where {TD, VD} = Data.Hamiltonian(f, TD, VD)
_as_ham(h::Data.AbstractHamiltonian, ::Type, ::Type) = h

# =============================================================================
# Consistency checks (DRY — unified via Traits.time_dependence)
# =============================================================================

"""
Check time dependence consistency (no-op when not checking).

# Arguments
- `_`: Operand (unused).
- `::Type`: Target time dependence type (unused).
- `::Val{false}`: Not checking.

# Returns
- `nothing`
"""
_check_td(_, ::Type, ::Val{false}) = nothing

"""
Check time dependence consistency when `is_autonomous` is specified.

# Arguments
- `x`: Operand to check.
- `::Type{TDu}`: Target time dependence type.
- `::Val{true}`: Checking is enabled.

# Returns
- `nothing` if traits match.

# Throws
- `Exceptions.IncorrectArgument`: If traits conflict.
"""
function _check_td(x, ::Type{TDu}, ::Val{true}) where {TDu}
    x isa Function && return nothing  # Functions have no traits to check
    TD2 = Traits.time_dependence(x)
    TD2 === TDu || throw(Exceptions.IncorrectArgument(
        "@Lie: is_autonomous conflicts with operand trait";
        got=string(TDu), expected=string(TD2), context="@Lie consistency check"))
    return nothing  # Explicitly return nothing when traits match
end

"""
Check variable dependence consistency (no-op when not checking).

# Arguments
- `_`: Operand (unused).
- `::Type`: Target variable dependence type (unused).
- `::Val{false}`: Not checking.

# Returns
- `nothing`
"""
_check_vd(_, ::Type, ::Val{false}) = nothing

"""
Check variable dependence consistency when `is_variable` is specified.

# Arguments
- `x`: Operand to check.
- `::Type{VDu}`: Target variable dependence type.
- `::Val{true}`: Checking is enabled.

# Returns
- `nothing` if traits match.

# Throws
- `Exceptions.IncorrectArgument`: If traits conflict.
"""
function _check_vd(x, ::Type{VDu}, ::Val{true}) where {VDu}
    x isa Function && return nothing  # Functions have no traits to check
    VD2 = Traits.variable_dependence(x)
    VD2 === VDu || throw(Exceptions.IncorrectArgument(
        "@Lie: is_variable conflicts with operand trait";
        got=string(VDu), expected=string(VD2), context="@Lie consistency check"))
    return nothing  # Explicitly return nothing when traits match
end

# =============================================================================
# Runtime dispatch (KISS — single method each)
# =============================================================================

"""
Runtime dispatch for Lie bracket macro expansion.

Normalizes operands, checks trait consistency, and calls [`CTFlows.DifferentialGeometry.ad`](@ref).

# Arguments
- `a`: First operand.
- `b`: Second operand.
- `::Type{TD}`: Time dependence type.
- `::Type{VD}`: Variable dependence type.
- `has_aut::Val`: Whether to check time dependence.
- `has_var::Val`: Whether to check variable dependence.
- `backend`: AD backend expression.

# Returns
- Result of [`CTFlows.DifferentialGeometry.ad`](@ref) call.
"""
function _lie_mac(a, b, ::Type{TD}, ::Type{VD}, has_aut::Val, has_var::Val, backend) where {TD, VD}
    _check_td(a, TD, has_aut); _check_td(b, TD, has_aut)
    _check_vd(a, VD, has_var); _check_vd(b, VD, has_var)
    return ad(_as_vf(a, TD, VD), _as_vf(b, TD, VD); ad_backend=backend)
end

"""
Runtime dispatch for Poisson bracket macro expansion.

Normalizes operands, checks trait consistency, and calls [`CTFlows.DifferentialGeometry.Poisson`](@ref).

# Arguments
- `h`: First Hamiltonian operand.
- `g`: Second Hamiltonian operand.
- `::Type{TD}`: Time dependence type.
- `::Type{VD}`: Variable dependence type.
- `has_aut::Val`: Whether to check time dependence.
- `has_var::Val`: Whether to check variable dependence.
- `backend`: AD backend expression.

# Returns
- Result of [`CTFlows.DifferentialGeometry.Poisson`](@ref) call.
"""
function _poisson_mac(h, g, ::Type{TD}, ::Type{VD}, has_aut::Val, has_var::Val, backend) where {TD, VD}
    _check_td(h, TD, has_aut); _check_td(g, TD, has_aut)
    _check_vd(h, VD, has_var); _check_vd(g, VD, has_var)
    return Poisson(_as_ham(h, TD, VD), _as_ham(g, TD, VD); ad_backend=backend)
end

# =============================================================================
# Macro-time helpers (SRP — each has single responsibility)
# =============================================================================

"""
Parse keyword arguments for the @Lie macro.

# Arguments
- `pfx`: Package prefix symbol.
- `epfx`: Exception prefix symbol.
- `args...`: Keyword arguments to parse.

# Returns
- `NamedTuple`: Parsed options (TD, VD, has_aut, has_var, backend).
- `Expr`: Error expression if parsing failed, otherwise `nothing`.
"""
function __parse_lie_opts(pfx, epfx, args...)
    is_autonomous = Common.__is_autonomous(); has_aut = false
    is_variable   = Common.__is_variable();   has_var = false
    backend_expr  = :($pfx.DifferentialGeometry.__dg_ad_backend())

    for arg in args
        if arg isa Expr && (arg.head === :(=) || arg.head === :kw)
            key, val = arg.args[1], arg.args[2]
            if key === :is_autonomous
                is_autonomous = val; has_aut = true
            elseif key === :is_variable
                is_variable   = val; has_var = true
            elseif key === :ad_backend
                backend_expr  = val
            else
                msg = "@Lie: unknown keyword argument"
                got = string(key)
                exp = "is_autonomous, is_variable, or ad_backend"
                ctx = "@Lie macro keyword parsing"
                return nothing, :(throw($epfx.Exceptions.IncorrectArgument(
                    $msg; got=$got, expected=$exp, context=$ctx)))
            end
        else
            msg = "@Lie: invalid argument"
            got = string(arg)
            exp = "a keyword=value argument (e.g. is_autonomous=false)"
            ctx = "@Lie macro argument parsing"
            return nothing, :(throw($epfx.Exceptions.IncorrectArgument(
                $msg; got=$got, expected=$exp, context=$ctx)))
        end
    end
    TD = is_autonomous ? :Autonomous : :NonAutonomous
    VD = is_variable   ? :NonFixed   : :Fixed
    return (TD=TD, VD=VD, has_aut=has_aut, has_var=has_var, backend=backend_expr), nothing
end

"""
Check if an expression contains both Lie and Poisson brackets.

# Arguments
- `expr`: Expression to check.

# Returns
- `Bool`: `true` if both `[...]` and `{...}` are present.
"""
function __has_mixed_brackets(expr)
    has_lie = Ref(false); has_poisson = Ref(false)
    postwalk(expr) do e
        @capture(e, [_,_]) && (has_lie[]     = true)
        @capture(e, {_,_}) && (has_poisson[] = true)
        e
    end
    return has_lie[] && has_poisson[]
end

"""
Transform bracket expressions into macro dispatch calls.

Replaces `[a, b]` with calls to `_lie_mac` and `{a, b}` with calls to `_poisson_mac`.

# Arguments
- `expr`: Expression to transform.
- `opts`: NamedTuple with TD, VD, has_aut, has_var, backend.
- `pfx`: Package prefix symbol.

# Returns
- `Expr`: Transformed expression.
"""
function __transform_brackets(expr, opts, pfx)
    (; TD, VD, has_aut, has_var, backend) = opts
    postwalk(expr) do x
        if @capture(x, [a_, b_])
            return :($pfx.DifferentialGeometry._lie_mac(
                $a, $b, $pfx.Traits.$TD, $pfx.Traits.$VD,
                Val($has_aut), Val($has_var), $backend))
        elseif @capture(x, {c_, d_})
            return :($pfx.DifferentialGeometry._poisson_mac(
                $c, $d, $pfx.Traits.$TD, $pfx.Traits.$VD,
                Val($has_aut), Val($has_var), $backend))
        else
            return x
        end
    end
end

# =============================================================================
# Macro — thin orchestrator (3 active lines)
# =============================================================================

"""
$(TYPEDSIGNATURES)

Macro for Lie brackets and Poisson brackets with compile-time typed dispatch.

Transforms bracket expressions into calls to [`CTFlows.DifferentialGeometry.ad`](@ref) (Lie brackets) or [`CTFlows.DifferentialGeometry.Poisson`](@ref)
(Poisson brackets) with compile-time type dispatch based on keyword arguments.

# Syntax
- Lie brackets: `[X, Y]` — computes the Lie bracket or Lie derivative
- Poisson brackets: `{H, G}` — computes the Poisson bracket
- Nested brackets: `[[X, Y], Z]` or `{{H, G}, K}` — supported

# Arguments
- `expr::Expr`: Bracket expression using `[...]` for Lie or `{...}` for Poisson.
- `args...`: Optional keyword arguments:
  - `is_autonomous::Bool`: Override time dependence (default: from global config).
  - `is_variable::Bool`: Override variable dependence (default: from global config).
  - `ad_backend::Expr`: AD backend expression (default: global backend).

# Returns
- Expanded code calling [`CTFlows.DifferentialGeometry._lie_mac`](@ref) or [`CTFlows.DifferentialGeometry._poisson_mac`](@ref) with typed dispatch.

# Throws
- `Exceptions.IncorrectArgument`: If unknown keyword argument is provided.
- `Exceptions.IncorrectArgument`: If invalid argument format is used.
- `Exceptions.IncorrectArgument`: If Lie and Poisson brackets are mixed in the same expression.
- `Exceptions.IncorrectArgument`: If `is_autonomous` conflicts with operand trait.
- `Exceptions.IncorrectArgument`: If `is_variable` conflicts with operand trait.

# Example
```julia
using CTFlows.DifferentialGeometry

# Lie bracket with functions
X = x -> [x[2], -x[1]]
Y = x -> [-x[2], x[1]]
Z = @Lie [X, Y]

# Poisson bracket with functions
H = (x, p) -> p[1]^2 / 2 + x[1]^2
G = (x, p) -> x[1] * p[1]
B = @Lie {H, G}

# With explicit type override
Z = @Lie [X, Y] is_autonomous=true is_variable=false
```

# Notes
- The macro uses compile-time typed dispatch via [`CTFlows.DifferentialGeometry._lie_mac`](@ref) and [`CTFlows.DifferentialGeometry._poisson_mac`](@ref).
- Operands can be plain functions or typed objects ([`CTFlows.Data.VectorField`](@ref), [`CTFlows.Data.Hamiltonian`](@ref)).
- Mixed types (function + typed object) are automatically normalized.

See also: [`CTFlows.DifferentialGeometry.ad`](@ref), [`CTFlows.DifferentialGeometry.Poisson`](@ref), [`CTFlows.DifferentialGeometry.Lift`](@ref)
"""
macro Lie(expr::Expr, args...)
    pfx  = diffgeo_prefix()
    epfx = e_prefix()
    opts, err = __parse_lie_opts(pfx, epfx, args...)
    err !== nothing && return esc(err)
    if __has_mixed_brackets(expr)
        msg = "@Lie: cannot mix Lie brackets [...] and Poisson brackets {...}"
        sug = "use only [...] for Lie brackets, or only {...} for Poisson brackets"
        ctx = "@Lie macro expression validation"
        return esc(:(throw($epfx.Exceptions.IncorrectArgument(
            $msg; suggestion=$sug, context=$ctx))))
    end
    return esc(__transform_brackets(expr, opts, pfx))
end
