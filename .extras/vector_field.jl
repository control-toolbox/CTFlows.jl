#!/usr/bin/env julia
using Revise
using Pkg

# Add the project to the path
Pkg.activate(@__DIR__)
Pkg.develop(path=joinpath(@__DIR__, ".."))

using CTFlows.Data
using CTFlows.Common
using CTFlows.Systems
using CTFlows.Flows
using CTFlows.Integrators
using CTFlows.Solutions
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
vf_default = Data.VectorField(x -> -x)
println("Default constructor (is_autonomous=true, is_variable=false):")
display(vf_default)

# Autonomous Fixed - depends only on state x
println("\n--- Scalar case ---")
vf_scalar = Data.VectorField(x -> -2x; is_autonomous=true, is_variable=false)
println("Scalar: vf(3.0) = ", vf_scalar(3.0))
display(vf_scalar)

println("\n--- Vector case ---")
vf_vector = Data.VectorField(x -> -x; is_autonomous=true, is_variable=false)
println("Vector: vf([1.0, 2.0]) = ", vf_vector([1.0, 2.0]))
display(vf_vector)

println("\n--- Matrix case ---")
vf_matrix = Data.VectorField(x -> -x; is_autonomous=true, is_variable=false)
x0_matrix = [1.0 2.0; 3.0 4.0]
println("Matrix: vf(x0_matrix) = ", vf_matrix(x0_matrix))
display(vf_matrix)

# NonAutonomous Fixed - depends on time t and state x
println("\n--- NonAutonomous cases ---")
vf_nonautonomous_fixed = Data.VectorField((t, x) -> t .* x; is_autonomous=false, is_variable=false)
println("NonAutonomous Fixed (vector): vf(2.0, [1.0, 2.0]) = ", vf_nonautonomous_fixed(2.0, [1.0, 2.0]))

# Autonomous NonFixed - depends on state x and variable v
vf_autonomous_nonfixed = Data.VectorField((x, v) -> x .+ v; is_autonomous=true, is_variable=true)
println("Autonomous NonFixed (vector): vf([1.0, 2.0], 0.5) = ", vf_autonomous_nonfixed([1.0, 2.0], 0.5))

# NonAutonomous NonFixed - depends on time t, state x, and variable v
vf_nonautonomous_nonfixed = Data.VectorField((t, x, v) -> t .* x .+ v; is_autonomous=false, is_variable=true)
println("NonAutonomous NonFixed (vector): vf(2.0, [1.0, 2.0], 0.5) = ", vf_nonautonomous_nonfixed(2.0, [1.0, 2.0], 0.5))

# Using keyword constructor with explicit flags
vf_kw_autonomous = Data.VectorField(x -> -x; is_autonomous=true, is_variable=false)
println("\nKeyword constructor with explicit flags:")
display(vf_kw_autonomous)

vf_kw_nonautonomous = Data.VectorField((t, x) -> t .* x; is_autonomous=false, is_variable=false)
println("NonAutonomous via keyword:")
display(vf_kw_nonautonomous)

vf_kw_nonfixed = Data.VectorField((x, v) -> x .+ v; is_autonomous=true, is_variable=true)
println("NonFixed via keyword:")
display(vf_kw_nonfixed)

# =============================================================================
# 2. VectorFieldSystem
# =============================================================================

println("\n2. VectorFieldSystem")
println("-" ^ 80)

println("\n--- Autonomous Fixed ---")
sys_af = Systems.VectorFieldSystem(vf_vector)
println("System from Autonomous Fixed VectorField:")
println("  time_dependence(sys) = ", Common.time_dependence(sys_af))
println("  variable_dependence(sys) = ", Common.variable_dependence(sys_af))

println("\n--- NonAutonomous Fixed ---")
vf_naf = Data.VectorField((t, x) -> t .* x; is_autonomous=false, is_variable=false)
sys_naf = Systems.VectorFieldSystem(vf_naf)
println("System from NonAutonomous Fixed VectorField:")
println("  time_dependence(sys) = ", Common.time_dependence(sys_naf))
println("  variable_dependence(sys) = ", Common.variable_dependence(sys_naf))

