# =============================================================================
# Panel — the engine's single, domain-free input unit
# =============================================================================

"""
$(TYPEDEF)

A logical group of time series to be rendered as one block (e.g. all state components,
or all control components). Domain-free: the case layer decides what a panel *means*.

# Fields
- `title::String`: the panel title (column title in `:split`, subplot title in `:group`).
- `labels::Vector{String}`: one name per component — the per-component **ylabel** in
  `:split`, and the legend entry in `:group`. An empty string draws no ylabel.
- `data::Matrix{Float64}`: sampled values, shape `(n_times, n_components)`.
- `style::NamedTuple`: series attributes splatted last so they override the defaults.
  A panel that should not be drawn is simply omitted by the case layer (there is no
  `:none` sentinel at the engine level).
"""
struct Panel
    title::String
    labels::Vector{String}
    data::Matrix{Float64}
    style::NamedTuple
end

# =============================================================================
# Replaceable defaults (double-underscore = semantic default a caller may override)
# =============================================================================

"""
$(TYPEDSIGNATURES)

Default overall layout: `:split` (one subplot per component). The alternative is
`:group` (one subplot per panel, components overlaid).
"""
__layout() = :split

"""
$(TYPEDSIGNATURES)

Default time-axis handling: `:default` (real time). Alternatives: `:normalize` /
`:normalise` (rescale the time grid to `[0, 1]`).
"""
__time() = :default

"""
$(TYPEDSIGNATURES)

Default series style: an empty `NamedTuple` (no override).
"""
__style() = NamedTuple()

# Default fonts, kept consistent across the engine.
const _TITLE_FONT = Plots.font(10, Plots.default(:fontfamily))
const _LABEL_FONT_SIZE = 10
