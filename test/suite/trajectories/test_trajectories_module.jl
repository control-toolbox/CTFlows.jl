"""
# ============================================================================
# Solutions Module Exports Tests
# ============================================================================
# This file tests the exports from the `Solutions` module. It verifies that
# the expected types and functions are properly exported by
# `CTFlows.Trajectories` and readily accessible to the end user.
#
# Functionality tests are in separate files:
# - test_building_solutions.jl for solution building functionality
"""

module TestTrajectoriesModule

using Test: Test
using CTFlows: CTFlows
import CTFlows.Trajectories
using CTFlows.Trajectories  # For testing exported symbols
import CTFlows.Flows: Flows
import CTModels: CTModels
import CTBase.Data: Data
using OrdinaryDiffEqTsit5: Tsit5
using ForwardDiff: ForwardDiff  # triggers the DI ForwardDiff extension (AutoForwardDiff)

const VERBOSE = isdefined(Main, :TestData) ? Main.TestData.VERBOSE : true
const SHOWTIMING = isdefined(Main, :TestData) ? Main.TestData.SHOWTIMING : true

const CurrentModule = TestTrajectoriesModule

# ============================================================================
# Hardcoded export lists
# ============================================================================
# These lists define the expected public API of the Solutions module.

const EXPORTED_ABSTRACT_TYPES = (
    :AbstractVectorFieldTrajectory, :AbstractHamiltonianVectorFieldTrajectory
)

const EXPORTED_CONCRETE_TYPES = (:VectorFieldTrajectory, :HamiltonianVectorFieldTrajectory)

# `plot` is a `RecipesBase.plot` method (an extension overload), not exported — call it
# qualified (`Trajectories.plot`) or via `Plots.plot`. See test_plots_extension.jl.
const EXPORTED_FUNCTIONS = (:state, :time_grid, :costate, :build_trajectory)

# Note: Solutions module has no private symbols (after filtering Julia internals)
# All symbols are exported

# ============================================================================
# Helper functions (generic for reuse in other modules)
# ============================================================================

"""
    test_exported_symbols(module_ref::Module, symbols::Tuple, test_module::Module)

Test that symbols are exported from a module and available via `using`.
"""
function test_exported_symbols(module_ref::Module, symbols::Tuple, test_module::Module)
    for sym in symbols
        Test.@testset "$(sym)" begin
            Test.@test isdefined(module_ref, sym)
            Test.@test isdefined(test_module, sym)
        end
    end
end

"""
    test_internal_symbols(module_ref::Module, symbols::Tuple, test_module::Module)

Test that symbols are defined in a module but NOT exported (not available via `using`).
Generic helper for modules with private symbols.
"""
function test_internal_symbols(module_ref::Module, symbols::Tuple, test_module::Module)
    for sym in symbols
        Test.@testset "$(sym)" begin
            Test.@test isdefined(module_ref, sym)
            Test.@test !isdefined(test_module, sym)
        end
    end
end

# ============================================================================
# OCP fixture — double integrator with a stationary control law
# ============================================================================
# Used only to build a genuine CTModels.Solution via Flow(ocp, law), for the
# unification test below (contrasted with a raw HamiltonianVectorFieldTrajectory
# from Flow(HamiltonianVectorField(...))).

function _build_double_integrator()
    pre = CTModels.Building.PreModel()
    CTModels.Building.time_dependence!(pre; autonomous=true)
    CTModels.Building.time!(pre; t0=0.0, tf=1.0)
    CTModels.Building.state!(pre, 2)
    CTModels.Building.control!(pre, 1)
    CTModels.Building.dynamics!(pre, (r, t, x, u, v) -> (r.=[x[2], u[1]]; nothing))
    CTModels.Building.objective!(pre, :min; lagrange=(t, x, u, v) -> 0.5 * u[1]^2)
    return CTModels.Building.build(pre)
end

# Built once at module top level (not inside the test function): the AD-differentiated
# Hamiltonian glue is keyed on the closure/OCP types, and rebuilding per-call defeats it.
const _OCP_DI_UNIFY = _build_double_integrator()
const _LAW_UNIFY = Data.DynClosedLoop((x, p) -> p[2])

