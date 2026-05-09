# to run the documentation generation:
# julia --project=. docs/make.jl
pushfirst!(LOAD_PATH, joinpath(@__DIR__))
pushfirst!(LOAD_PATH, joinpath(@__DIR__, ".."))

# control-toolbox packages
using CTFlows
using CTBase
using CTModels

# documentation
using DocumenterInterLinks
using Documenter
using Markdown
using MarkdownAST: MarkdownAST

# trigger extensions
using ForwardDiff
using OrdinaryDiffEqTsit5
using Plots
using SciMLBase, DiffEqBase

#
links = InterLinks(
    "CTBase" => (
        "https://control-toolbox.org/CTBase.jl/stable/",
        "https://control-toolbox.org/CTBase.jl/stable/objects.inv",
        joinpath(@__DIR__, "inventories", "CTBase.toml"),
    ),
    "CTModels" => (
        "https://control-toolbox.org/CTModels.jl/stable/",
        "https://control-toolbox.org/CTModels.jl/stable/objects.inv",
        joinpath(@__DIR__, "inventories", "CTModels.toml"),
    ),
)

# ═══════════════════════════════════════════════════════════════════════════════
# Configuration
# ═══════════════════════════════════════════════════════════════════════════════
# if draft is true, then the julia code from .md is not executed
# to disable the draft mode in a specific markdown file, use the following:
#=
```@meta
Draft = false
```
=#
draft = false  # Draft mode: if true, @example blocks in markdown are not executed

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
        remotes=nothing, # Disable remote links. Needed for DocumenterReference
        warnonly=true,
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
        plugins=[links],
    )
end

# ══════════════════════════════════════════════════════════════════════════════

deploydocs(; repo=repo_url * ".git", devbranch="main")