println("\n--- Autonomous NonFixed ---")
vf_anf = Data.VectorField((x, v) -> v .* x; is_autonomous=true, is_variable=true)
sys_anf = Systems.VectorFieldSystem(vf_anf)
println("System from Autonomous NonFixed VectorField:")
println("  time_dependence(sys) = ", Common.time_dependence(sys_anf))
println("  variable_dependence(sys) = ", Common.variable_dependence(sys_anf))

println("\n--- NonAutonomous NonFixed ---")
vf_nanf = Data.VectorField((t, x, v) -> t .* x .+ v; is_autonomous=false, is_variable=true)
sys_nanf = Systems.VectorFieldSystem(vf_nanf)
println("System from NonAutonomous NonFixed VectorField:")
println("  time_dependence(sys) = ", Common.time_dependence(sys_nanf))
println("  variable_dependence(sys) = ", Common.variable_dependence(sys_nanf))

# =============================================================================
# 3. Pipeline: build_system
# =============================================================================

println("\n3. Pipeline: build_system")
println("-" ^ 80)

# Build system directly from VectorField
sys_built = Systems.build_system(vf_vector)
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
# 5. Flow Construction
# =============================================================================

println("\n5. Flow Construction")
println("-" ^ 80)

println("\n--- build_flow from system and integrator ---")
println("Step 1: Build system from VectorField")
vf_flow = Data.VectorField(x -> -x; is_autonomous=true, is_variable=false)
sys_flow = Systems.build_system(vf_flow)
println("System: ", typeof(sys_flow))

println("\nStep 2: Create integrator")
integrator_flow = Integrators.SciML()
println("Integrator: ", typeof(integrator_flow))

println("\nStep 3: Build flow")
flow_from_build = Flows.Flow(sys_flow, integrator_flow)
println("Flow: ", typeof(flow_from_build))
println("  system(flow) = ", typeof(Flows.system(flow_from_build)))
println("  integrator(flow) = ", typeof(Flows.integrator(flow_from_build)))

println("\n--- Flow constructor from VectorField ---")
println("Direct construction: Flow(vf; opts...)")
flow_direct = Flows.Flow(vf_flow; reltol=1e-8)
println("Flow: ", typeof(flow_direct))
println("  system(flow) = ", typeof(Flows.system(flow_direct)))
println("  integrator(flow) = ", typeof(Flows.integrator(flow_direct)))
Flows.integrator(flow_direct)

println("\n--- NonFixed flow construction ---")
vf_nonfixed_flow = Data.VectorField((x, v) -> x .+ v; is_autonomous=true, is_variable=true)
flow_nonfixed = Flows.Flow(vf_nonfixed_flow)
println("NonFixed Flow: ", typeof(flow_nonfixed))
println("  variable_dependence(system(flow)) = ", Common.variable_dependence(Flows.system(flow_nonfixed)))

# =============================================================================
# 6. Complete Pipeline Examples with Tsit5 Integration
# =============================================================================

println("\n6. Complete Pipeline with Tsit5 Integration")
println("-" ^ 80)

# Load SciML extension
using OrdinaryDiffEqTsit5

println("\n--- Vector case pipeline (Fixed) ---")
println("Step 1: Create VectorField")
vf_vector = Data.VectorField(x -> -x; is_autonomous=true, is_variable=false)
display(vf_vector)
println("Call: vf([1.0, 2.0]) = ", vf_vector([1.0, 2.0]))

println("\nStep 2: Build System")
sys_vector = Systems.build_system(vf_vector)
println("System: ", typeof(sys_vector))
println("  time_dependence(sys) = ", Common.time_dependence(sys_vector))
println("  variable_dependence(sys) = ", Common.variable_dependence(sys_vector))

println("\nStep 3: Create Integrator")
integrator = Integrators.SciML()
println("Integrator: ", typeof(integrator))

println("\nStep 4: Integration via call()")
println("\n  4a. call(flow, config) with PointConfig")
flow = Flows.Flow(sys_vector, integrator)
config_point = Common.PointConfig(0.0, [1.0, 2.0], 1.0)
result_point = Flows.call(flow, config_point; variable=nothing, unsafe=false)
println("    result = ", result_point)

