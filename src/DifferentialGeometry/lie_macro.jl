# =============================================================================
# Normalization helpers (OCP — pass-through or wrap)
# =============================================================================

_as_vf(f::Function, ::Type{TD}, ::Type{VD}) where {TD, VD} =
    Data.VectorField(f, TD, VD, Traits.OutOfPlace)
_as_vf(vf::Data.AbstractVectorField, ::Type, ::Type) = vf

_as_ham(f::Function, ::Type{TD}, ::Type{VD}) where {TD, VD} = Data.Hamiltonian(f, TD, VD)
_as_ham(h::Data.AbstractHamiltonian, ::Type, ::Type) = h

# =============================================================================
# Consistency checks (DRY — unified via Traits.time_dependence)
# =============================================================================

_check_td(_, ::Type, ::Val{false}) = nothing
function _check_td(x, ::Type{TDu}, ::Val{true}) where {TDu}
    x isa Function && return nothing  # Functions have no traits to check
    TD2 = Traits.time_dependence(x)
    TD2 === TDu || throw(Exceptions.IncorrectArgument(
        "@Lie: is_autonomous conflicts with operand trait";
        got=string(TDu), expected=string(TD2), context="@Lie consistency check"))
    return nothing  # Explicitly return nothing when traits match
end

_check_vd(_, ::Type, ::Val{false}) = nothing
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

function _lie_mac(a, b, ::Type{TD}, ::Type{VD}, has_aut::Val, has_var::Val, backend) where {TD, VD}
    _check_td(a, TD, has_aut); _check_td(b, TD, has_aut)
    _check_vd(a, VD, has_var); _check_vd(b, VD, has_var)
    return ad(_as_vf(a, TD, VD), _as_vf(b, TD, VD); ad_backend=backend)
end

function _poisson_mac(h, g, ::Type{TD}, ::Type{VD}, has_aut::Val, has_var::Val, backend) where {TD, VD}
    _check_td(h, TD, has_aut); _check_td(g, TD, has_aut)
    _check_vd(h, VD, has_var); _check_vd(g, VD, has_var)
    return Poisson(_as_ham(h, TD, VD), _as_ham(g, TD, VD); ad_backend=backend)
end

# =============================================================================
# Macro-time helpers (SRP — each has single responsibility)
# =============================================================================

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

function __has_mixed_brackets(expr)
    has_lie = Ref(false); has_poisson = Ref(false)
    postwalk(expr) do e
        @capture(e, [_,_]) && (has_lie[]     = true)
        @capture(e, {_,_}) && (has_poisson[] = true)
        e
    end
    return has_lie[] && has_poisson[]
end

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
