# P3 — cost of a full flow call, ForwardDiff vs Mooncake, for the fix of MODE (fixA|fixB).
#     julia --project=probe/mooncake_cpu probe/mooncake_cpu/p3_cost.jl MODE
using OrdinaryDiffEqTsit5: OrdinaryDiffEqTsit5
using ADTypes: ADTypes
using Mooncake: Mooncake
using ForwardDiff: ForwardDiff
using DifferentiationInterface: DifferentiationInterface as DI
using CTBase: CTBase, Data
using CTFlows: Flows, Systems
using Chairmarks: @b
const MODE = ARGS[1]
const EXT = Base.get_extension(CTBase, :CTBaseDifferentiationInterface)
include("patches.jl")

h = Data.Hamiltonian((x, p) -> sum(abs2, p) / 2 + sum(sin, x))
tol = (reltol=1e-10, abstol=1e-10)
println("MODE = $MODE   (ms, median of Chairmarks @b; allocs per call)")
for n in (2, 10, 30, 100, 400, 1000)
    x0, p0 = rand(n), rand(n)
    row = String[]
    for (k, ad) in ("FD" => ADTypes.AutoForwardDiff(), "MC" => ADTypes.AutoMooncake())
        f = Flows.Flow(h; ad_backend=ad, tol...)
        f(0.0, x0, p0, 1.0)
        b = @b $f(0.0, $x0, $p0, 1.0) seconds = 3
        push!(
            row, "$k $(round(b.time * 1e3; digits=2)) ms / $(round(Int, b.allocs)) allocs"
        )
    end
    println("n=", rpad(n, 6), join(row, "   "))
end
