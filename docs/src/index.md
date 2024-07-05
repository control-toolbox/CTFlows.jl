# CTFlows.jl

```@meta
CurrentModule =  CTFlows
```

The `CTFlows.jl` package is part of the [control-toolbox ecosystem](https://github.com/control-toolbox).

```mermaid
flowchart TD
O(<a href='https://control-toolbox.org/docs/optimalcontrol/stable/'>OptimalControl</a>) --> B(<a href='https://control-toolbox.org/docs/ctbase/stable/'>CTBase</a>)
O --> D(<a href='https://control-toolbox.org/docs/ctdirect/stable/'>CTDirect</a>)
O --> F(<a href='https://control-toolbox.org/docs/ctflows/stable/'>CTFlows</a>)
P(<a href='https://control-toolbox.org/docs/ctproblems/stable/'>CTProblems</a>) --> F
P --> B
F --> B
D --> B
style F fill:#FBF275
```

!!! note "Install"

    To install a package from the control-toolbox ecosystem, 
    please visit the [installation page](https://github.com/control-toolbox#installation).

It aims to provide tools to solve [mathematical flows](https://en.wikipedia.org/w/index.php?title=Flow_(mathematics)&oldid=1147546136#Flows_of_vector_fields_on_manifolds) of vector fields, and in particular [Hamiltonian vector fields](https://en.wikipedia.org/w/index.php?title=Hamiltonian_vector_field&oldid=1065470192) directly from the definition of the Hamiltonian, using automatic differentiation to construct the assiocated Hamiltonian vector field.

The flow is then computed thanks to [OrdinaryDiffEq.jl](https://docs.sciml.ai/DiffEqDocs/stable/) package.
