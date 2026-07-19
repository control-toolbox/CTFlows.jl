"""
Family-A tests: the `method=:gpu` device selection for flow construction. All CPU-runnable —
building GPU-parameterized strategies needs no functional GPU (the `SciML{GPU}` metadata equals
`SciML{CPU}`, and the GPU AD default `AutoZygote` is an ADTypes marker), so these assert the
routing/resolution without executing on a device.
"""

module TestGPURouting

using Test: Test
import CTBase.Exceptions
import CTBase.Strategies
import CTFlows.Flows
import CTBase.Data
import CTBase.Traits
using ADTypes: ADTypes
using OrdinaryDiffEqTsit5

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

const _TEST_H = Data.Hamiltonian(
    (t, x, p, v) -> 0.5 * (x[1]^2 + p[1]^2); is_autonomous=true, is_variable=false
)
_test_vf() = Data.VectorField(x -> -x; is_autonomous=true, is_variable=false)

function test_gpu_routing()
    Test.@testset "GPU routing (method=:gpu)" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ====================================================================
        # method → effective description (device token completion)
        # ====================================================================

        Test.@testset "method → description" begin
            # default / :cpu → CPU base; :gpu → GPU variant.
            Test.@test Flows._flow_description(Traits.WithoutAD, nothing) == (:sciml, :cpu)
            Test.@test Flows._flow_description(Traits.WithoutAD, :cpu) == (:sciml, :cpu)
            Test.@test Flows._flow_description(Traits.WithoutAD, :gpu) == (:sciml, :gpu)
            Test.@test Flows._flow_description(Traits.WithAD, nothing) == (:di, :sciml, :cpu)
            Test.@test Flows._flow_description(Traits.WithAD, :gpu) == (:di, :sciml, :gpu)
        end

        # ====================================================================
        # one global :gpu token resolves GPU on BOTH families at once
        # ====================================================================

        Test.@testset "components resolve GPU on both families" begin
            routed = Flows._route_flow_options(Traits.WithoutAD, (;); method=:gpu)
            comps = Flows._build_flow_components(Traits.WithoutAD, routed; method=:gpu)
            Test.@test Strategies.parameter(typeof(comps.integrator)) == Strategies.GPU
            Test.@test !haskey(comps, :backend)  # AD-free plan has no :di backend

            routed_ad = Flows._route_flow_options(Traits.WithAD, (;); method=:gpu)
            comps_ad = Flows._build_flow_components(Traits.WithAD, routed_ad; method=:gpu)
            Test.@test Strategies.parameter(typeof(comps_ad.backend)) == Strategies.GPU
            Test.@test Strategies.parameter(typeof(comps_ad.integrator)) == Strategies.GPU
        end

        Test.@testset "default / :cpu resolve CPU" begin
            routed = Flows._route_flow_options(Traits.WithAD, (;))
            comps = Flows._build_flow_components(Traits.WithAD, routed)
            Test.@test Strategies.parameter(typeof(comps.backend)) == Strategies.CPU
            Test.@test Strategies.parameter(typeof(comps.integrator)) == Strategies.CPU
        end

        # ====================================================================
        # construction with method=:gpu (host CPU — no functional GPU needed)
        # ====================================================================

        Test.@testset "construction with method=:gpu" begin
            f_vf = Flows.Flow(_test_vf(); method=:gpu)                # AD-free
            Test.@test f_vf isa Flows.AbstractFlow
            f_h = Flows.Flow(_TEST_H; method=:gpu)                    # AD (AutoZygote default)
            Test.@test f_h isa Flows.AbstractFlow
            f_cpu = Flows.Flow(_test_vf(); method=:cpu)               # :cpu ≡ default
            Test.@test f_cpu isa Flows.AbstractFlow
        end

        # ====================================================================
        # behaviour change: ad_backend rejected on an AD-free flow
        # (the WithoutAD plan has no :di family)
        # ====================================================================

        Test.@testset "ad_backend rejected on AD-free flow" begin
            Test.@test_throws Exceptions.IncorrectArgument Flows.Flow(
                _test_vf(); ad_backend=ADTypes.AutoForwardDiff()
            )
        end

        # ====================================================================
        # unknown device token is rejected
        # ====================================================================

        Test.@testset "unknown method token rejected" begin
            Test.@test_throws Exception Flows._flow_description(Traits.WithoutAD, :tpu)
        end
    end
end

end # module

test_gpu_routing() = TestGPURouting.test_gpu_routing()
