# to run the documentation generation:
# julia --project=. docs/make.jl
pushfirst!(LOAD_PATH, joinpath(@__DIR__))
pushfirst!(LOAD_PATH, joinpath(@__DIR__, ".."))

using Documenter
using CTFlows
using CTBase
using Markdown
using MarkdownAST: MarkdownAST

# ══════════════════════════════════════════════════════════════════════════════
# Configuration
# ══════════════════════════════════════════════════════════════════════════════

draft = false  # Draft mode: if true, @example blocks are not executed

# ══════════════════════════════════════════════════════════════════════════════
# Load extensions
# ══════════════════════════════════════════════════════════════════════════════

const DocumenterReference = Base.get_extension(CTBase, :DocumenterReference)

if !isnothing(DocumenterReference)
    DocumenterReference.reset_config!()
end

# ══════════════════════════════════════════════════════════════════════════════
# Paths
# ══════════════════════════════════════════════════════════════════════════════

repo_url = "github.com/control-toolbox/CTFlows.jl"
src_dir = abspath(joinpath(@__DIR__, "..", "src"))
ext_dir = abspath(joinpath(@__DIR__, "..", "ext"))

# Include the API reference manager
include("api_reference.jl")

# ══════════════════════════════════════════════════════════════════════════════
# Build documentation
# ══════════════════════════════════════════════════════════════════════════════

with_api_reference(src_dir, ext_dir) do api_pages
    makedocs(;
        draft=draft,
        remotes=nothing,
        warnonly=[:cross_references],
        sitename="CTFlows.jl",
        format=Documenter.HTML(;
            repolink="https://" * repo_url,
            prettyurls=false,
            assets=[
                asset("https://control-toolbox.org/assets/css/documentation.css"),
                asset("https://control-toolbox.org/assets/js/documentation.js"),
            ],
        ),
        pages=["Introduction" => "index.md", "API Reference" => api_pages],
    )
end

# ══════════════════════════════════════════════════════════════════════════════

deploydocs(; repo=repo_url * ".git", devbranch="main")
