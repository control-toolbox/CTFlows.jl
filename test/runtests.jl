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
# ### Weekly cron suite (slow end-to-end integration tests, see test/cron/)
#   julia --project -e 'using Pkg; Pkg.test("CTFlows"; test_args=["cron"])'
#   julia --project -e 'using Pkg; Pkg.test("CTFlows"; test_args=["cron", "test_goddard"])'
#
# Test layout: `suite/<group>/test_<name>.jl` each defining `test_<name>()`.
# ==============================================================================

using Test
using CTBase
using CTFlows

# Capability constants computed once, here, where a top-level `using` is guaranteed
# to bind into Main. Suite files read Main.TestCapabilities.* instead of redefining
# is_cuda_on() locally (see issue #375 / CTSolvers.jl#190).
using CUDA
module TestCapabilities
using CUDA: CUDA
const CUDA_FUNCTIONAL = CUDA.functional()
end

if Main.TestCapabilities.CUDA_FUNCTIONAL
    println("✓ CUDA functional, GPU tests enabled")
else
    println("⚠️  CUDA not functional, GPU tests will be skipped")
end

# Trigger loading of optional extensions
const TestRunner = Base.get_extension(CTBase, :TestRunner)

# Controls nested testset output formatting (used by individual test files)
module TestData
const VERBOSE = true
const SHOWTIMING = true
end

using .TestData: VERBOSE, SHOWTIMING

# "cron" in test_args switches to the weekly cron suite (test/cron/) instead of the
# regular suite/ (see .github/workflows/CronIntegration.yml). Stripped from `args`
# before forwarding: left in, it would be treated as a (non-matching) selection glob
# on top of `available_tests` and silently select zero tests.
is_cron = "cron" in ARGS
filtered_args = filter(!=("cron"), ARGS)

# Run tests using the TestRunner extension
CTBase.run_tests(;
    args=String.(filtered_args),
    testset_name=is_cron ? "CTFlows cron tests" : "CTFlows tests",
    available_tests=(is_cron ? "cron/*/test_*" : "suite/*/test_*",),
    filename_builder=name -> Symbol(:test_, name),
    funcname_builder=name -> Symbol(:test_, name),
    verbose=VERBOSE,
    showtiming=SHOWTIMING,
    test_dir=@__DIR__,
    progress_bar_threshold=100,
    show_progress_bar=false,
)

# If running with coverage enabled, remind the user to run the post-processing script
# because .cov files are flushed at process exit and cannot be cleaned up by this script.
if Base.JLOptions().code_coverage != 0
    println(
        """

================================================================================
[CTFlows] Coverage files generated.

To process them, move them to the coverage/ directory, and generate a report,
please run:

    julia --project=@. -e 'using Pkg; Pkg.test("CTFlows"; coverage=true); include("test/coverage.jl")'
================================================================================
""",
    )
end
