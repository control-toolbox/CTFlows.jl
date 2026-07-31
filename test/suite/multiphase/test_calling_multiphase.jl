module TestCallingMultiphase

using Test: Test
using CTFlows: MultiPhase
using CTFlows: Systems
using CTFlows: Integrators
using CTFlows: Flows
using CTFlows: Configs
using CTBase: Traits
using CTFlows: Trajectories
using CommonSolve: CommonSolve

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

# ==============================================================================
# Fake types for testing (testing-creation.md §1)
# ==============================================================================

struct FakeStateSystem <: Systems.AbstractStateSystem{Traits.Autonomous,Traits.Fixed}
    data::Vector{Float64}
end

function Systems.get_ip_rhs(sys::FakeStateSystem, _)
    return (du, u, p, t) -> du .= sys.data .* u
end

struct FakeHamiltonianSystem <:
       Systems.AbstractHamiltonianSystem{Traits.Autonomous,Traits.Fixed}
    data::Vector{Float64}
end

function Systems.get_ip_rhs(sys::FakeHamiltonianSystem, _)
    return (dz, z, p, t) -> dz .= sys.data .* z
end

struct FakeIntegrator <: Integrators.AbstractIntegrator
    result::Any
end

struct FakeHamiltonianIntegrator <: Integrators.AbstractIntegrator
    result::Any
end

# Mock integrator for testing calling.jl functions
struct MockIntegrator <: Integrators.AbstractIntegrator
    multiplier::Float64
end

# Mock ODE problem type
struct MockODEProblem
    u0::Any
    tspan::Tuple{Float64,Float64}
end

# Mock integration result type
struct MockIntegrationResult <: Integrators.AbstractIntegrationResult
    u::Any
    t::Vector{Float64}
end

using CTBase: Strategies
using CTBase: Options

Strategies.id(::Type{FakeIntegrator}) = :fake_integrator
Strategies.metadata(::Type{FakeIntegrator}) = Strategies.StrategyMetadata()
Strategies.options(integ::FakeIntegrator) = Options.StrategyOptions()

Strategies.id(::Type{FakeHamiltonianIntegrator}) = :fake_ham_integrator
Strategies.metadata(::Type{FakeHamiltonianIntegrator}) = Strategies.StrategyMetadata()
Strategies.options(integ::FakeHamiltonianIntegrator) = Options.StrategyOptions()

Strategies.id(::Type{MockIntegrator}) = :mock_integrator
Strategies.metadata(::Type{MockIntegrator}) = Strategies.StrategyMetadata()
Strategies.options(integ::MockIntegrator) = Options.StrategyOptions()

# ==============================================================================
# Mock Integrator Interface Implementation
# ==============================================================================

function Integrators.build_problem(
    sys::Systems.AbstractSystem,
    config::Configs.StateEndPointConfig,
    integ::MockIntegrator;
    variable,
)
    x0 = Configs.initial_state(config)
    tspan = Configs.tspan(config)
    return MockODEProblem(x0, tspan)
end

function Integrators.build_problem(
    sys::Systems.AbstractSystem,
    config::Configs.StateTrajectoryConfig,
    integ::MockIntegrator;
    variable,
)
    x0 = Configs.initial_state(config)
    tspan = Configs.tspan(config)
    return MockODEProblem(x0, tspan)
end

function Integrators.build_problem(
    sys::Systems.AbstractSystem,
    config::Configs.HamiltonianEndPointConfig,
    integ::MockIntegrator;
    variable,
)
    x0, p0 = Configs.initial_state(config), Configs.initial_costate(config)
    tspan = Configs.tspan(config)
    return MockODEProblem(vcat(x0, p0), tspan)
end

function Integrators.build_problem(
    sys::Systems.AbstractSystem,
    config::Configs.HamiltonianTrajectoryConfig,
    integ::MockIntegrator;
    variable,
)
    x0, p0 = Configs.initial_state(config), Configs.initial_costate(config)
    tspan = Configs.tspan(config)
    return MockODEProblem(vcat(x0, p0), tspan)
end

function Integrators.build_options(
    integ::MockIntegrator, config::Configs.StateEndPointConfig
)
    return Dict{Symbol,Any}()
