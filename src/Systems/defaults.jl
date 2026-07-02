"""
$(TYPEDSIGNATURES)

Default value for in-place flag in hamiltonian_vector_field getter.

Returns `false` by default, meaning the getter returns out-of-place vector fields
unless specified otherwise.
"""
__hvf_inplace()::Bool = false
