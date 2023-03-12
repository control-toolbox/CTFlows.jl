using Documenter
using CTFlows

makedocs(
    sitename = "CTFlows.jl",
    format = Documenter.HTML(prettyurls = false),
    pages = [
        "Introduction" => "index.md",
        "API" => "api.md"
    ]
)

deploydocs(
    repo = "github.com/control-toolbox/CTFlows.jl.git",
    devbranch = "main"
)
