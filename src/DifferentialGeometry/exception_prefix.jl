"""
Return the default prefix for the exception-handling module used in `@Lie` generated code.
"""
__default_e_prefix()::Symbol = :CTBase

"""
Prefix reference for the exception-handling module used in `@Lie` generated code.

This `Ref` stores the symbol of the module that defines the `IncorrectArgument`
type thrown by the `@Lie` macro at expansion time.
"""
const E_PREFIX = Ref{Symbol}(__default_e_prefix())

"""
$(TYPEDSIGNATURES)

Return the current exception-handling module prefix used by `@Lie`.
"""
e_prefix()::Symbol = E_PREFIX[]

"""
$(TYPEDSIGNATURES)

Set the exception-handling module prefix used in `@Lie` generated code.
"""
e_prefix!(p::Symbol) = (E_PREFIX[] = p; nothing)
