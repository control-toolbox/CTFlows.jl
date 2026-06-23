# ==============================================================================
# CTFlows API Reference Manager
#
# Generates API reference pages via CTBase.automatic_reference_documentation,
# one section per CTFlows submodule. Generated .md files are cleaned up after
# the build.
#
# The per-submodule file lists below mirror the actual source tree under
# `src/<Submodule>/` and `ext/`. Keep them in sync when files are
# added/removed/renamed, otherwise docstrings silently drop out of the
# reference and internal `@ref` links break.
# ==============================================================================

"""
    generate_api_reference(src_dir::String, ext_dir::String)

Generate the API reference documentation for CTFlows.
Returns the list of pages.
"""
function generate_api_reference(src_dir::String, ext_dir::String)
    # Helper to build absolute paths
    src(files...) = [abspath(joinpath(src_dir, f)) for f in files]
    ext(files...) = [abspath(joinpath(ext_dir, f)) for f in files]

    # Base exclusion list for all core modules
    EXCLUDE_BASE = Symbol[:include, :eval]
    
    pages = [
        # ───────────────────────────────────────────────────────────────────
        # Configs
        # ───────────────────────────────────────────────────────────────────
        CTBase.automatic_reference_documentation(;
            subdirectory="api",
            primary_modules=[
                CTFlows.Configs => src(
                    joinpath("Configs", "Configs.jl"),
                    joinpath("Configs", "abstract.jl"),
                    joinpath("Configs", "concrete.jl"),
                    joinpath("Configs", "implementations.jl"),
                    joinpath("Configs", "interface.jl"),
                    joinpath("Configs", "show.jl"),
                ),
            ],
            exclude=EXCLUDE_BASE,
            public=true,
            private=true,
            title="Configs",
            title_in_menu="Configs",
            filename="api_configs",
        ),
        # ───────────────────────────────────────────────────────────────────
        # Common
        # ───────────────────────────────────────────────────────────────────
        CTBase.automatic_reference_documentation(;
            subdirectory="api",
            primary_modules=[
                CTFlows.Common => src(
                    joinpath("Common", "Common.jl"),
                    joinpath("Common", "abstract_cache.jl"),
                    joinpath("Common", "abstract_tag.jl"),
                    joinpath("Common", "default.jl"),
                    joinpath("Common", "helpers.jl"),
                    joinpath("Common", "internal_norm.jl"),
                    joinpath("Common", "ode_parameters.jl"),
                ),
            ],
            exclude=EXCLUDE_BASE,
            public=true,
            private=true,
            title="Common",
            title_in_menu="Common",
            filename="api_common",
        ),
        # ───────────────────────────────────────────────────────────────────
        # Data
        # ───────────────────────────────────────────────────────────────────
        CTBase.automatic_reference_documentation(;
            subdirectory="api",
            primary_modules=[
                CTFlows.Data => src(
                    joinpath("Data", "Data.jl"),
                    joinpath("Data", "abstract_vector_field.jl"),
                    joinpath("Data", "vector_field.jl"),
                    joinpath("Data", "abstract_hamiltonian.jl"),
                    joinpath("Data", "hamiltonian.jl"),
                    joinpath("Data", "abstract_hamiltonian_vector_field.jl"),
                    joinpath("Data", "hamiltonian_vector_field.jl"),
                    joinpath("Data", "helpers.jl"),
                ),
            ],
            exclude=EXCLUDE_BASE,
            public=true,
            private=true,
            title="Data",
            title_in_menu="Data",
            filename="api_data",
        ),
        # ───────────────────────────────────────────────────────────────────
        # Differentiation
        # ───────────────────────────────────────────────────────────────────
        CTBase.automatic_reference_documentation(;
            subdirectory="api",
            primary_modules=[
                CTFlows.Differentiation => src(
                    joinpath("Differentiation", "Differentiation.jl"),
                    joinpath("Differentiation", "abstract_ad_backend.jl"),
                    joinpath("Differentiation", "building.jl"),
                    joinpath("Differentiation", "differentiation_interface.jl"),
                ),
            ],
            exclude=EXCLUDE_BASE,
            public=true,
            private=true,
            title="Differentiation",
            title_in_menu="Differentiation",
            filename="api_differentiation",
        ),
        # ───────────────────────────────────────────────────────────────────
        # DifferentialGeometry
        # ───────────────────────────────────────────────────────────────────
        CTBase.automatic_reference_documentation(;
            subdirectory="api",
            primary_modules=[
                CTFlows.DifferentialGeometry => src(
                    joinpath("DifferentialGeometry", "DifferentialGeometry.jl"),
                    joinpath("DifferentialGeometry", "default.jl"),
                    joinpath("DifferentialGeometry", "prefix.jl"),
                    joinpath("DifferentialGeometry", "exception_prefix.jl"),
                    joinpath("DifferentialGeometry", "ad.jl"),
                    joinpath("DifferentialGeometry", "ad_types.jl"),
                    joinpath("DifferentialGeometry", "lift.jl"),
                    joinpath("DifferentialGeometry", "poisson.jl"),
                    joinpath("DifferentialGeometry", "time_derivative.jl"),
                    joinpath("DifferentialGeometry", "lie_macro.jl"),
                ),
            ],
            exclude=EXCLUDE_BASE,
            public=true,
            private=true,
            title="DifferentialGeometry",
            title_in_menu="DifferentialGeometry",
            filename="api_differential_geometry",
        ),
        # ───────────────────────────────────────────────────────────────────
        # Systems
        # ───────────────────────────────────────────────────────────────────
        CTBase.automatic_reference_documentation(;
            subdirectory="api",
            primary_modules=[
                CTFlows.Systems => src(
                    joinpath("Systems", "Systems.jl"),
                    joinpath("Systems", "abstract_system.jl"),
                    joinpath("Systems", "building.jl"),
                    joinpath("Systems", "rhs_functors.jl"),
                    joinpath("Systems", "vector_field_system.jl"),
                    joinpath("Systems", "hamiltonian_getter.jl"),
                    joinpath("Systems", "hamiltonian_rhs_functors.jl"),
                    joinpath("Systems", "hamiltonian_system.jl"),
                    joinpath("Systems", "hvf_rhs_functors.jl"),
                    joinpath("Systems", "hamiltonian_vector_field_system.jl"),
                ),
            ],
            exclude=EXCLUDE_BASE,
            public=true,
            private=true,
            title="Systems",
            title_in_menu="Systems",
            filename="api_systems",
        ),
        # ───────────────────────────────────────────────────────────────────
        # Integrators
        # ───────────────────────────────────────────────────────────────────
        CTBase.automatic_reference_documentation(;
            subdirectory="api",
            primary_modules=[
                CTFlows.Integrators => src(
                    joinpath("Integrators", "Integrators.jl"),
                    joinpath("Integrators", "abstract_integrator.jl"),
                    joinpath("Integrators", "building.jl"),
                    joinpath("Integrators", "integration_result.jl"),
                    joinpath("Integrators", "sciml.jl"),
                ),
            ],
            exclude=EXCLUDE_BASE,
            public=true,
            private=true,
            title="Integrators",
            title_in_menu="Integrators",
            filename="api_integrators",
        ),
        # ───────────────────────────────────────────────────────────────────
        # Flows
        # ───────────────────────────────────────────────────────────────────
        CTBase.automatic_reference_documentation(;
            subdirectory="api",
            primary_modules=[
                CTFlows.Flows => src(
                    joinpath("Flows", "Flows.jl"),
                    joinpath("Flows", "abstract_flow.jl"),
                    joinpath("Flows", "building.jl"),
                    joinpath("Flows", "calling.jl"),
                    joinpath("Flows", "flow.jl"),
                    joinpath("Flows", "flow_routing.jl"),
                    joinpath("Flows", "registry.jl"),
                ),
            ],
            exclude=EXCLUDE_BASE,
            public=true,
            private=true,
            title="Flows",
            title_in_menu="Flows",
            filename="api_flows",
        ),
        # ───────────────────────────────────────────────────────────────────
        # Trajectories
        # ───────────────────────────────────────────────────────────────────
        CTBase.automatic_reference_documentation(;
            subdirectory="api",
            primary_modules=[
                CTFlows.Trajectories => src(
                    joinpath("Trajectories", "Trajectories.jl"),
                    joinpath("Trajectories", "building.jl"),
                    joinpath("Trajectories", "vector_field_trajectory.jl"),
                    joinpath("Trajectories", "hamiltonian_vector_field_trajectory.jl"),
                ),
            ],
            exclude=EXCLUDE_BASE,
            public=true,
            private=true,
            title="Trajectories",
            title_in_menu="Trajectories",
            filename="api_trajectories",
        ),
        # ───────────────────────────────────────────────────────────────────
        # MultiPhase
        # ───────────────────────────────────────────────────────────────────
        CTBase.automatic_reference_documentation(;
            subdirectory="api",
            primary_modules=[
                CTFlows.MultiPhase => src(
                    joinpath("MultiPhase", "MultiPhase.jl"),
                    joinpath("MultiPhase", "calling.jl"),
                    joinpath("MultiPhase", "concatenation.jl"),
                    joinpath("MultiPhase", "multiphase_flow.jl"),
                ),
            ],
            exclude=EXCLUDE_BASE,
            public=true,
            private=true,
            title="MultiPhase",
            title_in_menu="MultiPhase",
            filename="api_multiphase",
        ),
    ]

    # ───────────────────────────────────────────────────────────────────
    # Extensions
    # ───────────────────────────────────────────────────────────────────

    CTFlowsForwardDiff = Base.get_extension(CTFlows, :CTFlowsForwardDiff)
    if !isnothing(CTFlowsForwardDiff)
        push!(pages, CTBase.automatic_reference_documentation(;
            subdirectory="api",
            primary_modules=[CTFlowsForwardDiff => ext("CTFlowsForwardDiff.jl")],
            external_modules_to_document=[CTFlows],
            exclude=EXCLUDE_BASE,
            public=true,
            private=true,
            title="ForwardDiff Extension",
            title_in_menu="ForwardDiff",
            filename="ext_forwarddiff",
        ))
    end

    CTFlowsDifferentiationInterface = Base.get_extension(CTFlows, :CTFlowsDifferentiationInterface)
    if !isnothing(CTFlowsDifferentiationInterface)
        push!(pages, CTBase.automatic_reference_documentation(;
            subdirectory="api",
            primary_modules=[CTFlowsDifferentiationInterface => ext("CTFlowsDifferentiationInterface.jl")],
            external_modules_to_document=[CTFlows],
            exclude=EXCLUDE_BASE,
            public=true,
            private=true,
            title="DifferentiationInterface Extension",
            title_in_menu="DifferentiationInterface",
            filename="ext_differentiation_interface",
        ))
    end

    CTFlowsOrdinaryDiffEqTsit5 = Base.get_extension(CTFlows, :CTFlowsOrdinaryDiffEqTsit5)
    if !isnothing(CTFlowsOrdinaryDiffEqTsit5)
        push!(pages, CTBase.automatic_reference_documentation(;
            subdirectory="api",
            primary_modules=[CTFlowsOrdinaryDiffEqTsit5 => ext("CTFlowsOrdinaryDiffEqTsit5.jl")],
            external_modules_to_document=[CTFlows],
            exclude=EXCLUDE_BASE,
            public=true,
            private=true,
            title="OrdinaryDiffEqTsit5 Extension",
            title_in_menu="OrdinaryDiffEqTsit5",
            filename="ext_ordinary_diffeq_tsit5",
        ))
    end

    CTFlowsPlots = Base.get_extension(CTFlows, :CTFlowsPlots)
    if !isnothing(CTFlowsPlots)
        push!(pages, CTBase.automatic_reference_documentation(;
            subdirectory="api",
            primary_modules=[CTFlowsPlots => ext("CTFlowsPlots.jl")],
            external_modules_to_document=[CTFlows],
            exclude=EXCLUDE_BASE,
            public=true,
            private=true,
            title="Plots Extension",
            title_in_menu="Plots",
            filename="ext_plots",
        ))
    end

    CTFlowsSciMLIntegrator = Base.get_extension(CTFlows, :CTFlowsSciMLIntegrator)
    if !isnothing(CTFlowsSciMLIntegrator)
        push!(pages, CTBase.automatic_reference_documentation(;
            subdirectory="api",
            primary_modules=[
                CTFlowsSciMLIntegrator => ext(
                    joinpath("CTFlowsSciMLIntegrator", "CTFlowsSciMLIntegrator.jl"),
                    joinpath("CTFlowsSciMLIntegrator", "real_norm.jl"),
                    joinpath("CTFlowsSciMLIntegrator", "strategies.jl"),
                    joinpath("CTFlowsSciMLIntegrator", "integration_result.jl"),
                    joinpath("CTFlowsSciMLIntegrator", "build_and_solve.jl"),
                ),
            ],
            external_modules_to_document=[CTFlows],
            exclude=EXCLUDE_BASE,
            public=true,
            private=true,
            title="SciML Integrator Extension",
            title_in_menu="SciML Integrator",
            filename="ext_sciml_integrator",
        ))
    end

    CTFlowsSciMLFlows = Base.get_extension(CTFlows, :CTFlowsSciMLFlows)
    if !isnothing(CTFlowsSciMLFlows)
        push!(pages, CTBase.automatic_reference_documentation(;
            subdirectory="api",
            primary_modules=[
                CTFlowsSciMLFlows => ext(
                    joinpath("CTFlowsSciMLFlows", "CTFlowsSciMLFlows.jl"),
                    joinpath("CTFlowsSciMLFlows", "sciml_rhs_functors.jl"),
                    joinpath("CTFlowsSciMLFlows", "sciml_function_system.jl"),
                    joinpath("CTFlowsSciMLFlows", "problem_flow.jl"),
                    joinpath("CTFlowsSciMLFlows", "flow_constructors.jl"),
                ),
            ],
            external_modules_to_document=[CTFlows],
            exclude=EXCLUDE_BASE,
            public=true,
            private=true,
            title="SciML Flows Extension",
            title_in_menu="SciML Flows",
            filename="ext_sciml_flows",
        ))
    end

    CTFlowsStaticArrays = Base.get_extension(CTFlows, :CTFlowsStaticArrays)
    if !isnothing(CTFlowsStaticArrays)
        push!(pages, CTBase.automatic_reference_documentation(;
            subdirectory="api",
            primary_modules=[CTFlowsStaticArrays => ext("CTFlowsStaticArrays.jl")],
            external_modules_to_document=[CTFlows],
            exclude=EXCLUDE_BASE,
            public=true,
            private=true,
            title="StaticArrays Extension",
            title_in_menu="StaticArrays",
            filename="ext_static_arrays",
        ))
    end

    return pages
end

"""
    with_api_reference(f::Function, src_dir::String, ext_dir::String)

Generate the API reference, execute `f(pages)`, then clean up generated `.md` files.
"""
function with_api_reference(f::Function, src_dir::String, ext_dir::String)
    pages = generate_api_reference(src_dir, ext_dir)
    try
        f(pages)
    finally
        docs_src = abspath(joinpath(@__DIR__, "src"))
        _cleanup_pages(docs_src, pages)
    end
end

function _cleanup_pages(docs_src::String, pages)
    for p in pages
        content = last(p)
        if content isa AbstractString
            fname = endswith(content, ".md") ? content : content * ".md"
            full_path = joinpath(docs_src, fname)
            if isfile(full_path)
                rm(full_path)
            end
        elseif content isa Vector
            _cleanup_pages(docs_src, content)
        end
    end
end
