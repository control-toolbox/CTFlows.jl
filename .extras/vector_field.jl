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
point_config = Common.StatePointConfig(0.0, [1.0, 0.0], 1.0)
display(point_config)

# TrajectoryConfig for full trajectory
traj_config = Common.StateTrajectoryConfig((0.0, 1.0), [1.0, 0.0])
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
integrator_flow = Integrators.SciML(abstol=1e-8)
println("Integrator: ", typeof(integrator_flow))

println("\nStep 3: Build flow")
flow_from_build = Flows.StateFlow(sys_flow, integrator_flow)
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
flow = Flows.StateFlow(sys_vector, integrator)
config_point = Common.StatePointConfig(0.0, [1.0, 2.0], 1.0)
result_point = Flows.call(flow, config_point; variable=nothing, unsafe=false)
println("    result = ", result_point)

println("\n  4b. call(flow, config) with TrajectoryConfig")
config_traj = Common.StateTrajectoryConfig((0.0, 1.0), [1.0, 2.0])
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
flow_nonfixed = Flows.StateFlow(sys_nonfixed, integrator)
config_nonfixed = Common.StatePointConfig(0.0, [1.0, 2.0], 1.0)
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
flow_scalar = Flows.StateFlow(sys_scalar, integrator)
config_scalar = Common.StatePointConfig(0.0, 3.0, 1.0)
result_scalar = Flows.call(flow_scalar, config_scalar; variable=nothing, unsafe=false)
println("  Result: ", result_scalar, " (scalar)")

println("\n--- Matrix case ---")
vf_matrix = Data.VectorField(x -> -x; is_autonomous=true, is_variable=false)
x0_matrix = [1.0 2.0; 3.0 4.0]
println("Matrix VectorField:")
display(vf_matrix)
sys_matrix = Systems.build_system(vf_matrix)
flow_matrix = Flows.StateFlow(sys_matrix, integrator)
config_matrix = Common.StatePointConfig(0.0, x0_matrix, 1.0)
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
println("     flow = Flows.StateFlow(system, integrator)")
println("     result = Flows.call(flow, config; variable=nothing, unsafe=false)")
println("     result = flow(t0, x0, tf)  # direct callable, builds config internally")

# =============================================================================
# 9. Multi-Phase Concatenation with Jumps
# =============================================================================

println("\n9. Multi-Phase Concatenation with Jumps")
println("-" ^ 80)

using CTFlows.MultiPhase
using Plots

println("\n--- Example 1: Two-phase flow without jump ---")
println("Linear system: dx/dt = -x, solution: x(t) = x0 * exp(-t)")

vf_linear = Data.VectorField(x -> -x; is_autonomous=true, is_variable=false)
sys_linear = Systems.build_system(vf_linear)
integ_linear = Integrators.SciML()
flow_linear = Flows.StateFlow(sys_linear, integ_linear)

# Create two-phase flow
mpf_two_phase = flow_linear * (0.5, flow_linear)

println("Two-phase flow: f * (0.5, f)")
println("  Phase 1: [0.0, 0.5]")
println("  Phase 2: [0.5, 1.0]")

# Point integration
x0 = [1.0]
xf_two = mpf_two_phase(0.0, x0, 1.0)
println("  Final state: x(1.0) = ", xf_two[1])
println("  Expected: exp(-1.0) = ", exp(-1.0))

# Trajectory integration
sol_two = mpf_two_phase((0.0, 1.0), x0)
println("  Solution type: ", typeof(sol_two))
println("  Time points: ", Integrators.times(sol_two))

# Plot two-phase trajectory
p_two = plot(Integrators.times(sol_two), [u[1] for u in sol_two.(Integrators.times(sol_two))],
              label="Two-phase (no jump)", title="Two-Phase Trajectory", 
              xlabel="t", ylabel="x(t)", linewidth=2, marker=:circle, markersize=3)
display(p_two)

println("\n--- Example 2: Two-phase flow with jump ---")
jump_value = 5.0
mpf_jump = flow_linear * (0.5, jump_value, flow_linear)

println("Two-phase flow with jump: f * (0.5, 5.0, f)")
println("  Phase 1: [0.0, 0.5]")
println("  Jump: +5.0 at t=0.5")
println("  Phase 2: [0.5, 1.0]")

# Point integration
xf_jump = mpf_jump(0.0, x0, 1.0)
expected_jump = (exp(-0.5) + jump_value) * exp(-0.5)
println("  Final state: x(1.0) = ", xf_jump[1])
println("  Expected: (exp(-0.5) + 5.0) * exp(-0.5) = ", expected_jump)

# Trajectory integration
sol_jump = mpf_jump((0.0, 1.0), x0)

