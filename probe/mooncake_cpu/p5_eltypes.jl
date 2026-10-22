# P5 — which element types of the call reach Mooncake and fail (to scope the Dual guard).
#     julia --project=probe/mooncake_cpu probe/mooncake_cpu/p5_eltypes.jl
using OrdinaryDiffEqTsit5: OrdinaryDiffEqTsit5
using ADTypes: ADTypes
using Mooncake: Mooncake
using ForwardDiff: ForwardDiff
using DifferentiationInterface: DifferentiationInterface as DI
using CTBase: CTBase, Data
using CTFlows: Flows, Systems
const MODE = "fixB2"
const EXT = Base.get_extension(CTBase, :CTBaseDifferentiationInterface)
include("patches.jl")

h = Data.Hamiltonian((x, p) -> sum(abs2, p) / 2 + sum(sin, x))
h1 = Data.Hamiltonian((x, p) -> p^2 / 2 + sin(x))
hv = Data.Hamiltonian((x, p, v) -> sum(abs2, p) / 2 + v[1] * sum(sin, x); is_variable=true)
MC = ADTypes.AutoMooncake()
f, f1, fv = (Flows.Flow(g; ad_backend=MC) for g in (h, h1, hv))
x0, p0 = [0.3, -0.7], [1.0, 0.5]
cases = [
    "Float32 state" => () -> f(0.0f0, Float32.(x0), Float32.(p0), 1.0f0),
    "Int t0" => () -> f(0, x0, p0, 1.0),
    "BigFloat state" => () -> f(0.0, big.(x0), big.(p0), 1.0),
    "Dual state (outer FD on x0)" =>
        () -> ForwardDiff.jacobian(z -> vcat(f(0.0, z, p0, 1.0)...), x0),
    "Dual 1-D state" => () -> ForwardDiff.derivative(z -> f1(0.0, z, 1.0, 1.0)[1], 0.3),
    "Dual tf (outer FD on tf)" =>
        () -> ForwardDiff.derivative(T -> sum(f(0.0, x0, p0, T)[1]), 1.0),
    "Dual variable (outer FD on v)" =>
        () -> ForwardDiff.derivative(w -> sum(fv(0.0, x0, p0, 1.0; variable=[w])[1]), 0.5),
]
for (k, run) in cases
    try
        run()
        println(rpad(k, 32), "✓")
    catch e
        println(
            rpad(k, 32),
            "✗ ",
            nameof(typeof(e)),
            ": ",
            replace(first(sprint(showerror, e), 110), '\n' => ' '),
        )
    end
end
