# Notes

- **Getter for Hamiltonian vector field (HVF) from Hamiltonian, system, and flow**: Implement a unified getter mechanism to extract the Hamiltonian vector field from different contexts (Hamiltonian data structure, system definition, or flow object). This would provide a consistent interface for accessing the vector field regardless of the source.

- **Replace closures with callable structs**: Refactor the codebase to use callable structs (functors) instead of closures. This improves type stability, performance, and debuggability. Callable structs can store state explicitly and are more amenable to compilation and optimization by the Julia compiler.

- **Improve consistency between scalar and vector operations**: Review the use of `scalarize` in solution construction to ensure proper handling of scalar vs vector cases. Determine if the current scalarization approach is semantically correct or if it indicates a deeper inconsistency in the API design. This may involve unifying the interface to handle both cases more uniformly.