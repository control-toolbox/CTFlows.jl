function test_default()

    Test.@test CTFlowsODE.__abstol() isa Real
    Test.@test CTFlowsODE.__abstol() > 0
    Test.@test CTFlowsODE.__abstol() < 1
    Test.@test CTFlowsODE.__reltol() isa Real
    Test.@test CTFlowsODE.__reltol() > 0
    Test.@test CTFlowsODE.__reltol() < 1
    Test.@test CTFlowsODE.__saveat() isa Vector
    Test.@test CTFlowsODE.__alg() isa Tsit5
    Test.@test CTFlowsODE.__tstops() isa Vector{<:Time}

end
