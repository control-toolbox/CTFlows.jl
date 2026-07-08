# =============================================================================
# Rendering — turn Panels + a time grid into a laid-out, styled figure
#
# A Panel is a *column*: a titled vertical stack of component-subplots. In :split the
# column title sits on the top subplot, each component's name is its ylabel, and the
# time name is the xlabel of the bottom subplot only (no legend). Columns are placed
# either stacked (one under another) or paired (side by side, e.g. state | costate).
# =============================================================================

# One component subplot to draw.
struct _Cell
    y::Vector{Float64}
    ylabel::String
    title::String        # only the top cell of a column carries the panel title
    is_last::Bool         # bottom cell of a column carries the time xlabel
    style::NamedTuple
end

# Compute the plotted time axis from the `time` option.
function _time_axis(times, time::Symbol)
    if time === :default
        return collect(float.(times))
    elseif time === :normalize || time === :normalise
        t0, tf = first(times), last(times)
        return tf > t0 ? collect((times .- t0) ./ (tf - t0)) : collect(float.(times .- t0))
    else
        throw(
            Exceptions.IncorrectArgument(
                "Invalid time normalization";
                got="time=$time",
                expected=":default, :normalize or :normalise",
                context="PlotEngine._time_axis",
            ),
        )
    end
end

# The component cells of one panel (column).
function _panel_cells(p::Panel)
    k = size(p.data, 2)
    return [
        _Cell(p.data[:, i], p.labels[i], i == 1 ? p.title : "", i == k, p.style) for
        i in 1:k
    ]
end

# Flatten panels into ordered cells + a Plots grid, per the placement.
# - :stacked → a single column of every panel's components, in order      → (Σk, 1)
# - :paired  → panels side by side, equal component counts, interleaved   → (k, P)
#   (falls back to :stacked if the panels do not share the same height).
function _cells_and_grid(panels::AbstractVector{Panel}, placement::Symbol)
    per_panel = _panel_cells.(panels)
    if placement === :paired && allequal(length.(per_panel))
        k, P = length(first(per_panel)), length(per_panel)
        cells = _Cell[per_panel[j][i] for i in 1:k for j in 1:P]   # row-major interleave
        return cells, (k, P)
    else
        cells = reduce(vcat, per_panel)
        return cells, (length(cells), 1)
    end
end

# Size heuristics share the same width and per-row height so the two layouts stay
# visually consistent (a :group figure has the height of a single :split row).
const _ROW_HEIGHT = 180
const _HEIGHT_PAD = 60
_width(cols::Integer) = max(600, 340 * cols)

"""
$(TYPEDSIGNATURES)

Default figure size for a `:split` grid `(rows, cols)`.
"""
__size_plot(grid::Tuple) = (_width(grid[2]), _ROW_HEIGHT * grid[1] + _HEIGHT_PAD)

"""
$(TYPEDSIGNATURES)

Default figure size for a `:group` layout with `n` panels (one subplot each). Same width
as `:split` for a single panel, and the height of a single `:split` row.
"""
__size_group(n::Integer) = (_width(max(n, 1)), _ROW_HEIGHT + _HEIGHT_PAD)

# y-range guard for a constant series (Plots would otherwise collapse the axis).
_ylims(y) = (lo=minimum(y); hi=maximum(y); (hi - lo) ≤ 1e-8 ? (lo - 1, hi + 1) : :auto)

# Draw the split cells into `p`, one per subplot (targeted with `subplot=i`).
function _fill_split!(p, x, time_name::String, cells::AbstractVector{_Cell}; kwargs...)
    for (i, c) in enumerate(cells)
        Plots.plot!(p, x, c.y; subplot=i, label="", legend=false, kwargs..., c.style...)
        Plots.plot!(
            p;
            subplot=i,
            title=c.title,
            ylabel=c.ylabel,
            xlabel=c.is_last ? time_name : "",
            ylims=_ylims(c.y),
            titlefont=_TITLE_FONT,
            guidefontsize=_LABEL_FONT_SIZE,
        )
    end
    return p
end

