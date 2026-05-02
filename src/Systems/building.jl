"""
$(TYPEDSIGNATURES)

Build a `VectorFieldSystem` from a `VectorField`.
"""
function build_system(vf::Data.VectorField)
    return VectorFieldSystem(vf)
end
