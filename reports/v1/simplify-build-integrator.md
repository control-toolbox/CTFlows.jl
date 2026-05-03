# Simplify `build_integrator` by removing Symbol dispatch (Point 3)

Remove the unnecessary `id::Symbol` parameter from `build_integrator` and the `Flow` constructor to eliminate defensive code against a hypothetical need.

---

## What changes and why

**Current state**: `build_integrator(id::Symbol; kwargs...)` dispatches on `:sciml` and throws `IncorrectArgument` for any other symbol. The `Flow` constructor accepts `id::Symbol=:sciml` and forwards it to `build_integrator`. This adds friction without benefit since there is only one integrator today.

**After refactoring**: Both functions accept only keyword options. `build_integrator` directly returns `SciML(; kwargs...)` without any validation. The API becomes cleaner and future-proof — if a second integrator arrives, dispatch can be reintroduced via type or Symbol with a real use case to justify it.

**API change**:
- Before: `Flow(vf, :sciml; reltol=1e-8)`
- After: `Flow(vf; reltol=1e-8)`

---

## Files affected

### Source code
- `src/Integrators/building.jl` — simplify `build_integrator` signature and implementation
- `src/Flows/building.jl` — remove `id::Symbol` parameter from `Flow` constructor

### Tests
- `test/suite/integrators/test_building_integrators.jl` — remove Symbol dispatch tests, keep export verification
- `test/suite/flows/test_building_flows.jl` — update Flow constructor calls to remove `:sciml`

### Documentation
- `docs/src/index.md` — update example to remove `:sciml`
- `windsurf/rules/documentation.md` — update examples to remove `:sciml`

---

## Step-by-step implementation

### Step 0 — Branch

```bash
git checkout develop && git pull
git checkout -b refactor/simplify-build-integrator
```

### Step 1 — `src/Integrators/building.jl`

Simplify the function signature and implementation:

```julia
"""
$(TYPEDSIGNATURES)

Build a `SciML` integrator with the given options.

# Arguments
- `kwargs...`: Options forwarded to the `SciML` constructor.

# Returns
- `CTFlows.Integrators.SciML`: The configured integrator.

# Example
\`\`\`julia
using CTFlows.Integrators

integrator = Integrators.build_integrator(reltol=1e-8, alg=Tsit5())
\`\`\`

See also: [`CTFlows.Integrators.SciML`](@ref), [`CTFlows.Integrators.build_sciml_integrator`](@ref).
"""
function build_integrator(; kwargs...)
    return SciML(; kwargs...)
end
```

**Changes**:
- Remove `id::Symbol` parameter from signature
- Remove the `if/else` dispatch logic
- Remove the `IncorrectArgument` exception (no longer needed)
- Update docstring to reflect new signature and purpose

### Step 2 — `src/Flows/building.jl`

Update the `Flow` constructor to remove the `id` parameter:

```julia
"""
$(TYPEDSIGNATURES)

High-level constructor for `Flow` from vector field data.

This constructor builds a complete flow by:
1. Building a `VectorFieldSystem` from the vector field data
2. Building a `SciML` integrator with the given options
3. Routing options through the integrator's CTSolvers strategy
4. Combining them into a callable `Flow`

# Arguments
- `data::CTFlows.Data.VectorField`: The vector field defining the system dynamics.
- `opts...`: Keyword options passed to the integrator's strategy.

# Returns
- `CTFlows.Flows.Flow`: The complete flow ready for integration.

# Example
\`\`\`julia
using CTFlows.Data, CTFlows.Flows, CTFlows.Common

vf = Data.VectorField((t, x, v) -> x, Common.Autonomous(), Common.Fixed())
flow = Flows.Flow(vf; reltol=1e-8)
\`\`\`

See also: [`CTFlows.Flows.Flow`](@ref), [`CTFlows.Systems.build_system`](@ref), [`CTFlows.Integrators.build_integrator`](@ref).
"""
function Flow(data::Data.VectorField; opts...)
    system = Systems.build_system(data)
    integrator = Integrators.build_integrator(; opts...)
    return Flow(system, integrator)
end
```

**Changes**:
- Remove `id::Symbol=:sciml` parameter from signature
- Call `Integrators.build_integrator(; opts...)` without the `id` argument
- Update docstring to remove references to integrator identifier
- Update example to remove `:sciml`

### Step 3 — `test/suite/integrators/test_building_integrators.jl`

Remove Symbol dispatch tests, keep export verification:

