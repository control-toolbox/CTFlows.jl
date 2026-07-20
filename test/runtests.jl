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

# CUDA availability check — GPU execution tests (suite/extensions/test_gpu_flows.jl) self-gate
# on `is_cuda_on()` and skip cleanly when no functional device is present (e.g. CI CPU runners,
# dev machines). The real GPU run is the `test-gpu-kkt` job on the kkt NVIDIA runner.
using CUDA
is_cuda_on() = CUDA.functional()
if is_cuda_on()
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
