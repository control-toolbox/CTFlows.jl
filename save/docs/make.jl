using Documenter
using DocumenterMermaid
using CTFlows
using CTModels
using OrdinaryDiffEq

# to add docstrings from external packages
const CTFlowsODE = Base.get_extension(CTFlows, :CTFlowsODE)
Modules = [CTFlowsODE]
for Module in Modules
    isnothing(DocMeta.getdocmeta(Module, :DocTestSetup)) &&
        DocMeta.setdocmeta!(Module, :DocTestSetup, :(using $Module); recursive=true)
end

repo_url = "github.com/control-toolbox/CTFlows.jl"

API_PAGES = [
    "concatenation.md",
    "ctflowsode.md",
    "default.md",
    "differential_geometry.md",
    "ext_default.md",
    "ext_types.md",
    "ext_utils.md",
    "function.md",
    "hamiltonian.md",
    "optimal_control_problem_utils.md",
    "optimal_control_problem.md",
    "types.md",
    "utils.md",
    "vector_field.md",
]

makedocs(;
    sitename="CTFlows.jl",
    format=Documenter.HTML(;
        repolink="https://" * repo_url,
        prettyurls=false,
        assets=[
            asset("https://control-toolbox.org/assets/css/documentation.css"),
            asset("https://control-toolbox.org/assets/js/documentation.js"),
        ],
    ),
    pages=["Introduction" => "index.md", "API" => API_PAGES],
)

deploydocs(; repo=repo_url * ".git", devbranch="main")
