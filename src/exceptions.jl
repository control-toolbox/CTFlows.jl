#
"""
$(TYPEDEF)

Exception thrown when an extension is not loaded but the user tries to call a function of it.

**Fields**

$(TYPEDFIELDS)
"""
struct ExtensionError <: CTException
    var::String
end

"""
$(TYPEDSIGNATURES)

Print the exception.
"""
Base.showerror(io::IO, e::ExtensionError) = print(io, "ExtensionError: ", e.var)