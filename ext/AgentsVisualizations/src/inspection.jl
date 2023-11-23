##########################################################################################
# Agent inspection on mouse hover
#
# Note: This only works in combination with ABMPlot.
##########################################################################################

# 2D space
function Makie.show_data(inspector::DataInspector,
        p::ABMP{S}, idx, source::Scatter) where {S<:Agents.SpaceType}
    if p._used_poly[]
        return show_data_poly(inspector, p, idx, source)
    else
        return show_data_2D(inspector, p, idx, source)
    end
end

function show_data_2D(inspector::DataInspector,
        p::ABMP{S}, idx, source::Scatter) where {S<:Agents.AbstractSpace}
    pos = source.converted[1][][idx]
    proj_pos = Makie.shift_project(Makie.parent_scene(p), p, to_ndim(Point3f, pos, 0))
    Makie.update_tooltip_alignment!(inspector, proj_pos)

    model = p.abmobs[].model[]
    a = inspector.plot.attributes
    a.text[] = Agents.agent2string(model, convert_mouse_position(abmspace(model), pos))
    a.visible[] = true

    return true
end

function show_data_2D(inspector::DataInspector,
        p::ABMP{S}, idx, source::Scatter) where {S<:Nothing}
    pos = source.converted[1][][idx]
    proj_pos = Makie.shift_project(Makie.parent_scene(p), p, to_ndim(Point3f, pos, 0))
    Makie.update_tooltip_alignment!(inspector, proj_pos)

    model = p.abmobs[].model[]
    a = inspector.plot.attributes
    a.text[] = Agents.agent2string(model, p.pos[][idx]) # weird af special case
    a.visible[] = true

    return true
end

# TODO: Fix this tooltip
function show_data_poly(inspector::DataInspector,
        p::ABMP{S}, idx, ::Makie.Poly) where {S<:Agents.AbstractSpace}
    pos = source.converted[1][][idx]
    proj_pos = Makie.shift_project(Makie.parent_scene(p), p, to_ndim(Point3f, pos, 0))
    Makie.update_tooltip_alignment!(inspector, proj_pos)

    model = p.abmobs[].model[]
    a = inspector.plot.attributes
    a.text[] = Agents.agent2string(model, convert_mouse_position(abmspace(model), pos))
    a.visible[] = true

    return true
end

# 3D space
function Makie.show_data(inspector::DataInspector,
        p::ABMP{S}, idx, source::MeshScatter) where {S<:Agents.SpaceType}
    # need to dispatch here should we for example have 3D polys at some point
    return show_data_3D(inspector, p, idx, source)
end

function show_data_3D(inspector::DataInspector,
        p::ABMP{S}, idx, source::MeshScatter) where {S<:Agents.AbstractSpace}
    pos = source.converted[1][][idx]
    proj_pos = Makie.shift_project(Makie.parent_scene(p), p, to_ndim(Point3f, pos, 0))
    Makie.update_tooltip_alignment!(inspector, proj_pos)

    model = p.abmobs[].model[]
    a = inspector.plot.attributes
    a.text[] = Agents.agent2string(model, convert_mouse_position(abmspace(model), pos))
    a.visible[] = true

    return true
end

##########################################################################################
# Agent to string conversion
##########################################################################################

function Agents.agent2string(model::ABM, pos)
    ids = ids_to_inspect(model, pos)
    s = ""

    for (i, id) in enumerate(ids)
        if i > 1
            s *= "\n"
        end
        s *= Agents.agent2string(model[id])
    end

    return s
end

function Agents.agent2string(agent::A) where {A<:AbstractAgent}
    agentstring = "▶ $(nameof(A))\n"

    agentstring *= "id: $(getproperty(agent, :id))\n"

    if hasproperty(agent, :pos)
        pos = getproperty(agent, :pos)
        if pos isa Union{NTuple{<:Any, <:AbstractFloat},SVector{<:Any, <:AbstractFloat}}
            pos = round.(pos, sigdigits=2)
        elseif pos isa Tuple{<:Int, <:Int, <:AbstractFloat}
            pos = (pos[1], pos[2], round(pos[3], sigdigits=2))
        end
        agentstring *= "pos: $(pos)\n"
    end

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