end

function Integrators.build_options(
    integ::MockIntegrator, config::Configs.StateTrajectoryConfig
)
    return Dict{Symbol,Any}()
end

function Integrators.build_options(
    integ::MockIntegrator, config::Configs.HamiltonianEndPointConfig
)
    return Dict{Symbol,Any}()
end

function Integrators.build_options(
    integ::MockIntegrator, config::Configs.HamiltonianTrajectoryConfig
)
    return Dict{Symbol,Any}()
end

function CommonSolve.solve(
    prob::MockODEProblem,
    integ::MockIntegrator;
    options=Dict{Symbol,Any}(),
    unsafe=Flows.__unsafe(),
)
    multiplier = integ.multiplier
    t0, tf = prob.tspan
    u_final = prob.u0 * multiplier
    return MockIntegrationResult(u_final, [t0, tf])
end

# ==============================================================================
# Mock Solutions Interface Implementation
# ==============================================================================

function Integrators.final_state(result::MockIntegrationResult)
    return result.u
end

function Integrators.times(result::MockIntegrationResult)
    return result.t
end

function Integrators.evaluate_at(result::MockIntegrationResult, t::Real)
    # Simple linear interpolation
    t0, tf = result.t[1], result.t[end]
    if t <= t0
        return result.u * 0.5  # Mock initial state
    elseif t >= tf
        return result.u
    else
        return result.u * 0.75  # Mock intermediate state
    end
end

function Trajectories.build_trajectory(
    ::Type{Traits.EndPointMode},
    ::Type{Traits.StateDynamics},
    config::Configs.AbstractConfig,
    result::MockIntegrationResult,
    variable=nothing,
)
    # For StateEndPointConfig, return the final state directly (as expected by _evaluate_phase)
    return result.u
end

function Trajectories.build_trajectory(
    ::Type{Traits.TrajectoryMode},
    ::Type{Traits.StateDynamics},
    config::Configs.AbstractConfig,
    result::MockIntegrationResult,
    variable=nothing,
)
    # For StateTrajectoryConfig with StateFlow, return the full result
    return result
end

function Trajectories.build_trajectory(
    ::Type{Traits.EndPointMode},
    ::Type{Traits.HamiltonianDynamics},
    config::Configs.AbstractConfig,
    result::MockIntegrationResult,
    variable=nothing,
)
    # For HamiltonianFlow, return a tuple (x, p) matching _ham_split_solution behavior
    x_len = length(result.u) ÷ 2
    x_part = result.u[1:x_len]
    p_part = result.u[(x_len + 1):end]
    return (x_part, p_part)
end

function Trajectories.build_trajectory(
    ::Type{Traits.TrajectoryMode},
    ::Type{Traits.HamiltonianDynamics},
    config::Configs.AbstractConfig,
    result::MockIntegrationResult,
    variable=nothing,
)
    # For HamiltonianTrajectoryConfig, return the full result
    return result
end

# ==============================================================================
# Mock Integrators.merge Implementation
# ==============================================================================

function Integrators.merge(segments::Vector{<:MockIntegrationResult})
    if isempty(segments)
        return MockIntegrationResult(Float64[], Float64[])
    end

    # Combine final states and times
    combined_u = vcat([s.u for s in segments]...)
    combined_t = vcat([s.t for s in segments]...)

    return MockIntegrationResult(combined_u, combined_t)
end

# ==============================================================================
# Test function
# ==============================================================================