# Plot two-phase trajectory with jump
p_jump = plot(Integrators.times(sol_jump), [u[1] for u in sol_jump.(Integrators.times(sol_jump))],
              label="Two-phase with jump", title="Two-Phase Trajectory with Jump",
              xlabel="t", ylabel="x(t)", linewidth=2, marker=:circle, markersize=3)
display(p_jump)

# Compare both trajectories
p_compare = plot(Integrators.times(sol_two), [u[1] for u in sol_two.(Integrators.times(sol_two))],
                label="No jump", linewidth=2, marker=:circle, markersize=3)
plot!(Integrators.times(sol_jump), [u[1] for u in sol_jump.(Integrators.times(sol_jump))],
      label="With jump (+5.0)", linewidth=2, marker=:diamond, markersize=3)
title!("Comparison: With vs Without Jump")
xlabel!("t")
ylabel!("x(t)")
display(p_compare)

println("\n--- Example 3: Three-phase flow with multiple jumps ---")
mpf_three = flow_linear * (0.3, 2.0, flow_linear) * (0.6, 3.0, flow_linear)

println("Three-phase flow: f * (0.3, 2.0, f) * (0.6, 3.0, f)")
println("  Phase 1: [0.0, 0.3]")
println("  Jump 1: +2.0 at t=0.3")
println("  Phase 2: [0.3, 0.6]")
println("  Jump 2: +3.0 at t=0.6")
println("  Phase 3: [0.6, 1.0]")

# Point integration
xf_three = mpf_three(0.0, x0, 1.0)
expected_three = ((1.0 * exp(-0.3) + 2.0) * exp(-0.3) + 3.0) * exp(-0.4)
println("  Final state: x(1.0) = ", xf_three[1])
println("  Expected: ((exp(-0.3) + 2.0) * exp(-0.3) + 3.0) * exp(-0.4) = ", expected_three)

# Trajectory integration
sol_three = mpf_three((0.0, 1.0), x0)

# Plot three-phase trajectory
p_three = plot(Integrators.times(sol_three), [u[1] for u in sol_three.(Integrators.times(sol_three))],
               label="Three-phase with jumps", title="Three-Phase Trajectory with Multiple Jumps",
               xlabel="t", ylabel="x(t)", linewidth=2, marker=:circle, markersize=3)
display(p_three)

# Compare all three trajectories
p_all = plot(Integrators.times(sol_two), [u[1] for u in sol_two.(Integrators.times(sol_two))],
             label="Two-phase (no jump)", linewidth=2, marker=:circle, markersize=3)
plot!(Integrators.times(sol_jump), [u[1] for u in sol_jump.(Integrators.times(sol_jump))],
      label="Two-phase (+5.0)", linewidth=2, marker=:diamond, markersize=3)
plot!(Integrators.times(sol_three), [u[1] for u in sol_three.(Integrators.times(sol_three))],
      label="Three-phase (+2.0, +3.0)", linewidth=2, marker=:square, markersize=3)
title!("Comparison: All Multi-Phase Trajectories")
xlabel!("t")
ylabel!("x(t)")
display(p_all)

println("\n--- Example 4: Trajectory with zero jump (should be same as no jump) ---")
mpf_zero = flow_linear * (0.5, 0.0, flow_linear)

println("Two-phase flow with zero jump: f * (0.5, 0.0, f)")
xf_zero = mpf_zero(0.0, x0, 1.0)
println("  Final state: x(1.0) = ", xf_zero[1])
println("  Expected: exp(-1.0) = ", exp(-1.0))
println("  Match: ", isapprox(xf_zero[1], exp(-1.0), atol=1e-10))

println("\n--- Example 5: Switch after final time (should be ignored) ---")
mpf_after = flow_linear * (2.0, flow_linear)

println("Two-phase flow with switch after final time: f * (2.0, f)")
println("  Switch at t=2.0, but final time is 1.0")
xf_after = mpf_after(0.0, x0, 1.0)
println("  Final state: x(1.0) = ", xf_after[1])
println("  Expected: exp(-1.0) = ", exp(-1.0))
println("  Match: ", isapprox(xf_after[1], exp(-1.0), atol=1e-10))

println("\n--- Example 6: Trajectory with discontinuity verification ---")
mpf_discontinuity = flow_linear * (0.5, 5.0, flow_linear)
sol_discontinuity = mpf_discontinuity((0.0, 1.0), x0)

t_switch = 0.5
u_before = sol_discontinuity(t_switch - 1e-6)
u_after = sol_discontinuity(t_switch + 1e-6)

println("Verify discontinuity at t=0.5:")
println("  u(0.5 - ε) = ", u_before[1])
println("  u(0.5 + ε) = ", u_after[1])
println("  Jump magnitude: ", u_after[1] - u_before[1])
println("  Expected jump: 5.0")

println("\nAll multi-phase examples completed successfully!")

