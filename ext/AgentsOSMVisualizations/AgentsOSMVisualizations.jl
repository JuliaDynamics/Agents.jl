module AgentsOSMVisualizations

using Agents, Makie, OSMMakie
const _ABMPlot = Agents.get_ABMPlot_type()

include("src/spaces/openstreetmap.jl")

# Change defaults
default_colors = OSMMakie.WAYTYPECOLORS
default_colors["primary"] = colorant"#a1777f"
default_colors["secondary"] = colorant"#a18f78"
default_colors["tertiary"] = colorant"#b3b381"

function Agents.osmplot!(ax::Axis, model::ABM; kwargs...)
    osm_plot = OSMMakie.osmplot!(ax, abmspace(model).map;
        graphplotkwargs = (; arrow_show = false), kwargs...
    )
    osm_plot.plots[1].plots[1].plots[1].inspectable[] = false
    osm_plot.plots[1].plots[3].inspectable[] = false
    return
end

end