module TestHamiltonianVectorFieldTrajectory

using Test: Test
import CTFlows.Integrators: Integrators
import CTFlows.Trajectories: Trajectories
import CTBase.Exceptions
import GPUArraysCore: GPUArraysCore

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

# Top-level CPU-backed `AbstractGPUArray` stand-in: lets the scalar-x0 split branch be
# exercised on a "device" array without a GPU (guards its GPU-safe `_safe_only` collapse).
struct FakeGPUArray{T,N} <: GPUArraysCore.AbstractGPUArray{T,N}
    data::Array{T,N}
end
Base.size(a::FakeGPUArray) = size(a.data)
Base.getindex(a::FakeGPUArray, i::Int...) = a.data[i...]
Base.setindex!(a::FakeGPUArray, v, i::Int...) = (a.data[i...] = v)
function Base.similar(::FakeGPUArray, ::Type{T}, dims::Dims) where {T}
    return FakeGPUArray(Array{T}(undef, dims))
end
# GPUArrays.jl (loaded via CUDA in the test session) overrides copyto!/view/getindex for
# AbstractGPUArray with device-kernel implementations this CPU stand-in cannot satisfy;
# delegate them to the backing Array so the fake only exercises CTFlows' AbstractGPUArray
# dispatch, never GPUArrays' device paths.
function Base.copyto!(dst::FakeGPUArray{T,N}, src::AbstractArray{T,N}) where {T,N}
    (copyto!(dst.data, src); dst)
end
# resolve the ambiguity with GPUArrays' copyto!(::AnyGPUArray, ::Array)
function Base.copyto!(dst::FakeGPUArray{T,N}, src::Array{T,N}) where {T,N}
    (copyto!(dst.data, src); dst)
end
Base.view(a::FakeGPUArray, I::Vararg{Any}) = view(a.data, I...)
Base.getindex(a::FakeGPUArray, I::AbstractUnitRange) = FakeGPUArray(a.data[I])
Base.getindex(a::FakeGPUArray, I::AbstractUnitRange, ::Colon) = FakeGPUArray(a.data[I, :])

# =============================================================================
# Fake integration result for testing
# =============================================================================

struct FakeHamiltonianResult <: Integrators.AbstractIntegrationResult
    final_u::Vector{Float64}
    ts::Vector{Float64}
    us::Vector{Vector{Float64}}
end

# =============================================================================
# Fake HamiltonianVectorFieldTrajectory for testing plot stub
# =============================================================================

struct FakeHamiltonianVectorFieldTrajectory <:
       Trajectories.AbstractHamiltonianVectorFieldTrajectory
    data::String
end

Integrators.final_state(r::FakeHamiltonianResult) = r.final_u
Integrators.times(r::FakeHamiltonianResult) = r.ts
Integrators.status(r::FakeHamiltonianResult) = :Success
Integrators.successful(r::FakeHamiltonianResult) = true
function Integrators.evaluate_at(r::FakeHamiltonianResult, t::Real)
    idx = findfirst(≥(t), r.ts)
    if isnothing(idx)
        idx = length(r.ts)
    end
    return r.us[idx]
end

# Implement merge for FakeHamiltonianResult to support merge tests
function Integrators.merge(results::AbstractVector{<:FakeHamiltonianResult})
    if isempty(results)
        throw(
            Exceptions.IncorrectArgument(
                "Cannot merge empty sequence of FakeHamiltonianResult";
                got="0 results",
                expected="at least 1 result",
                context="FakeHamiltonianResult merge",
            ),
        )
    end
    # Combine times and states from all results
    all_ts = vcat([r.ts for r in results]...)
    all_us = vcat([r.us for r in results]...)
    # Use final_u from the last result
    final_u = results[end].final_u
    return FakeHamiltonianResult(final_u, all_ts, all_us)
end

