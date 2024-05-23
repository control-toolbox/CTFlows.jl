function test_abstract_system()

    Σ = DummySystem()

    @test_throws NotImplemented CTFlows.state_type(Σ)
    @test_throws NotImplemented CTFlows.variable_type(Σ)
    @test_throws NotImplemented CTFlows.default_variable(Σ)
    @test_throws NotImplemented CTFlows.is_variable(Σ)
    @test_throws NotImplemented CTFlows.convert_state(Σ)
    @test_throws NotImplemented CTFlows.convert_variable(Σ)
    @test_throws NotImplemented CTFlows.convert_ode_sol(Σ)
    @test_throws NotImplemented CTFlows.convert_ode_u(Σ)
    @test_throws NotImplemented CTFlows.rhs(Σ)

end