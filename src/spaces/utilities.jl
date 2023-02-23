export euclidean_distance, manhattan_distance, get_direction, normalize_position, walk!, spacesize

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
euclidean_distance(
    a::A,
    b::B,
    model::ABM{<:Union{ContinuousSpace,AbstractGridSpace}},
) where {A <: AbstractAgent,B <: AbstractAgent} = euclidean_distance(a.pos, b.pos, model)

function euclidean_distance(
    p1::ValidPos,
    p2::ValidPos,
    model::ABM{<:Union{ContinuousSpace{D,false},AbstractGridSpace{D,false}}},
) where {D}
    sqrt(sum(abs2.(p1 .- p2)))
end

function euclidean_distance(
    p1::ValidPos,
    p2::ValidPos,
    model::ABM{<:Union{ContinuousSpace{D,true},AbstractGridSpace{D,true}}},
) where {D}
    direct = abs.(p1 .- p2)
    sqrt(sum(min.(direct, spacesize(model) .- direct).^2))
end

"""
    manhattan_distance(a, b, model::ABM)

Return the manhattan distance between `a` and `b` (either agents or agent positions),
respecting periodic boundary conditions (if in use). Works with any space where it makes
sense: currently `AbstractGridSpace` and `ContinuousSpace`.
"""
manhattan_distance(
    a::A,
    b::B,
    model::ABM{<:Union{ContinuousSpace,AbstractGridSpace}},
) where {A <: AbstractAgent,B <: AbstractAgent} = manhattan_distance(a.pos, b.pos, model)

function manhattan_distance(
    p1::ValidPos,
    p2::ValidPos,
    model::ABM{<:Union{ContinuousSpace{D,false},AbstractGridSpace{D,false}}},
) where {D}
    sum(abs.(p1 .- p2))
end

function manhattan_distance(
    p1::ValidPos,
    p2::ValidPos,
    model::ABM{<:Union{ContinuousSpace{D,true},AbstractGridSpace{D,true}}}
) where {D}
    direct = abs.(p1 .- p2)
    sum(min.(direct, spacesize(model) .- direct))
end

"""
    get_direction(from, to, model::ABM)
Return the direction vector from the position `from` to position `to` taking into account
periodicity of the space.
"""
get_direction(from, to, model::ABM) = get_direction(from, to, model.space)
# Periodic spaces version
function get_direction(
    from::ValidPos,
    to::ValidPos,
    space::Union{ContinuousSpace{D,true},AbstractGridSpace{D,true}}
) where {D}
    direct_dir = to .- from
    inverse_dir = direct_dir .- sign.(direct_dir) .* spacesize(space)
    return map((x, y) -> argmin(abs, (x, y)), direct_dir, inverse_dir)
end

function get_direction(
    from::ValidPos, 
    to::ValidPos, 
    space::Union{AbstractGridSpace{D,false},ContinuousSpace{D,false}}
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
    neighbors = copy(nearby_positions(position, model; kwargs...))
    if radius == 1
        return neighbors
    end
    
    seen = Set{Int}(neighbors)
    push!(seen, position)
    k, n = 1, nv(model)
    for _ in 2:radius
        thislevel = @view neighbors[k:end]
        k = length(neighbors)
        if isempty(thislevel) || k == n
    	    return neighbors
    	end
    	for v in thislevel
    	    for w in nearby_positions(v, model; kwargs...)
    	        if w ∉ seen
    	            push!(neighbors, w)
    	            push!(seen, w)  
    	        end
    	    end
    	end
    end  
    return neighbors
end

#######################################################################################
# %% Walking
#######################################################################################
"""
    normalize_position(pos, model::ABM{<:Union{AbstractGridSpace,ContinuousSpace}})

Return the position `pos` normalized for the extents of the space of the given `model`.
For periodic spaces, this wraps the position along each dimension, while for non-periodic
spaces this clamps the position to the space extent.
"""
normalize_position(pos, model::ABM) = normalize_position(pos, model.space)

function normalize_position(pos, space::ContinuousSpace{D,true}) where {D}
    return mod.(pos, spacesize(space))
end

function normalize_position(pos, space::ContinuousSpace{D,false}) where {D}
    ss = spacesize(space)
    return Tuple(clamp.(pos, 0.0, prevfloat.(ss)))
end

function normalize_position(pos, space::AbstractGridSpace{D,true}) where {D}
    return mod1.(pos, spacesize(space))
end

function normalize_position(pos, space::AbstractGridSpace{D,false}) where {D}
    return Tuple(clamp.(pos, ones(Int, D), spacesize(space)))
end

"""
    walk!(agent, direction::NTuple, model; ifempty = true)

Move agent in the given `direction` respecting periodic boundary conditions.
For non-periodic spaces, agents will walk to, but not exceed the boundary value.
Available for both `AbstractGridSpace` and `ContinuousSpace`s.

The type of `direction` must be the same as the space position. `AbstractGridSpace` asks
for `Int`, and `ContinuousSpace` for `Float64` tuples, describing the walk distance in
each direction. `direction = (2, -3)` is an example of a valid direction on a
`AbstractGridSpace`, which moves the agent to the right 2 positions and down 3 positions.
Agent velocity is ignored for this operation in `ContinuousSpace`.

## Keywords
- `ifempty` will check that the target position is unoccupied and only move if that's true.
  Available only on `AbstractGridSpace`.

Example usage in [Battle Royale](
    https://juliadynamics.github.io/AgentsExampleZoo.jl/dev/examples/battle/).
"""
function walk!(
    agent::AbstractAgent,
    direction::NTuple{D,Int},
    model::ABM{<:AbstractGridSpace};
    ifempty::Bool = true
) where {D}
    target = normalize_position(agent.pos .+ direction, model)
    if !ifempty || isempty(ids_in_position(target, model))
        move_agent!(agent, target, model)
    end
end

function walk!(
    agent::AbstractAgent,
    direction::NTuple{D,Float64},
    model::ABM{<:ContinuousSpace}
) where {D}
    target = normalize_position(agent.pos .+ direction, model)
    move_agent!(agent, target, model)
end

"""
    walk!(agent, rand, model)

Invoke a random walk by providing the `rand` function in place of
`direction`. For `AbstractGridSpace`, the walk will cover ±1 positions in all directions,
`ContinuousSpace` will reside within [-1, 1].
"""
walk!(agent, ::typeof(rand), model::ABM{<:AbstractGridSpace{D}}; kwargs...) where {D} =
    walk!(agent, Tuple(rand(model.rng, -1:1, D)), model; kwargs...)

walk!(agent, ::typeof(rand), model::ABM{<:ContinuousSpace{D}}) where {D} =
    walk!(agent, Tuple(2.0 * rand(model.rng) - 1.0 for _ in 1:D), model)

"""
    spacesize(model::ABM)

Return the size of the model's space. Works for [`AbstractGridSpace`](@ref) and
[`ContinuousSpace`](@ref).
"""
spacesize(model::ABM) = spacesize(model.space)
