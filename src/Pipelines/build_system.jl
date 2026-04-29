"""
$(TYPEDSIGNATURES)

Build a `VectorFieldSystem` from a `VectorField`. The variable for `NonFixed`
vector fields is **not** captured here; it is supplied at flow-call time via
the `variable` kwarg.
"""
build_system(vf::Systems.VectorField) = Systems.VectorFieldSystem(vf)