function test_calling_multiphase()
    Test.@testset "Calling Multiphase Tests" verbose=VERBOSE showtiming=SHOWTIMING begin
        Test.@testset "_extract_initial_state" begin
            x0 = [1.0, 2.0]
            p0 = [0.5, 0.3]

            Test.@testset "StateEndPointConfig" begin
                config = Configs.StateEndPointConfig(0.0, x0, 1.0)
                result = MultiPhase._extract_initial_state(config)
                Test.@test result === x0
            end

            Test.@testset "StateTrajectoryConfig" begin
                config = Configs.StateTrajectoryConfig((0.0, 1.0), x0)
                result = MultiPhase._extract_initial_state(config)
                Test.@test result === x0
            end

            Test.@testset "HamiltonianEndPointConfig" begin
                config = Configs.HamiltonianEndPointConfig(0.0, x0, p0, 1.0)
                result = MultiPhase._extract_initial_state(config)
                Test.@test result === (x0, p0)
            end

            Test.@testset "HamiltonianTrajectoryConfig" begin
                config = Configs.HamiltonianTrajectoryConfig((0.0, 1.0), x0, p0)
                result = MultiPhase._extract_initial_state(config)
                Test.@test result === (x0, p0)
            end
        end

        Test.@testset "_format_final_output" begin
            x = [1.0, 2.0]
            p = [0.5, 0.3]

            Test.@testset "MultiPhaseStateFlow" begin
                sys = FakeStateSystem([1.0, 2.0])
                integ = FakeIntegrator(:fake_result)
                flow1 = Flows.StateFlow(sys, integ)
                flow2 = Flows.StateFlow(sys, integ)
                mpf = flow1 * (0.5, flow2)

                result = MultiPhase._format_final_output(mpf, x)
                Test.@test result === x
            end

            Test.@testset "MultiPhaseHamiltonianFlow" begin
                hsys = FakeHamiltonianSystem([1.0, 2.0])
                hinteg = FakeHamiltonianIntegrator(:fake_result)
                hflow1 = Flows.HamiltonianFlow(hsys, hinteg)
                hflow2 = Flows.HamiltonianFlow(hsys, hinteg)
                hmpf = hflow1 * (0.5, hflow2)

                result = MultiPhase._format_final_output(hmpf, (x, p))
                Test.@test result == vcat(x, p)
            end
        end

        Test.@testset "_extract_final_state" begin
            x0 = [1.0, 2.0]
            p0 = [0.5, 0.3]

            Test.@testset "StateDynamics with MockIntegrationResult" begin
                sys = FakeStateSystem([1.0, 2.0])
                integ = FakeIntegrator(:fake_result)
                flow = Flows.StateFlow(sys, integ)
                mpf = flow * (0.5, flow)

                u_final = [3.0, 4.0]
                segment = MockIntegrationResult(u_final, [0.0, 1.0])
                result = MultiPhase._extract_final_state(mpf, segment, x0)
                Test.@test result == u_final
            end

            Test.@testset "HamiltonianDynamics with MockIntegrationResult (flat vector)" begin
                hsys = FakeHamiltonianSystem([1.0, 2.0])
                hinteg = FakeHamiltonianIntegrator(:fake_result)
                hflow = Flows.HamiltonianFlow(hsys, hinteg)
                hmpf = hflow * (0.5, hflow)

                u_final = vcat(x0 * 2, p0 * 2)
                segment = MockIntegrationResult(u_final, [0.0, 1.0])
                xf, pf = MultiPhase._extract_final_state(hmpf, segment, (x0, p0))
                Test.@test xf == x0 * 2
                Test.@test pf == p0 * 2
            end

            Test.@testset "HamiltonianDynamics with HamiltonianVectorFieldTrajectory (regression for BoundsError)" begin
                hsys = FakeHamiltonianSystem([1.0, 2.0])
                hinteg = FakeHamiltonianIntegrator(:fake_result)
                hflow = Flows.HamiltonianFlow(hsys, hinteg)
                hmpf = hflow * (0.5, hflow)

                u_final = vcat(x0 * 2, p0 * 2)
                mock_result = MockIntegrationResult(u_final, [0.0, 1.0])
                segment = Trajectories.HamiltonianVectorFieldTrajectory(x0, mock_result)

                xf, pf = MultiPhase._extract_final_state(hmpf, segment, (x0, p0))
                Test.@test xf == x0 * 2
                Test.@test pf == p0 * 2
            end
        end

        # ==============================================================
        # Unit: _apply_component_jump
        # ==============================================================
        Test.@testset "_apply_component_jump" begin
            v = [1.0, 2.0]

            Test.@testset "additive vector" begin
                j = [0.1, 0.2]
                Test.@test MultiPhase._apply_component_jump(v, j) == v .+ j
            end

            Test.@testset "callable function" begin
                f = v -> 2.0 .* v
                Test.@test MultiPhase._apply_component_jump(v, f) == 2.0 .* v
            end

            Test.@testset "nothing — identity" begin
                Test.@test MultiPhase._apply_component_jump(v, nothing) === v
            end
        end

        # ==============================================================
        # Unit: _apply_jump
        # ==============================================================
        Test.@testset "_apply_jump" begin
            x = [1.0, 2.0]
            p = [0.5, 0.3]
            jump = [0.1, 0.2]

            Test.@testset "MultiPhaseStateFlow — additive vector" begin
                sys = FakeStateSystem([1.0, 2.0])
                integ = FakeIntegrator(:fake_result)
                flow1 = Flows.StateFlow(sys, integ)
                flow2 = Flows.StateFlow(sys, integ)
                mpf = flow1 * (0.5, jump, flow2)

                result = MultiPhase._apply_jump(mpf, 1, x)
                Test.@test result == x + jump
            end

            Test.@testset "MultiPhaseStateFlow — callable function" begin
                sys = FakeStateSystem([1.0, 2.0])
                integ = FakeIntegrator(:fake_result)
                flow1 = Flows.StateFlow(sys, integ)
                flow2 = Flows.StateFlow(sys, integ)
                f = x -> 2.0 .* x
                mpf = flow1 * (0.5, f, flow2)

                result = MultiPhase._apply_jump(mpf, 1, x)
                Test.@test result == 2.0 .* x
            end

            Test.@testset "MultiPhaseHamiltonianFlow — additive vector (costate)" begin
                hsys = FakeHamiltonianSystem([1.0, 2.0])
                hinteg = FakeHamiltonianIntegrator(:fake_result)
                hflow1 = Flows.HamiltonianFlow(hsys, hinteg)
                hflow2 = Flows.HamiltonianFlow(hsys, hinteg)
                hmpf = hflow1 * (0.5, jump, hflow2)

                result = MultiPhase._apply_jump(hmpf, 1, (x, p))
                Test.@test result == (x, p + jump)
            end

            Test.@testset "MultiPhaseHamiltonianFlow — callable function" begin
                hsys = FakeHamiltonianSystem([1.0, 2.0])
                hinteg = FakeHamiltonianIntegrator(:fake_result)
                hflow1 = Flows.HamiltonianFlow(hsys, hinteg)
                hflow2 = Flows.HamiltonianFlow(hsys, hinteg)
                f = (x, p) -> (2.0 .* x, 3.0 .* p)
                hmpf = hflow1 * (0.5, f, hflow2)

                result = MultiPhase._apply_jump(hmpf, 1, (x, p))
                Test.@test result == (2.0 .* x, 3.0 .* p)
            end
        end

        # ==============================================================
        # Unit: _apply_hamiltonian_jump
        # ==============================================================
        Test.@testset "_apply_hamiltonian_jump" begin
            x = [1.0, 2.0]
            p = [0.5, 0.3]
            state_tuple = (x, p)

            Test.@testset "Tuple — additive (jump_x, jump_p)" begin
                jump_x = [0.1, 0.2]
                jump_p = [0.01, 0.02]
                result = MultiPhase._apply_hamiltonian_jump(state_tuple, (jump_x, jump_p))
                Test.@test result[1] == x + jump_x
                Test.@test result[2] == p + jump_p
            end

            Test.@testset "Tuple — (nothing, jump_p): costate-only" begin
                jump_p = [0.01, 0.02]
                result = MultiPhase._apply_hamiltonian_jump(state_tuple, (nothing, jump_p))
                Test.@test result[1] === x
                Test.@test result[2] == p + jump_p
            end

            Test.@testset "Tuple — (jump_x, nothing): state-only" begin
                jump_x = [0.1, 0.2]
                result = MultiPhase._apply_hamiltonian_jump(state_tuple, (jump_x, nothing))
                Test.@test result[1] == x + jump_x
                Test.@test result[2] === p
            end

            Test.@testset "Tuple — (f_x, f_p): callable functions" begin
                fx = x -> 2.0 .* x
                fp = p -> 3.0 .* p
                result = MultiPhase._apply_hamiltonian_jump(state_tuple, (fx, fp))
                Test.@test result[1] == 2.0 .* x
                Test.@test result[2] == 3.0 .* p
            end

            Test.@testset "single vector — costate-only (additive)" begin
                jump_p = [0.01, 0.02]
                result = MultiPhase._apply_hamiltonian_jump(state_tuple, jump_p)
                Test.@test result[1] == x
                Test.@test result[2] == p + jump_p
            end

            Test.@testset "callable function — full transformation" begin
                f = (x, p) -> (2.0 .* x, 3.0 .* p)
                result = MultiPhase._apply_hamiltonian_jump(state_tuple, f)
                Test.@test result[1] == 2.0 .* x
                Test.@test result[2] == 3.0 .* p
            end
        end

        Test.@testset "_evaluate_phase" begin
            x = [1.0, 2.0]
            p = [0.5, 0.3]

            Test.@testset "StateFlow with StateEndPointConfig" begin
                sys = FakeStateSystem([1.0, 2.0])
                integ = MockIntegrator(2.0)  # Multiplier of 2
                flow = Flows.StateFlow(sys, integ)
                t0 = 0.0
                tf = 1.0

                result = MultiPhase._evaluate_phase(
                    flow,
                    t0,
                    tf,
                    x,
                    Configs.StateEndPointConfig(t0, x, tf);
                    variable=Flows.__variable(),
                    unsafe=Flows.__unsafe(),
                )

                Test.@test result == x * 2
            end

            Test.@testset "StateFlow with StateTrajectoryConfig" begin
                sys = FakeStateSystem([1.0, 2.0])
                integ = MockIntegrator(2.0)
                flow = Flows.StateFlow(sys, integ)
                tspan = (0.0, 1.0)

                result = MultiPhase._evaluate_phase(
                    flow,
                    0.0,
                    1.0,
                    x,
                    Configs.StateTrajectoryConfig(tspan, x);
                    variable=Flows.__variable(),
                    unsafe=Flows.__unsafe(),
                )

                Test.@test result.u == x * 2
            end

            Test.@testset "HamiltonianFlow with StateEndPointConfig" begin
                hsys = FakeHamiltonianSystem([1.0, 2.0])
                integ = MockIntegrator(2.0)
                flow = Flows.HamiltonianFlow(hsys, integ)
                t0 = 0.0
                tf = 1.0

                result = MultiPhase._evaluate_phase(
                    flow,
                    t0,
                    tf,
                    (x, p),
                    Configs.HamiltonianEndPointConfig(t0, x, p, tf);
                    variable=Flows.__variable(),
                    unsafe=Flows.__unsafe(),
                )

                Test.@test result[1] == x * 2
                Test.@test result[2] == p * 2
            end

            Test.@testset "HamiltonianFlow with StateTrajectoryConfig" begin
                hsys = FakeHamiltonianSystem([1.0, 2.0])
                integ = MockIntegrator(2.0)
                flow = Flows.HamiltonianFlow(hsys, integ)
                tspan = (0.0, 1.0)

                result = MultiPhase._evaluate_phase(
                    flow,
                    0.0,
                    1.0,
                    (x, p),
                    Configs.HamiltonianTrajectoryConfig(tspan, x, p);
                    variable=Flows.__variable(),
                    unsafe=Flows.__unsafe(),
                )

                Test.@test result.u == vcat(x * 2, p * 2)
            end
        end

        Test.@testset "_evaluate_multiphase with StateEndPointConfig" begin
            x0 = [1.0, 2.0]
            p0 = [0.5, 0.3]

            Test.@testset "MultiPhaseStateFlow without jump" begin
                sys = FakeStateSystem([1.0, 2.0])
                integ = MockIntegrator(2.0)
                flow1 = Flows.StateFlow(sys, integ)
                flow2 = Flows.StateFlow(sys, integ)
                mpf = flow1 * (0.5, flow2)

                result = MultiPhase._evaluate_multiphase(
                    mpf,
                    Configs.StateEndPointConfig(0.0, x0, 1.0);
                    variable=Flows.__variable(),
                    unsafe=Flows.__unsafe(),
                )

                # Each phase multiplies by 2, so final is x0 * 2 * 2 = x0 * 4
                Test.@test result == x0 * 4
            end

            Test.@testset "MultiPhaseStateFlow with jump" begin
                sys = FakeStateSystem([1.0, 2.0])
                integ = MockIntegrator(2.0)
                flow1 = Flows.StateFlow(sys, integ)
                flow2 = Flows.StateFlow(sys, integ)
                jump = [0.1, 0.2]
                mpf = flow1 * (0.5, jump, flow2)

                result = MultiPhase._evaluate_multiphase(
                    mpf,
                    Configs.StateEndPointConfig(0.0, x0, 1.0);
                    variable=Flows.__variable(),
                    unsafe=Flows.__unsafe(),
                )

                # Phase 1: x0 * 2, then jump applied, then phase 2: (x0 * 2 + jump) * 2
                expected = (x0 * 2 + jump) * 2
                Test.@test result == expected
            end

            Test.@testset "MultiPhaseHamiltonianFlow without jump" begin
                hsys = FakeHamiltonianSystem([1.0, 2.0])
                integ = MockIntegrator(2.0)
                hflow1 = Flows.HamiltonianFlow(hsys, integ)
                hflow2 = Flows.HamiltonianFlow(hsys, integ)
                hmpf = hflow1 * (0.5, hflow2)

                result = MultiPhase._evaluate_multiphase(
                    hmpf,
                    Configs.HamiltonianEndPointConfig(0.0, x0, p0, 1.0);
                    variable=Flows.__variable(),
                    unsafe=Flows.__unsafe(),
                )

                # Each phase multiplies by 2, _format_final_output returns vcat(x, p)
                Test.@test result == vcat(x0 * 4, p0 * 4)
            end

            Test.@testset "MultiPhaseHamiltonianFlow with jump" begin
                hsys = FakeHamiltonianSystem([1.0, 2.0])
                integ = MockIntegrator(2.0)
                hflow1 = Flows.HamiltonianFlow(hsys, integ)
                hflow2 = Flows.HamiltonianFlow(hsys, integ)
                jump_p = [0.01, 0.02]
                hmpf = hflow1 * (0.5, jump_p, hflow2)

                result = MultiPhase._evaluate_multiphase(
                    hmpf,
                    Configs.HamiltonianEndPointConfig(0.0, x0, p0, 1.0);
                    variable=Flows.__variable(),
                    unsafe=Flows.__unsafe(),
                )

                # Phase 1: x0*2, p0*2, then jump_p applied to p, then phase 2: x*2, (p+jump_p)*2
                # _format_final_output returns vcat(x, p)
                Test.@test result == vcat(x0 * 4, (p0 * 2 + jump_p) * 2)
            end
        end

        Test.@testset "_evaluate_multiphase with StateTrajectoryConfig" begin
            x0 = [1.0, 2.0]
            p0 = [0.5, 0.3]

            Test.@testset "MultiPhaseStateFlow without jump" begin
                sys = FakeStateSystem([1.0, 2.0])
                integ = MockIntegrator(2.0)
                flow1 = Flows.StateFlow(sys, integ)
                flow2 = Flows.StateFlow(sys, integ)
                mpf = flow1 * (0.5, flow2)

                result = MultiPhase._evaluate_multiphase(
                    mpf,
                    Configs.StateTrajectoryConfig((0.0, 1.0), x0);
                    variable=Flows.__variable(),
                    unsafe=Flows.__unsafe(),
                )

                # Result should be a merged MockIntegrationResult
                Test.@test result isa MockIntegrationResult
                # Each phase produces x0*2, so combined should be [x0*2, x0*4]
                Test.@test result.u == vcat(x0 * 2, x0 * 4)
            end

            Test.@testset "MultiPhaseStateFlow with jump" begin
                sys = FakeStateSystem([1.0, 2.0])
                integ = MockIntegrator(2.0)
                flow1 = Flows.StateFlow(sys, integ)
                flow2 = Flows.StateFlow(sys, integ)
                jump = [0.1, 0.2]
                mpf = flow1 * (0.5, jump, flow2)

                result = MultiPhase._evaluate_multiphase(
                    mpf,
                    Configs.StateTrajectoryConfig((0.0, 1.0), x0);
                    variable=Flows.__variable(),
                    unsafe=Flows.__unsafe(),
                )

                Test.@test result isa MockIntegrationResult
                # Phase 1: x0*2, then jump, then phase 2: (x0*2+jump)*2
                expected = vcat(x0 * 2, (x0 * 2 + jump) * 2)
                Test.@test result.u == expected
            end

            Test.@testset "MultiPhaseHamiltonianFlow without jump" begin
                hsys = FakeHamiltonianSystem([1.0, 2.0])
                integ = MockIntegrator(2.0)
                hflow1 = Flows.HamiltonianFlow(hsys, integ)
                hflow2 = Flows.HamiltonianFlow(hsys, integ)
                hmpf = hflow1 * (0.5, hflow2)

                result = MultiPhase._evaluate_multiphase(
                    hmpf,
                    Configs.HamiltonianTrajectoryConfig((0.0, 1.0), x0, p0);
                    variable=Flows.__variable(),
                    unsafe=Flows.__unsafe(),
                )

                Test.@test result isa MockIntegrationResult
                # Each phase produces vcat(x0*2, p0*2)
                expected = vcat(x0 * 2, p0 * 2, x0 * 4, p0 * 4)
                Test.@test result.u == expected
            end

            Test.@testset "MultiPhaseHamiltonianFlow with jump" begin
                hsys = FakeHamiltonianSystem([1.0, 2.0])
                integ = MockIntegrator(2.0)
                hflow1 = Flows.HamiltonianFlow(hsys, integ)
                hflow2 = Flows.HamiltonianFlow(hsys, integ)
                jump_p = [0.01, 0.02]
                hmpf = hflow1 * (0.5, jump_p, hflow2)

                result = MultiPhase._evaluate_multiphase(
                    hmpf,
                    Configs.HamiltonianTrajectoryConfig((0.0, 1.0), x0, p0);
                    variable=Flows.__variable(),
                    unsafe=Flows.__unsafe(),
                )

                Test.@test result isa MockIntegrationResult
                # Phase 1: vcat(x0*2, p0*2), then jump, then phase 2: vcat(x*2, (p+jump_p)*2)
                expected = vcat(x0 * 2, p0 * 2, x0 * 4, (p0 * 2 + jump_p) * 2)
                Test.@test result.u == expected
            end
        end

        Test.@testset "MultiPhaseStateFlow callable" begin
            x0 = [1.0, 2.0]

            Test.@testset "call with (t0, x0, tf)" begin
                sys = FakeStateSystem([1.0, 2.0])
                integ = MockIntegrator(2.0)
                flow1 = Flows.StateFlow(sys, integ)
                flow2 = Flows.StateFlow(sys, integ)
                mpf = flow1 * (0.5, flow2)

                result = mpf(0.0, x0, 1.0)
                # Each phase multiplies by 2, so final is x0 * 4
                Test.@test result isa AbstractVector && length(result) == 2
                Test.@test result == x0 * 4
            end

            Test.@testset "1-D scalar convention: vector x0 input → scalar output" begin
                sys = FakeStateSystem([1.0])
                integ = MockIntegrator(2.0)
                flow1 = Flows.StateFlow(sys, integ)
                flow2 = Flows.StateFlow(sys, integ)
                mpf = flow1 * (0.5, flow2)

                x0_1d = [3.0]              # length-1 vector
                result = mpf(0.0, x0_1d, 1.0)
                Test.@test result isa Number        # 1-D = scalar convention
                Test.@test result ≈ only(x0_1d) * 4   # same value as scalar input
            end

            Test.@testset "matrix 2×2 convention: matrix x0 → matrix output" begin
                sys = FakeStateSystem([1.0, 2.0])
                integ = MockIntegrator(2.0)
                flow1 = Flows.StateFlow(sys, integ)
                flow2 = Flows.StateFlow(sys, integ)
                mpf = flow1 * (0.5, flow2)

                X0 = [1.0 2.0; 3.0 4.0]
                result = mpf(0.0, X0, 1.0)
                Test.@test result isa AbstractMatrix   # must stay a matrix
                Test.@test size(result) == (2, 2)
                Test.@test result == X0 * 4
            end

            Test.@testset "matrix 1×1 convention: 1×1 matrix x0 → matrix output" begin
                sys = FakeStateSystem([1.0])
                integ = MockIntegrator(2.0)
                flow1 = Flows.StateFlow(sys, integ)
                flow2 = Flows.StateFlow(sys, integ)
                mpf = flow1 * (0.5, flow2)

                X0 = fill(1.0, 1, 1)               # 1×1 matrix
                result = mpf(0.0, X0, 1.0)
                Test.@test result isa AbstractMatrix   # must NOT collapse to scalar
                Test.@test size(result) == (1, 1)
                Test.@test result == fill(4.0, 1, 1)
            end

            Test.@testset "1-D scalar convention: scalar x0 input → scalar output" begin
                sys = FakeStateSystem([1.0])
                integ = MockIntegrator(2.0)
                flow1 = Flows.StateFlow(sys, integ)
                flow2 = Flows.StateFlow(sys, integ)
                mpf = flow1 * (0.5, flow2)

                result = mpf(0.0, 3.0, 1.0)
                Test.@test result isa Number        # 1-D = scalar convention
                Test.@test result ≈ 3.0 * 4
            end

            Test.@testset "call with (tspan, x0)" begin
                sys = FakeStateSystem([1.0, 2.0])
                integ = MockIntegrator(2.0)
                flow1 = Flows.StateFlow(sys, integ)
                flow2 = Flows.StateFlow(sys, integ)
                mpf = flow1 * (0.5, flow2)

                result = mpf((0.0, 1.0), x0)
                # Result should be a merged MockIntegrationResult
                Test.@test result isa MockIntegrationResult
                Test.@test result.u == vcat(x0 * 2, x0 * 4)
            end

            Test.@testset "n-D vector trajectory: 2-D state → MockIntegrationResult" begin
                sys = FakeStateSystem([1.0, 2.0])
                integ = MockIntegrator(2.0)
                flow1 = Flows.StateFlow(sys, integ)
                flow2 = Flows.StateFlow(sys, integ)
                mpf = flow1 * (0.5, flow2)

                x0_2d = [1.0, 2.0]
                result = mpf((0.0, 1.0), x0_2d)
                Test.@test result isa MockIntegrationResult
                Test.@test result.u isa AbstractVector && length(result.u) == 4
                Test.@test result.u == vcat(x0_2d * 2, x0_2d * 4)
            end
        end

        Test.@testset "MultiPhaseHamiltonianFlow callable" begin
            x0 = [1.0, 2.0]
            p0 = [0.5, 0.3]

            Test.@testset "call with (t0, x0, p0, tf)" begin
                hsys = FakeHamiltonianSystem([1.0, 2.0])
                integ = MockIntegrator(2.0)
                hflow1 = Flows.HamiltonianFlow(hsys, integ)
                hflow2 = Flows.HamiltonianFlow(hsys, integ)
                hmpf = hflow1 * (0.5, hflow2)

                result = hmpf(0.0, x0, p0, 1.0)
                # Each phase multiplies by 2
                Test.@test result == vcat(x0 * 4, p0 * 4)
            end

            Test.@testset "call with (tspan, x0, p0)" begin
                hsys = FakeHamiltonianSystem([1.0, 2.0])
                integ = MockIntegrator(2.0)
                hflow1 = Flows.HamiltonianFlow(hsys, integ)
                hflow2 = Flows.HamiltonianFlow(hsys, integ)
                hmpf = hflow1 * (0.5, hflow2)

                result = hmpf((0.0, 1.0), x0, p0)
                # Result should be a merged MockIntegrationResult
                Test.@test result isa MockIntegrationResult
                Test.@test result.u == vcat(x0 * 2, p0 * 2, x0 * 4, p0 * 4)
            end
        end
    end
end

end # module

test_calling_multiphase() = TestCallingMultiphase.test_calling_multiphase()
