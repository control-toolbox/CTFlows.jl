# to run the documentation generation: julia --project=. docs/make.jl
# to serve the documentation (option 1 — handles clean URLs natively):
#   npx serve docs/build/1 --listen 5173
# to serve the documentation (option 2 — Julia only):
#   julia --project=docs -e 'using LiveServer; LiveServer.serve(dir="docs/build/1", single_page=true)'
# note: single_page=true is required so that reloading /getting-started serves the correct HTML
pushfirst!(LOAD_PATH, joinpath(@__DIR__))
pushfirst!(LOAD_PATH, joinpath(@__DIR__, ".."))

using Documenter
using DocumenterVitepress
using DocumenterInterLinks
using CTFlows
using CTBase
using CTModels
using CTSolvers
using Markdown
using MarkdownAST: MarkdownAST

# trigger extensions
using ForwardDiff
using DifferentiationInterface
using OrdinaryDiffEqTsit5
using Plots
using CairoMakie
using SciMLBase, DiffEqBase
using StaticArrays

# Make extension modules available in Main so that @docs blocks can resolve
# qualified bindings like CTFlowsSciMLIntegrator.SciMLIntegrationResult.
for _ext_sym in (
    :CTFlowsPlots,
    :CTFlowsMakie,
    :CTFlowsSciMLIntegrator,
    :CTFlowsSciMLFlows,
    :CTFlowsStaticArrays,
)
    _m = Base.get_extension(CTFlows, _ext_sym)
    isnothing(_m) || @eval Main const $_ext_sym = $_m
end

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
draft = false # Draft mode: if true, @example blocks in markdown are not executed

# ═══════════════════════════════════════════════════════════════════════════════
# Cross-package links (InterLinks)
# ═══════════════════════════════════════════════════════════════════════════════
links = InterLinks(
    "CTFlows" => (
        "https://control-toolbox.org/CTFlows.jl/stable/",
        joinpath(@__DIR__, "build", "1", "objects.inv"),
        "https://control-toolbox.org/CTFlows.jl/stable/objects.inv",
    ),
    "CTBase" => (
        "https://control-toolbox.org/CTBase.jl/stable/",
        "https://control-toolbox.org/CTBase.jl/stable/objects.inv",
    ),
    "CTModels" => (
        "https://control-toolbox.org/CTModels.jl/stable/",
        "https://control-toolbox.org/CTModels.jl/stable/objects.inv",
    ),
    "CTSolvers" => (
        "https://control-toolbox.org/CTSolvers.jl/stable/",
        "https://control-toolbox.org/CTSolvers.jl/stable/objects.inv",
    ),
)

# ═══════════════════════════════════════════════════════════════════════════════
# Extensions
# ═══════════════════════════════════════════════════════════════════════════════
const DocumenterReference = Base.get_extension(CTBase, :DocumenterReference)

if !isnothing(DocumenterReference)
    DocumenterReference.reset_config!()
end

# ═══════════════════════════════════════════════════════════════════════════════
# Paths
# ═══════════════════════════════════════════════════════════════════════════════
repo_url = "github.com/control-toolbox/CTFlows.jl"
src_dir = abspath(joinpath(@__DIR__, "..", "src"))
ext_dir = abspath(joinpath(@__DIR__, "..", "ext"))

# Include the API reference manager
include("api_reference.jl")

# ═══════════════════════════════════════════════════════════════════════════════
# Build documentation
# ═══════════════════════════════════════════════════════════════════════════════
with_api_reference(src_dir, ext_dir) do api_pages
    return makedocs(;
        draft=draft,
        remotes=nothing,
        warnonly=[:cross_references, :external_cross_references],
        sitename="CTFlows.jl",
        format=DocumenterVitepress.MarkdownVitepress(;
            repo=repo_url, devbranch="main", devurl="dev", sidebar_drawer=true
        ),
        pages=[
            # index.md is the VitePress root — not listed here
            "Getting Started" => "getting-started.md",
            "Flows" => [
                "Overview" => "flows/overview.md",
                "Building a flow" => "flows/building_a_flow.md",
                "Integrating" => "flows/integrating.md",
                "Trajectories" => "flows/trajectories.md",
                "Multi-phase flows" => "flows/multiphase.md",
                "Optimal control" => "flows/optimal_control.md",
                "Control laws" => "flows/control_laws.md",
                "Constrained flows" => "flows/constrained.md",
                "SciML flows" => "flows/sciml.md",
                "GPU flows" => "flows/gpu.md",
            ],
            "Compatibility" => [
                "Overview" => "compatibility/overview.md",
                "Shape contract" => "compatibility/shape_contract.md",
                "Flow(VectorField)" => "compatibility/vector_field.md",
                "Flow(HamiltonianVectorField)" => "compatibility/hamiltonian_vector_field.md",
                "Flow(Hamiltonian)" => "compatibility/hamiltonian.md",
                "Flow(SciML)" => "compatibility/sciml.md",
                "Flow(ocp)" => "compatibility/ocp_free.md",
                "Flow(ocp, law)" => "compatibility/ocp_control_laws.md",
                "Flow(h̃, law)" => "compatibility/pseudo_hamiltonian.md",
                "Flow(fc, law)" => "compatibility/controlled_vector_field.md",
                "GPU" => "compatibility/gpu.md",
            ],
            "Developer notes" => ["GPU internals" => "dev/gpu-internals.md"],
            "API Reference" => api_pages,
        ],
        plugins=[links],
    )
end

# ═══════════════════════════════════════════════════════════════════════════════
# Deploy documentation to GitHub Pages
# ═══════════════════════════════════════════════════════════════════════════════
bases_file = joinpath(@__DIR__, "build", "bases.txt")
if isfile(bases_file)
    DocumenterVitepress.deploydocs(;
        repo=repo_url * ".git", devbranch="main", push_preview=false
    )
else
    @info "Skipping deployment: no bases were built (prerelease with existing higher stable release)."
end
