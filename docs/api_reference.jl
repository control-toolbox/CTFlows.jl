# ==============================================================================
# CTFlows API Reference Manager
#
# One CTBase.automatic_reference_documentation call per documented page.
# Keep the file lists in sync with src/<Submodule>/ and ext/ when files
# are added, removed, or renamed, otherwise docstrings silently drop out of
# the reference and internal `@ref` links break.
# ==============================================================================

"""
    generate_api_reference(src_dir::String, ext_dir::String)

Generate the API reference documentation for CTFlows.
Returns the list of pages.
"""
function generate_api_reference(src_dir::String, ext_dir::String)
    src(files...) = [abspath(joinpath(src_dir, f)) for f in files]
    ext(files...) = [abspath(joinpath(ext_dir, f)) for f in files]

    EXCLUDE_SYMBOLS = Symbol[:include, :eval]
    EXCLUDE_INTERNALS = vcat(
        EXCLUDE_SYMBOLS,
        Symbol[
            :DOCTYPE_ABSTRACT_TYPE,
            :DOCTYPE_CONSTANT,
            :DOCTYPE_FUNCTION,
            :DOCTYPE_MACRO,
            :DOCTYPE_MODULE,
            :DOCTYPE_STRUCT,
        ],
    )

    # ── Shared config: one entry per submodule ────────────────────────────────
    modules_config = [
        (
            mod=CTFlows.Configs,
            title="Configs",
            filename="configs",
            files=src(
                joinpath("Configs", "Configs.jl"),
                joinpath("Configs", "abstract.jl"),
                joinpath("Configs", "interface.jl"),
                joinpath("Configs", "implementations.jl"),
                joinpath("Configs", "concrete.jl"),
                joinpath("Configs", "show.jl"),
            ),
        ),
        (
            mod=CTFlows.Systems,
            title="Systems",
            filename="systems",
            files=src(
                joinpath("Systems", "Systems.jl"),
                joinpath("Systems", "ode_parameters.jl"),
                joinpath("Systems", "defaults.jl"),
                joinpath("Systems", "coercion.jl"),
                joinpath("Systems", "abstract_system.jl"),
                joinpath("Systems", "rhs_functors.jl"),
                joinpath("Systems", "hvf_rhs_functors.jl"),
                joinpath("Systems", "hamiltonian_rhs_functors.jl"),
                joinpath("Systems", "pseudo_hamiltonian_rhs_functors.jl"),
                joinpath("Systems", "constrained_pseudo_hamiltonian_rhs_functors.jl"),
                joinpath("Systems", "vector_field_system.jl"),
                joinpath("Systems", "hamiltonian_vector_field_system.jl"),
                joinpath("Systems", "hamiltonian_system.jl"),
                joinpath("Systems", "pseudo_hamiltonian_system.jl"),
                joinpath("Systems", "constrained_pseudo_hamiltonian_system.jl"),
                joinpath("Systems", "building.jl"),
                joinpath("Systems", "hamiltonian_getter.jl"),
                joinpath("Systems", "hamiltonian_getters_extra.jl"),
            ),
        ),
        (
            mod=CTFlows.Display,
            title="Display",
            filename="display",
            files=src(joinpath("Display", "Display.jl")),
        ),
        (
            mod=CTFlows.Integrators,
            title="Integrators",
            filename="integrators",
            files=src(joinpath("Integrators", "Integrators.jl")),
        ),
        (
            mod=CTFlows.Trajectories,
            title="Trajectories",
            filename="trajectories",
            files=src(
                joinpath("Trajectories", "Trajectories.jl"),
                joinpath("Trajectories", "vector_field_trajectory.jl"),
                joinpath("Trajectories", "hamiltonian_vector_field_trajectory.jl"),
                joinpath("Trajectories", "state_flow_trajectory.jl"),
                joinpath("Trajectories", "building.jl"),
            ),
        ),
        (
            mod=CTFlows.Flows,
            title="Flows",
            filename="flows",
            files=src(
                joinpath("Flows", "Flows.jl"),
                joinpath("Flows", "defaults.jl"),
                joinpath("Flows", "abstract_flow.jl"),
                joinpath("Flows", "flow.jl"),
                joinpath("Flows", "registry.jl"),
                joinpath("Flows", "flow_routing.jl"),
                joinpath("Flows", "ocp_readouts.jl"),
                joinpath("Flows", "optimal_control_flow.jl"),
                joinpath("Flows", "controlled_flow.jl"),
                joinpath("Flows", "building.jl"),
                joinpath("Flows", "calling.jl"),
            ),
            # Flows re-exports `hamiltonian_vector_field` and `vector_field` from Systems;
            # documenting them here too would duplicate the Systems-page docstring (same
            # canonical binding).
            exclude=vcat(EXCLUDE_SYMBOLS, [:hamiltonian_vector_field, :vector_field]),
        ),
        (
            mod=CTFlows.MultiPhase,
            title="MultiPhase",
            filename="multiphase",
            files=src(
                joinpath("MultiPhase", "MultiPhase.jl"),
                joinpath("MultiPhase", "multiphase_flow.jl"),
                joinpath("MultiPhase", "concatenation.jl"),
                joinpath("MultiPhase", "calling.jl"),
            ),
        ),
    ]

    # ── Extensions: one entry per extension module (loaded conditionally) ─────
    extensions_config = [
        (
            sym=:CTFlowsPlots,
            title="Plots Extension",
            title_in_menu="Plots",
            filename="ext_plots",
            files=ext(
                "CTFlowsPlots.jl",
                joinpath("CTFlowsPlots", "TrajectoryPlots", "TrajectoryPlots.jl"),
                joinpath("CTFlowsPlots", "TrajectoryPlots", "description.jl"),
                joinpath("CTFlowsPlots", "TrajectoryPlots", "panels.jl"),
                joinpath("CTFlowsPlots", "TrajectoryPlots", "plot.jl"),
            ),
        ),
        (
            sym=:CTFlowsSciMLIntegrator,
            title="SciML Integrator Extension",
            title_in_menu="SciML Integrator",
            filename="ext_sciml_integrator",
            files=ext(
                joinpath("CTFlowsSciMLIntegrator", "CTFlowsSciMLIntegrator.jl"),
                joinpath("CTFlowsSciMLIntegrator", "build_problem.jl"),
                joinpath("CTFlowsSciMLIntegrator", "build_options.jl"),
            ),
        ),
        (
            sym=:CTFlowsSciMLFlows,
            title="SciML Flows Extension",
            title_in_menu="SciML Flows",
            filename="ext_sciml_flows",
            files=ext(
                joinpath("CTFlowsSciMLFlows", "CTFlowsSciMLFlows.jl"),
                joinpath("CTFlowsSciMLFlows", "sciml_rhs_functors.jl"),
                joinpath("CTFlowsSciMLFlows", "sciml_function_system.jl"),
                joinpath("CTFlowsSciMLFlows", "problem_flow.jl"),
                joinpath("CTFlowsSciMLFlows", "flow_constructors.jl"),
            ),
        ),
        (
            sym=:CTFlowsStaticArrays,
            title="StaticArrays Extension",
            title_in_menu="StaticArrays",
            filename="ext_static_arrays",
            files=ext("CTFlowsStaticArrays.jl"),
        ),
    ]
    loaded_extensions = [
        (cfg=cfg, mod=Base.get_extension(CTFlows, cfg.sym)) for
        cfg in extensions_config if !isnothing(Base.get_extension(CTFlows, cfg.sym))
    ]

    # ── Public pages: one flat page per submodule ─────────────────────────────
    # No external_modules_to_document here: submodules re-export some symbols at
    # the CTFlows level, and scanning CTFlows would document them a second time
    # (e.g. `hamiltonian_vector_field`), triggering a duplicate-docs error.
    pages = [
        CTBase.automatic_reference_documentation(;
            subdirectory="api",
            primary_modules=[cfg.mod => cfg.files],
            exclude=hasproperty(cfg, :exclude) ? cfg.exclude : EXCLUDE_SYMBOLS,
            public=true,
            private=false,
            title=cfg.title,
            title_in_menu=cfg.title,
            filename=cfg.filename,
        ) for cfg in modules_config
    ]

    # ── Public pages: one per loaded extension ────────────────────────────────
    for entry in loaded_extensions
        push!(
            pages,
            CTBase.automatic_reference_documentation(;
                subdirectory="api",
                primary_modules=[entry.mod => entry.cfg.files],
                external_modules_to_document=[CTFlows],
                exclude=EXCLUDE_SYMBOLS,
                public=true,
                private=false,
                title=entry.cfg.title,
                title_in_menu=entry.cfg.title_in_menu,
                filename=entry.cfg.filename,
            ),
        )
    end

    # ── Internals: all private symbols in one page, sections by module ────────
    internals_modules = Any[cfg.mod => cfg.files for cfg in modules_config]
    for entry in loaded_extensions
        push!(internals_modules, entry.mod => entry.cfg.files)
    end

    push!(
        pages,
        CTBase.automatic_reference_documentation(;
            subdirectory="api",
            primary_modules=internals_modules,
            exclude=EXCLUDE_INTERNALS,
            public=false,
            private=true,
            title="Internals",
            title_in_menu="Internals",
            filename="internals",
        ),
    )

    return pages
end

"""
    with_api_reference(f::Function, src_dir::String, ext_dir::String)

Generates the API reference, executes `f(pages)`, and cleans up generated files.
"""
function with_api_reference(f::Function, src_dir::String, ext_dir::String)
    pages = generate_api_reference(src_dir, ext_dir)
    try
        f(pages)
    finally
        docs_src = abspath(joinpath(@__DIR__, "src"))
        function cleanup(pages)
            for p in pages
                content = last(p)
                if content isa AbstractString
                    fname = endswith(content, ".md") ? content : content * ".md"
                    full_path = joinpath(docs_src, fname)
                    isfile(full_path) && rm(full_path)
                elseif content isa Vector
                    cleanup(content)
                end
            end
        end
        cleanup(pages)
    end
end
