# ==============================================================================
# CTFlows API Reference Manager
#
# Generates API reference pages via CTBase.automatic_reference_documentation,
# one section per CTFlows submodule. Generated .md files are cleaned up after
# the build.
# ==============================================================================

"""
    generate_api_reference(src_dir::String, ext_dir::String)

Generate the API reference documentation for CTFlows.
Returns the list of pages.
"""
function generate_api_reference(src_dir::String, ext_dir::String)
    src(files...) = [abspath(joinpath(src_dir, f)) for f in files]

    EXCLUDE_SYMBOLS = Symbol[:include, :eval]

    pages = [
        # ───────────────────────────────────────────────────────────────────
        # Common
        # ───────────────────────────────────────────────────────────────────
        CTBase.automatic_reference_documentation(;
            subdirectory=".",
            primary_modules=[
                CTFlows.Common => src(
                    joinpath("Common", "Common.jl"),
                    joinpath("Common", "abstract_tag.jl"),
                    joinpath("Common", "configs.jl"),
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
        # Systems
        # ───────────────────────────────────────────────────────────────────
        CTBase.automatic_reference_documentation(;
            subdirectory=".",
            primary_modules=[
                CTFlows.Systems => src(
                    joinpath("Systems", "Systems.jl"),
                    joinpath("Systems", "abstract_system.jl"),
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
            subdirectory=".",
            primary_modules=[
                CTFlows.Integrators => src(
                    joinpath("Integrators", "Integrators.jl"),
                    joinpath("Integrators", "abstract_ode_integrator.jl"),
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
            subdirectory=".",
            primary_modules=[
                CTFlows.Flows => src(
                    joinpath("Flows", "Flows.jl"),
                    joinpath("Flows", "abstract_flow.jl"),
                    joinpath("Flows", "flow.jl"),
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
        # Pipelines
        # ───────────────────────────────────────────────────────────────────
        CTBase.automatic_reference_documentation(;
            subdirectory=".",
            primary_modules=[
                CTFlows.Pipelines => src(
                    joinpath("Pipelines", "Pipelines.jl"),
                    joinpath("Pipelines", "build_system.jl"),
                    joinpath("Pipelines", "build_flow.jl"),
                    joinpath("Pipelines", "flow_constructor.jl"),
                    joinpath("Pipelines", "solve.jl"),
                ),
            ],
            exclude=EXCLUDE_SYMBOLS,
            public=true,
            private=true,
            title="Pipelines",
            title_in_menu="Pipelines",
            filename="api_pipelines",
        ),
    ]

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
