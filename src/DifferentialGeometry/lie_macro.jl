macro Lie(expr::Expr, args...)
    # All options are runtime kwargs (spliced into generated call)
    is_autonomous_kw = nothing
    is_variable_kw   = nothing
    ad_backend_kw    = nothing

    for arg in args
        if @capture(arg, is_autonomous = val_)
            is_autonomous_kw = :(is_autonomous = $val)
        elseif @capture(arg, is_variable = val_)
            is_variable_kw = :(is_variable = $val)
        elseif @capture(arg, ad_backend = val_)
            ad_backend_kw = :(ad_backend = $val)
        end
    end

    prefix = diffgeo_prefix()
    extra_kws = filter(!isnothing, [is_autonomous_kw, is_variable_kw, ad_backend_kw])

    function fun(x)
        is_lie     = @capture(x, [a_, b_])
        is_poisson = @capture(x, {c_, d_})
        if is_lie
            return :($prefix.ad($a, $b; $(extra_kws...)))
        elseif is_poisson
            return :($prefix.Poisson($c, $d; $(extra_kws...)))
        else
            return x
        end
    end
    return esc(postwalk(fun, expr))
end
