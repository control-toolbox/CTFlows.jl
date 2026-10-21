# Patches shared by the probes: see p2_rhs_paths.jl for the modes.
@eval Flows _check_host_arrays(device, ad, host) = nothing

if MODE == "fixA"
    @eval Systems begin
        _ham_split(u::Vector, N::Int) = (u[1:N], u[(N + 1):2N])
        _ham_split(u::Matrix, N::Int) = (u[1:N, :], u[(N + 1):2N, :])
        _aug_split(u::Vector, n_x::Int, n_v::Int) =
            (u[1:n_x], u[(n_x + 1):(2 * n_x)], u[(end - n_v + 1):end])
    end
elseif MODE == "fixB"
    @eval EXT begin
        _materialize(::ADTypes.AutoMooncake, x::SubArray{<:Any,<:Any,<:Array}) = copy(x)
        _materialize(ad, x) = x
        _derivator(::Type{<:SubArray}) = (f, ad, x) -> DI.gradient(f, ad, _materialize(ad, x))
    end
end

if MODE == "fixB2"
    # like fixB, but every array argument is materialized before the closures capture it
    @eval EXT begin
        _materialize(::ADTypes.AutoMooncake, x::SubArray{<:Any,<:Any,<:Array}) = copy(x)
        _materialize(ad, x) = x
        function Differentiation.hamiltonian_gradient(
            backend::Differentiation.DifferentiationInterface,
            h::Data.AbstractHamiltonian, t, x, p, v,
        )
            di_backend = _checked_backend(backend)
            x = _materialize(di_backend, x)
            p = _materialize(di_backend, p)
            h_x(x_) = h(t, x_, p, v)
            h_p(p_) = h(t, x, p_, v)
            return (_derivator(typeof(x))(h_x, di_backend, x), _derivator(typeof(p))(h_p, di_backend, p))
        end
    end
end
