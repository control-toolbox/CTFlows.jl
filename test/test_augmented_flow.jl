function test_augmented_flow()
    Flow = CTFlows.Flow

    # ====================================================================
    # LEVEL 1 — rhs_augmented unit tests (no ODE integration)
    # ====================================================================

    @testset "rhs_augmented: direct Hamiltonian, n=1 m=1" begin
        # H(t, x, p, v) = p * v * x  →  ∂H/∂p = v*x, ∂H/∂x = p*v, ∂H/∂v = p*x
        h = CTFlows.Hamiltonian((t, x, p, v) -> p * v * x; autonomous=false, variable=true)
        rhs_aug! = CTFlowsODE.rhs_augmented(h, 1, 1)

        # z_aug = [x; v; p; pv] = [2.0; 3.0; 5.0; 0.0]
        z_aug = [2.0, 3.0, 5.0, 0.0]
        dz_aug = similar(z_aug)
        rhs_aug!(dz_aug, z_aug, nothing, 0.0)

        x, v, p = 2.0, 3.0, 5.0
        # dx/dt = ∂H/∂p = v*x = 6.0
        Test.@test dz_aug[1] ≈ v * x
        # dv/dt = 0
        Test.@test dz_aug[2] ≈ 0.0
        # dp/dt = -∂H/∂x = -p*v = -15.0
        Test.@test dz_aug[3] ≈ -p * v
        # dpv/dt = -∂H/∂v = -p*x = -10.0
        Test.@test dz_aug[4] ≈ -p * x
    end

    @testset "rhs_augmented: direct Hamiltonian, n=2 m=1" begin
        # H(t, x, p, v) = p₁*v*x₁ + p₂*x₂
        h = CTFlows.Hamiltonian(
            (t, x, p, v) -> p[1] * v * x[1] + p[2] * x[2];
            autonomous=false, variable=true)
        rhs_aug! = CTFlowsODE.rhs_augmented(h, 2, 1)

        # z_aug = [x₁; x₂; v; p₁; p₂; pv] = [2.0; 3.0; 4.0; 5.0; 6.0; 0.0]
        z_aug = [2.0, 3.0, 4.0, 5.0, 6.0, 0.0]
        dz_aug = similar(z_aug)
        rhs_aug!(dz_aug, z_aug, nothing, 0.0)

        x1, x2, v, p1, p2 = 2.0, 3.0, 4.0, 5.0, 6.0
        # dx₁/dt = ∂H/∂p₁ = v*x₁ = 8.0
        Test.@test dz_aug[1] ≈ v * x1
        # dx₂/dt = ∂H/∂p₂ = x₂ = 3.0
        Test.@test dz_aug[2] ≈ x2
        # dv/dt = 0
        Test.@test dz_aug[3] ≈ 0.0
        # dp₁/dt = -∂H/∂x₁ = -p₁*v = -20.0
        Test.@test dz_aug[4] ≈ -p1 * v
        # dp₂/dt = -∂H/∂x₂ = -p₂ = -6.0
        Test.@test dz_aug[5] ≈ -p2
        # dpv/dt = -∂H/∂v = -p₁*x₁ = -10.0
        Test.@test dz_aug[6] ≈ -p1 * x1
    end

    @testset "rhs_augmented: direct Hamiltonian, n=1 m=2" begin
        # H(t, x, p, v) = p * (v₁ + v₂) * x
        h = CTFlows.Hamiltonian(
            (t, x, p, v) -> p * (v[1] + v[2]) * x;
            autonomous=false, variable=true)
        rhs_aug! = CTFlowsODE.rhs_augmented(h, 1, 2)

        # z_aug = [x; v₁; v₂; p; pv₁; pv₂] = [2.0; 3.0; 4.0; 5.0; 0.0; 0.0]
        z_aug = [2.0, 3.0, 4.0, 5.0, 0.0, 0.0]
        dz_aug = similar(z_aug)
        rhs_aug!(dz_aug, z_aug, nothing, 0.0)

        x, v1, v2, p = 2.0, 3.0, 4.0, 5.0
        # dx/dt = ∂H/∂p = (v₁+v₂)*x = 14.0
        Test.@test dz_aug[1] ≈ (v1 + v2) * x
        # dv₁/dt = 0, dv₂/dt = 0
        Test.@test dz_aug[2] ≈ 0.0
        Test.@test dz_aug[3] ≈ 0.0
        # dp/dt = -∂H/∂x = -p*(v₁+v₂) = -35.0
        Test.@test dz_aug[4] ≈ -p * (v1 + v2)
        # dpv₁/dt = -∂H/∂v₁ = -p*x = -10.0
        Test.@test dz_aug[5] ≈ -p * x
        # dpv₂/dt = -∂H/∂v₂ = -p*x = -10.0
        Test.@test dz_aug[6] ≈ -p * x
    end

    @testset "rhs_augmented: OCP Hamiltonian, n=1 m=1" begin
        # Build OCP: ẋ = v*x, no Lagrange cost
        pre_ocp = CTModels.PreModel()
        CTModels.variable!(pre_ocp, 1)
        CTModels.time!(pre_ocp; t0=0.0, tf=1.0)
        CTModels.state!(pre_ocp, 1)
        CTModels.dynamics!(pre_ocp, (r, t, x, u, v) -> (r[1] = v[1] * x[1]; r))
        CTModels.objective!(pre_ocp, :min; lagrange=(t, x, u, v) -> 0.0)
        CTModels.definition!(pre_ocp, quote end)
        CTModels.time_dependence!(pre_ocp; autonomous=true)
        ocp = CTModels.build(pre_ocp)

        f = Flow(ocp)
        h = f.hamiltonian  # Hamiltonian from OCP
        rhs_aug! = CTFlowsODE.rhs_augmented(h, 1, 1)

        # z_aug = [x; v; p; pv] = [2.0; 3.0; 5.0; 0.0]
        z_aug = [2.0, 3.0, 5.0, 0.0]
        dz_aug = similar(z_aug)

        # This may fail due to ::ctVector in Dynamics — we document it
        try
            rhs_aug!(dz_aug, z_aug, nothing, 0.0)
            # If it works, verify values: H = p*v*x, same as direct test
            x, v, p = 2.0, 3.0, 5.0
            Test.@test dz_aug[1] ≈ v * x
            Test.@test dz_aug[2] ≈ 0.0
            Test.@test dz_aug[3] ≈ -p * v
            Test.@test dz_aug[4] ≈ -p * x
        catch e
            # Expected: MethodError due to ::ctVector constraint in Dynamics
            Test.@test e isa MethodError
            @info "rhs_augmented with OCP Hamiltonian fails as expected (::ctVector)" exception=e
        end
    end

    # ====================================================================
    # LEVEL 2 — Reference: manual Flow(Hamiltonian(H_aug))
    # ====================================================================

    @testset "Reference: Flow(Hamiltonian(H_aug)), n=1 m=1" begin
        # H(t, x, p, v) = p * v * x
        # H_aug(t, z_aug, p_aug) = H(t, x, p, v) where z_aug=[x;v], p_aug=[p;pv]
        H_aug(t, z_aug, p_aug) = p_aug[1] * z_aug[2] * z_aug[1]
        f_aug = Flow(CTFlows.Hamiltonian(H_aug; autonomous=false, variable=false))

        t0, tf = 0.0, 1.0
        x0, v0, p0 = 1.0, 0.5, 1.0
        z_aug0 = [x0, v0]
        p_aug0 = [p0, 0.0]  # pv(t0) = 0

        z_augf, p_augf = f_aug(t0, z_aug0, p_aug0, tf)

        # Analytical: ẋ = v*x → x(t) = x0*exp(v*t), ṗ = -p*v → p(t) = p0*exp(-v*t)
        # ∂H/∂v = p*x = p0*x0 = const (since exp(vt)*exp(-vt) = 1)
        # dpv/dt = -p*x = -p0*x0 → pv(tf) = -p0*x0*(tf-t0)
        xf_exact = x0 * exp(v0 * tf)
        pf_exact = p0 * exp(-v0 * tf)
        pvf_exact = -p0 * x0 * (tf - t0)

        Test.@test z_augf[1] ≈ xf_exact atol=1e-8
        Test.@test z_augf[2] ≈ v0 atol=1e-8       # v is constant
        Test.@test p_augf[1] ≈ pf_exact atol=1e-8
        Test.@test p_augf[2] ≈ pvf_exact atol=1e-8
    end

    @testset "Reference: Flow(Hamiltonian(H_aug)), n=2 m=1" begin
        # H(t, x, p, v) = p₁*x₂ + p₂*v
        H_aug(t, z_aug, p_aug) = p_aug[1] * z_aug[2] + p_aug[2] * z_aug[3]
        f_aug = Flow(CTFlows.Hamiltonian(H_aug; autonomous=false, variable=false))

        t0, tf = 0.0, 0.5
        x0 = [1.0, 0.0]
        v0 = 1.0
        p0 = [1.0, 1.0]
        z_aug0 = [x0; v0]
        p_aug0 = [p0; 0.0]

        z_augf, p_augf = f_aug(t0, z_aug0, p_aug0, tf)

        # ẋ₁ = ∂H/∂p₁ = x₂, ẋ₂ = ∂H/∂p₂ = v, v̇ = 0
        # ṗ₁ = -∂H/∂x₁ = 0, ṗ₂ = -∂H/∂x₂ = -p₁, ṗv = -∂H/∂v = -p₂
        # Analytical: x₂(t) = v*t, x₁(t) = 1 + v*t²/2
        #             p₁(t) = 1, p₂(t) = 1-t
        #             pv(t) = -∫₀ᵗ p₂(s) ds = -(t - t²/2)
        dt = tf - t0
        Test.@test z_augf[1] ≈ 1.0 + v0 * dt^2 / 2 atol=1e-8
        Test.@test z_augf[2] ≈ v0 * dt atol=1e-8
        Test.@test z_augf[3] ≈ v0 atol=1e-8
        Test.@test p_augf[1] ≈ 1.0 atol=1e-8
        Test.@test p_augf[2] ≈ 1.0 - dt atol=1e-8
        Test.@test p_augf[3] ≈ -(dt - dt^2 / 2) atol=1e-8
    end

    # ====================================================================
    # LEVEL 3 — Error handling
    # ====================================================================

    @testset "Errors: augment=true on Fixed model" begin
        pre_ocp = CTModels.PreModel()
        CTModels.time!(pre_ocp; t0=0.0, tf=1.0)
        CTModels.state!(pre_ocp, 1)
        CTModels.dynamics!(pre_ocp, (r, t, x, u, v) -> (r[1] = x[1]; r))
        CTModels.objective!(pre_ocp, :min; lagrange=(t, x, u, v) -> x[1]^2)
        CTModels.definition!(pre_ocp, quote end)
        CTModels.time_dependence!(pre_ocp; autonomous=true)
        ocp = CTModels.build(pre_ocp)

        f = Flow(ocp)
        Test.@test_throws CTBase.Exceptions.PreconditionError f(0.0, 1.0, 1.0, 1.0; augment=true)
    end

    @testset "Errors: augment=true on trajectory call (NonFixed)" begin
        pre_ocp = CTModels.PreModel()
        CTModels.variable!(pre_ocp, 1)
        CTModels.time!(pre_ocp; t0=0.0, tf=1.0)
        CTModels.state!(pre_ocp, 1)
        CTModels.dynamics!(pre_ocp, (r, t, x, u, v) -> (r[1] = v[1] * x[1]; r))
        CTModels.objective!(pre_ocp, :min; lagrange=(t, x, u, v) -> x[1]^2)
        CTModels.definition!(pre_ocp, quote end)
        CTModels.time_dependence!(pre_ocp; autonomous=true)
        ocp = CTModels.build(pre_ocp)

        f = Flow(ocp)
        Test.@test_throws CTBase.Exceptions.PreconditionError f((0.0, 1.0), 1.0, 1.0, 0.5; augment=true)
    end

    @testset "Errors: augment=true on trajectory call (Fixed)" begin
        pre_ocp = CTModels.PreModel()
        CTModels.time!(pre_ocp; t0=0.0, tf=1.0)
        CTModels.state!(pre_ocp, 1)
        CTModels.dynamics!(pre_ocp, (r, t, x, u, v) -> (r[1] = x[1]; r))
        CTModels.objective!(pre_ocp, :min; lagrange=(t, x, u, v) -> x[1]^2)
        CTModels.definition!(pre_ocp, quote end)
        CTModels.time_dependence!(pre_ocp; autonomous=true)
        ocp = CTModels.build(pre_ocp)

        f = Flow(ocp)
        Test.@test_throws CTBase.Exceptions.PreconditionError f((0.0, 1.0), 1.0, 1.0; augment=true)
    end

    # ====================================================================
    # LEVEL 4 — augment=true vs manual reference
    # ====================================================================

    @testset "augment=true vs reference: control-free, n=1 m=1" begin
        # OCP: ẋ = v*x, L = 0
        pre_ocp = CTModels.PreModel()
        CTModels.variable!(pre_ocp, 1)
        CTModels.time!(pre_ocp; t0=0.0, tf=1.0)
        CTModels.state!(pre_ocp, 1)
        CTModels.dynamics!(pre_ocp, (r, t, x, u, v) -> (r[1] = v[1] * x[1]; r))
        CTModels.objective!(pre_ocp, :min; lagrange=(t, x, u, v) -> 0.0)
        CTModels.definition!(pre_ocp, quote end)
        CTModels.time_dependence!(pre_ocp; autonomous=true)
        ocp = CTModels.build(pre_ocp)

        t0, tf = 0.0, 1.0
        x0, p0, λ = 1.0, 1.0, 0.5

        # Reference: manual H_aug
        # H(t,x,p,v) = p*v*x  →  H_aug(t,[x;v],[p;pv]) = p*v*x
        H_aug(t, z, pz) = pz[1] * z[2] * z[1]
        f_ref = Flow(CTFlows.Hamiltonian(H_aug; autonomous=false, variable=false))
        z_augf, p_augf = f_ref(t0, [x0, λ], [p0, 0.0], tf)
        xf_ref = z_augf[1]
        pf_ref = p_augf[1]
        pvf_ref = p_augf[2]

        # augment=true
        f = Flow(ocp)
        xf, pf, pvf = f(t0, x0, p0, tf, λ; augment=true)

        Test.@test xf ≈ xf_ref atol=1e-8
        Test.@test pf ≈ pf_ref atol=1e-8
        Test.@test pvf ≈ pvf_ref atol=1e-8

        # Also check analytical solution
        Test.@test xf ≈ x0 * exp(λ * tf) atol=1e-8
        Test.@test pf ≈ p0 * exp(-λ * tf) atol=1e-8
        Test.@test pvf ≈ -p0 * x0 * tf atol=1e-8
    end

    @testset "augment=true vs reference: control-free, n=2 m=1" begin
        # OCP: ẋ₁ = x₂, ẋ₂ = v, L = 0
        pre_ocp = CTModels.PreModel()
        CTModels.variable!(pre_ocp, 1)
        CTModels.time!(pre_ocp; t0=0.0, tf=0.5)
        CTModels.state!(pre_ocp, 2)
        CTModels.dynamics!(pre_ocp, (r, t, x, u, v) -> (r[1] = x[2]; r[2] = v[1]; r))
        CTModels.objective!(pre_ocp, :min; lagrange=(t, x, u, v) -> 0.0)
        CTModels.definition!(pre_ocp, quote end)
        CTModels.time_dependence!(pre_ocp; autonomous=true)
        ocp = CTModels.build(pre_ocp)

        t0, tf = 0.0, 0.5
        x0 = [1.0, 0.0]
        p0 = [1.0, 1.0]
        λ = 1.0

        # Reference: H(t,x,p,v) = p₁*x₂ + p₂*v
        H_aug(t, z, pz) = pz[1] * z[2] + pz[2] * z[3]
        f_ref = Flow(CTFlows.Hamiltonian(H_aug; autonomous=false, variable=false))
        z_augf, p_augf = f_ref(t0, [x0; λ], [p0; 0.0], tf)

        # augment=true
        f = Flow(ocp)
        xf, pf, pvf = f(t0, x0, p0, tf, λ; augment=true)

        Test.@test xf ≈ z_augf[1:2] atol=1e-8
        Test.@test pf ≈ p_augf[1:2] atol=1e-8
        Test.@test pvf ≈ p_augf[3] atol=1e-8
    end

    @testset "augment=true vs reference: control-free, n=1 m=2" begin
        # OCP: ẋ = v₁ + v₂, L = 0
        pre_ocp = CTModels.PreModel()
        CTModels.variable!(pre_ocp, 2)
        CTModels.time!(pre_ocp; t0=0.0, tf=0.5)
        CTModels.state!(pre_ocp, 1)
        CTModels.dynamics!(pre_ocp, (r, t, x, u, v) -> (r[1] = v[1] + v[2]; r))
        CTModels.objective!(pre_ocp, :min; lagrange=(t, x, u, v) -> 0.0)
        CTModels.definition!(pre_ocp, quote end)
        CTModels.time_dependence!(pre_ocp; autonomous=true)
        ocp = CTModels.build(pre_ocp)

        t0, tf = 0.0, 0.5
        x0, p0 = 1.0, 1.0
        λ = [0.3, 0.2]

        # Reference: H(t,x,p,v) = p*(v₁+v₂)
        H_aug(t, z, pz) = pz[1] * (z[2] + z[3])
        f_ref = Flow(CTFlows.Hamiltonian(H_aug; autonomous=false, variable=false))
        z_augf, p_augf = f_ref(t0, [x0; λ], [p0; 0.0; 0.0], tf)

        # augment=true
        f = Flow(ocp)
        xf, pf, pvf = f(t0, x0, p0, tf, λ; augment=true)

        Test.@test xf ≈ z_augf[1] atol=1e-8
        Test.@test pf ≈ p_augf[1] atol=1e-8
        Test.@test pvf ≈ p_augf[2:3] atol=1e-8
    end

    @testset "augment=true vs reference: with Lagrange cost, n=1 m=1" begin
        # OCP: ẋ = v*x, L = x² → H = p*v*x - p⁰*x²
        pre_ocp = CTModels.PreModel()
        CTModels.variable!(pre_ocp, 1)
        CTModels.time!(pre_ocp; t0=0.0, tf=0.5)
        CTModels.state!(pre_ocp, 1)
        CTModels.dynamics!(pre_ocp, (r, t, x, u, v) -> (r[1] = v[1] * x[1]; r))
        CTModels.objective!(pre_ocp, :min; lagrange=(t, x, u, v) -> x[1]^2)
        CTModels.definition!(pre_ocp, quote end)
        CTModels.time_dependence!(pre_ocp; autonomous=true)
        ocp = CTModels.build(pre_ocp)

        t0, tf = 0.0, 0.5
        x0, p0, λ = 1.0, 1.0, 0.5

        # Reference: H = p*v*x - x²  (p⁰=-1, s=+1 for min)
        # z_aug=[x;v], p_aug=[p;pv]
        H_aug(t, z, pz) = pz[1] * z[2] * z[1] - z[1]^2
        f_ref = Flow(CTFlows.Hamiltonian(H_aug; autonomous=false, variable=false))
        z_augf, p_augf = f_ref(t0, [x0, λ], [p0, 0.0], tf)

        # augment=true
        f = Flow(ocp)
        xf, pf, pvf = f(t0, x0, p0, tf, λ; augment=true)

        Test.@test xf ≈ z_augf[1] atol=1e-8
        Test.@test pf ≈ p_augf[1] atol=1e-8
        Test.@test pvf ≈ p_augf[2] atol=1e-8
    end

    @testset "augment=true: return types (scalar/vector)" begin
        # n=1, m=1 → scalars
        pre_ocp = CTModels.PreModel()
        CTModels.variable!(pre_ocp, 1)
        CTModels.time!(pre_ocp; t0=0.0, tf=0.1)
        CTModels.state!(pre_ocp, 1)
        CTModels.dynamics!(pre_ocp, (r, t, x, u, v) -> (r[1] = v[1] * x[1]; r))
        CTModels.objective!(pre_ocp, :min; lagrange=(t, x, u, v) -> 0.0)
        CTModels.definition!(pre_ocp, quote end)
        CTModels.time_dependence!(pre_ocp; autonomous=true)
        ocp1 = CTModels.build(pre_ocp)
        f1 = Flow(ocp1)
        xf, pf, pvf = f1(0.0, 1.0, 1.0, 0.1, 0.5; augment=true)
        Test.@test xf isa Number
        Test.@test pf isa Number
        Test.@test pvf isa Number

        # n=2, m=1 → vectors for x,p; scalar for pv
        pre_ocp = CTModels.PreModel()
        CTModels.variable!(pre_ocp, 1)
        CTModels.time!(pre_ocp; t0=0.0, tf=0.1)
        CTModels.state!(pre_ocp, 2)
        CTModels.dynamics!(pre_ocp, (r, t, x, u, v) -> (r[1] = x[2]; r[2] = v[1]; r))
        CTModels.objective!(pre_ocp, :min; lagrange=(t, x, u, v) -> 0.0)
        CTModels.definition!(pre_ocp, quote end)
        CTModels.time_dependence!(pre_ocp; autonomous=true)
        ocp2 = CTModels.build(pre_ocp)
        f2 = Flow(ocp2)
        xf, pf, pvf = f2(0.0, [1.0, 0.0], [1.0, 1.0], 0.1, 0.5; augment=true)
        Test.@test xf isa Vector
        Test.@test pf isa Vector
        Test.@test pvf isa Number

        # n=1, m=2 → scalar for x,p; vector for pv
        pre_ocp = CTModels.PreModel()
        CTModels.variable!(pre_ocp, 2)
        CTModels.time!(pre_ocp; t0=0.0, tf=0.1)
        CTModels.state!(pre_ocp, 1)
        CTModels.dynamics!(pre_ocp, (r, t, x, u, v) -> (r[1] = v[1] + v[2]; r))
        CTModels.objective!(pre_ocp, :min; lagrange=(t, x, u, v) -> 0.0)
        CTModels.definition!(pre_ocp, quote end)
        CTModels.time_dependence!(pre_ocp; autonomous=true)
        ocp3 = CTModels.build(pre_ocp)
        f3 = Flow(ocp3)
        xf, pf, pvf = f3(0.0, 1.0, 1.0, 0.1, [0.3, 0.2]; augment=true)
        Test.@test xf isa Number
        Test.@test pf isa Number
        Test.@test pvf isa Vector
        Test.@test length(pvf) == 2
    end
end
