# =============================================================================
# Output grids of trajectories: regrid, and generated grids (issue #435)
# =============================================================================

"""
$(TYPEDSIGNATURES)

Return the trajectory on another output grid; the integration result (and its interpolant)
is shared. See [`CTSolvers.Integrators.regrid`](@extref).
"""
function Integrators.regrid(sol::VectorFieldTrajectory, grid::AbstractVector{<:Real})
    return VectorFieldTrajectory(Integrators.regrid(sol.result, grid), sol.variable, sol.x0)
end

"""
$(TYPEDSIGNATURES)

Return the Hamiltonian trajectory on another output grid; the integration result (and its
interpolant) is shared. See [`CTSolvers.Integrators.regrid`](@extref).
"""
function Integrators.regrid(
    sol::HamiltonianVectorFieldTrajectory, grid::AbstractVector{<:Real}
)
    return HamiltonianVectorFieldTrajectory(
        sol.x0, Integrators.regrid(sol.result, grid), sol.variable
    )
end

# ── generated grids ──────────────────────────────────────────────────────────

"""
$(TYPEDSIGNATURES)

Generate the output grid `spec` on the phases delimited by `bounds` (`[t0, t₁, …, tf]`, in
integration order): exactly `spec.n` distinct times, every bound included once.

`curve(t)` returns the plotted values at `t` as a vector (state, costate, control);
`steps` are the solver times, used as the pre-grid of an
[`CTFlows.Configs.AdaptiveGrid`](@extref). The `n - 1` intervals are shared between the
phases in proportion to their mass (duration for a uniform grid), at least one per phase.

# Throws
- `CTBase.Exceptions.IncorrectArgument`: If `spec.n` is smaller than the number of bounds.
"""
function generate_grid(spec::Configs.AbstractGrid, curve, steps, bounds::AbstractVector)
    nphases = length(bounds) - 1
    if spec.n < nphases + 1
        throw(
            Exceptions.IncorrectArgument(
                "The generated grid is too small for the number of phases";
                got="n=$(spec.n) for $(nphases) phases",
                expected="n ≥ $(nphases + 1) (one interval per phase at least)",
                context="generated output grid",
            ),
        )
    end
    tables = [_cdf_table(spec, curve, steps, bounds[i], bounds[i + 1]) for i in 1:nphases]
    counts = _share_intervals([table.mass for table in tables], spec.n - 1)
    grid = Float64[]
    for (i, table) in enumerate(tables)
        part = _invert_cdf(table.F, table.T, counts[i] + 1)
        append!(grid, i == 1 ? part : part[2:end])
    end
    return grid
end

"""
$(TYPEDSIGNATURES)

Uniform cumulative distribution on the phase `[a, b]`; its mass is the duration.
"""
_cdf_table(::Configs.UniformGrid, curve, steps, a, b) =
    (F=[0.0, 1.0], T=[Float64(a), Float64(b)], mass=abs(b - a))

"""
$(TYPEDSIGNATURES)

Cumulative distribution on the phase `[a, b]` of the curvature density
`ρ ∝ ‖ỹ''‖^{1/2}` of the scaled plotted curves, mixed with the uniform density, tabulated on
the solver steps subdivided in 8. Components with a negligible range are ignored, and so
are negligible curvatures (`_NEGLIGIBLE_CURVATURE`); with no curvature at all the
distribution is uniform.
"""
function _cdf_table(spec::Configs.AdaptiveGrid, curve, steps, a, b)
    T = _pre_grid(steps, a, b, 8)
    Y = reduce(hcat, [_curve_in_phase(curve, t, a, b) for t in T])
    Yn = _scale_rows(Y)
    τ = (T .- a) ./ (b - a)
    n = length(T)
    ρ = zeros(n)
    for j in 2:(n - 1)
        h1, h2 = τ[j] - τ[j - 1], τ[j + 1] - τ[j]
        d2 = 2 .* ((Yn[:, j + 1] .- Yn[:, j]) ./ h2 .- (Yn[:, j] .- Yn[:, j - 1]) ./ h1) ./ (h1 + h2)
        κ = sqrt(sum(abs2, d2))
        ρ[j] = κ > _NEGLIGIBLE_CURVATURE ? sqrt(κ) : 0.0
    end
    n > 2 && (ρ[1] = ρ[2]; ρ[n] = ρ[n - 1])
    s = vcat(0.0, cumsum([(ρ[j] + ρ[j + 1]) / 2 * (τ[j + 1] - τ[j]) for j in 1:(n - 1)]))
    Fc = s[end] > 0 ? s ./ s[end] : τ
    u = spec.uniform
    return (F=(1 - u) .* Fc .+ u .* τ, T=T, mass=(1 - u) * s[end] + u)
