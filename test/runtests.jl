using CTFlows
using Test

# Include all test files from the suite
include("suite/systems/test_abstract_system.jl")
include("suite/flows/test_abstract_flow.jl")
include("suite/flows/test_flow.jl")
include("suite/modelers/test_abstract_flow_modeler.jl")
include("suite/integrators/test_abstract_ode_integrator.jl")
include("suite/ad_backends/test_abstract_ad_backend.jl")
include("suite/pipelines/test_build_system.jl")
include("suite/pipelines/test_build_flow.jl")
include("suite/pipelines/test_integrate.jl")
include("suite/pipelines/test_build_solution.jl")
include("suite/pipelines/test_solve.jl")
include("suite/meta/test_aqua.jl")

# Run all tests
@testset "CTFlows Test Suite" begin
    test_abstract_system()
    test_abstract_flow()
    test_flow()
    test_abstract_flow_modeler()
    test_abstract_ode_integrator()
    test_abstract_ad_backend()
    test_build_system()
    test_build_flow()
    test_integrate()
    test_build_solution()
    test_solve()
    test_aqua()
end
