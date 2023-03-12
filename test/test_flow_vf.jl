#
t0 = 0.0
tf = 1.0
x0 = [-1.0, 0.0]
p0 = [12.0, 6.0]

#
#
#
V(z) = [z[2], z[4], 0.0, -z[3]]
z = Flow(VectorField(V))
zf = z(t0, [x0; p0], tf)
@test zf ≈ [0.0, 0.0, 12.0, -6.0] atol=1e-5

#
V(t, z, l) = V(z)
z = Flow(VectorField{:nonautonomous}(V), abstol=1e-12)
zf = z(t0, [x0; p0], tf, 0.0)
@test zf ≈ [0.0, 0.0, 12.0, -6.0] atol=1e-5

# scalar case / vectorial usage
x = Flow(VectorField{:autonomous, :vectorial}(x -> [-x[1]]))
@test x(0.0, [1.0], 1.0) ≈ [exp(-1)] atol=1e-5