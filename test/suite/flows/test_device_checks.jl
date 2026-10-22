"""
Tests of the checks done at the beginning of a flow call (issue #436), all CPU-runnable and
independent of the AD backend packages other test files loaded (fakes only):

- a GPU flow (`method=:gpu`) refuses a host array (numbers, i.e. 1-D states, and device
  arrays are accepted);
- the `AutoMooncake` backend refuses non-IEEE element types (a `ForwardDiff.Dual` from an
  outer ForwardDiff, a `BigFloat`) in the state, costate, times or variable, and accepts
  host arrays of IEEE floats (issue #448);
- the package of the AD backend must be loaded: `ExtensionError` naming it, raised before the
  integration, instead of a raw `MethodError` from DifferentiationInterface.jl.
"""

module TestDeviceChecks

using Test: Test
using CTBase: Data
using CTBase: Exceptions
using CTBase: Strategies
using CTFlows: Configs
using CTFlows: Flows
using CTFlows: Integrators
using ADTypes: ADTypes
using GPUArraysCore: GPUArraysCore
using DifferentiationInterface: DifferentiationInterface  # loads the CTBase DI extension
using ForwardDiff: ForwardDiff
using OrdinaryDiffEqTsit5

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

# ── fakes (module top-level) ────────────────────────────────────────────────

"""A device array: only its type matters to the checks."""
struct FakeDeviceArray{T,N} <: GPUArraysCore.AbstractGPUArray{T,N} end

"""An ADTypes backend that no DifferentiationInterface extension knows: never available."""
struct AutoFakeBackend <: ADTypes.AbstractADType end

const H = Data.Hamiltonian(
    (x, p) -> 0.5 * sum(abs2, p) + x[1]; is_autonomous=true, is_variable=false
)
const H1 = Data.Hamiltonian((x, p) -> 0.5 * p^2 + x; is_autonomous=true, is_variable=false)
_vf() = Data.VectorField(x -> -x; is_autonomous=true, is_variable=false)

const X0, P0 = [1.0, 0.0], [0.0, 1.0]
const DEVICE_X0 = FakeDeviceArray{Float64,1}()
const DEVICE_P0 = FakeDeviceArray{Float64,1}()

# what an outer ForwardDiff passes through the flow
const DUAL = ForwardDiff.Dual(1.0, 1.0)
const DUAL_X0 = [ForwardDiff.Dual(1.0, 1.0), ForwardDiff.Dual(0.0, 0.0)]

_throws(f) =
    try
        f()
        nothing
    catch err
        err
    end

