"""
CTFlowsStaticArrays

Extension module providing type-stable support for `StaticArrays.SVector` and `SMatrix` in Hamiltonian flows.

This module extends the internal `_ham_split` function to handle `SVector` and `SMatrix` inputs efficiently when the state dimension `N` is known at compile time. This enables zero-allocation operations for Hamiltonian systems with immutable array types.

# Extension Details

The extension provides:
- `_ham_split(u::SVector, N::Int)`: Type-stable splitting of `SVector` into `(x, p)` components using `SVector` constructors.
- `_ham_split(u::SMatrix, N::Int)`: Type-stable splitting of `SMatrix` into `(X, P)` components using `SMatrix` constructors.

# Usage

Load the extension with `using CTFlowsStaticArrays` after loading `CTFlows`:

```julia
using CTFlows
using CTFlowsStaticArrays  # Loads this extension

# Now HamiltonianFlow works efficiently with SVector
hvf = HamiltonianVectorField((x, p) -> (p, -x); is_autonomous=true, is_variable=false)
flow = Flow(hvf; reltol=1e-8)
xf, pf = flow(0.0, SA[1.0, 0.0], SA[0.0, 1.0], π/2)

# And with SMatrix for matrix initial conditions
X0 = SA[1.0 2.0; 3.0 4.0]
P0 = SA[0.0 0.0; 1.0 1.0]
Xf, Pf = flow(0.0, X0, P0, π/2)
```

# Notes
- This extension is optional and only needed when using `StaticArrays.SVector` or `SMatrix` with Hamiltonian flows.
- For standard `Vector` or `Matrix` types, the base implementation in `CTFlows.Systems` handles splitting correctly.
"""
module CTFlowsStaticArrays

using CTFlows: CTFlows, Systems
using StaticArrays: SVector, SMatrix

"""
Type-stable split of a `SVector` into state and costate components.

# Arguments
- `u::SVector`: Combined state vector `[x; p]`.
- `N::Int`: Known state dimension (compile-time).

# Returns
- `Tuple{SVector{N}, SVector{N}}`: Tuple of `(x, p)` as `SVector`s.

# Notes
- This method provides type stability for SciML's out-of-place ODE solvers when using `StaticArrays`.
- Used automatically when the `CTFlowsStaticArrays` extension is loaded.
"""
function Systems._ham_split(u::SVector{NN,T}, N::Int) where {NN,T}
    x = SVector{N,T}(ntuple(i -> u[i], Val(N)))
    pk = SVector{N,T}(ntuple(i -> u[N + i], Val(N)))
    return (x, pk)
end

"""
Type-stable split of a `SMatrix` into state and costate components.

# Arguments
- `u::SMatrix{NN,M,T}`: Combined state matrix stacked vertically `[X; P]`.
- `N::Int`: Known state dimension.

# Returns
- `Tuple{SMatrix{N,M,T}, SMatrix{N,M,T}}`: Tuple of `(X, P)` as `SMatrix`s.

# Notes
- This method provides type stability for SciML's out-of-place ODE solvers when using `StaticArrays` for matrix initial conditions.
- Constructs new `SMatrix` objects since views don't work with immutable static arrays.
- Uses 1D column-major linear indexing to enumerate elements: for result element `k` (1-based),
  row = `(k-1) % N + 1`, col = `(k-1) ÷ N + 1`.
- Used automatically when the `CTFlowsStaticArrays` extension is loaded.
"""
function Systems._ham_split(u::SMatrix{NN,M,T}, N::Int) where {NN,M,T}
    # Enumerate result elements in column-major order via single index k
    X = SMatrix{N,M,T}(ntuple(k -> u[(k - 1) % N + 1, (k - 1) ÷ N + 1], Val(N*M)))
    P = SMatrix{N,M,T}(ntuple(k -> u[N + (k - 1) % N + 1, (k - 1) ÷ N + 1], Val(N*M)))
    return (X, P)
end

end # module CTFlowsStaticArrays