```julia
function test_building_integrators()
    Test.@testset "Integrator Building Tests" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ====================================================================
        # UNIT TESTS - build_integrator
        # ====================================================================

        Test.@testset "build_integrator" begin

            Test.@testset "builds SciML integrator" begin
                # This will throw ExtensionError if CTFlowsSciMLExt is not loaded,
                # but at least it calls the right function
                result = Integrators.build_integrator()
                Test.@test result isa Integrators.SciML
            end

            Test.@testset "forwards keyword options" begin
                result = Integrators.build_integrator(reltol=1e-10)
                Test.@test result isa Integrators.SciML
            end
        end

        # ====================================================================
        # UNIT TESTS - Exports Verification
        # ====================================================================

        Test.@testset "Exports Verification" begin
            Test.@testset "build_integrator is exported" begin
                Test.@test isdefined(Integrators, :build_integrator)
            end
        end
    end
end
```

**Changes**:
- Remove test for "valid id :sciml" (no longer relevant)
- Remove test for "unknown id throws IncorrectArgument" (no longer throws)
- Remove test for "error message for unknown id" (no longer throws)
- Add test for "forwards keyword options" (verifies kwargs forwarding)
- Keep export verification test

### Step 4 — `test/suite/flows/test_building_flows.jl`

Update Flow constructor calls to remove `:sciml`:

```julia
Test.@testset "Flow constructor from VectorField" begin
    Test.@testset "default constructor" begin
        vf = Data.VectorField(x -> -x; autonomous=true, variable=false)
        flow = Flows.Flow(vf)

        Test.@test flow isa Flows.Flow
        Test.@test flow isa Flows.AbstractFlow
        Test.@test flow.system isa Systems.VectorFieldSystem
        Test.@test flow.integrator isa Integrators.AbstractIntegrator
    end

    Test.@testset "with keyword options" begin
        vf = Data.VectorField(x -> -x; autonomous=true, variable=false)
        flow = Flows.Flow(vf; reltol=1e-10)

        Test.@test flow isa Flows.Flow
        Test.@test flow.integrator isa Integrators.AbstractIntegrator
    end
end
```

**Changes**:
- Rename test from "default integrator id (:sciml)" to "default constructor"
- Remove test for "explicit integrator id (:sciml)" (no longer relevant)
- Update "with keyword options" test to remove `:sciml` argument
- All other tests remain unchanged (they already use the default constructor)

### Step 5 — `docs/src/index.md`

Update the API example:

```julia
# Build a flow from vector field data
using CTFlows.Data, CTFlows.Flows, CTFlows.Common

vf = Data.VectorField((t, x, v) -> x, Autonomous(), Fixed())
flow = Flows.Flow(vf; reltol=1e-8)

# Integrate using a configuration
config = Common.TrajectoryConfig((0.0, 1.0), [1.0, 0.0])
sol = Flows.call(flow, config)

# Or point-to-point integration
config = Common.PointConfig((0.0, 1.0), [1.0, 0.0])
final_state = Flows.call(flow, config)
```

**Changes**:
- Change `Flow(vf, :sciml; reltol=1e-8)` to `Flow(vf; reltol=1e-8)`

### Step 6 — `windsurf/rules/documentation.md`

Update examples to remove `:sciml`:

Find and replace all occurrences:
- `Flows.Flow(vf, :sciml)` → `Flows.Flow(vf)`
- `Flows.Flow(vf, :sciml; ...)` → `Flows.Flow(vf; ...)`

**Changes**:
- Update any examples showing the old API
- Ensure consistency with the new simplified API

---

## Testing

### Run affected test suites

```bash
# Test integrators
julia --project=@. -e 'using Pkg; Pkg.test("CTFlows"; test_args=["suite/integrators/test_building_integrators"])'

# Test flows
julia --project=@. -e 'using Pkg; Pkg.test("CTFlows"; test_args=["suite/flows/test_building_flows"])'
```

### Run full test suite

```bash
julia --project=@. -e 'using Pkg; Pkg.test("CTFlows")'
```

### Verify documentation builds

```bash
cd docs
julia --project make.jl
```

---

## Rollback plan

If issues arise, revert the changes:

```bash
git checkout develop
git branch -D refactor/simplify-build-integrator
```

Or if already committed:

```bash
git revert <commit-hash>
```

---

## Future extensibility

If a second integrator is added in the future, the Symbol dispatch can be reintroduced with a real use case:

```julia
# Future: multiple integrators
function build_integrator(id::Symbol=:sciml; kwargs...)
    if id === :sciml
        return SciML(; kwargs...)
    elseif id === :custom
        return CustomIntegrator(; kwargs...)
    else
        throw(IncorrectArgument(...))
    end
end
```

Or better, use type-based dispatch:

```julia
# Future: type-based dispatch (preferred)
function build_integrator(::Type{SciML}; kwargs...)
    return SciML(; kwargs...)
end

function build_integrator(::Type{CustomIntegrator}; kwargs...)
    return CustomIntegrator(; kwargs...)
end
```

The current simplification removes premature optimization and makes the API cleaner for the current single-integrator case.
