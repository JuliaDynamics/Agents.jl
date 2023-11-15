##########################################################################################
# Agent inspection on mouse hover
#
# Note: This only works in combination with ABMPlot.
##########################################################################################

# 2D space
function Makie.show_data(inspector::DataInspector,
            plot::_ABMPlot{<:Tuple{<:ABMObservable{<:Observable{<:ABM{<:S}}}}},
            idx, source::Scatter) where {S}
    if plot._used_poly[]
        return show_data_poly(inspector, plot, idx, source)
    else
        return show_data_2D(inspector, plot, idx, source)
    end
end

function show_data_2D(inspector::DataInspector,
            plot::_ABMPlot{<:Tuple{<:ABMObservable{<:Observable{<:ABM{<:S}}}}},
            idx, source::Scatter) where {S}
    a = inspector.plot.attributes
    scene = Makie.parent_scene(plot)

    pos = source.converted[1][][idx]
    proj_pos = Makie.shift_project(scene, plot, to_ndim(Point3f, pos, 0))
    Makie.update_tooltip_alignment!(inspector, proj_pos)
    size = source.markersize[] isa Vector ? source.markersize[][idx] : source.markersize[]

    model = plot.abmobs[].model[]
    id = collect(allids(model))[idx]
    a.text[] = Agents.agent2string(model, model[id].pos)
    a.visible[] = true

    return true
end

# TODO: Fix this tooltip
function show_data_poly(inspector::DataInspector,
            plot::_ABMPlot{<:Tuple{<:ABMObservable{<:Observable{<:ABM{<:S}}}}},
            idx, ::Makie.Poly) where {S}
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
    a.text[] = Agents.agent2string(plot.abmobs[].model[], agent_pos)
    a.visible[] = true

    return true
end

# 3D space
function Makie.show_data(inspector::DataInspector, plot::_ABMPlot{<:Tuple{<:ABMObservable}},
            idx, source::MeshScatter)
    # need to dispatch here should we for example have 3D polys at some point
    return show_data_3D(inspector, plot, idx, source)
end

function show_data_3D(inspector::DataInspector, plot::_ABMPlot{<:Tuple{<:ABMObservable}},
            idx, source::MeshScatter)
    a = inspector.plot.attributes
    scene = Makie.parent_scene(plot)

    pos = source.converted[1][][idx]
    proj_pos = Makie.shift_project(scene, plot, to_ndim(Point3f, pos, 0))
    Makie.update_tooltip_alignment!(inspector, proj_pos)
    size = source.markersize[] isa Vector ? source.markersize[][idx] : source.markersize[]

    model = plot.abmobs[].model[]
    id = collect(allids(model))[idx]
    a.text[] = Agents.agent2string(model, model[id].pos)
    a.visible[] = true

    return true
end

##########################################################################################
# Agent to string conversion
##########################################################################################

function Agents.agent2string(model::ABM, agent_pos)
    ids = ids_to_inspect(model, agent_pos)
    s = ""

    for id in ids
        s *= Agents.agent2string(model[id]) * "\n"
    end

    return s
end

Agents.ids_to_inspect(model::ABM, agent_pos) = []

function Agents.agent2string(agent::A) where {A<:AbstractAgent}
    agentstring = "▶ $(nameof(A))\n"

    agentstring *= "id: $(getproperty(agent, :id))\n"

    agent_pos = getproperty(agent, :pos)
    if agent_pos isa Union{NTuple{<:Any, <:AbstractFloat},SVector{<:Any, <:AbstractFloat}}
        agent_pos = round.(agent_pos, sigdigits=2)
    elseif agent_pos isa Tuple{<:Int, <:Int, <:AbstractFloat}
        agent_pos = (agent_pos[1], agent_pos[2], round(agent_pos[3], sigdigits=2))
    end
    agentstring *= "pos: $(agent_pos)\n"

    for field in fieldnames(A)[3:end]
        val = getproperty(agent, field)
        if val isa AbstractFloat
            val = round(val, sigdigits=2)
        elseif val isa AbstractArray{<:AbstractFloat}
            val = round.(val, sigdigits=2)
        elseif val isa NTuple{<:Any, <:AbstractFloat}
            val = round.(val, sigdigits=2)
        end
        agentstring *= "$(field): $val\n"
    end

    return agentstring
end
