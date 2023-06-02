##########################################################################################
# Agent inspection on mouse hover
#
# Note: This only works in combination with ABMPlot.
##########################################################################################

# 2D space
function Makie.show_data(inspector::DataInspector,
            plot::_ABMPlot{<:Tuple{<:ABMObservable{<:ABM{<:S}}}},
            idx, source::Scatter) where {S<:SUPPORTED_SPACES}
    if plot._used_poly[]
        return show_data_poly(inspector, plot, idx, source)
    else
        return show_data_2D(inspector, plot, idx, source)
    end
end

function show_data_2D(inspector::DataInspector,
            plot::_ABMPlot{<:Tuple{<:ABMObservable{<:ABM{<:S}}}},
            idx, source::Scatter) where {S<:SUPPORTED_SPACES}
    a = inspector.plot.attributes
    scene = Makie.parent_scene(plot)

    pos = source.converted[1][][idx]
    proj_pos = Makie.shift_project(scene, plot, to_ndim(Point3f, pos, 0))
    Makie.update_tooltip_alignment!(inspector, proj_pos)
    size = source.markersize[] isa Vector ? source.markersize[][idx] : source.markersize[]

    model = plot.abmobs[].model[]
    id = collect(allids(model))[idx]
    a.text[] = agent2string(model, model[id].pos)
    a.visible[] = true

    return true
end

# TODO: Fix this tooltip
function show_data_poly(inspector::DataInspector,
            plot::_ABMPlot{<:Tuple{<:ABMObservable{<:ABM{<:S}}}},
            idx, ::Makie.Poly) where {S<:SUPPORTED_SPACES}
    a = inspector.plot.attributes
    scene = Makie.parent_scene(plot)

    proj_pos = Makie.shift_project(scene, plot, to_ndim(Point3f, plot[:pos][][idx], 0))
    Makie.update_tooltip_alignment!(inspector, proj_pos)
    sizes = plot.sizes[]

    if S <: ContinuousSpace
        agent_pos = Tuple(plot[:pos][][idx])
    elseif S <: GridSpace
        agent_pos = Tuple(Int.(plot[:pos][][idx]))
    end
    a.text[] = agent2string(plot.abmobs[].model[], agent_pos)
    a.visible[] = true

    return true
end

# 3D space
function Makie.show_data(inspector::DataInspector,
            plot::_ABMPlot{<:Tuple{<:ABMObservable{<:ABM{<:SUPPORTED_SPACES}}}},
            idx, source::MeshScatter)
    # need to dispatch here should we for example have 3D polys at some point
    return show_data_3D(inspector, plot, idx, source)
end

function show_data_3D(inspector::DataInspector,
            plot::_ABMPlot{<:ABMObservable{<:Tuple{<:ABM{<:S}}}},
            idx, source::MeshScatter) where {S<:SUPPORTED_SPACES}
    a = inspector.plot.attributes
    scene = Makie.parent_scene(plot)

    pos = source.converted[1][][idx]
    proj_pos = Makie.shift_project(scene, plot, to_ndim(Point3f, pos, 0))
    Makie.update_tooltip_alignment!(inspector, proj_pos)
    size = source.markersize[] isa Vector ? source.markersize[][idx] : source.markersize[]

    model = plot.abmobs[].model[]
    id = collect(allids(model))[idx]
    a.text[] = agent2string(model, model[id].pos)
    a.visible[] = true

    return true
end

##########################################################################################
# Agent to string conversion
##########################################################################################

function agent2string(model::ABM{<:S}, agent_pos) where {S<:SUPPORTED_SPACES}
    ids = ids_to_inspect(model, agent_pos)
    s = ""

    for id in ids
        s *= agent2string(model[id]) * "\n"
    end

    return s
end

ids_to_inspect(model::ABM{<:AbstractGridSpace}, agent_pos) =
    ids_in_position(agent_pos, model)
function ids_to_inspect(model::ABM{<:GridSpaceSingle}, agent_pos)
    id = id_in_position(agent_pos, model)
    if id == 0
        return ()
    else
        return (id,)
    end
end

ids_to_inspect(model::ABM{<:ContinuousSpace}, agent_pos) =
    nearby_ids(agent_pos, model, 0.0)
ids_to_inspect(model::ABM{<:OpenStreetMapSpace}, agent_pos) =
    nearby_ids(agent_pos, model, 0.0)
ids_to_inspect(model::ABM{<:GraphSpace}, agent_pos) =
    model.space.stored_ids[agent_pos]
ids_to_inspect(model::ABM, agent_pos) = []

"""
    agent2string(agent::A)
Convert agent data into a string which is used to display all agent variables and their
values in the tooltip on mouse hover. Concatenates strings if there are multiple agents
at one position.
Custom tooltips for agents can be implemented by adding a specialised method
for `agent2string`.
Example:
```julia
function InteractiveDynamics.agent2string(agent::SpecialAgent)
    \"\"\"
    ✨ SpecialAgent ✨
    ID = \$(agent.id)
    Main weapon = \$(agent.charisma)
    Side weapon = \$(agent.pistol)
    \"\"\"
end
```
"""
function agent2string(agent::A) where {A<:AbstractAgent}
    agentstring = "▶ $(nameof(A))\n"

    agentstring *= "id: $(getproperty(agent, :id))\n"

    agent_pos = getproperty(agent, :pos)
    if agent_pos isa NTuple{<:Any, <:AbstractFloat}
        agent_pos = round.(agent_pos, sigdigits=2)
    end
    agentstring *= "pos: $(agent_pos)\n"

    for field in fieldnames(A)[3:end]
        val = getproperty(agent, field)
        V = typeof(val)
        if V <: AbstractFloat
            val = round(val, sigdigits=2)
        elseif V <: AbstractArray{<:AbstractFloat}
            val = round.(val, sigdigits=2)
        elseif V <: NTuple{<:Any, <:AbstractFloat}
            val = round.(val, sigdigits=2)
        end
        agentstring *= "$(field): $val\n"
    end

    return agentstring
end
