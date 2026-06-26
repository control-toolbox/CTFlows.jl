## Contributing

[issue-url]: https://github.com/control-toolbox/CTFlows.jl/issues
[first-good-issue-url]: https://github.com/control-toolbox/CTFlows.jl/contribute

If you think you found a bug or if you have a feature request / suggestion, feel free to open an [issue][issue-url].  
Before opening a pull request, please start an issue or a discussion on the topic. 

Contributions are welcomed, check out [how to contribute to a Github project](https://docs.github.com/en/get-started/exploring-projects-on-github/contributing-to-a-project). If it is your first contribution, you can also check [this first contribution tutorial](https://github.com/firstcontributions/first-contributions). You can find first good issues (if any 🙂) [here][first-good-issue-url]. You may find other packages to contribute to at the [control-toolbox organization](https://github.com/control-toolbox).

If you want to ask a question, feel free to start a discussion [here](https://github.com/orgs/control-toolbox/discussions). This forum is for general discussion about this repository and the [control-toolbox organization](https://github.com/control-toolbox).

>[!NOTE]
> If you want to add an application or a package to the control-toolbox ecosystem, please follow this [set up tutorial](https://github.com/orgs/control-toolbox/discussions/65).

---

## Code philosophy

CTFlows follows a set of design principles that apply to all contributions. Before
writing code, please read the philosophy documents in [`dev/philosophy/`](dev/philosophy/PHILOSOPHY.md).

The short version:

- **One submodule per responsibility.** Each submodule lives in `src/<Name>/` with its
  own manifest. The package top-level exports nothing — all symbols are accessed via
  qualified paths (`CTFlows.Submodule.symbol`).
- **Qualified imports everywhere.** Use `import Pkg: Pkg` or `using Pkg: Pkg`, never a
  bare `using Pkg`. Call sites read `Module.symbol`.
- **One abstract type per noun, one trait-parameter per orthogonal axis.** Conceptual
  variants are types; orthogonal axes (autonomous?, in-place?, …) are traits in type
  parameters. Dispatch via extractors.
- **Structured errors.** Seven typed exceptions from CTBase; sharp rule between
  `IncorrectArgument` (single value) and `PreconditionError` (relational/state).
  See [`dev/philosophy/exceptions.md`](dev/philosophy/exceptions.md).
- **Tests: module wrapper + callable entry + qualified imports.**
  See [`dev/philosophy/testing.md`](dev/philosophy/testing.md).
- **Docstrings last**, once the API is stable.

Full philosophy: [`dev/philosophy/PHILOSOPHY.md`](dev/philosophy/PHILOSOPHY.md)
