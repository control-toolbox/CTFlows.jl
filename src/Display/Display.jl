"""
    Display

Shared display helpers for CTFlows `Base.show` methods.

This submodule centralises the visual conventions used across CTFlows so that every
`show(io, ::MIME"text/plain", x)` renders consistently with the control-toolbox ecosystem
(CTBase, CTSolvers): a styled type-name header followed by tree-style branches
(`├─`, `└─`, `│`) and semantic colours drawn from the shared palette exposed by
[`CTBase.Core.get_format_codes`](@extref).

All helpers respect the `:color` `IOContext` flag automatically (through the palette
format codes), so the same call renders in colour on an interactive terminal and in plain
text when colour is disabled.

No symbol is exported: access everything through `Display.<symbol>`.
"""
module Display

# ==============================================================================
# External package imports
# ==============================================================================

import DocStringExtensions: TYPEDSIGNATURES
import CTBase.Core

# ==============================================================================
# Tree characters (styled with the `muted` palette role at print time)
# ==============================================================================

"""
$(TYPEDSIGNATURES)

Tree-branch prefix for a mid-list field (`├─ `), styled with the `muted` palette role at print time.
"""
const BRANCH_MID = "├─ "

"""
$(TYPEDSIGNATURES)

Tree-branch prefix for the last field in a list (`└─ `), styled with the `muted` palette role at print time.
"""
const BRANCH_END = "└─ "

"""
$(TYPEDSIGNATURES)

Return the palette format codes for `io`.

Thin wrapper over [`CTBase.Core.get_format_codes`](@extref); returns a `NamedTuple` of ANSI
escape strings (`name`, `type`, `value`, `keyword`, `count`, `label`, `muted`, `reset`, …)
that are empty when colour is disabled on `io`.
"""
format_codes(io::IO) = Core.get_format_codes(io)

"""
$(TYPEDSIGNATURES)

Print the styled type-name header (no trailing newline).

The `name` is rendered with the `name` palette role (bold blue by default).
"""
function print_header(io::IO, name; fmt=format_codes(io))
    print(io, fmt.name, name, fmt.reset)
    return nothing
end

"""
$(TYPEDSIGNATURES)

Print one tree branch `├─ label: value` (or `└─ ` when `last`) on its own line.

A leading newline is emitted so the caller prints the header first, then a sequence of
fields; no trailing newline is emitted, keeping the standard "no newline after the last
field" REPL convention. The branch character and label use the `muted`/`label` roles; the
value uses `value_style` (the `value` role by default). Pass `value_style = ""` to leave the
value unstyled.

When `value` renders on several lines (e.g. a nested object whose own `show` is multi-line),
continuation lines are indented under the branch character and prefixed with a `│` pipe
(blanks when `last`). `value` is rendered through `print` (so strings/symbols keep their
plain form and objects use their own `show`), preserving colour from `io`.
"""
function print_field(
    io::IO, label, value; last::Bool=false, fmt=format_codes(io), value_style=nothing
)
    style = value_style === nothing ? fmt.value : value_style
    reset = isempty(style) ? "" : fmt.reset
    prefix = last ? BRANCH_END : BRANCH_MID
    valstr = if value isa AbstractString
        value
    else
        sprint(print, value; context=IOContext(io, :color => get(io, :color, false)))
    end
    lines = split(valstr, "\n")
    print(io, "\n", fmt.muted, prefix, fmt.reset)
    isempty(string(label)) || print(io, fmt.label, label, fmt.reset, ": ")
    print(io, style, lines[1], reset)
    if length(lines) > 1
        cont = last ? "   " : string(fmt.muted, "│", fmt.reset, "  ")
        for l in @view lines[2:end]
            print(io, "\n", cont, style, l, reset)
        end
    end
    return nothing
end

"""
$(TYPEDSIGNATURES)

Print a sequence of branches, automatically marking the last one with `└─`.

`fields` is an iterable of `(label, value)` or `(label, value, value_style)` tuples; the
optional third element overrides the value style for that field (pass `""` for plain). This
is convenient when some fields are appended conditionally and the "last" field is only known
at runtime.
"""
function print_fields(io::IO, fields; fmt=format_codes(io))
    n = length(fields)
    for (i, f) in enumerate(fields)
        style = length(f) >= 3 ? f[3] : nothing
        print_field(io, f[1], f[2]; last=(i == n), fmt=fmt, value_style=style)
    end
    return nothing
end

end # module Display
