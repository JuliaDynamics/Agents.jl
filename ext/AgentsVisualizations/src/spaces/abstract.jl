Agents.agents_space_dimensionality(model::ABM) = 
    Agents.agents_space_dimensionality(abmspace(model))

"Plot agents into a 2D space."
function Agents.agentsplot!(ax::Axis, model::ABM, p::_ABMPlot)
    if p._used_poly[]
        poly!(p, p.marker; p.color, p.agentsplotkwargs...)
    else
        scatter!(p, p.pos; p.color, p.marker, p.markersize, p.agentsplotkwargs...)
    end
    return p
end

"Plot agents into a 3D space."
function Agents.agentsplot!(ax::Axis3, model::ABM, p::_ABMPlot)
    p.marker[] == :circle && (p.marker[] = Sphere(Point3f(0), 1))
    meshscatter!(p, p.pos; p.color, p.marker, p.markersize, p.agentsplotkwargs...)
    return p
end

## Preplots

Agents.spaceplot!(ax::Axis, model::ABM; spaceplotkwargs...) = nothing
Agents.spaceplot!(ax::Axis3, model::ABM; spaceplotkwargs...) = nothing

function Agents.static_preplot!(ax::Axis, model::ABM, p::_ABMPlot)
    hasproperty(p, :static_preplot!) && return old_static_preplot!(ax, model, p)
    return nothing
end

function Agents.static_preplot!(ax::Axis3, model::ABM, p::_ABMPlot)
    hasproperty(p, :static_preplot!) && return old_static_preplot!(ax, model, p)
    return nothing
end

function old_static_preplot!(ax, model, p)
    @warn "Usage of the static_preplot! kwarg is deprecated. " *
        "Please remove it from the call to abmplot and define a custom method for " *
        "Agents.static_preplot!(ax, model, p) instead."
    return p.static_preplot![](ax, model)
end

## Lifting

function Agents.abmplot_heatobs(model::ABM, heatarray)
    isnothing(heatarray) && return nothing
    # TODO: use surface!(heatobs) here?
    matrix = Agents.get_data(model, heatarray, identity)
    return matrix
end

Agents.abmplot_ids(model::ABM) = allids(model)

function Agents.abmplot_pos(model::ABM, offset, ids)
    postype = agents_space_dimensionality(abmspace(model)) == 3 ? Point3f : Point2f
    if isnothing(offset)
        return [postype(model[i].pos) for i in ids]
    else
        return [postype(model[i].pos .+ offset(model[i])) for i in ids]
    end
end

Agents.abmplot_colors(model::ABM, ac, ids) = to_color(ac)
Agents.abmplot_colors(model::ABM, ac::Function, ids) =
    to_color.([ac(model[i]) for i in ids])

function Agents.abmplot_markers(model::ABM, used_poly, am, pos, ids)
    marker = am
    # need to update used_poly Observable here for inspection
    used_poly[] = user_used_polygons(am, marker)
    if used_poly[] # for polygons we always need vector, even if all agents are same polygon
        marker = [translate(am, p) for p in pos]
    end
    return marker
end

function Agents.abmplot_markers(model::ABM, used_poly, am::Function, pos, ids)
    marker = [am(model[i]) for i in ids]
    # need to update used_poly Observable here for use with inspection
    used_poly[] = user_used_polygons(am, marker)
    if used_poly[]
        marker = [translate_polygon(m, p) for (m, p) in zip(marker, pos)]
    end
    return marker
end

user_used_polygons(am, marker) = false
user_used_polygons(am::Makie.Polygon, marker) = true
user_used_polygons(am::Function, marker::Vector{<:Makie.Polygon}) = true

Agents.abmplot_markersizes(model::ABM, as, ids) = as
Agents.abmplot_markersizes(model::ABM, as::Function, ids) =
    [as(model[i]) for i in ids]

## Inspection

# 2D space
function Makie.show_data(inspector::DataInspector, 
        p::ABMP{<:Agents.AbstractSpace}, idx, source::Scatter)
    pos = source.converted[1][][idx]
    proj_pos = Makie.shift_project(Makie.parent_scene(p), p, to_ndim(Point3f, pos, 0))
    Makie.update_tooltip_alignment!(inspector, proj_pos)

    model = p.abmobs[].model[]
    a = inspector.plot.attributes
    a.text[] = Agents.agent2string(model, convert_mouse_position(abmspace(model), pos))
    a.visible[] = true

    return true
end

# Polygon plots
function Makie.show_data(inspector::DataInspector,
        p::ABMP{<:Agents.AbstractSpace}, idx, source::Makie.Mesh)
    # poly plots with multiple elements don't seem to allow inspection per element but only
    # for the whole block of poly elements which is really not what we want
    # using the current mouseposition on the scene when hovering a Mesh (i.e. an agent)
    # allows us to search for nearby_ids to that position and use them for the tooltip
    # FIXME this still pulls in too many agents sometimes...
    pos = mouseposition(p)
    proj_pos = Point2f0(mouseposition_px(inspector.root))
    Makie.update_tooltip_alignment!(inspector, proj_pos)

    model = p.abmobs[].model[]
    a = inspector.plot.attributes
    a.text[] = Agents.agent2string(model, convert_mouse_position(abmspace(model), pos))
    a.visible[] = true

    return true
end

# 3D space
function Makie.show_data(inspector::DataInspector,
        p::ABMP{<:Agents.AbstractSpace}, idx, source::MeshScatter)
    pos = source.converted[1][][idx]
    proj_pos = Makie.shift_project(Makie.parent_scene(p), p, to_ndim(Point3f, pos, 0))
    Makie.update_tooltip_alignment!(inspector, proj_pos)

    model = p.abmobs[].model[]
    a = inspector.plot.attributes
    a.text[] = Agents.agent2string(model, convert_mouse_position(abmspace(model), pos))
    a.visible[] = true

    return true
end

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

Agents.convert_mouse_position(::S, pos) where {S<:Agents.AbstractSpace} = Tuple(pos)

Agents.ids_to_inspect(model::ABM, pos) = ids_in_position(pos, model)
