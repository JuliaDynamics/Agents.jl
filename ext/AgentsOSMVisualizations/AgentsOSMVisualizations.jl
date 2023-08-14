module AgentsOSMVisualizations

using Agents, OSMMakie
using OSMMakie.Makie: Axis, @colorant_str

# Change defaults
default_colors = OSMMakie.WAYTYPECOLORS
default_colors["primary"] = colorant"#a1777f"
default_colors["secondary"] = colorant"#a18f78"
default_colors["tertiary"] = colorant"#b3b381"

function Agents.agents_osmplot!(ax::Axis, model::ABM; kwargs...)
    osm_plot = OSMMakie.osmplot!(ax, abmspace(model).map;
        graphplotkwargs = (; arrow_show = false), kwargs...
    )
    osm_plot.plots[1].plots[1].plots[1].inspectable[] = false
    osm_plot.plots[1].plots[3].inspectable[] = false
    return
end


end