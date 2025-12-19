function test_default()
    # Test core default functions
    Test.@testset "Core defaults" begin
        # Test __autonomous()
        Test.@test CTFlows.__autonomous() isa Bool
        Test.@test CTFlows.__autonomous() == true

        # Test __variable()
        Test.@test CTFlows.__variable() isa Bool
        Test.@test CTFlows.__variable() == false

        # Test __backend()
        backend = CTFlows.__backend()
        Test.@test backend isa DifferentiationInterface.AutoForwardDiff
    end

    # Test extension defaults (CTFlowsODE)
    Test.@testset "CTFlowsODE defaults" begin
        Test.@test CTFlowsODE.__abstol() isa Real
        Test.@test CTFlowsODE.__abstol() > 0
        Test.@test CTFlowsODE.__abstol() < 1
        Test.@test CTFlowsODE.__reltol() isa Real
        Test.@test CTFlowsODE.__reltol() > 0
        Test.@test CTFlowsODE.__reltol() < 1
        Test.@test CTFlowsODE.__saveat() isa Vector
        Test.@test CTFlowsODE.__alg() isa Tsit5
        Test.@test CTFlowsODE.__tstops() isa Vector{<:CTFlows.Time}
    end
end
