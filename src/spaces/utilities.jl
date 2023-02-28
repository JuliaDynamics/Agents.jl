export euclidean_distance, manhattan_distance, get_direction, spacesize


"""
    spacesize(model::ABM)

Return the size of the model's space. Works for [`AbstractGridSpace`](@ref) and
[`ContinuousSpace`](@ref).
"""
spacesize(model::ABM) = spacesize(abmspace(model))

#######################################################################################
# %% Distances and directions in Grid/Continuous space
#######################################################################################
"""
    euclidean_distance(a, b, model::ABM)

Return the euclidean distance between `a` and `b` (either agents or agent positions),
respecting periodic boundary conditions (if in use). Works with any space where it makes
sense: currently `AbstractGridSpace` and `ContinuousSpace`.

Example usage in the [Flocking model](@ref).
"""
euclidean_distance(a::A, b::B, model::ABM,
) where {A <: AbstractAgent,B <: AbstractAgent} = euclidean_distance(a.pos, b.pos, model.space)

euclidean_distance(p1, p2, model::ABM) = euclidean_distance(p1, p2, model.space)

function euclidean_distance(
    p1::ValidPos,
    p2::ValidPos,
    space::Union{ContinuousSpace{D,false},AbstractGridSpace{D,false}},
) where {D}
    sqrt(sum(abs2.(p1 .- p2)))
end

function euclidean_distance(
    p1::ValidPos,
    p2::ValidPos,
    space::Union{ContinuousSpace{D,true},AbstractGridSpace{D,true}},
) where {D}
    direct = abs.(p1 .- p2)
    sqrt(sum(min.(direct, spacesize(space) .- direct).^2))
end

"""
    manhattan_distance(a, b, model::ABM)

Return the manhattan distance between `a` and `b` (either agents or agent positions),
respecting periodic boundary conditions (if in use). Works with any space where it makes
sense: currently `AbstractGridSpace` and `ContinuousSpace`.
"""
manhattan_distance(a::A, b::B, model::ABM
) where {A <: AbstractAgent,B <: AbstractAgent} = manhattan_distance(a.pos, b.pos, model.space)

manhattan_distance(p1, p2, model::ABM) = euclidean_distance(p1, p2, model.space)

function manhattan_distance(
    p1::ValidPos,
    p2::ValidPos,
    space::Union{ContinuousSpace{D,false},AbstractGridSpace{D,false}},
) where {D}
    sum(abs.(p1 .- p2))
end

function manhattan_distance(
    p1::ValidPos,
    p2::ValidPos,
    space::Union{ContinuousSpace{D,true},AbstractGridSpace{D,true}}
) where {D}
    direct = abs.(p1 .- p2)
    sum(min.(direct, spacesize(space) .- direct))
end

"""
    get_direction(from, to, model::ABM)
Return the direction vector from the position `from` to position `to` taking into account
periodicity of the space.
"""
get_direction(from, to, model::ABM) = get_direction(from, to, model.space)

function get_direction(
    from::ValidPos,
    to::ValidPos,
    space::Union{ContinuousSpace{D,true},AbstractGridSpace{D,true}},
) where {D}
    direct_dir = to .- from
    inverse_dir = direct_dir .- sign.(direct_dir) .* spacesize(space)
    return map((x, y) -> argmin(abs, (x, y)), direct_dir, inverse_dir)
end

function get_direction(
    from::ValidPos,
    to::ValidPos,
    space::Union{AbstractGridSpace{D,false},ContinuousSpace{D,false}},
) where {D}
    return to .- from
end

#######################################################################################
# %% Utilities for graph-based spaces (Graph/OpenStreetMap)
#######################################################################################
GraphBasedSpace = Union{GraphSpace,OpenStreetMapSpace}
_get_graph(space::GraphSpace) = space.graph
_get_graph(space::OpenStreetMapSpace) = space.map.graph
"""
    nv(model::ABM)
Return the number of positions (vertices) in the `model` space.
"""
Graphs.nv(abm::ABM{<:GraphBasedSpace}) = Graphs.nv(_get_graph(abm.space))

"""
    ne(model::ABM)
Return the number of edges in the `model` space.
"""
Graphs.ne(abm::ABM{<:GraphBasedSpace}) = Graphs.ne(_get_graph(abm.space))

positions(model::ABM{<:GraphBasedSpace}) = 1:nv(model)

function nearby_positions(
    position::Integer,
    model::ABM{<:GraphBasedSpace},
    radius::Integer;
    kwargs...,
)
    nearby = copy(nearby_positions(position, model; kwargs...))
    radius == 1 && return nearby
    seen = Set{Int}(nearby)
    push!(seen, position)
    k, n = 0, nv(model)
    for _ in 2:radius
        thislevel = @view nearby[k+1:end]
        isempty(thislevel) && return nearby
        k = length(nearby)
        k == n && return nearby
    	for v in thislevel
    	    for w in nearby_positions(v, model; kwargs...)
    	        if w ∉ seen
    	            push!(seen, w)
    	            push!(nearby, w)
    	        end
    	    end
    	end
    end
    return nearby
end