println("\n  4b. call(flow, config) with TrajectoryConfig")
config_traj = Common.TrajectoryConfig((0.0, 1.0), [1.0, 2.0])
result_traj = Flows.call(flow, config_traj; variable=nothing, unsafe=false)
println("    result type: ", typeof(result_traj))
println("    result is VectorFieldSolution: ", result_traj isa Solutions.VectorFieldSolution)
display(result_traj)

# Load Plots extension for plotting
using Plots
println("\n  --- Plotting with Plots extension ---")
plot(result_traj)  # Uses CTFlowsPlotsExt
result_traj(0.5)  # Evaluate at t=0.5 using extension

println("\n  4c. Direct flow callable (builds config internally)")
result_direct = flow(0.0, [1.0, 2.0], 1.0)
println("    flow(0.0, [1.0, 2.0], 1.0) = ", result_direct)

println("\n--- NonFixed case (with variable) ---")
vf_nonfixed = Data.VectorField((x, v) -> x .+ v; is_autonomous=true, is_variable=true)
println("VectorField (NonFixed):")
display(vf_nonfixed)

sys_nonfixed = Systems.build_system(vf_nonfixed)
flow_nonfixed = Flows.Flow(sys_nonfixed, integrator)
config_nonfixed = Common.PointConfig(0.0, [1.0, 2.0], 1.0)
result_nonfixed = Flows.call(flow_nonfixed, config_nonfixed; variable=0.5, unsafe=false)
println("Result with variable=0.5: ", result_nonfixed)

println("\n  Direct flow callable with variable:")
result_direct_nonfixed = flow_nonfixed(0.0, [1.0, 2.0], 1.0; variable=0.5, unsafe=false)
println("    flow(0.0, [1.0, 2.0], 1.0; variable=0.5) = ", result_direct_nonfixed)

println("\n--- Scalar case ---")
vf_scalar = Data.VectorField(x -> -2x; is_autonomous=true, is_variable=false)
println("Scalar VectorField:")
display(vf_scalar)
sys_scalar = Systems.build_system(vf_scalar)
flow_scalar = Flows.Flow(sys_scalar, integrator)
config_scalar = Common.PointConfig(0.0, 3.0, 1.0)
result_scalar = Flows.call(flow_scalar, config_scalar; variable=nothing, unsafe=false)
println("  Result: ", result_scalar, " (scalar)")

println("\n--- Matrix case ---")
vf_matrix = Data.VectorField(x -> -x; is_autonomous=true, is_variable=false)
x0_matrix = [1.0 2.0; 3.0 4.0]
println("Matrix VectorField:")
display(vf_matrix)
sys_matrix = Systems.build_system(vf_matrix)
flow_matrix = Flows.Flow(sys_matrix, integrator)
config_matrix = Common.PointConfig(0.0, x0_matrix, 1.0)
result_matrix = Flows.call(flow_matrix, config_matrix; variable=nothing, unsafe=false)
println("  Result: ", result_matrix, " (matrix)")

# =============================================================================
# 6. Trait Information
# =============================================================================

println("\n6. Trait Information")
println("-" ^ 80)

println("Available traits:")
println("  TimeDependence: Autonomous, NonAutonomous")
println("  VariableDependence: Fixed, NonFixed")

println("\nTrait types are concrete structs for type parameter compatibility")
println("  Common.Autonomous (type, not instance)")
println("  Common.Fixed (type, not instance)")

println("\n--- Trait accessors ---")
println("  time_dependence(vf) returns the time dependence trait")
println("  variable_dependence(vf) returns the variable dependence trait")
println("  time_dependence(sys) returns the time dependence trait from system")
println("  variable_dependence(sys) returns the variable dependence trait from system")

# =============================================================================
# 8. Summary
# =============================================================================

println("\n8. Summary")
println("-" ^ 80)

println("To execute the complete pipeline with Flow:")
println("  1. Install OrdinaryDiffEq: Pkg.add(\"OrdinaryDiffEqTsit5\")")
println("  2. The CTFlowsSciMLExt extension will be automatically activated")
println("  3. Then you can use:")
println("     integrator = Integrators.SciML()")
println("     flow = Flows.Flow(system, integrator)")
println("     result = Flows.call(flow, config; variable=nothing, unsafe=false)")
println("     result = flow(t0, x0, tf)  # direct callable, builds config internally")