function test_device_checks()
    Test.@testset "Call checks (device, AD backend)" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ====================================================================
        # UNIT — helpers
        # ====================================================================
        Test.@testset "Unit: _is_host_array" begin
            Test.@test Flows._is_host_array([1.0, 2.0])
            Test.@test Flows._is_host_array([1.0 2.0; 3.0 4.0])
            Test.@test !Flows._is_host_array(1.0)            # a 1-D state is a scalar
            Test.@test !Flows._is_host_array(DEVICE_X0)
        end

        Test.@testset "Unit: _integrator_device" begin
            Test.@test Flows._integrator_device(Flows.integrator(Flows.Flow(_vf()))) ===
                Strategies.CPU
            Test.@test Flows._integrator_device(
                Flows.integrator(Flows.Flow(_vf(); method=:gpu))
            ) === Strategies.GPU
            Test.@test Flows._integrator_device(:not_an_integrator) === nothing
        end

        Test.@testset "Unit: _system_ad_backend" begin
            Test.@test Flows._system_ad_backend(Flows.system(Flows.Flow(_vf()))) === nothing
            Test.@test Flows._system_ad_backend(Flows.system(Flows.Flow(H))) ===
                ADTypes.AutoForwardDiff()
            Test.@test Flows._system_ad_backend(
                Flows.system(Flows.Flow(H; ad_backend=AutoFakeBackend()))
            ) === AutoFakeBackend()
        end

        Test.@testset "Unit: _call_arrays" begin
            Test.@test Flows._call_arrays(Configs.StateEndPointConfig(0.0, X0, 1.0)) ==
                (X0,)
            Test.@test Flows._call_arrays(
                Configs.HamiltonianEndPointConfig(0.0, X0, P0, 1.0)
            ) == (X0, P0)
            Test.@test Flows._call_arrays(
                Configs.HamiltonianTrajectoryConfig((0.0, 1.0), X0, P0)
            ) == (X0, P0)
        end

        # ====================================================================
        # CONTRACT — _check_host_arrays
        # ====================================================================
        Test.@testset "Contract: _check_host_arrays" begin
            host = (X0,)
            # CPU device or no device → accepted
            Test.@test Flows._check_host_arrays(Strategies.CPU, host) === nothing
            Test.@test Flows._check_host_arrays(nothing, host) === nothing
            # GPU device → refused
            err = _throws(() -> Flows._check_host_arrays(Strategies.GPU, host))
            Test.@test err isa Exceptions.PreconditionError
            Test.@test occursin("method=:gpu", err.msg)
            Test.@test occursin("Vector{Float64}", err.reason)
            Test.@test occursin("CuArray", err.suggestion)
        end

        # ====================================================================
        # UNIT / CONTRACT — element types under AutoMooncake (issue #448)
        # ====================================================================
        Test.@testset "Unit: _value_eltype" begin
            Test.@test Flows._value_eltype(X0) === Float64
            Test.@test Flows._value_eltype(Float32[1, 2]) === Float32
            Test.@test Flows._value_eltype(1.0) === Float64
            Test.@test Flows._value_eltype(DUAL) === typeof(DUAL)
            Test.@test Flows._value_eltype(nothing) === nothing
            Test.@test Flows._value_eltype(:not_a_value) === nothing
        end

        Test.@testset "Unit: _mooncake_eltype" begin
            for T in (Float64, Float32, Float16, Int, Bool)
                Test.@test Flows._mooncake_eltype(T)
            end
            for T in (typeof(DUAL), BigFloat, Rational{Int})
                Test.@test !Flows._mooncake_eltype(T)
            end
            Test.@test Flows._mooncake_eltype(ComplexF64)   # not a Real: not this check's call
        end

        Test.@testset "Contract: _check_ad_eltypes" begin
            ok = (X0, P0, 0.0, 1, nothing)
            Test.@test Flows._check_ad_eltypes(ADTypes.AutoMooncake(), ok) === nothing
            Test.@test Flows._check_ad_eltypes(nothing, (DUAL_X0,)) === nothing
            Test.@test Flows._check_ad_eltypes(ADTypes.AutoForwardDiff(), (DUAL_X0,)) ===
                nothing
            err = _throws(
                () -> Flows._check_ad_eltypes(ADTypes.AutoMooncake(), (X0, DUAL_X0))
            )
            Test.@test err isa Exceptions.PreconditionError
            Test.@test occursin("AutoMooncake", err.msg)
            Test.@test occursin("Dual", err.msg)
            Test.@test occursin("nested AD", err.reason)
            Test.@test occursin("AutoForwardDiff()", err.suggestion)
            Test.@test occursin("AutoFiniteDiff()", err.suggestion)
        end

        # ====================================================================
        # CONTRACT — _check_call on real flows (no integration)
        # ====================================================================
        Test.@testset "Contract: GPU flow refuses host arrays, accepts the rest [$kind]" for (
            kind, flow, config_host, config_device, config_scalar
        ) in (
            (
                "AD-free state flow",
                Flows.Flow(_vf(); method=:gpu),
                Configs.StateEndPointConfig(0.0, X0, 1.0),
                Configs.StateEndPointConfig(0.0, DEVICE_X0, 1.0),
                Configs.StateEndPointConfig(0.0, 1.0, 1.0),
            ),
            (
                "Hamiltonian flow",
                Flows.Flow(H1; method=:gpu, ad_backend=ADTypes.AutoForwardDiff()),
                Configs.HamiltonianEndPointConfig(0.0, X0, P0, 1.0),
                Configs.HamiltonianEndPointConfig(0.0, DEVICE_X0, DEVICE_P0, 1.0),
                Configs.HamiltonianEndPointConfig(0.0, 1.0, 0.5, 1.0),
            ),
        )
            Test.@test_throws Exceptions.PreconditionError Flows._check_call(
                flow, config_host
            )
            Test.@test Flows._check_call(flow, config_device) === nothing
            Test.@test Flows._check_call(flow, config_scalar) === nothing
        end

        Test.@testset "Contract: a host costate alone is refused too" begin
            f = Flows.Flow(H; method=:gpu, ad_backend=ADTypes.AutoForwardDiff())
            Test.@test_throws Exceptions.PreconditionError Flows._check_call(
                f, Configs.HamiltonianEndPointConfig(0.0, DEVICE_X0, P0, 1.0)
            )
        end

        Test.@testset "Contract: the CPU flow accepts host arrays" begin
            Test.@test Flows._check_call(
                Flows.Flow(_vf()), Configs.StateEndPointConfig(0.0, X0, 1.0)
            ) === nothing
            Test.@test Flows._check_call(
                Flows.Flow(H), Configs.HamiltonianEndPointConfig(0.0, X0, P0, 1.0)
            ) === nothing
            Test.@test Flows._check_call(
                Flows.Flow(H; method=:cpu),
                Configs.HamiltonianEndPointConfig(0.0, X0, P0, 1.0),
            ) === nothing
        end

        Test.@testset "Contract: Mooncake accepts IEEE host arrays and scalars" begin
            f = Flows.Flow(H; ad_backend=ADTypes.AutoMooncake())
            # they pass the device and element-type checks; the availability check of the
            # package comes next (loaded or not depending on the other tests: not asserted)
            for ok in (
                Configs.HamiltonianEndPointConfig(0.0, X0, P0, 1.0),
                Configs.HamiltonianEndPointConfig(0, Float32.(X0), Float32.(P0), 1),
                Configs.HamiltonianEndPointConfig(0.0, 1.0, 0.5, 1.0),
            )
                err = _throws(() -> Flows._check_call(f, ok; variable=[0.5]))
                Test.@test !(err isa Exceptions.PreconditionError)
            end
        end

        Test.@testset "Contract: Mooncake refuses non-IEEE values [$kind]" for (
            kind, config, variable
        ) in (
            (
                "Dual state",
                Configs.HamiltonianEndPointConfig(0.0, DUAL_X0, P0, 1.0),
                nothing,
            ),
            (
                "Dual costate",
                Configs.HamiltonianEndPointConfig(0.0, X0, DUAL_X0, 1.0),
                nothing,
            ),
            (
                "Dual 1-D state",
                Configs.HamiltonianEndPointConfig(0.0, DUAL, 0.5, 1.0),
                nothing,
            ),
            (
                "Dual final time",
                Configs.HamiltonianEndPointConfig(0.0, X0, P0, DUAL),
                nothing,
            ),
            ("Dual variable", Configs.HamiltonianEndPointConfig(0.0, X0, P0, 1.0), [DUAL]),
            (
                "BigFloat state",
                Configs.HamiltonianEndPointConfig(0.0, big.(X0), P0, 1.0),
                nothing,
            ),
        )
            f = Flows.Flow(H; ad_backend=ADTypes.AutoMooncake())
            Test.@test_throws Exceptions.PreconditionError Flows._check_call(
                f, config; variable=variable
            )
        end

        # ====================================================================
        # ERROR — backend package not loaded: ExtensionError, before the integration
        # ====================================================================
        Test.@testset "Error: unavailable backend → ExtensionError naming the package [$kind]" for (
            kind, call
        ) in (
            ("point call", f -> f(0.0, X0, P0, 1.0)),
            ("trajectory call", f -> f((0.0, 1.0), X0, P0)),
            ("trajectory with a grid", f -> f([0.0, 0.5, 1.0], X0, P0)),
        )
            f = Flows.Flow(H; ad_backend=AutoFakeBackend())
            err = _throws(() -> call(f))
            Test.@test err isa Exceptions.ExtensionError
            Test.@test err.weakdeps == (:FakeBackend,)
        end

        Test.@testset "Error: unavailable backend with device arrays (GPU flow)" begin
            f = Flows.Flow(H; method=:gpu, ad_backend=AutoFakeBackend())
            err = _throws(
                () -> Flows._check_call(
                    f, Configs.HamiltonianEndPointConfig(0.0, DEVICE_X0, DEVICE_P0, 1.0)
                ),
            )
            Test.@test err isa Exceptions.ExtensionError
            Test.@test err.weakdeps == (:FakeBackend,)
        end

        # ====================================================================
        # INTEGRATION — the checks apply on every path of a real call
        # ====================================================================
        Test.@testset "Integration: method=:gpu with a host array [$kind]" for (
            kind, call
        ) in (
            ("state point", () -> Flows.Flow(_vf(); method=:gpu)(0.0, X0, 1.0)),
            ("state trajectory", () -> Flows.Flow(_vf(); method=:gpu)((0.0, 1.0), X0)),
            (
                "Hamiltonian point",
                () -> Flows.Flow(H; method=:gpu, ad_backend=ADTypes.AutoForwardDiff())(
                    0.0, X0, P0, 1.0
                ),
            ),
            (
                "Hamiltonian trajectory",
                () -> Flows.Flow(H; method=:gpu, ad_backend=ADTypes.AutoForwardDiff())(
                    (0.0, 1.0), X0, P0
                ),
            ),
            (
                "multi-phase",
                () -> (f=Flows.Flow(_vf(); method=:gpu); (f * (0.5, f))((0.0, 1.0), X0)),
            ),
        )
            Test.@test_throws Exceptions.PreconditionError call()
        end

        Test.@testset "Integration: variable_costate path checks the device too" begin
            hv = Data.Hamiltonian(
                (x, p, v) -> 0.5 * sum(abs2, p) + v[1] * x[1];
                is_autonomous=true,
                is_variable=true,
            )
            f = Flows.Flow(hv; method=:gpu, ad_backend=ADTypes.AutoForwardDiff())
            Test.@test_throws Exceptions.PreconditionError f(
                0.0, X0, P0, 1.0; variable=[0.5], variable_costate=true
            )
        end

        # ====================================================================
        # NON-REGRESSION — the default CPU flow still integrates host arrays
        # ====================================================================
        Test.@testset "Non-regression: CPU flows are unaffected" begin
            xf, pf = Flows.Flow(H)(0.0, X0, P0, 1.0)
            Test.@test xf ≈ [0.5, 1.0] atol = 1e-8
            Test.@test pf ≈ [-1.0, 1.0] atol = 1e-8
            Test.@test Flows.Flow(_vf())(0.0, X0, 1.0) ≈ X0 .* exp(-1.0) atol = 1e-8
            # a 1-D state is a scalar, also under method=:gpu (no host array involved)
            x1, p1 = Flows.Flow(H1; method=:gpu, ad_backend=ADTypes.AutoForwardDiff())(
                0.0, 1.0, 0.5, 1.0
            )
            Test.@test x1 isa Real && p1 isa Real
        end
    end
end

end # module

test_device_checks() = TestDeviceChecks.test_device_checks()