# ============================================================================
# Test function
# ============================================================================

function test_trajectories_module()
    Test.@testset "Trajectories Module Exports" verbose=VERBOSE showtiming=SHOWTIMING begin

        # ====================================================================
        # Module availability
        # ====================================================================

        Test.@testset "Module availability" begin
            Test.@testset "Trajectories module exists" begin
                Test.@test isdefined(CTFlows, :Trajectories)
                Test.@test CTFlows.Trajectories isa Module
            end
        end

        # ====================================================================
        # Exported abstract types verification
        # ====================================================================

        Test.@testset "Exported abstract types" begin
            test_exported_symbols(Trajectories, EXPORTED_ABSTRACT_TYPES, CurrentModule)
        end

        # ====================================================================
        # Exported concrete types verification
        # ====================================================================

        Test.@testset "Exported concrete types" begin
            test_exported_symbols(Trajectories, EXPORTED_CONCRETE_TYPES, CurrentModule)
        end

        # ====================================================================
        # Exported functions verification
        # ====================================================================

        Test.@testset "Exported functions" begin
            test_exported_symbols(Trajectories, EXPORTED_FUNCTIONS, CurrentModule)
        end

        # ====================================================================
        # Type hierarchy tests
        # ====================================================================

        Test.@testset "Type hierarchy" begin
            Test.@testset "Abstract types are abstract" begin
                Test.@test isabstracttype(Trajectories.AbstractVectorFieldTrajectory)
                Test.@test isabstracttype(
                    Trajectories.AbstractHamiltonianVectorFieldTrajectory
                )
            end

            Test.@testset "Concrete types inherit from abstract types" begin
                Test.@test Trajectories.VectorFieldTrajectory <:
                    Trajectories.AbstractVectorFieldTrajectory
                Test.@test Trajectories.HamiltonianVectorFieldTrajectory <:
                    Trajectories.AbstractHamiltonianVectorFieldTrajectory
            end
        end

        # ====================================================================
        # Unification with CTModels.Components (issue #370)
        # ====================================================================
        # `Trajectories.{state,control,costate,objective,time_grid}` must *be* the
        # CTModels.Components generics of the same name — not distinct function
        # objects with the same spelling — so that importing both into one module
        # succeeds instead of erroring.

        Test.@testset "CTModels.Components generic identity" begin
            for f in (:state, :control, :costate, :objective, :time_grid)
                Test.@test getproperty(Trajectories, f) ===
                    getproperty(CTModels.Components, f)
            end
        end

        Test.@testset "One import resolves both a trajectory and a solution" begin
            # Raw geometric API: Flow(HamiltonianVectorField(...)) over a span →
            # HamiltonianVectorFieldTrajectory (harmonic oscillator, AD-free vector field —
            # avoids the AD-differentiated Hamiltonian path, orthogonal to this test's point).
            hvf = Data.HamiltonianVectorField((x, p) -> (p, -x))
            fh = Flows.Flow(hvf; alg=Tsit5(), reltol=1e-10, abstol=1e-10)
            traj = fh((0.0, 1.0), [1.0, 0.0], [0.0, 1.0])
            Test.@test traj isa Trajectories.HamiltonianVectorFieldTrajectory

            # Flow(ocp, law) → genuine CTModels.Solution
            fo = Flows.Flow(
                _OCP_DI_UNIFY, _LAW_UNIFY; alg=Tsit5(), reltol=1e-10, abstol=1e-10
            )
            sol = fo((0.0, 1.0), [-1.0, 0.0], [12.0, 6.0])
            Test.@test sol isa CTModels.Solutions.Solution

            # A single unqualified `state`, imported once, resolves both shapes.
            x_traj = state(traj)
            x_sol = state(sol)
            Test.@test x_traj(0.0) isa Union{Number,AbstractVector}
            Test.@test x_sol(0.0) isa Union{Number,AbstractVector}
        end
    end
end

end # module

test_trajectories_module() = TestTrajectoriesModule.test_trajectories_module()
