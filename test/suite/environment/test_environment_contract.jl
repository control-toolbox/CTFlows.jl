module TestEnvironmentContract

using Test: Test
using CTFlows: CTFlows
using SciMLBase: SciMLBase  # triggers CTFlowsSciMLFlows + CTFlowsSciMLIntegrator extensions

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

# CTFlows has no dedicated GPU extension (no MadNLPGPU/CUDSS). The GPU path runs
# through the SciML extensions, so we check those are armed.
const _SciMLFlows = Base.get_extension(CTFlows, :CTFlowsSciMLFlows)
const _SciMLIntegrator = Base.get_extension(CTFlows, :CTFlowsSciMLIntegrator)

"""
    _local_is_cuda_on_offenders()

Recursively find, under `test/suite/`, source lines defining a local `is_cuda_on()`
function — the anti-pattern consolidated into Main.TestCapabilities by this fix
(see issue #375 / CTSolvers.jl#190).
"""
function _local_is_cuda_on_offenders()
    suite_dir = joinpath(@__DIR__, "..")
    offenders = Tuple{String,Int}[]
    for (root, _, files) in walkdir(suite_dir)
        for f in files
            endswith(f, ".jl") || continue
            path = joinpath(root, f)
            for (lineno, line) in enumerate(eachline(path))
                if occursin(r"is_cuda_on\(\)\s*=", line)
                    push!(offenders, (relpath(path, suite_dir), lineno))
                end
            end
        end
    end
    return offenders
end

function test_environment_contract()
    Test.@testset "Test-environment contract" verbose=VERBOSE showtiming=SHOWTIMING begin
        Test.@testset "SciML extensions armed" begin
            Test.@test !isnothing(_SciMLFlows)
            Test.@test !isnothing(_SciMLIntegrator)
        end

        Test.@testset "GPU driver required on the GPU runner" begin
            if get(ENV, "RUNNER_NAME", "") == "kkt"
                Test.@test Main.TestCapabilities.CUDA_FUNCTIONAL
            end
        end

        Test.@testset "local is_cuda_on() anti-pattern has not returned" begin
            offenders = _local_is_cuda_on_offenders()
            Test.@test isempty(offenders)
            for (file, lineno) in offenders
                @warn "local is_cuda_on() at $file:$lineno — use Main.TestCapabilities instead"
            end
        end
    end
end

end # module

test_environment_contract() = TestEnvironmentContract.test_environment_contract()
