#!/usr/bin/env julia
using Revise
using Pkg

# Add the project to the path
Pkg.activate(@__DIR__)
Pkg.develop(path=joinpath(@__DIR__, ".."))

using CTFlows.Systems
using CTFlows.Flows
using CTFlows.Integrators
using CTFlows.Pipelines
using CTFlows.Common
using OrdinaryDiffEqTsit5

println("=" ^ 80)
println("CTFlows v1 Examples")
println("=" ^ 80)

# =============================================================================
# 1. VectorField with Explicit Traits
# =============================================================================

println("\n1. VectorField with Explicit Traits")
println("-" ^ 80)

# Using keyword constructor with defaults
vf_default = Systems.VectorField(x -> -x)
println("Default constructor (autonomous=true, variable=false):")
display(vf_default)

# Autonomous Fixed - depends only on state x
println("\n--- Scalar case ---")
vf_scalar = Systems.VectorField(x -> -2x, Systems.Autonomous, Systems.Fixed)
println("Scalar: vf(3.0) = ", vf_scalar(3.0))
display(vf_scalar)

println("\n--- Vector case ---")
vf_vector = Systems.VectorField(x -> -x, Systems.Autonomous, Systems.Fixed)
println("Vector: vf([1.0, 2.0]) = ", vf_vector([1.0, 2.0]))
display(vf_vector)

println("\n--- Matrix case ---")
vf_matrix = Systems.VectorField(x -> -x, Systems.Autonomous, Systems.Fixed)
x0_matrix = [1.0 2.0; 3.0 4.0]
println("Matrix: vf(x0_matrix) = ", vf_matrix(x0_matrix))
display(vf_matrix)

# NonAutonomous Fixed - depends on time t and state x
println("\n--- NonAutonomous cases ---")
vf_nonautonomous_fixed = Systems.VectorField((t, x) -> t .* x, Systems.NonAutonomous, Systems.Fixed)
println("NonAutonomous Fixed (vector): vf(2.0, [1.0, 2.0]) = ", vf_nonautonomous_fixed(2.0, [1.0, 2.0]))

# Autonomous NonFixed - depends on state x and variable v
vf_autonomous_nonfixed = Systems.VectorField((x, v) -> x .+ v, Systems.Autonomous, Systems.NonFixed)
println("Autonomous NonFixed (vector): vf([1.0, 2.0], 0.5) = ", vf_autonomous_nonfixed([1.0, 2.0], 0.5))

# NonAutonomous NonFixed - depends on time t, state x, and variable v
vf_nonautonomous_nonfixed = Systems.VectorField((t, x, v) -> t .* x .+ v, Systems.NonAutonomous, Systems.NonFixed)
println("NonAutonomous NonFixed (vector): vf(2.0, [1.0, 2.0], 0.5) = ", vf_nonautonomous_nonfixed(2.0, [1.0, 2.0], 0.5))

# Using keyword constructor with explicit flags
vf_kw_autonomous = Systems.VectorField(x -> -x; autonomous=true, variable=false)
println("\nKeyword constructor with explicit flags:")
display(vf_kw_autonomous)

vf_kw_nonautonomous = Systems.VectorField((t, x) -> t .* x; autonomous=false, variable=false)
println("NonAutonomous via keyword:")
display(vf_kw_nonautonomous)

vf_kw_nonfixed = Systems.VectorField((x, v) -> x .+ v; autonomous=true, variable=true)
println("NonFixed via keyword:")
display(vf_kw_nonfixed)

# =============================================================================
# 2. VectorFieldSystem
# =============================================================================

println("\n2. VectorFieldSystem")
println("-" ^ 80)

sys = Systems.VectorFieldSystem(vf_vector)
println("VectorFieldSystem created from VectorField")
println("  variable_dependence(sys) = ", Systems.variable_dependence(sys))

# =============================================================================
# 3. Pipeline: build_system
# =============================================================================

println("\n3. Pipeline: build_system")
println("-" ^ 80)

# Build system directly from VectorField
sys_built = Pipelines.build_system(vf_vector)
println("Built system: ", typeof(sys_built))

# =============================================================================
# 4. Config Objects (PointConfig, TrajectoryConfig)
# =============================================================================

println("\n4. Config Objects")
println("-" ^ 80)

# PointConfig for single point integration
point_config = Common.PointConfig(0.0, [1.0, 0.0], 1.0)
display(point_config)

# TrajectoryConfig for full trajectory
traj_config = Common.TrajectoryConfig((0.0, 1.0), [1.0, 0.0])
display(traj_config)