# Draw the group panels into `p`: one subplot per panel, components overlaid, a legend
# to tell them apart (there is no per-component subplot to hang an ylabel on).
function _fill_group!(p, x, time_name::String, panels::AbstractVector{Panel}; kwargs...)
    for (i, pan) in enumerate(panels)
        for j in 1:size(pan.data, 2)
            Plots.plot!(
                p,
                x,
                pan.data[:, j];
                subplot=i,
                label=pan.labels[j],
                kwargs...,
                pan.style...,
            )
        end
        Plots.plot!(
            p;
            subplot=i,
            title=pan.title,
            xlabel=time_name,
            ylims=_ylims(pan.data),
            titlefont=_TITLE_FONT,
            guidefontsize=_LABEL_FONT_SIZE,
        )
    end
    return p
end

function _new_plot(grid, size, plot_title; extra...)
    base = (; layout=grid, size=size, extra...)
    return if plot_title === nothing
        Plots.plot(; base...)
    else
        Plots.plot(; base..., plot_title=plot_title)
    end
end

# Margins so per-component ylabels (left) and the bottom time label are not clipped.
# CTModels uses leftmargin=3mm / bottommargin=5mm; we keep the 5mm bottom but need a
# little more on the left because our ylabels carry full OCP component names (e.g.
# "thrust"), longer than CTModels' generated "x₁"-style labels.
const _LEFT_MARGIN = 5 * Plots.Measures.mm
const _BOTTOM_MARGIN = 5 * Plots.Measures.mm

"""
$(TYPEDSIGNATURES)

Render `panels` sampled on `times` into a new `Plots.Plot`.

# Keyword arguments
- `layout`: `:split` (default; one subplot per component) or `:group` (one subplot per
  panel, components overlaid).
- `placement` (`:split` only): `:stacked` (panels in one column) or `:paired` (panels
  side by side, e.g. state | costate).
- `time`: `:default` or `:normalize`/`:normalise`.
- `time_name`: x-axis label (e.g. `"t"`).
- `size`: figure size; `nothing` uses a size heuristic.
- `plot_title`: overall figure title; `nothing` for none.
- other `kwargs...`: forwarded to every series.
"""
function render(
    times,
    panels::AbstractVector{Panel};
    layout::Symbol=__layout(),
    placement::Symbol=:stacked,
    time::Symbol=__time(),
    time_name::String="t",
    size=nothing,
    plot_title=nothing,
    kwargs...,
)
    isempty(panels) && throw(
        Exceptions.IncorrectArgument(
            "nothing to plot";
            got="no panels (empty description or every group styled :none)",
            expected="at least one group to draw",
            context="PlotEngine.render",
        ),
    )
    x = _time_axis(times, time)
    if layout === :split
        cells, grid = _cells_and_grid(panels, placement)
        p = _new_plot(
            grid,
            size === nothing ? __size_plot(grid) : size,
            plot_title;
            left_margin=_LEFT_MARGIN,
            bottom_margin=_BOTTOM_MARGIN,
        )
        return _fill_split!(p, x, time_name, cells; kwargs...)
    elseif layout === :group
        n = length(panels)
        p = _new_plot(
            (1, n),
            size === nothing ? __size_group(n) : size,
            plot_title;
            bottom_margin=_BOTTOM_MARGIN,
        )
        return _fill_group!(p, x, time_name, panels; kwargs...)
    else
        throw(
            Exceptions.IncorrectArgument(
                "Invalid layout";
                got="layout=$layout",
                expected=":split or :group",
                context="PlotEngine.render",
            ),
        )
    end
end

"""
$(TYPEDSIGNATURES)

Overlay `panels` onto an existing plot `p` (same layout/placement assumed), targeting
each existing subplot by index. Use it to compare several sets of trajectories.
"""
function render!(
    p,
    times,
    panels::AbstractVector{Panel};
    layout::Symbol=__layout(),
    placement::Symbol=:stacked,
    time::Symbol=__time(),
    time_name::String="t",
    kwargs...,
)
    x = _time_axis(times, time)
    if layout === :split
        cells, _ = _cells_and_grid(panels, placement)
        return _fill_split!(p, x, time_name, cells; kwargs...)
    elseif layout === :group
        return _fill_group!(p, x, time_name, panels; kwargs...)
    else
        throw(
            Exceptions.IncorrectArgument(
                "Invalid layout";
                got="layout=$layout",
                expected=":split or :group",
                context="PlotEngine.render!",
            ),
        )
    end
end
