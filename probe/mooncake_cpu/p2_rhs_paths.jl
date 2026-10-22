# P2 — every AD-backed RHS path, AutoMooncake on host arrays, against AutoForwardDiff.
#
#     julia --project=probe/mooncake_cpu probe/mooncake_cpu/p2_rhs_paths.jl MODE
#
# MODE = raw   : the #436 guard is bypassed, nothing else changed
#        fixA  : `_ham_split` / `_aug_split` return copies (CTFlows-side fix)
#        fixB  : CTBase DI extension materializes a host `SubArray` before `DI.gradient`
#                when the backend is AutoMooncake (CTBase-side fix)
# Each mode runs in its own process: the patches redefine methods globally.
using OrdinaryDiffEqTsit5: OrdinaryDiffEqTsit5
using ADTypes: ADTypes
using Mooncake: Mooncake
using ForwardDiff: ForwardDiff
using DifferentiationInterface: DifferentiationInterface as DI
using CTBase: CTBase, Data
using CTFlows: Flows, Systems
using CTModels: CTModels

const MODE = isempty(ARGS) ? "raw" : ARGS[1]
const EXT = Base.get_extension(CTBase, :CTBaseDifferentiationInterface)

# the guard of #436 is always bypassed (patches.jl): we measure what is behind it
include("patches.jl")

FD = ADTypes.AutoForwardDiff()
MC = ADTypes.AutoMooncake()
tol = (reltol=1e-10, abstol=1e-10)

# ---- fixtures --------------------------------------------------------------
h = Data.Hamiltonian((x, p) -> sum(abs2, p) / 2 + sum(sin, x))
h1 = Data.Hamiltonian((x, p) -> p^2 / 2 + sin(x))
hv = Data.Hamiltonian((x, p, v) -> sum(abs2, p) / 2 + v[1] * sum(sin, x); is_variable=true)
h̃ = Data.PseudoHamiltonian((x, p, u) -> sum(p .* u) - 0.5 * sum(abs2, u) + sum(sin, x))
law = Data.DynClosedLoop((x, p) -> p)

function ocp_free(n)
    pre = CTModels.Building.PreModel()
    CTModels.Building.time_dependence!(pre; autonomous=true)
    CTModels.Building.time!(pre; t0=0.0, tf=1.0)
    CTModels.Building.state!(pre, n)
    CTModels.Building.dynamics!(pre, (r, t, x, u, v) -> (r.=sin.(x); nothing))
    CTModels.Building.objective!(pre, :min; mayer=(x0, xf, v) -> sum(xf))
    return CTModels.Building.build(pre)
end
function ocp_freev(n)
    pre = CTModels.Building.PreModel()
    CTModels.Building.time_dependence!(pre; autonomous=true)
    CTModels.Building.time!(pre; t0=0.0, tf=1.0)
    CTModels.Building.state!(pre, n)
    CTModels.Building.variable!(pre, 1)
    CTModels.Building.dynamics!(pre, (r, t, x, u, v) -> (r.=v[1] .* sin.(x); nothing))
    CTModels.Building.objective!(pre, :min; mayer=(x0, xf, v) -> sum(xf))
    return CTModels.Building.build(pre)
end
function ocp_ctrl(n)
    pre = CTModels.Building.PreModel()
    CTModels.Building.time_dependence!(pre; autonomous=true)
    CTModels.Building.time!(pre; t0=0.0, tf=1.0)
    CTModels.Building.state!(pre, n)
    CTModels.Building.control!(pre, n)
    CTModels.Building.dynamics!(pre, (r, t, x, u, v) -> (r.=u .- sin.(x); nothing))
    CTModels.Building.objective!(pre, :min; lagrange=(t, x, u, v) -> 0.5 * sum(abs2, u))
    return CTModels.Building.build(pre)
end
O2, O2v, O2c = ocp_free(2), ocp_freev(2), ocp_ctrl(2)

x0, p0 = [0.3, -0.7], [1.0, 0.5]
X0, P0 = [0.3 0.1; -0.7 0.2], [1.0 -1.0; 0.5 0.4]

_flat(r) =
    if r isa Tuple
        reduce(vcat, map(_flat, r))
    elseif r isa Number
        [r]
    else
        vec(collect(r))
    end
