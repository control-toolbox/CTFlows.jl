function test_default()

    Test.@test CTFlows.__abstol() isa Real
    Test.@test CTFlows.__abstol() > 0
    Test.@test CTFlows.__abstol() < 1
    Test.@test CTFlows.__reltol() isa Real
    Test.@test CTFlows.__reltol() > 0
    Test.@test CTFlows.__reltol() < 1
    Test.@test CTFlows.__saveat() isa Vector
    Test.@test isnothing(CTFlows.__alg())
    Test.@test CTFlows.__tstops() isa Vector{<:Time}

end