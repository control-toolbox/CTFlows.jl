# P4 — differentiating a Mooncake flow w.r.t. its initial condition (shooting use case).
#     julia --project=probe/mooncake_cpu probe/mooncake_cpu/p4_nested.jl
using OrdinaryDiffEqTsit5: OrdinaryDiffEqTsit5
using ADTypes: ADTypes
using Mooncake: Mooncake
using ForwardDiff: ForwardDiff
using FiniteDiff: FiniteDiff
using DifferentiationInterface: DifferentiationInterface as DI
using CTBase: CTBase, Data
using CTFlows: Flows, Systems
const MODE = "fixB2"
const EXT = Base.get_extension(CTBase, :CTBaseDifferentiationInterface)
include("patches.jl")

h = Data.Hamiltonian((x, p) -> sum(abs2, p) / 2 + sum(sin, x))
tol = (reltol=1e-10, abstol=1e-10)
z0 = [0.3, -0.7, 1.0, 0.5]
F(ad) = (f = Flows.Flow(h; ad_backend=ad, tol...); z -> vcat(f(0.0, z[1:2], z[3:4], 1.0)...))
Jref = ForwardDiff.jacobian(F(ADTypes.AutoForwardDiff()), z0)
for (k, outer) in ("outer ForwardDiff" => ADTypes.AutoForwardDiff(),
                   "outer FiniteDiff" => ADTypes.AutoFiniteDiff(),
                   "outer Mooncake" => ADTypes.AutoMooncake())
    try
        J = DI.jacobian(F(ADTypes.AutoMooncake()), outer, z0)
        println(rpad(k, 20), "✓  max|J-Jref| = ", maximum(abs, J - Jref))
    catch e
        println(rpad(k, 20), "✗ ", nameof(typeof(e)), ": ", replace(first(sprint(showerror, e), 400), '\n' => ' '))
    end
end
