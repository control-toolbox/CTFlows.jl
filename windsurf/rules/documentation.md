---
trigger: always_on
---

# Julia API Documentation Standards

## 🤖 **Agent Directive**

**When applying this rule, explicitly state**: "📖 **Applying Documentation Rule**: [specific documentation principle being applied]"

This ensures transparency about which documentation principle is being used and why.

---

This document defines how the `docs/` directory of a Control Toolbox package is organised and built. It complements [`docstrings.md`](docstrings.md) (which covers *what* to write inside docstrings) by specifying *how* those docstrings are turned into a published documentation site via [Documenter.jl](https://documenter.juliadocs.org/) and [`CTBase.automatic_reference_documentation()`](https://control-toolbox.org/CTBase.jl/stable/guide/api-documentation.html).

## Reference Implementations

Three control-toolbox packages illustrate the spectrum of complexity. All three share the same skeleton; differences are stylistic.

| Package | Scale | Notable features |
| --- | --- | --- |
| [`CTSolvers.jl/docs`](https://github.com/control-toolbox/CTSolvers.jl/tree/main/docs) | mid-weight package | Architecture page + Developer Guides + API Reference; `subdirectory="api"`; DocumenterMermaid |
| [`CTModels.jl/docs`](https://github.com/control-toolbox/CTModels.jl/tree/main/docs) | single package | Introduction + API Reference only; `subdirectory="."`; multiple extensions with `DocMeta.setdocmeta!`; Q&A-style Quick Start |
| [`OptimalControl.jl/docs`](https://github.com/control-toolbox/OptimalControl.jl/tree/main/docs) | meta-package | `DocumenterInterLinks` for cross-refs to dependencies; copies `Project.toml`/`Manifest.toml` to assets; documents only its Private API (Public is exposed via `@extref`) |

## Core Principles

1. **Auto-generated API reference** — never hand-write API pages; use `CTBase.automatic_reference_documentation()`.
2. **One page per submodule** — each submodule gets its own auto-generated API page.
3. **One page per loaded extension** — each `Base.get_extension`-detected extension gets its own page when present.
4. **Public + private documented** — both `public=true` and `private=true`, since users access internals via qualified paths (consistent with [`modules.md`](modules.md)).
5. **Hand-written guides separate from API** — narrative guides live under `docs/src/guides/`; the API reference is generated.
6. **Index page is the entry point** — `docs/src/index.md` provides admonitions, module table, guide links via `[@ref]`, and a Quick Start.
7. **Cross-references resolve at build time** — every `[@extref]` in a docstring must be backed by an `InterLinks` entry in `make.jl`.

## Directory Layout

```text
docs/
├── Project.toml
├── make.jl                  # entry point; uses with_api_reference()
├── api_reference.jl         # generate_api_reference() + with_api_reference()
├── inventories/             # InterLinks fallback inventories (one per dependency)
│   ├── CTBase.toml
│   ├── CTModels.toml
│   └── CTSolvers.toml
└── src/
    ├── index.md             # landing page
    ├── architecture.md      # narrative architecture page (optional)
    ├── guides/              # hand-written guides
    │   ├── implementing_a_modeler.md
    │   ├── implementing_an_integrator.md
    │   └── ...
    └── api/                 # auto-generated (cleaned up after build)
```

## Cross-Reference Infrastructure: DocumenterInterLinks

For the `[@extref]` syntax (defined in [`docstrings.md`](docstrings.md)) to actually resolve at build time, `make.jl` must declare an `InterLinks` registry — one entry per cross-referenced dependency:

```julia
using DocumenterInterLinks

links = InterLinks(
    "CTBase" => (
        "https://control-toolbox.org/CTBase.jl/stable/",
        "https://control-toolbox.org/CTBase.jl/stable/objects.inv",
        joinpath(@__DIR__, "inventories", "CTBase.toml"),
    ),
    "CTModels" => (
        "https://control-toolbox.org/CTModels.jl/stable/",
        "https://control-toolbox.org/CTModels.jl/stable/objects.inv",
        joinpath(@__DIR__, "inventories", "CTModels.toml"),
    ),
    "CTSolvers" => (
        "https://control-toolbox.org/CTSolvers.jl/stable/",
        "https://control-toolbox.org/CTSolvers.jl/stable/objects.inv",
        joinpath(@__DIR__, "inventories", "CTSolvers.toml"),
    ),
    # … one entry per dependency referenced via @extref
)
```

Each entry is a 3-tuple: stable docs URL, `objects.inv` URL (Sphinx-style inventory served by Documenter.jl), and a local TOML inventory under `docs/inventories/` used as fallback. Pass `links` to `makedocs` via the `plugins` argument:

```julia
makedocs(; plugins=[links], ...)
```

This is what makes references like `` [`CTSolvers.Strategies.AbstractStrategy`](@extref) `` resolve to the dependency's published documentation.

## `docs/make.jl` Template

### Common skeleton

```julia
pushfirst!(LOAD_PATH, joinpath(@__DIR__))
pushfirst!(LOAD_PATH, joinpath(@__DIR__, ".."))

using Documenter
using DocumenterInterLinks
using CTFlows
using CTBase
using Markdown
using MarkdownAST: MarkdownAST
# Optional: using DocumenterMermaid

# ─────────────────────────────────────────────────────────────────────────────
# DocumenterReference extension (from CTBase)
# ─────────────────────────────────────────────────────────────────────────────
const DocumenterReference = Base.get_extension(CTBase, :DocumenterReference)
if !isnothing(DocumenterReference)
    DocumenterReference.reset_config!()
end

# ─────────────────────────────────────────────────────────────────────────────
# DocMeta setup for the package and its extensions (loop pattern)
# ─────────────────────────────────────────────────────────────────────────────
const CTFlowsODE = Base.get_extension(CTFlows, :CTFlowsODE)
Modules = [CTFlows, CTFlowsODE]   # add extensions and dependencies as needed
for Module in Modules
    isnothing(Module) && continue
    isnothing(DocMeta.getdocmeta(Module, :DocTestSetup)) &&
        DocMeta.setdocmeta!(Module, :DocTestSetup, :(using $Module); recursive=true)
end

# ─────────────────────────────────────────────────────────────────────────────
# InterLinks (only if @extref is used in docstrings)
# ─────────────────────────────────────────────────────────────────────────────
links = InterLinks(
    "CTBase"    => ("https://control-toolbox.org/CTBase.jl/stable/",
                    "https://control-toolbox.org/CTBase.jl/stable/objects.inv",
                    joinpath(@__DIR__, "inventories", "CTBase.toml")),
    "CTModels"  => ("https://control-toolbox.org/CTModels.jl/stable/",
                    "https://control-toolbox.org/CTModels.jl/stable/objects.inv",
                    joinpath(@__DIR__, "inventories", "CTModels.toml")),
    "CTSolvers" => ("https://control-toolbox.org/CTSolvers.jl/stable/",
                    "https://control-toolbox.org/CTSolvers.jl/stable/objects.inv",
                    joinpath(@__DIR__, "inventories", "CTSolvers.toml")),
)

# ─────────────────────────────────────────────────────────────────────────────
# Paths and API reference generator
# ─────────────────────────────────────────────────────────────────────────────
repo_url = "github.com/control-toolbox/CTFlows.jl"
src_dir  = abspath(joinpath(@__DIR__, "..", "src"))
ext_dir  = abspath(joinpath(@__DIR__, "..", "ext"))

include("api_reference.jl")

# ─────────────────────────────────────────────────────────────────────────────
# Build
# ─────────────────────────────────────────────────────────────────────────────
with_api_reference(src_dir, ext_dir) do api_pages
    makedocs(;
        draft       = false,
        remotes     = nothing,
        warnonly    = [:cross_references],
        sitename    = "CTFlows.jl",
        plugins     = [links],
        format      = Documenter.HTML(;
            repolink  = "https://" * repo_url,
            prettyurls = false,
            assets    = [
                asset("https://control-toolbox.org/assets/css/documentation.css"),
                asset("https://control-toolbox.org/assets/js/documentation.js"),
            ],
        ),
        pages = [
            "Introduction"     => "index.md",
            "Architecture"     => "architecture.md",
            "Developer Guides" => [
                "Implementing a System"      => "guides/implementing_a_system.md",
                "Implementing a Flow Modeler" => "guides/implementing_a_flow_modeler.md",
                "Implementing an ODE Integrator" => "guides/implementing_an_ode_integrator.md",
                "Implementing an AD Backend" => "guides/implementing_an_ad_backend.md",
                "Pipelines"                  => "guides/pipelines.md",
                "Multi-phase Composition"    => "guides/multi_phase_composition.md",
                "Error Messages Reference"   => "guides/error_messages.md",
            ],
            "API Reference" => api_pages,
        ],
    )
end

deploydocs(; repo=repo_url * ".git", devbranch="main")
```

### Variations

`pages` structure:

- **Light (CTModels-style)** — `pages = ["Introduction" => "index.md", "API Reference" => api_pages]`. Use when there are no narrative guides.
- **Full (CTSolvers-style, recommended for CTFlows)** — Architecture + guides + API Reference, as shown above.

`warnonly` setting:

- `warnonly = true` (CTSolvers) — accept all build warnings.
- `warnonly = [:cross_references]` (CTModels, recommended for CTFlows) — accept only cross-reference warnings.

`prettyurls`:

- `false` for local browsing during development.
- `true` for deployed documentation (omit or rely on default).

## `docs/api_reference.jl` Template

The file defines two public functions and one internal helper:

- `generate_api_reference(src_dir, ext_dir) -> pages` — builds the `pages` vector by calling `CTBase.automatic_reference_documentation` for each submodule and each loaded extension.
- `with_api_reference(f, src_dir, ext_dir)` — wrapper that generates pages, calls `f(pages)`, then cleans up generated `.md` files via `_cleanup_pages` (in a `try/finally`).
- `_cleanup_pages(docs_src, pages)` — recursive helper that deletes the auto-generated files after the build.

### Submodule call

```julia
CTBase.automatic_reference_documentation(;
    subdirectory                = "api",                       # "api" (CTSolvers) or "." (CTModels)
    primary_modules             = [
        CTFlows.Systems => src(
            joinpath("Systems", "Systems.jl"),
            joinpath("Systems", "abstract_system.jl"),
            # ... all included files of the submodule
        ),
    ],
    external_modules_to_document = [CTFlows],                  # include re-exported symbols
    exclude                     = EXCLUDE_SYMBOLS,
    public                      = true,
    private                     = true,
    title                       = "Systems",
    title_in_menu               = "Systems",
    filename                    = "api_systems",               # "api_*" (CTModels) or "*" (CTSolvers)
)
```

### Extension call (auto-detected)

```julia
CTFlowsODE = Base.get_extension(CTFlows, :CTFlowsODE)
if !isnothing(CTFlowsODE)
    push!(pages,
        CTBase.automatic_reference_documentation(;
            subdirectory                 = "api",
            primary_modules              = [CTFlowsODE => ext("CTFlowsODE.jl")],
            external_modules_to_document = [CTFlows],
            exclude                      = EXCLUDE_SYMBOLS,
            public                       = true,
            private                      = true,
            title                        = "ODE Extension",
            title_in_menu                = "ODE",
            filename                     = "api_ext_ode",
        ),
    )
end
```

### Variations on the API call

- **`subdirectory`** — `"api"` puts pages under `docs/src/api/`; `"."` puts them directly under `docs/src/`. Pick one and stay consistent.
- **`filename` prefix** — `"api_systems"` (CTModels) makes auto-generated files visually distinct from hand-written ones; `"systems"` (CTSolvers) is fine when pages live under `api/`.
- **`external_modules_to_document`** — set to `[CTFlows]` whenever a submodule re-exports symbols at package level (almost always).
- **`EXCLUDE_SYMBOLS`** — start from `Symbol[:include, :eval]` and extend with package-specific noise (private macros, helper symbols leaked from `using`).

### Cleanup helper

```julia
function _cleanup_pages(docs_src::String, pages)
    for p in pages
        val = last(p)
        if val isa AbstractString
            fname = endswith(val, ".md") ? val : val * ".md"
            full_path = joinpath(docs_src, fname)
            if isfile(full_path)
                rm(full_path)
                println("Removed temporary API doc: $full_path")
            end
        elseif val isa AbstractVector
            _cleanup_pages(docs_src, val)
        end
    end
end
```

### Meta-package variant (OptimalControl-style)

When the package re-exports symbols from several control-toolbox dependencies, the public API is documented via `[@extref]` to those dependencies; the package itself only documents its **private** API:

```julia
pages = [
    CTBase.automatic_reference_documentation(;
        subdirectory                 = "api",
        primary_modules              = [
            OptimalControl => src(joinpath("helpers", "..."), ...)
        ],
        external_modules_to_document = [CTBase, CTModels, CTSolvers],
        public                       = false,           # public API lives in the dependencies
        private                      = true,
        title                        = "Private",
        title_in_menu                = "Private",
        filename                     = "private",
    ),
]
```

For CTFlows (single package), this variant does not apply — it is documented here for completeness.

### Optional: copy `Project.toml` / `Manifest.toml` to assets

For packages where users may want to reproduce the exact documentation environment (typically the meta-package):

```julia
mkpath(joinpath(@__DIR__, "src", "assets"))
cp(joinpath(@__DIR__, "Project.toml"),
   joinpath(@__DIR__, "src", "assets", "Project.toml"); force=true)
cp(joinpath(@__DIR__, "Manifest.toml"),
   joinpath(@__DIR__, "src", "assets", "Manifest.toml"); force=true)
```

Place these `cp` calls in `make.jl`, before `makedocs`.

## `docs/src/index.md` Template

Mandatory structure — the *end* of the file (Documentation section + Quick Start) is what users land on first:

````markdown
# CTFlows.jl

```@meta
CurrentModule = CTFlows
```

The `CTFlows.jl` package is part of the [control-toolbox ecosystem](https://github.com/control-toolbox).
It provides the **flow layer** for optimal control problems:

- **Systems** — assembled callable objects (`AbstractSystem`)
- **Flows** — system + integrator pairs (`AbstractFlow`)
- **Modelers** — flow modeler strategies (`AbstractFlowModeler`)
- **Integrators** — ODE integrator strategies (`AbstractODEIntegrator`)
- **AD Backends** — automatic-differentiation strategies (`AbstractADBackend`)
- **Pipelines** — `build_system`, `build_flow`, `integrate`, `build_solution`, `solve`

!!! info "CTFlows vs CTModels and CTSolvers"
    **CTFlows** focuses on **flowing** dynamical systems associated with optimal control problems
    (assembling systems, integrating ODEs, building solutions).
    For **defining** the problems themselves, see [CTModels.jl](https://github.com/control-toolbox/CTModels.jl);
    for **solving** them via discretisation and NLP, see [CTSolvers.jl](https://github.com/control-toolbox/CTSolvers.jl).

!!! note
    The root package is [OptimalControl.jl](https://github.com/control-toolbox/OptimalControl.jl) which aims
    to provide tools to model and solve optimal control problems with ordinary differential equations
    by direct and indirect methods, both on CPU and GPU.

!!! warning "Qualified Module Access"
    CTFlows does **not** export functions at the package level. All functions and types are
    accessed via qualified module paths (consistent with the [submodule architecture](modules.md)):

    ```julia
    using CTFlows
    CTFlows.Systems.dimensions(sys)               # ✓ Qualified
    CTFlows.Pipelines.build_system(input, m, ad)  # ✓ Qualified
    ```

## Modules

| Module | Purpose |
|--------|---------|
| `Core` | Shared types and utilities |
| `Systems` | `AbstractSystem`, concrete systems, `MultiPhaseSystem` |
| `Flows` | `AbstractFlow`, `Flow`, `MultiPhaseFlow` |
| `Modelers` | `AbstractFlowModeler` and concrete modelers |
| `Integrators` | `AbstractODEIntegrator` and concrete integrators |
| `ADBackends` | `AbstractADBackend` and concrete backends |
| `Pipelines` | `build_system`, `build_flow`, `integrate`, `build_solution`, `solve` |

## Documentation

### Developer Guides

- [Architecture](@ref) — module overview, type hierarchy, data flow
- [Implementing a System](@ref) — `AbstractSystem` contract
- [Implementing a Flow Modeler](@ref) — `AbstractFlowModeler` strategy
- [Implementing an ODE Integrator](@ref) — `AbstractODEIntegrator` strategy
- [Implementing an AD Backend](@ref) — `AbstractADBackend` strategy
- [Pipelines](@ref) — `build_system`, `build_flow`, `integrate`, `build_solution`, `solve`
- [Multi-phase Composition](@ref) — `MultiPhaseSystem` and `MultiPhaseFlow`
- [Error Messages Reference](@ref) — exception types with examples and fixes

### API Reference

Auto-generated documentation for all public and private symbols, organised by submodule.

## Quick Start

```julia
using CTFlows
using OrdinaryDiffEq  # loads the ODE integration extension

# Build a system from an OCP
sys = CTFlows.Pipelines.build_system((ocp, u), modeler, ad_backend)

# Build a flow (system + integrator)
flow = CTFlows.Pipelines.build_flow(sys, integrator)

# Integrate
sol = CTFlows.Pipelines.solve(flow, (t0, tf), x0, p0)
```
````

### Quick Start variants

- **Code-first (CTSolvers-style, shown above)** — a short, runnable Julia code block illustrating typical usage with qualified paths.
- **Q&A (CTModels-style)** — a list of "I want to ..." entries, each pointing to the relevant API page or guide. Useful when the API surface is wide.

## Conventions

### Admonitions

| Type | Use |
| --- | --- |
| `!!! info` | Contrasting the package with siblings, scope statements |
| `!!! note` | Pointers to the root package or related material |
| `!!! warning` | Qualified-access policy, breaking caveats |
| `!!! tip` | Performance hints, idiomatic patterns |

### Cross-references

- `[Title](@ref)` — in-package references (resolves to a heading or docstring in the current docs).
- `` [`Pkg.Submodule.sym`](@extref) `` — references to symbols in a dependency with separate documentation. Requires the dependency to appear in `InterLinks`.

See [`docstrings.md`](docstrings.md) for the full cross-reference policy.

### Code examples

Prefer fully qualified calls in examples (`CTFlows.Systems.dimensions(sys)`) — consistent with [`modules.md`](modules.md). Exceptions: short snippets where the qualified form would obscure the point and the symbol is unambiguous.

## Build Commands

### Local build

```bash
julia --project=docs -e 'using Pkg; Pkg.develop(PackageSpec(path=pwd())); Pkg.instantiate(); include("docs/make.jl")'
```

### CI deployment

Handled by `deploydocs(; repo=repo_url * ".git", devbranch="main")` at the bottom of `make.jl`. The standard control-toolbox GitHub Actions workflow takes care of the rest.

## Quality Checklist

Before finalising the documentation setup, verify:

- [ ] `docs/make.jl` uses the `with_api_reference()` wrapper.
- [ ] `docs/api_reference.jl` exists with `generate_api_reference`, `with_api_reference`, and `_cleanup_pages` functions.
- [ ] `DocumenterReference` extension is loaded and reset via `reset_config!()`.
- [ ] If `[@extref]` is used in any docstring, `DocumenterInterLinks` is set up in `make.jl` with one `InterLinks` entry per cross-referenced dependency, and `links` is passed to `makedocs(; plugins=[links])`.
- [ ] One `automatic_reference_documentation` call per submodule, both `public=true` and `private=true`, with `external_modules_to_document=[CTFlows]` when relevant.
- [ ] Each known extension is detected via `Base.get_extension` and conditionally documented.
- [ ] `DocMeta.setdocmeta!` loop covers the package and its loaded extensions when doctests are used.
- [ ] `docs/src/index.md` contains: meta block, ecosystem link, info/note/warning admonitions, modules table, guide links via `[@ref]`, API reference note, and Quick Start.
- [ ] All cross-references use `[@ref]` / `[@extref]` correctly (see [`docstrings.md`](docstrings.md)).
- [ ] Hand-written guides are placed under `docs/src/guides/`.
- [ ] No hand-written API pages — everything in `api/` is generated and cleaned up by `_cleanup_pages`.
