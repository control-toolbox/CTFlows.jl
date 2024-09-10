using Documenter
using DocumenterMermaid
using CTFlows

repo_url = "github.com/control-toolbox/OptimalControlProblems.jl"

makedocs(;
    sitename="CTFlows.jl",
    format=Documenter.HTML(;
        repolink = "https://"*repo_url,
        prettyurls=false,
        assets=[
            asset("https://control-toolbox.org/assets/css/documentation.css"),
            asset("https://control-toolbox.org/assets/js/documentation.js"),
        ],
    ),
    pages=["Introduction" => "index.md", "API" => "api.md", "Developers" => "dev.md"],
)

deploydocs(;
    repo=repo_url*".git", devbranch="main"
)
