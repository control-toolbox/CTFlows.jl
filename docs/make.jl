using Documenter
using DocumenterMermaid
using CTFlows

makedocs(
    sitename = "CTFlows.jl",
    format = Documenter.HTML(
        prettyurls = false,
        assets=[
            asset("https://control-toolbox.org/assets/css/documentation.css"),
            asset("https://control-toolbox.org/assets/js/documentation.js"),
        ],
    ),
    pages = [
        "Introduction" => "index.md",
        "API" => "api.md",
        "Developers" => "dev-api.md",
    ]
)

deploydocs(
    repo = "github.com/control-toolbox/CTFlows.jl.git",
    devbranch = "main"
)
