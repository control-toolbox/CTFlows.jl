"""
$(TYPEDSIGNATURES)

Default value for in-place flag in hamiltonian_vector_field getter.

Returns `false` by default, meaning the getter returns out-of-place vector fields
unless specified otherwise.
"""
__hvf_inplace()::Bool = false

"""
$(TYPEDSIGNATURES)

Default AD backend for the `hamiltonian_vector_field(h::Data.AbstractHamiltonian; ...)` getter.

Returns `Differentiation.DifferentiationInterface()`, the CPU-default strategy. Callers that
need a device-specific backend (e.g. GPU) must build and pass one explicitly — this default is
not device-aware.

See also: [`CTFlows.Systems.hamiltonian_vector_field`](@extref), [`CTBase.Differentiation.DifferentiationInterface`](@extref).
"""
__hvf_ad_backend() = Differentiation.DifferentiationInterface()
