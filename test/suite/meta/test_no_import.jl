"""
Regression guard for the Handbook rule "using, never import" (tenet 2,
`philosophy/modules.md#using-never-import`): flags any tracked `.jl` or `.md`
file that still uses the `import` keyword, or the forbidden dotted
`using Pkg.Sub` form (the canonical spelling is `using Pkg: Sub`).
"""

module TestNoImport

using Test: Test

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

const IMPORT_RE = r"^\s*import\b"
const DOTTED_USING_RE = r"^\s*using\s+[A-Za-z_]\w*\.[A-Za-z_]"

# These 5 "module exports" test files deliberately use the dotted bare form
# (`using CTFlows.Flows`) to verify — via `isdefined(test_module, sym)` — that the
# module's declared exports actually land unqualified in a user's scope. This is the
# "opt-in" pattern documented as legitimate in `philosophy/modules.md` ("using
# MyPackage.Systems # opt-in: brings Systems exports into scope"), not a violation.
const DOTTED_USING_EXEMPT = (
    "test_flow_module.jl",
    "test_trajectories_module.jl",
    "test_configs_module.jl",
    "test_multiphase_module.jl",
    "test_systems_module.jl",
)

function test_no_import()
    Test.@testset "No `import` / no dotted `using Pkg.Sub` (Handbook tenet 2)" verbose = VERBOSE showtiming =
        SHOWTIMING begin
        repo_root = joinpath(@__DIR__, "..", "..", "..")
        tracked = filter(
            f -> endswith(f, ".jl") || endswith(f, ".md"),
            readlines(Cmd(`git ls-files`; dir=repo_root)),
        )
        for relpath in tracked
            path = joinpath(repo_root, relpath)
            check_dotted = !(basename(relpath) in DOTTED_USING_EXEMPT)
            for line in eachline(path)
                Test.@test !occursin(IMPORT_RE, line)
                if check_dotted
                    Test.@test !occursin(DOTTED_USING_RE, line)
                end
            end
        end
    end
end

end # module

test_no_import() = TestNoImport.test_no_import()
