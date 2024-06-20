function test_default()

    @test CTFlows.__abstol() isa Real
    @test CTFlows.__abstol() > 0
    @test CTFlows.__abstol() < 1
    @test CTFlows.__reltol() isa Real
    @test CTFlows.__reltol() > 0
    @test CTFlows.__reltol() < 1
    @test CTFlows.__saveat() isa Vector
    @test isnothing(CTFlows.__alg())
    @test CTFlows.__tstops() isa Vector{<:Time}

end