function test_hamiltonian_vector_field_trajectory()
    Test.@testset "Hamiltonian Vector Field Solution Tests" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ====================================================================
        # UNIT TESTS - Construction
        # ====================================================================

        Test.@testset "Construction" begin
            result = FakeHamiltonianResult(
                [1.0, 2.0, 3.0, 4.0],
                [0.0, 0.5, 1.0],
                [[1, 2, 3, 4], [1.5, 2.5, 3.5, 4.5], [2, 3, 4, 5]],
            )
            x0 = [1.0, 2.0]  # initial state
            sol = Trajectories.HamiltonianVectorFieldTrajectory(x0, result)
            Test.@test sol isa Trajectories.HamiltonianVectorFieldTrajectory
            Test.@test sol isa Trajectories.AbstractHamiltonianVectorFieldTrajectory
        end

        # ====================================================================
        # UNIT TESTS - sol(t) returns tuple
        # ====================================================================

        Test.@testset "sol(t) returns tuple" begin
            result = FakeHamiltonianResult(
                [1.0, 2.0, 3.0, 4.0],
                [0.0, 0.5, 1.0],
                [[1, 2, 3, 4], [1.5, 2.5, 3.5, 4.5], [2, 3, 4, 5]],
            )
            x0 = [1.0, 2.0]  # initial state
            sol = Trajectories.HamiltonianVectorFieldTrajectory(x0, result)

            x, p = sol(0.0)
            Test.@test x == [1.0, 2.0]
            Test.@test p == [3.0, 4.0]

            x, p = sol(0.5)
            Test.@test x == [1.5, 2.5]
            Test.@test p == [3.5, 4.5]

            x, p = sol(1.0)
            Test.@test x == [2.0, 3.0]
            Test.@test p == [4.0, 5.0]
        end

        # ====================================================================
        # UNIT TESTS - state and costate accessors
        # ====================================================================

        Test.@testset "state and costate accessors" begin
            result = FakeHamiltonianResult(
                [1.0, 2.0, 3.0, 4.0],
                [0.0, 0.5, 1.0],
                [[1, 2, 3, 4], [1.5, 2.5, 3.5, 4.5], [2, 3, 4, 5]],
            )
            x0 = [1.0, 2.0]  # initial state
            sol = Trajectories.HamiltonianVectorFieldTrajectory(x0, result)

            x_func = Trajectories.state(sol)
            Test.@test x_func isa Function
            Test.@test x_func(0.0) == [1.0, 2.0]

            p_func = Trajectories.costate(sol)
            Test.@test p_func isa Function
            Test.@test p_func(0.0) == [3.0, 4.0]
        end

        # ====================================================================
        # UNIT TESTS - final_state
        # ====================================================================

        Test.@testset "final_state" begin
            result = FakeHamiltonianResult(
                [1.0, 2.0, 3.0, 4.0],
                [0.0, 0.5, 1.0],
                [[1, 2, 3, 4], [1.5, 2.5, 3.5, 4.5], [2, 3, 4, 5]],
            )
            x0 = [1.0, 2.0]  # initial state
            sol = Trajectories.HamiltonianVectorFieldTrajectory(x0, result)

            x, p = Integrators.final_state(sol)
            Test.@test x == [1.0, 2.0]
            Test.@test p == [3.0, 4.0]
        end

        # ====================================================================
        # UNIT TESTS - status and successful
        # ====================================================================

        Test.@testset "status and successful" begin
            result = FakeHamiltonianResult(
                [1.0, 2.0, 3.0, 4.0],
                [0.0, 0.5, 1.0],
                [[1, 2, 3, 4], [1.5, 2.5, 3.5, 4.5], [2, 3, 4, 5]],
            )
            x0 = [1.0, 2.0]  # initial state
            sol = Trajectories.HamiltonianVectorFieldTrajectory(x0, result)

            Test.@test Integrators.status(sol) == :Success
            Test.@test Integrators.successful(sol) == true
        end

        # ====================================================================
        # UNIT TESTS - time_grid
        # ====================================================================

        Test.@testset "time_grid" begin
            result = FakeHamiltonianResult(
                [1.0, 2.0, 3.0, 4.0],
                [0.0, 0.5, 1.0],
                [[1, 2, 3, 4], [1.5, 2.5, 3.5, 4.5], [2, 3, 4, 5]],
            )
            x0 = [1.0, 2.0]  # initial state
            sol = Trajectories.HamiltonianVectorFieldTrajectory(x0, result)

            tg = Trajectories.time_grid(sol)
            Test.@test tg == [0.0, 0.5, 1.0]
        end

        # ====================================================================
        # UNIT TESTS - Integrators.merge
        # ====================================================================

        Test.@testset "Integrators.merge" begin
            Test.@testset "merge single segment" begin
                result = FakeHamiltonianResult(
                    [1.0, 2.0, 3.0, 4.0],
                    [0.0, 0.5, 1.0],
                    [[1, 2, 3, 4], [1.5, 2.5, 3.5, 4.5], [2, 3, 4, 5]],
                )
                x0 = [1.0, 2.0]  # initial state
                sol = Trajectories.HamiltonianVectorFieldTrajectory(x0, result)

                merged = Integrators.merge([sol])
                Test.@test merged isa Trajectories.HamiltonianVectorFieldTrajectory
            end

            Test.@testset "merge multiple segments" begin
                result1 = FakeHamiltonianResult(
                    [1.0, 2.0, 3.0, 4.0], [0.0, 0.5], [[1, 2, 3, 4], [1.5, 2.5, 3.5, 4.5]]
                )
                result2 = FakeHamiltonianResult(
                    [1.5, 2.5, 3.5, 4.5], [0.5, 1.0], [[2, 3, 4, 5], [2.5, 3.5, 4.5, 5.5]]
                )
                x0 = [1.0, 2.0]  # initial state
                sol1 = Trajectories.HamiltonianVectorFieldTrajectory(x0, result1)
                sol2 = Trajectories.HamiltonianVectorFieldTrajectory(x0, result2)

                merged = Integrators.merge([sol1, sol2])
                Test.@test merged isa Trajectories.HamiltonianVectorFieldTrajectory
            end

            Test.@testset "merge throws on empty sequence" begin
                Test.@test_throws Exceptions.IncorrectArgument Integrators.merge(
                    Trajectories.HamiltonianVectorFieldTrajectory[]
                )
            end
        end

        # ====================================================================
        # UNIT TESTS - Base.show
        # ====================================================================

        Test.@testset "Base.show" begin
            Test.@testset "text/plain format" begin
                result = FakeHamiltonianResult(
                    [1.0, 2.0, 3.0, 4.0],
                    [0.0, 0.5, 1.0],
                    [[1, 2, 3, 4], [1.5, 2.5, 3.5, 4.5], [2, 3, 4, 5]],
                )
                x0 = [1.0, 2.0]  # initial state
                sol = Trajectories.HamiltonianVectorFieldTrajectory(x0, result)

                io = IOBuffer()
                show(io, MIME("text/plain"), sol)
                output = String(take!(io))
                Test.@test occursin("HamiltonianVectorFieldTrajectory", output)
            end

            Test.@testset "compact format" begin
                result = FakeHamiltonianResult(
                    [1.0, 2.0, 3.0, 4.0],
                    [0.0, 0.5, 1.0],
                    [[1, 2, 3, 4], [1.5, 2.5, 3.5, 4.5], [2, 3, 4, 5]],
                )
                x0 = [1.0, 2.0]  # initial state
                sol = Trajectories.HamiltonianVectorFieldTrajectory(x0, result)

                io = IOBuffer()
                show(io, sol)
                output = String(take!(io))
                Test.@test occursin("HamiltonianVectorFieldTrajectory", output)
            end

            Test.@testset "show handles empty times gracefully" begin
                result = FakeHamiltonianResult(
                    [1.0, 2.0, 3.0, 4.0], Float64[], Vector{Vector{Float64}}[]
                )
                x0 = [1.0, 2.0]  # initial state
                sol = Trajectories.HamiltonianVectorFieldTrajectory(x0, result)

                io = IOBuffer()
                show(io, MIME("text/plain"), sol)
                output = String(take!(io))
                Test.@test occursin("HamiltonianVectorFieldTrajectory", output)
            end
        end

        # ====================================================================
        # UNIT TESTS - Plot stub
        # ====================================================================

        Test.@testset "Plot stub" begin
            Test.@testset "throws ExtensionError without Plots extension" begin
                fake_sol = FakeHamiltonianVectorFieldTrajectory("test data")

                Test.@test_throws Exceptions.ExtensionError Trajectories.plot(fake_sol)
            end

            Test.@testset "error message mentions Plots extension" begin
                fake_sol = FakeHamiltonianVectorFieldTrajectory("test data")

                try
                    Trajectories.plot(fake_sol)
                    Test.@test false  # Should not reach here
                catch err
                    Test.@test err isa Exceptions.ExtensionError
                    msg = sprint(showerror, err)
                    Test.@test occursin("Plots", msg)
                end
            end
        end

        # ====================================================================
        # UNIT TESTS - _ham_split_solution (internal helper)
        # ====================================================================

        Test.@testset "_ham_split_solution" begin
            Test.@testset "scalar x0" begin
                u = [1.0, 2.0]
                x0 = 1.0
                x, p = Trajectories._ham_split_solution(u, x0)
                Test.@test x == 1.0
                Test.@test p == 2.0
                Test.@test x isa Float64
                Test.@test p isa Float64
            end

            Test.@testset "vector x0" begin
                u = [1.0, 2.0, 3.0, 4.0]
                x0 = [1.0, 2.0]
                x, p = Trajectories._ham_split_solution(u, x0)
                Test.@test x == [1.0, 2.0]
                Test.@test p == [3.0, 4.0]
                Test.@test length(x) == 2
                Test.@test length(p) == 2
            end

            Test.@testset "matrix x0" begin
                u = [1.0 2.0; 3.0 4.0; 5.0 6.0; 7.0 8.0]
                x0 = [1.0 2.0; 3.0 4.0]
                x, p = Trajectories._ham_split_solution(u, x0)
                Test.@test size(x) == (2, 2)
                Test.@test size(p) == (2, 2)
                Test.@test x == [1.0 2.0; 3.0 4.0]
                Test.@test p == [5.0 6.0; 7.0 8.0]
            end

            # scalar x0 on a device `u`: the collapse routes through the GPU-safe
            # `_safe_only` (not raw `only`), consistent with every other split path.
            Test.@testset "scalar x0, device u (GPU-safe collapse)" begin
                u = FakeGPUArray([1.0, 2.0])
                x, p = Trajectories._ham_split_solution(u, 1.0)
                Test.@test x === 1.0
                Test.@test p === 2.0
            end
        end

        # ====================================================================
        # UNIT TESTS - Type stability (@inferred)
        # ====================================================================

        Test.@testset "Type stability" begin
            result = FakeHamiltonianResult(
                [1.0, 2.0, 3.0, 4.0],
                [0.0, 0.5, 1.0],
                [[1, 2, 3, 4], [1.5, 2.5, 3.5, 4.5], [2, 3, 4, 5]],
            )
            x0 = [1.0, 2.0]
            sol = Trajectories.HamiltonianVectorFieldTrajectory(x0, result)

            Test.@testset "state accessor returns concrete type" begin
                x_func = Trajectories.state(sol)
                Test.@test x_func isa Trajectories.StateProjection
            end

            Test.@testset "costate accessor returns concrete type" begin
                p_func = Trajectories.costate(sol)
                Test.@test p_func isa Trajectories.CostateProjection
            end

            Test.@testset "state function call is type-stable" begin
                x_func = Trajectories.state(sol)
                Test.@test_nowarn Test.@inferred x_func(0.0)
            end

            Test.@testset "costate function call is type-stable" begin
                p_func = Trajectories.costate(sol)
                Test.@test_nowarn Test.@inferred p_func(0.0)
            end

            Test.@testset "sol(t) is type-stable" begin
                Test.@test_nowarn Test.@inferred sol(0.0)
            end
        end

        # ====================================================================
        # UNIT TESTS - Allocation (@allocated)
        # ====================================================================

        Test.@testset "Allocation: functor adds no overhead vs direct call" begin
            result = FakeHamiltonianResult(
                [1.0, 2.0, 3.0, 4.0],
                [0.0, 0.5, 1.0],
                [[1, 2, 3, 4], [1.5, 2.5, 3.5, 4.5], [2, 3, 4, 5]],
            )
            x0 = [1.0, 2.0]
            sol = Trajectories.HamiltonianVectorFieldTrajectory(x0, result)

            x_func = Trajectories.state(sol)
            p_func = Trajectories.costate(sol)
            # warm-up (force compilation)
            x_func(0.0);
            p_func(0.0);
            sol(0.0)

            Test.@testset "StateProjection matches direct sol(t)[1]" begin
                Test.@test (@allocated x_func(0.0)) == (@allocated sol(0.0)[1])
            end

            Test.@testset "CostateProjection matches direct sol(t)[2]" begin
                Test.@test (@allocated p_func(0.0)) == (@allocated sol(0.0)[2])
            end

            # §9: the accessors return the projection stored at construction, so they
            # rebuild nothing and allocate nothing.
            Test.@testset "state/costate accessors allocate nothing" begin
                Trajectories.state(sol)
                Trajectories.costate(sol)   # warm-up
                Test.@test (@allocated Trajectories.state(sol)) == 0
                Test.@test (@allocated Trajectories.costate(sol)) == 0
            end
        end

        # ====================================================================
        # UNIT TESTS - Edge cases
        # ====================================================================

        Test.@testset "Edge cases" begin
            Test.@testset "time beyond grid returns last point" begin
                result = FakeHamiltonianResult(
                    [1.0, 2.0, 3.0, 4.0],
                    [0.0, 0.5, 1.0],
                    [[1, 2, 3, 4], [1.5, 2.5, 3.5, 4.5], [2, 3, 4, 5]],
                )
                x0 = [1.0, 2.0]
                sol = Trajectories.HamiltonianVectorFieldTrajectory(x0, result)

                x, p = sol(2.0)  # Beyond max time
                Test.@test x == [2.0, 3.0]
                Test.@test p == [4.0, 5.0]
            end

            Test.@testset "scalar initial state" begin
                result = FakeHamiltonianResult(
                    [1.0, 2.0], [0.0, 0.5, 1.0], [[1.0, 2.0], [1.5, 2.5], [2.0, 3.0]]
                )
                x0 = 1.0
                sol = Trajectories.HamiltonianVectorFieldTrajectory(x0, result)

                x, p = sol(0.0)
                Test.@test x == 1.0
                Test.@test p == 2.0
                Test.@test x isa Float64
                Test.@test p isa Float64
            end
        end
    end
end

end # module

# CRITICAL: Redefine in outer scope for TestRunner
function test_hamiltonian_vector_field_trajectory()
    return TestHamiltonianVectorFieldTrajectory.test_hamiltonian_vector_field_trajectory()
end