end

"""
Curvature below which the scaled curves are considered straight. The curves are scaled to
a unit range over a unit time, where a significant bend has a curvature of order one; the
finite-difference rounding noise on a straight segment, amplified by the square roots of
the density, would otherwise drive the whole grid.
"""
const _NEGLIGIBLE_CURVATURE = 1e-6

"""
$(TYPEDSIGNATURES)

Pre-grid of the phase `[a, b]`: the solver steps inside it, each interval subdivided in `k`,
in integration order.
"""
function _pre_grid(steps, a, b, k::Int)
    lo, hi = minmax(a, b)
    S = sort!(unique!(vcat(Float64(a), filter(t -> lo < t < hi, steps), Float64(b))); rev=b < a)
    return unique!(reduce(vcat, [collect(range(S[i], S[i + 1], k + 1)) for i in 1:(length(S) - 1)]))
end

"""
$(TYPEDSIGNATURES)

Evaluate the plotted curve inside the phase `[a, b]`: at the phase start, slightly inside,
so that the right limit is read after a jump (the trajectory is left-continuous).
"""
_curve_in_phase(curve, t, a, b) = curve(t == a ? a + 1e-12 * (b - a) : t)

"""
$(TYPEDSIGNATURES)

Scale every row (component) by its range; a component whose range is negligible with
respect to its size is constant and gets a zero row (otherwise its rounding noise would
dominate the density).
"""
function _scale_rows(Y::AbstractMatrix)
    out = zeros(size(Y))
    for (i, row) in enumerate(eachrow(Y))
        range_i = maximum(row) - minimum(row)
        range_i > 1e-8 * max(1.0, maximum(abs, row)) && (out[i, :] .= row ./ range_i)
    end
    return out
end

"""
$(TYPEDSIGNATURES)

Share `total` intervals between phases in proportion to `masses` (largest remainder), at
least one per phase.
"""
function _share_intervals(masses::AbstractVector, total::Int)
    m = sum(masses) > 0 ? masses ./ sum(masses) : fill(1 / length(masses), length(masses))
    share = m .* total
    counts = max.(1, floor.(Int, share))
    while sum(counts) < total
        counts[argmax(share .- counts)] += 1
    end
    while sum(counts) > total
        i = argmax([c > 1 ? c - s : -Inf for (c, s) in zip(counts, share)])
        counts[i] -= 1
    end
    return counts
end

"""
$(TYPEDSIGNATURES)

Invert the tabulated cumulative distribution `F` (non-decreasing, from 0 to 1) over the
times `T` at `n` equally spaced levels; the bounds are exact.
"""
function _invert_cdf(F::AbstractVector, T::AbstractVector, n::Int)
    out = Vector{Float64}(undef, n)
    j = 1
    for (k, level) in enumerate(range(0, 1, n))
        while j < length(F) - 1 && F[j + 1] < level
            j += 1
        end
        w = F[j + 1] > F[j] ? (level - F[j]) / (F[j + 1] - F[j]) : 0.0
        out[k] = T[j] + clamp(w, 0, 1) * (T[j + 1] - T[j])
    end
    out[1], out[n] = T[1], T[end]
    return out
end

"""
$(TYPEDSIGNATURES)

Flatten a plotted value (number or array) into a vector of floats.
"""
_flat(v::Number) = [Float64(v)]
_flat(v::AbstractArray) = vec(Float64.(v))
_flat(::Nothing) = Float64[]

"""
$(TYPEDSIGNATURES)

Plotted curve `t -> [x(t); p(t); u(t)]` from callables (`nothing` entries are skipped).
"""
_plotted_curve(fs...) = t -> reduce(vcat, (_flat(f(t)) for f in fs if f !== nothing); init=Float64[])

"""
$(TYPEDSIGNATURES)

Apply the output grid of a call to a trajectory (or integration result): unchanged without
a generated grid; otherwise generate it from `curve` over `bounds` (the solver times of
`traj` as pre-grid) and regrid.
"""
apply_generated_grid(traj, ::Union{Nothing,AbstractVector}, curve, bounds) = traj
function apply_generated_grid(traj, spec::Configs.AbstractGrid, curve, bounds)
    steps = unique(Integrators.times(traj))
    return Integrators.regrid(traj, generate_grid(spec, curve, steps, bounds))
end
