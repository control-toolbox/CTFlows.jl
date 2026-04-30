---
trigger: always_on
---

# Julia Test Execution Guide

## 🤖 **Agent Directive**

**When applying this rule, explicitly state**: "🧪 **Applying Testing Rule**: [specific testing principle being applied]"

This ensures transparency about which testing standard is being used and why.

---

This document defines how to run tests for the CTFlows.jl project. For test creation standards, see `testing.md`.

## Running Tests

For detailed instructions on how to run tests (specific tests, test groups, or all tests), please refer to the testing guide:

**See**: `test/README.md`

This file contains comprehensive information about:

- Running all enabled tests
- Running specific test groups using glob patterns
- Running individual test files
- Running all tests including optional/long tests
- Generating coverage reports

### Capturing Test Output (Agents)

When running tests from the terminal (especially AI agents), **always pipe the output to a file via `tee`** instead of truncating with `tail -N`. Truncated output frequently hides the first failure or the compilation errors that trigger subsequent issues, forcing a second run.

**✅ Good — capture full log, inspect tail afterwards:**

```bash
julia --project -e 'using Pkg; Pkg.test("CTFlows"; test_args=["suite/systems/test_abstract_system"])' \
  2>&1 | tee /tmp/ctflows_test.log
# then, if needed, grep/tail the saved log without rerunning:
grep -E "Error|Fail|Test Summary" /tmp/ctflows_test.log
tail -200 /tmp/ctflows_test.log
```

**❌ Avoid — truncated stream lost if you need more context:**

```bash
julia --project -e '...' 2>&1 | tail -120   # if the relevant error is above line -120, you must rerun
```

**Rules of thumb:**

- Save to `/tmp/<pkg>_<scope>.log` (e.g., `/tmp/ctflows_test_systems.log`) so multiple concurrent sessions do not collide.
- Prefer `tee` on the full run; then use `grep`, `rg`, `tail`, or `less` on the saved file.
- Clean up `/tmp/*.log` files periodically; do not commit them.

## Quick Test Commands

### Convenience Alias: `jtest`

If the `jtest` alias is defined in your shell (typically in `~/.zsh_aliases`), you can use it as a shortcut:

```bash
# Alias definition (in ~/.zsh_aliases)
alias jtest="/Users/ocots/bin/julia_test.sh"
```

The `jtest` script wraps `Pkg.test()`:

```bash
# Run all tests
jtest

# Run specific test suite
jtest suite/systems/test_abstract_system
```

**Script location**: `~/bin/julia_test.sh` (user-local). If you have this alias, it provides a convenient way to run tests without typing the full Julia invocation each time.

### Run all tests

```bash
julia --project=@. -e 'using Pkg; Pkg.test()'
```

### Run specific test group

```bash
julia --project=@. -e 'using Pkg; Pkg.test(; test_args=["ocp"])'
```

### Generate coverage report

```bash
julia --project=@. -e 'using Pkg; Pkg.test("CTFlows"; coverage=true); include("test/coverage.jl")'
```

## References

- Test README: `test/README.md`
- Test creation standards: `testing.md`
- Test workflows: `@/test-julia`, `@/test-julia-debug`
- Shared test problems: `test/problems/TestProblems.jl`
- Test runner: Uses `CTBase.TestRunner` extension
