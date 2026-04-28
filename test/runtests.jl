# ==============================================================================
# CTFlows Test Runner
# ==============================================================================
#
# ## Running tests
#
# ### All tests
#   julia --project -e 'using Pkg; Pkg.test("CTFlows")'
#
# ### Specific test(s) — glob patterns matched against test file paths/names
#   julia --project -e 'using Pkg; Pkg.test("CTFlows"; test_args=["test_abstract_system"])'
#   julia --project -e 'using Pkg; Pkg.test("CTFlows"; test_args=["*pipelines*"])'
#   julia --project -e 'using Pkg; Pkg.test("CTFlows"; test_args=["-n"])'  # dry run
#
# Test layout: `suite/<group>/test_<name>.jl` each defining `test_<name>()`.
# ==============================================================================

using Test
using CTBase
using CTFlows

# Trigger loading of optional extensions
const TestRunner = Base.get_extension(CTBase, :TestRunner)

# Controls nested testset output formatting (used by individual test files)
module TestOptions
const VERBOSE = true
const SHOWTIMING = true
end
using .TestOptions: VERBOSE, SHOWTIMING

# Run tests using the TestRunner extension
CTBase.run_tests(;
    args=String.(ARGS),
    testset_name="CTFlows tests",
    available_tests=("suite/*/test_*",),
    filename_builder=name -> Symbol(:test_, name),
    funcname_builder=name -> Symbol(:test_, name),
    verbose=VERBOSE,
    showtiming=SHOWTIMING,
    test_dir=@__DIR__,
)
