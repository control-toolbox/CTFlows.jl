# Types
    
## Index

```@index
Pages   = ["types.md"]
Modules = [CTFlows]
Order = [:module, :constant, :type, :function, :macro]
```

!!! warning

    In the examples in the documentation below, the methods are not prefixed by the module name even if they are private. 

    ```julia-repl
    julia> using CTFlows
    julia> x = 1
    julia> private_fun(x) # throw an error
    ```

    must be replaced by

    ```julia-repl
    julia> using CTFlows
    julia> x = 1
    julia> CTFlows.private_fun(x)
    ```

    However, if the method is reexported by another package, then, there is no need of prefixing.

    ```julia-repl
    julia> module OptimalControl
               import CTFlows: private_fun
               export private_fun
           end
    julia> using OptimalControl
    julia> x = 1
    julia> private_fun(x)
    ```

## Documentation

```@autodocs
Pages = ["types.jl"]
Modules = [CTFlows]
Order = [:module, :constant, :type, :function, :macro]
```