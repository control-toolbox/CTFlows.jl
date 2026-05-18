# Exception Types Reference

CTBase provides seven exception types, all subtypes of `CTException`. Import with:

```julia
import CTBase.Exceptions
```

Catch all domain errors uniformly with:

```julia
try
    risky_operation()
catch e
    if e isa Exceptions.CTException
        handle_error(e)
    else
        rethrow()
    end
end
```

**Hierarchy:**

```text
CTException (abstract)
├── IncorrectArgument      # Invalid argument value
├── PreconditionError      # Wrong order / state violation
├── NotImplemented         # Interface stub
├── ParsingError           # DSL / syntax error
├── AmbiguousDescription   # Description tuple not found
├── ExtensionError         # Missing optional dependency
└── SolverFailure          # Solver / integrator failure
```

---

## 1. IncorrectArgument

Use when an individual argument is invalid or violates a precondition.

**Fields:**

- `msg::String`: Main error message (required)
- `got::Union{String, Nothing}`: What value was received (optional)
- `expected::Union{String, Nothing}`: What value was expected (optional)
- `suggestion::Union{String, Nothing}`: How to fix the problem (optional)
- `context::Union{String, Nothing}`: Where the error occurred (optional)

**Examples:**

```julia
# Simple message
throw(IncorrectArgument("Invalid criterion"))

# With got/expected
throw(IncorrectArgument(
    "Invalid criterion",
    got=":invalid",
    expected=":min or :max"
))

# Full context
throw(IncorrectArgument(
    "Invalid criterion",
    got=":invalid",
    expected=":min or :max",
    suggestion="Use objective!(ocp, :min, ...) or objective!(ocp, :max, ...)",
    context="objective! function"
))
```

**When to use:**

- Invalid function arguments
- Type mismatches
- Value out of range
- Missing required parameters
- Invalid combinations of parameters

---

## 2. PreconditionError

Use when a function call violates a precondition or is not allowed in the current state of the system. The arguments may be valid, but the *timing* or *state* is wrong.

**Fields:**

- `msg::String`: Main error message (required)
- `reason::Union{String, Nothing}`: Why the precondition failed (optional)
- `suggestion::Union{String, Nothing}`: How to fix the problem (optional)
- `context::Union{String, Nothing}`: Where the error occurred (optional)

**Examples:**

```julia
# Simple message
throw(PreconditionError("State must be set before dynamics"))

# With reason and suggestion
throw(PreconditionError(
    "Cannot call state! twice",
    reason="state has already been defined for this OCP",
    suggestion="Create a new OCP instance"
))

# Full context
throw(PreconditionError(
    "Cannot modify frozen OCP",
    reason="OCP has been finalized and is immutable",
    suggestion="Create a new OCP or modify before calling finalize!()",
    context="constraint! function"
))
```

**When to use:**

- Functions called in the wrong order
- Operations on uninitialized objects
- State machine violations
- Workflow step dependencies

**Distinction from `IncorrectArgument`:**

- `IncorrectArgument`: the *value* of an argument is wrong
- `PreconditionError`: the *timing* or *state* is wrong

---

## 3. NotImplemented

Use to mark interface points that must be implemented by concrete subtypes.

**Fields:**

- `msg::String`: Description of what is not implemented (required)
- `required_method::Union{String, Nothing}`: Method signature that needs implementation (optional)
- `suggestion::Union{String, Nothing}`: How to fix the problem (optional)
- `context::Union{String, Nothing}`: Where the error occurred (optional)

**Examples:**

```julia
# Simple message
throw(NotImplemented("solve! not implemented for MyStrategy"))

# With required_method and suggestion
throw(NotImplemented(
    "Method solve! not implemented",
    required_method="solve!(::MyStrategy, ...)",
    suggestion="Import the relevant package (e.g. CTDirect) or implement solve!(::MyStrategy, ...)"
))

# For abstract type contracts
abstract type AbstractStrategy end

function solve!(strategy::AbstractStrategy, problem)
    throw(NotImplemented(
        "solve! must be implemented for each strategy type",
        required_method="solve!(::$(typeof(strategy)), problem)",
        suggestion="Define solve!(::$(typeof(strategy)), problem)",
        context="strategy dispatch"
    ))
end
```

**When to use:**

- Abstract type interface methods
- Extension points
- Optional features not yet implemented
- Platform-specific functionality

---

## 4. ParsingError

Use for parsing errors in DSLs or structured input.

**Fields:**

- `msg::String`: Description of the parsing error (required)
- `location::Union{String, Nothing}`: Where in the input the error occurred (optional)
- `suggestion::Union{String, Nothing}`: How to fix the problem (optional)

**Examples:**

