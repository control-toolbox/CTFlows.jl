var documenterSearchIndex = {"docs":
[{"location":"api.html#API","page":"API","title":"API","text":"","category":"section"},{"location":"api.html","page":"API","title":"API","text":"CollapsedDocStrings = true","category":"page"},{"location":"api.html#Index","page":"API","title":"Index","text":"","category":"section"},{"location":"api.html","page":"API","title":"API","text":"Pages   = [\"api.md\"]\nModules = [CTFlows]\nOrder   = [:module, :constant, :type, :function, :macro]","category":"page"},{"location":"api.html#Documentation","page":"API","title":"Documentation","text":"","category":"section"},{"location":"api.html","page":"API","title":"API","text":"Modules = [CTFlows]\nOrder   = [:module, :constant, :type, :function, :macro]\nPrivate = false","category":"page"},{"location":"api.html","page":"API","title":"API","text":"","category":"page"},{"location":"dev.html#Private-functions","page":"Developers","title":"Private functions","text":"","category":"section"},{"location":"dev.html","page":"Developers","title":"Developers","text":"CollapsedDocStrings = true","category":"page"},{"location":"dev.html#Index","page":"Developers","title":"Index","text":"","category":"section"},{"location":"dev.html","page":"Developers","title":"Developers","text":"Pages   = [\"dev.md\"]\nModules = [CTFlows]\nOrder   = [:module, :constant, :type, :function, :macro]","category":"page"},{"location":"dev.html#Documentation","page":"Developers","title":"Documentation","text":"","category":"section"},{"location":"dev.html","page":"Developers","title":"Developers","text":"Modules = [CTFlows]\nOrder   = [:module, :constant, :type, :function, :macro]\nPublic  = false","category":"page"},{"location":"dev.html#CTFlows.makeH-Tuple{CTBase.Dynamics, CTBase.ControlLaw, CTBase.Lagrange, Real, Real, CTBase.MixedConstraint, CTBase.Multiplier}","page":"Developers","title":"CTFlows.makeH","text":"makeH(\n    f::CTBase.Dynamics,\n    u::CTBase.ControlLaw,\n    f⁰::CTBase.Lagrange,\n    p⁰::Real,\n    s::Real,\n    g::CTBase.MixedConstraint,\n    μ::CTBase.Multiplier\n) -> CTFlows.var\"#H#22\"{CTBase.Dynamics{time_dependence, variable_dependence}, CTBase.ControlLaw{time_dependence1, variable_dependence1}, CTBase.Lagrange{time_dependence2, variable_dependence2}, var\"#s182\", var\"#s1821\", CTBase.MixedConstraint{time_dependence3, variable_dependence3}, CTBase.Multiplier{time_dependence4, variable_dependence4}} where {time_dependence, variable_dependence, time_dependence1, variable_dependence1, time_dependence2, variable_dependence2, var\"#s182\"<:Real, var\"#s1821\"<:Real, time_dependence3, variable_dependence3, time_dependence4, variable_dependence4}\n\n\nConstructs the Hamiltonian: \n\nH(t, x, p) = p ⋅ f(t, x, u(t, x, p)) + s p⁰ f⁰(t, x, u(t, x, p)) + μ(t, x, p) ⋅ g(t, x, u(t, x, p))\n\n\n\n\n\n","category":"method"},{"location":"dev.html#CTFlows.makeH-Tuple{CTBase.Dynamics, CTBase.ControlLaw, CTBase.Lagrange, Real, Real}","page":"Developers","title":"CTFlows.makeH","text":"makeH(\n    f::CTBase.Dynamics,\n    u::CTBase.ControlLaw,\n    f⁰::CTBase.Lagrange,\n    p⁰::Real,\n    s::Real\n) -> CTFlows.var\"#H#20\"{CTBase.Dynamics{time_dependence, variable_dependence}, CTBase.ControlLaw{time_dependence1, variable_dependence1}, CTBase.Lagrange{time_dependence2, variable_dependence2}, <:Real, <:Real} where {time_dependence, variable_dependence, time_dependence1, variable_dependence1, time_dependence2, variable_dependence2}\n\n\nConstructs the Hamiltonian: \n\nH(t, x, p) = p ⋅ f(t, x, u(t, x, p)) + s p⁰ f⁰(t, x, u(t, x, p))\n\n\n\n\n\n","category":"method"},{"location":"dev.html#CTFlows.makeH-Tuple{CTBase.Dynamics, CTBase.ControlLaw, CTBase.MixedConstraint, CTBase.Multiplier}","page":"Developers","title":"CTFlows.makeH","text":"makeH(\n    f::CTBase.Dynamics,\n    u::CTBase.ControlLaw,\n    g::CTBase.MixedConstraint,\n    μ::CTBase.Multiplier\n) -> CTFlows.var\"#H#21\"{CTBase.Dynamics{time_dependence, variable_dependence}, CTBase.ControlLaw{time_dependence1, variable_dependence1}, CTBase.MixedConstraint{time_dependence2, variable_dependence2}, CTBase.Multiplier{time_dependence3, variable_dependence3}} where {time_dependence, variable_dependence, time_dependence1, variable_dependence1, time_dependence2, variable_dependence2, time_dependence3, variable_dependence3}\n\n\nConstructs the Hamiltonian: \n\nH(t, x, p) = p ⋅ f(t, x, u(t, x, p)) + μ(t, x, p) ⋅ g(t, x, u(t, x, p))\n\n\n\n\n\n","category":"method"},{"location":"dev.html#CTFlows.makeH-Tuple{CTBase.Dynamics, CTBase.ControlLaw}","page":"Developers","title":"CTFlows.makeH","text":"makeH(\n    f::CTBase.Dynamics,\n    u::CTBase.ControlLaw\n) -> CTFlows.var\"#18#19\"{CTBase.Dynamics{time_dependence, variable_dependence}, CTBase.ControlLaw{time_dependence1, variable_dependence1}} where {time_dependence, variable_dependence, time_dependence1, variable_dependence1}\n\n\nConstructs the Hamiltonian: \n\nH(t, x, p) = p f(t, x, u(t, x, p))\n\n\n\n\n\n","category":"method"},{"location":"dev.html","page":"Developers","title":"Developers","text":"","category":"page"},{"location":"index.html#CTFlows.jl","page":"Introduction","title":"CTFlows.jl","text":"","category":"section"},{"location":"index.html","page":"Introduction","title":"Introduction","text":"CurrentModule =  CTFlows","category":"page"},{"location":"index.html","page":"Introduction","title":"Introduction","text":"The CTFlows.jl package is part of the control-toolbox ecosystem.","category":"page"},{"location":"index.html","page":"Introduction","title":"Introduction","text":"flowchart TD\nO(<a href='https://control-toolbox.org/OptimalControl.jl/stable/'>OptimalControl</a>) --> B(<a href='https://control-toolbox.org/OptimalControl.jl/stable/api-ctbase.html'>CTBase</a>)\nO --> D(<a href='https://control-toolbox.org/OptimalControl.jl/stable/api-ctdirect.html'>CTDirect</a>)\nO --> F(<a href='https://control-toolbox.org/OptimalControl.jl/stable/api-ctflows.html'>CTFlows</a>)\nF --> B\nD --> B\nstyle F fill:#FBF275","category":"page"},{"location":"index.html","page":"Introduction","title":"Introduction","text":"It aims to provide tools to solve mathematical flows of vector fields, and in particular Hamiltonian vector fields directly from the definition of the Hamiltonian, using automatic differentiation to construct the assiocated Hamiltonian vector field.","category":"page"},{"location":"index.html","page":"Introduction","title":"Introduction","text":"The flow is then computed thanks to OrdinaryDiffEq.jl package.","category":"page"},{"location":"index.html","page":"Introduction","title":"Introduction","text":"","category":"page"}]
}
