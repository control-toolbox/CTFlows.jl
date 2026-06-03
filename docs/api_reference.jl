# ==============================================================================
# CTFlows API Reference Manager
#
# Generates API reference pages via CTBase.automatic_reference_documentation,
# one section per CTFlows submodule. Generated .md files are cleaned up after
# the build.
#
# The per-submodule file lists below mirror the actual source tree under
# `src/<Submodule>/`. Keep them in sync when files are added/removed/renamed,
# otherwise docstrings silently drop out of the reference and internal
# `@ref` links break.
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

    EXCLUDE_SYMBOLS = Symbol[:include, :eval]

    pages = [
        # ───────────────────────────────────────────────────────────────────
        # Traits
        # ───────────────────────────────────────────────────────────────────
        CTBase.automatic_reference_documentation(;
            subdirectory="api",
            primary_modules=[
                CTFlows.Traits => src(
                    joinpath("Traits", "Traits.jl"),
                    joinpath("Traits", "abstract.jl"),
                    joinpath("Traits", "ad.jl"),
                    joinpath("Traits", "content.jl"),
                    joinpath("Traits", "helpers.jl"),
                    joinpath("Traits", "mode.jl"),
                    joinpath("Traits", "mutability.jl"),
                    joinpath("Traits", "time_dependence.jl"),
                    joinpath("Traits", "variable_costate.jl"),
                    joinpath("Traits", "variable_dependence.jl"),
                ),
            ],
            exclude=EXCLUDE_SYMBOLS,
            public=true,
            private=true,
            title="Traits",
            title_in_menu="Traits",
            filename="api_traits",
        ),
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
            exclude=EXCLUDE_SYMBOLS,
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
            exclude=EXCLUDE_SYMBOLS,
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
            exclude=EXCLUDE_SYMBOLS,
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
            exclude=EXCLUDE_SYMBOLS,
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
            exclude=EXCLUDE_SYMBOLS,
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
            exclude=EXCLUDE_SYMBOLS,
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
            exclude=EXCLUDE_SYMBOLS,
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
            exclude=EXCLUDE_SYMBOLS,
            public=true,
            private=true,
            title="Flows",
            title_in_menu="Flows",
            filename="api_flows",
        ),
        # ───────────────────────────────────────────────────────────────────
        # Solutions
        # ───────────────────────────────────────────────────────────────────
        CTBase.automatic_reference_documentation(;
            subdirectory="api",
            primary_modules=[
                CTFlows.Solutions => src(
                    joinpath("Solutions", "Solutions.jl"),
                    joinpath("Solutions", "building.jl"),
                    joinpath("Solutions", "vector_field_solution.jl"),
                    joinpath("Solutions", "hamiltonian_vector_field_solution.jl"),
                ),
            ],
            exclude=EXCLUDE_SYMBOLS,
            public=true,
            private=true,
            title="Solutions",
            title_in_menu="Solutions",
            filename="api_solutions",
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
            exclude=EXCLUDE_SYMBOLS,
            public=true,
            private=true,
            title="MultiPhase",
            title_in_menu="MultiPhase",
            filename="api_multiphase",
        ),
    ]

    # ───────────────────────────────────────────────────────────────────
    # Extension: ForwardDiff
    # ───────────────────────────────────────────────────────────────────
    CTFlowsForwardDiff = Base.get_extension(CTFlows, :CTFlowsForwardDiff)
    if !isnothing(CTFlowsForwardDiff)
        push!(
            pages,
            CTBase.automatic_reference_documentation(;
                subdirectory="api",
                primary_modules=[CTFlowsForwardDiff => ext("CTFlowsForwardDiff.jl")],
                external_modules_to_document=[CTFlows],
                exclude=EXCLUDE_SYMBOLS,
                public=true,
                private=true,
                title="ForwardDiff Extension",
                title_in_menu="ForwardDiff",
                filename="ext_forwarddiff",
            ),
        )
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