# =============================================================================
# 5. Complete Pipeline Examples (VectorField → System → Flow)
# =============================================================================

println("\n5. Complete Pipeline Structure")
println("-" ^ 80)

println("\n--- Vector case pipeline (Fixed) ---")
println("Step 1: Create VectorField")
vf_vector = Systems.VectorField(x -> -x, Systems.Autonomous, Systems.Fixed)
display(vf_vector)
println("Call: vf([1.0, 2.0]) = ", vf_vector([1.0, 2.0]))

println("\nStep 2: Build System")
sys_vector = Pipelines.build_system(vf_vector)
println("System: ", typeof(sys_vector))
println("  time_dependence(sys) = ", Systems.time_dependence(sys_vector))
println("  variable_dependence(sys) = ", Systems.variable_dependence(sys_vector))

println("\nStep 3: Build Flow (requires SciML extension)")
println("  flow = Pipelines.build_flow(sys_vector, integrator)")
println("  # Requires: using OrdinaryDiffEq")
println("  # integrator = Integrators.SciMLIntegrator()")

println("\nStep 4: Call Flow - multiple ways")
println("\n  4a. With PointConfig:")
println("    config = Common.PointConfig(0.0, [1.0, 2.0], 1.0)")
println("    result = flow(config)")

println("\n  4b. With TrajectoryConfig:")
println("    config = Common.TrajectoryConfig((0.0, 1.0), [1.0, 2.0])")
println("    result = flow(config)")

println("\n  4c. With args (builds PointConfig internally):")
println("    result = flow(0.0, [1.0, 2.0], 1.0)")

println("\n  4d. With tspan (builds TrajectoryConfig internally):")
println("    result = flow((0.0, 1.0), [1.0, 2.0])")

println("\n  4e. Via integrate function:")
println("    result = Pipelines.integrate(flow, config)")

println("\n  4f. Via solve function:")
println("    result = Pipelines.solve(flow, config)")

println("\n--- NonFixed case (with variable) ---")
vf_nonfixed = Systems.VectorField((x, v) -> x .+ v, Systems.Autonomous, Systems.NonFixed)
println("VectorField (NonFixed):")
display(vf_nonfixed)

sys_nonfixed = Pipelines.build_system(vf_nonfixed)
println("System (NonFixed): ", typeof(sys_nonfixed))

println("\nFlow calls with variable kwarg:")
println("  flow(config; variable=0.5)")
println("  flow(0.0, [1.0, 2.0], 1.0; variable=0.5)")
println("  flow((0.0, 1.0), [1.0, 2.0]; variable=0.5)")

println("\n--- Scalar case ---")
vf_scalar = Systems.VectorField(x -> -2x, Systems.Autonomous, Systems.Fixed)
println("Scalar VectorField:")
display(vf_scalar)
println("  flow(0.0, 3.0, 1.0)  # PointConfig with scalar x0")

println("\n--- Matrix case ---")
vf_matrix = Systems.VectorField(x -> -x, Systems.Autonomous, Systems.Fixed)
x0_matrix = [1.0 2.0; 3.0 4.0]
println("Matrix VectorField:")
display(vf_matrix)
println("  flow(0.0, x0_matrix, 1.0)  # PointConfig with matrix x0")

# =============================================================================
# 6. Trait Information
# =============================================================================

println("\n6. Trait Information")
println("-" ^ 80)

println("Available traits:")
println("  TimeDependence: Autonomous, NonAutonomous")
println("  VariableDependence: Fixed, NonFixed")

println("\nTrait types are concrete structs for type parameter compatibility")
println("  Systems.Autonomous (type, not instance)")
println("  Systems.Fixed (type, not instance)")

println("\n--- Trait accessors ---")
println("  time_dependence(vf) returns the time dependence trait")
println("  variable_dependence(vf) returns the variable dependence trait")
println("  time_dependence(sys) returns the time dependence trait from system")
println("  variable_dependence(sys) returns the variable dependence trait from system")

# =============================================================================
# 7. Summary
# =============================================================================

println("\n" * "=" ^ 80)
println("Examples completed successfully!")
println("=" ^ 80)
println("\nTo execute the complete pipeline with Flow:")
println("  1. Install OrdinaryDiffEq: Pkg.add(\"OrdinaryDiffEqTsit5\")")
println("  2. The CTFlowsSciMLExt extension will be automatically activated")
println("  3. Then you can use:")
println("     integrator = Integrators.SciMLIntegrator()")
println("     flow = Pipelines.build_flow(system, integrator)")
println("     result = flow(config)")
println("     result = Pipelines.integrate(flow, config)")
println("     result = Pipelines.solve(flow, config)")

