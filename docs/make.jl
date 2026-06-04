# to run the documentation generation:
# julia --project=. docs/make.jl
pushfirst!(LOAD_PATH, joinpath(@__DIR__))
pushfirst!(LOAD_PATH, joinpath(@__DIR__, ".."))

# control-toolbox packages
using CTFlows
using CTBase
using CTModels
using CTSolvers

# documentation
using DocumenterInterLinks
using Documenter
using Markdown
using MarkdownAST: MarkdownAST

# trigger extensions
using ForwardDiff
using DifferentiationInterface
using OrdinaryDiffEqTsit5
using Plots
using SciMLBase, DiffEqBase
using StaticArrays

# Make extension modules available in Main so that @docs blocks can resolve
# qualified bindings like CTFlowsSciML.SciMLFunctionSystem.
for _ext_sym in (:CTFlowsForwardDiff, :CTFlowsDifferentiationInterface,
                 :CTFlowsOrdinaryDiffEqTsit5, :CTFlowsPlots,
                 :CTFlowsSciML, :CTFlowsStaticArrays)
    _m = Base.get_extension(CTFlows, _ext_sym)
    isnothing(_m) || @eval Main const $_ext_sym = $_m
end

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
    "CTSolvers" => (
        "https://control-toolbox.org/CTSolvers.jl/stable/",
        "https://control-toolbox.org/CTSolvers.jl/stable/objects.inv",
        joinpath(@__DIR__, "inventories", "CTSolvers.toml"),
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
            size_threshold_ignore=[
                joinpath("api", "api_traits_public.md"),
            ],
        ),
        pages=[
            "Introduction" => "index.md",
            "Flows" => [
                "Overview"           => "flows/index.md",
                "Traits"             => "flows/traits.md",
                "Data structures"    => "flows/data.md",
                "Building a flow"    => "flows/building_a_flow.md",
                "Integrating"        => "flows/integrating.md",
                "Solutions"          => "flows/solutions.md",
                "Multi-phase flows"  => "flows/multiphase.md",
            ],
            "Differential Geometry" => [
                "Overview" => "differential_geometry/index.md",
                "Hamiltonian lift" => "differential_geometry/lift.md",
                "Lie derivative & bracket" => "differential_geometry/lie_derivative_bracket.md",
                "Poisson bracket" => "differential_geometry/poisson.md",
                "Partial time derivative" => "differential_geometry/time_derivative.md",
                "The @Lie macro" => "differential_geometry/lie_macro.md",
                "Limitations & configuration" => "differential_geometry/limitations.md",
            ],
            "API Reference" => api_pages,
        ],
        plugins=[links],
    )
end

# ══════════════════════════════════════════════════════════════════════════════

deploydocs(; repo=repo_url * ".git", devbranch="main")
