# docs/

Documentation site for CTFlows.jl, built with
[DocumenterVitepress](https://github.com/LuxDL/DocumenterVitepress.jl).

Build (from the package root):

```bash
julia --project=. docs/make.jl
```

Preview after build: `npx serve docs/build/1 --listen 5173`

Documentation conventions and build workflow:
[ct-conventions](https://github.com/control-toolbox/ct-conventions) (rules `SITE1`–`SITE17`, `method.md`).

## `@repl` vs `@example` — ANSI color rule

Before `DocumenterVitepress` **v0.3.5**, ANSI-colored output from `@repl` was rendered as raw
escape sequences. This was fixed in v0.3.5
([#373](https://github.com/LuxDL/DocumenterVitepress.jl/pull/373)): colored `@repl` output is
now rendered correctly while the input remains Julia syntax-highlighted. The documentation
environment requires `DocumenterVitepress` 0.3.5 or later (`docs/Project.toml`).

**Rules:**

- Use **`@repl`** for interactive examples, including output from custom ANSI-colored `show`
  methods (flows, systems, integrators, trajectory objects, …).
- Use **`@example`** for regular evaluated examples when REPL formatting is not needed; existing
  blocks whose output already renders correctly are kept.
- Use **`@ansi`** when explicitly demonstrating terminal styling or raw ANSI output.
- To display an exception, write the expression that raises it directly in a **`@repl`** block:
  `@repl` captures the exception as output (`ERROR: …`) instead of failing the documentation
  build. No `try/catch` is needed.