```julia
# Simple message
throw(ParsingError("Unexpected token 'end'"))

# With location and suggestion
throw(ParsingError(
    "Unexpected token 'end'",
    location="line 42, column 15",
    suggestion="Check syntax balance or remove extra 'end'"
))
```

**When to use:**

- DSL parsing errors
- Configuration file parsing
- Input validation during parsing
- Syntax errors

---

## 5. AmbiguousDescription

Use when a description (a tuple of `Symbol`s) cannot be matched to any known valid description in a catalogue.

**Fields:**

- `description::Tuple{Vararg{Symbol}}`: The ambiguous or incorrect description tuple (required)
- `candidates::Union{Vector{String}, Nothing}`: Suggested valid alternatives (optional)
- `suggestion::Union{String, Nothing}`: How to fix the problem (optional)
- `context::Union{String, Nothing}`: Where the error occurred (optional)

**Constructor:** `AmbiguousDescription(description; msg=..., candidates=..., suggestion=..., context=...)`

**Examples:**

```julia
# Simple
throw(AmbiguousDescription((:f,)))

# With candidates and suggestion
throw(AmbiguousDescription(
    (:descent,),
    candidates=["(:descent, :bfgs, :bisection)", "(:descent, :gradient, :fixedstep)"],
    suggestion="Use a complete description like (:descent, :bfgs, :bisection)",
    context="algorithm selection"
))
```

**When to use:**

- Description-based APIs where a partial `Symbol` tuple doesn't match any catalogue entry
- Algorithm selection via symbolic descriptions
- Pattern matching in mathematical modeling DSLs

---

## 6. ExtensionError

Use when a feature requires optional dependencies (weak dependencies) that are not loaded.

**Fields:**

- `weakdeps::Tuple{Vararg{Symbol}}`: Names of missing packages
- `feature::Union{String, Nothing}`: Which feature requires them (optional)
- `context::Union{String, Nothing}`: Where the error occurred (optional)

**Constructor:** `ExtensionError(pkgs::Symbol...; message="", feature=nothing, context=nothing)`

⚠️ `ExtensionError()` with no arguments throws `PreconditionError` instead.

**Examples:**

```julia
# Single missing dependency
throw(ExtensionError(:Plots))

# With feature description
throw(ExtensionError(
    :Plots,
    feature="result visualization",
    context="plot_results function"
))

# Multiple missing dependencies
throw(ExtensionError(:SciMLBase, :OrdinaryDiffEq;
    message="to integrate ODEs",
    feature="ODE integration",
    context="build_flow"
))
```

**When to use:**

- Extension stubs in `ext/` files (SciML, ForwardDiff, Plots, StaticArrays)
- Weak dependency not loaded by the user
- ODE integration, plotting, AD functionality behind extensions

---

## 7. SolverFailure

Use when a solver (ODE integrator, optimization solver, linear solver) fails to complete successfully.

**Fields:**

- `msg::String`: Error message describing the failure (required)
- `retcode::Union{String, Nothing}`: Solver-specific return code (optional)
- `suggestion::Union{String, Nothing}`: How to fix the problem (optional)
- `context::Union{String, Nothing}`: Where the error occurred (optional)

**Examples:**

```julia
# Simple
throw(SolverFailure("ODE integration failed"))

# With SciML retcode
throw(SolverFailure(
    "ODE integration failed",
    retcode=":Unstable",
    suggestion="Reduce time step or check initial conditions",
    context="SciML integrator in build_flow"
))

# Optimization solver
throw(SolverFailure(
    "Optimization solver did not converge",
    retcode=":MaxIterations",
    suggestion="Increase max iterations or adjust tolerance settings",
    context="IPOPT solver in CTDirect"
))
```

**Common SciML return codes:** `:Unstable`, `:DtLessThanMin`, `:MaxIters`, `:Success`

**When to use:**

- ODE integration failures in CTFlows (SciML integrators)
- Non-convergence of optimization solvers
- Ill-conditioned linear systems
- Any numerical solver returning a failure status

**Distinction from other exceptions:**

- `IncorrectArgument`: the *input* is invalid
- `PreconditionError`: the *state* or *timing* is wrong
- `SolverFailure`: the *numerical computation* itself failed

---

## Quick Reference

| Situation | Exception |
| --- | --- |
| Invalid argument value | `IncorrectArgument` |
| Wrong function call order / state | `PreconditionError` |
| Unimplemented interface method | `NotImplemented` |
| DSL / syntax parsing error | `ParsingError` |
| Description tuple not matched | `AmbiguousDescription` |
| Missing optional dependency | `ExtensionError` |
| Solver / integrator failure | `SolverFailure` |