_endpoint(sol) = hasproperty(sol, :x0) ? _flat(sol(1.0)) : _flat(sol)

# name => (ad -> result vector)
cases = [
    "Flow(h) point" => ad -> _flat(Flows.Flow(h; ad_backend=ad, tol...)(0.0, x0, p0, 1.0)),
    "Flow(h) trajectory" =>
        ad -> begin
            s = Flows.Flow(h; ad_backend=ad, tol...)((0.0, 1.0), x0, p0)
            _flat(s(0.5))
        end,
    "Flow(h) Matrix batch" =>
        ad -> _flat(Flows.Flow(h; ad_backend=ad, tol...)(0.0, X0, P0, 1.0)),
    "Flow(h) 1-D scalar" =>
        ad -> _flat(Flows.Flow(h1; ad_backend=ad, tol...)(0.0, 0.3, 1.0, 1.0)),
    "Flow(hv) variable" =>
        ad ->
            _flat(Flows.Flow(hv; ad_backend=ad, tol...)(0.0, x0, p0, 1.0; variable=[0.5])),
    "Flow(hv) variable_costate" =>
        ad -> _flat(
            Flows.Flow(hv; ad_backend=ad, tol...)(
                0.0, x0, p0, 1.0; variable=[0.5], variable_costate=true
            ),
        ),
    "Flow(h̃, law) :total" =>
        ad -> _flat(Flows.Flow(h̃, law; ad_backend=ad, tol...)(0.0, x0, p0, 1.0)),
    "Flow(h̃, law) :partial" =>
        ad -> _flat(
            Flows.Flow(h̃, law; hamiltonian_type=:partial, ad_backend=ad, tol...)(
                0.0, x0, p0, 1.0
            ),
        ),
    "Flow(ocp) Hamiltonian call" =>
        ad -> _flat(Flows.Flow(O2; ad_backend=ad, tol...)(0.0, x0, p0, 1.0)),
    "Flow(ocp) state-only call" =>
        ad -> _flat(Flows.Flow(O2; ad_backend=ad, tol...)(0.0, x0, 1.0)),
    "Flow(ocp) Matrix batch" =>
        ad -> _flat(Flows.Flow(O2; ad_backend=ad, tol...)(0.0, X0, P0, 1.0)),
    "Flow(ocp_v) variable_costate" =>
        ad -> _flat(
            Flows.Flow(O2v; ad_backend=ad, tol...)(
                0.0, x0, p0, 1.0; variable=0.5, variable_costate=true
            ),
        ),
    "Flow(ocp, law) :total" =>
        ad -> _flat(Flows.Flow(O2c, law; ad_backend=ad, tol...)(0.0, x0, p0, 1.0)),
    "Flow(ocp, law) :partial" =>
        ad -> _flat(
            Flows.Flow(O2c, law; hamiltonian_type=:partial, ad_backend=ad, tol...)(
                0.0, x0, p0, 1.0
            ),
        ),
    "Flow(ocp, law) constrained" =>
        ad -> _flat(
            Flows.Flow(
                O2c,
                law;
                constraint=(x, u) -> sum(u),
                multiplier=(x, p) -> 0.3,
                ad_backend=ad,
                tol...,
            )(
                0.0, x0, p0, 1.0
            ),
        ),
    "outer FD.jacobian ∘ Flow(h)" =>
        ad -> begin
            f = Flows.Flow(h; ad_backend=ad, tol...)
            vec(
                ForwardDiff.jacobian(z -> _flat(f(0.0, z[1:2], z[3:4], 1.0)), vcat(x0, p0)),
            )
        end,
]

println("MODE = $MODE")
for (name, run) in cases
    ref = try
        run(FD)
    catch e
        println(rpad(name, 32), "FD REF FAILS: ", first(sprint(showerror, e), 100))
        continue
    end
    try
        r = run(MC)
        d = maximum(abs, r .- ref)
        println(rpad(name, 32), d < 1e-8 ? "✓" : "✗ WRONG", "  max|MC-FD| = ", d)
    catch e
        msg = replace(first(sprint(showerror, e), 160), '\n' => ' ')
        println(rpad(name, 32), "✗ ", nameof(typeof(e)), ": ", msg)
    end
end
