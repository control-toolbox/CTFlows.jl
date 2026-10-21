# P1 — root cause at the DI/Mooncake level, no CTFlows involved.
using DifferentiationInterface: DifferentiationInterface as DI
using ADTypes: AutoMooncake, AutoForwardDiff
using Mooncake: Mooncake
using ForwardDiff: ForwardDiff
using Chairmarks: @b

f(x) = sum(abs2, x) / 2 + sum(sin, x)
u = collect(1.0:6.0)
xs = Dict(
    "Vector" => u[1:3],
    "view (UnitRange)" => view(u, 1:3),
    "view (Matrix col block)" => view(reshape(u, 3, 2), :, 1),
    "Matrix view rows" => view(reshape(u, 6, 1), 1:3, :),
    "reshape" => reshape(u[1:4], 2, 2),
)
g(x) = sum(abs2, x) / 2 + sum(sin, x)
backs = [
    "Mooncake default" => AutoMooncake(),
    "Mooncake friendly" => AutoMooncake(; config=Mooncake.Config(; friendly_tangents=true)),
    "ForwardDiff" => AutoForwardDiff(),
]
for (kx, x) in sort(collect(xs); by=first), (kb, b) in backs
    try
        gr = DI.gradient(g, b, x)
        ref = x .+ cos.(x)
        ok = gr isa AbstractArray && isapprox(collect(gr), collect(ref))
        neg = try; -gr; "neg ok"; catch; "neg FAILS"; end
        println(rpad(kx, 26), rpad(kb, 20), ok ? "✓ " : "✗ ", typeof(gr) |> string |> s -> first(s, 70), "  ", neg)
    catch e
        println(rpad(kx, 26), rpad(kb, 20), "ERR ", first(sprint(showerror, e), 120))
    end
end

println("\n-- unprepared DI.gradient cost (µs), closure over a view, like CTBase --")
for n in (2, 20, 200, 2000)
    w = rand(2n); x = view(w, 1:n); xc = w[1:n]
    p = view(w, n+1:2n)
    h(x_) = sum(abs2, p) / 2 + sum(sin, x_)
    fd = @b DI.gradient($h, $(AutoForwardDiff()), $x)
    mf = @b DI.gradient($h, $(AutoMooncake(; config=Mooncake.Config(; friendly_tangents=true))), $x)
    mc = @b DI.gradient($h, $(AutoMooncake()), $xc)
    println("n=$n  FD(view) ", round(fd.time*1e6; digits=2), "  MC friendly(view) ", round(mf.time*1e6; digits=2), "  MC default(copy) ", round(mc.time*1e6; digits=2))
end
