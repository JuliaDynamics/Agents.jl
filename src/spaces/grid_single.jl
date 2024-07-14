# This file defines the `GridSpaceSingle`. Notice that a lot of the space functionality
# comes from `AbstractGridSpace`, i.e., it is shared with `GridSpace`.
# This shared functionality is in the spaces/grid_general.jl file.
# The space also inherits a lot of discrete space functionality from spaces/discrete.jl.

# The way we make `GridSpaceSingle` faster is by having an array that directly
# stores IDs for each space position, and using ID=0 as an empty position.
export GridSpaceSingle, id_in_position

# type P stands for Periodic and is a boolean
struct GridSpaceSingle{D,P} <: AbstractGridSpace{D,P}
    stored_ids::Array{Int,D}
    extent::NTuple{D,Int}
    metric::Symbol
    offsets_at_radius::Vector{Vector{NTuple{D,Int}}}
    offsets_within_radius::Vector{Vector{NTuple{D,Int}}}
    offsets_within_radius_no_0::Vector{Vector{NTuple{D,Int}}}
end
spacesize(space::GridSpaceSingle) = space.extent

"""
    GridSpaceSingle(d::NTuple{D, Int}; periodic = true, metric = :chebyshev)

This is a specialized version of [`GridSpace`](@ref) that allows only one
agent per position, and utilizes this knowledge to offer significant performance
gains versus [`GridSpace`](@ref).

This space **reserves agent ID = 0 for internal usage.** Agents should be initialized
with non-zero IDs, either positive or negative. This is not checked internally.

All arguments and keywords behave exactly as in [`GridSpace`](@ref).
"""
function GridSpaceSingle(d::NTuple{D,Int};
        periodic::Union{Bool,NTuple{D,Bool}} = true,
        metric = :chebyshev
    ) where {D}
    s = zeros(Int, d)
    return GridSpaceSingle{D,periodic}(s, d, metric,
        Vector{Vector{NTuple{D,Int}}}(),
        Vector{Vector{NTuple{D,Int}}}(),
        Vector{Vector{NTuple{D,Int}}}(),
    )
end
# Implementation of space API
function add_agent_to_space!(a::AbstractAgent, model::ABM{<:GridSpaceSingle})
    pos = a.pos
    !isempty(pos, model) && error(lazy"Cannot add agent $(a) to occupied position $(pos)")
    abmspace(model).stored_ids[pos...] = a.id
    return a
end

function remove_agent_from_space!(a::AbstractAgent, model::ABM{<:GridSpaceSingle})
    abmspace(model).stored_ids[a.pos...] = 0
    return a
end

# `random_position` comes from `AbstractGridSpace` in spaces/grid_general.jl
# move_agent! does not need be implemented.
# The generic version at core/space_interaction_API.jl covers it.
# `random_empty` comes from spaces/discrete.jl as long as we extend:
Base.isempty(pos::ValidPos, model::ABM{<:GridSpaceSingle}) = abmspace(model).stored_ids[pos...] == 0
# And we also need to extend the iterator of empty positions
function empty_positions(model::ABM{<:GridSpaceSingle})
    Iterators.filter(i -> abmspace(model).stored_ids[i...] == 0, positions(model))
end

"""
    id_in_position(pos, model::ABM{<:GridSpaceSingle}) → id

Return the agent ID in the given position.
This will be `0` if there is no agent in this position.

This is similar to [`ids_in_position`](@ref), but specialized for `GridSpaceSingle`.
See also [`isempty`](@ref).
"""
function id_in_position(pos, model::ABM{<:GridSpaceSingle})
    return abmspace(model).stored_ids[pos...]
end

#######################################################################################
# Implementation of nearby_stuff
#######################################################################################
# The following functions utilize the 1-agent-per-position knowledge,
# hence giving faster nearby looping than `GridSpace`.
# Notice that the code here is a near duplication of `nearby_positions`
# defined in spaces/grid_general.jl. Unfortunately
# the duplication is necessary because `nearby_ids(pos, ...)` should in principle
# contain the id at the given `pos` as well.

function nearby_ids(pos::NTuple{D, Int}, model::ABM{<:GridSpaceSingle{D,true}}, r = 1,
        get_offset_indices = offsets_within_radius # internal, see last function
    ) where {D}
    nindices = get_offset_indices(model, r)
    stored_ids = abmspace(model).stored_ids
    space_size = spacesize(model)
    position_iterator = (pos .+ β for β in nindices)
    # check if we are far from the wall to skip bounds checks
    if all(i -> r < pos[i] <= space_size[i] - r, 1:D)
        ids_iterator = (stored_ids[p...] for p in position_iterator
                        if stored_ids[p...] != 0)
    else
        ids_iterator = (checkbounds(Bool, stored_ids, p...) ?
                        stored_ids[p...] : stored_ids[mod1.(p, space_size)...]
                        for p in position_iterator if stored_ids[mod1.(p, space_size)...] != 0)
    end
    return ids_iterator
end

function nearby_ids(pos::NTuple{D, Int}, model::ABM{<:GridSpaceSingle{D,false}}, r = 1,
        get_offset_indices = offsets_within_radius # internal, see last function
    ) where {D}
    nindices = get_offset_indices(model, r)
    stored_ids = abmspace(model).stored_ids
    space_size = spacesize(model)
    position_iterator = (pos .+ β for β in nindices)
    # check if we are far from the wall to skip bounds checks
    if all(i -> r < pos[i] <= space_size[i] - r, 1:D)
        ids_iterator = (stored_ids[p...] for p in position_iterator
                        if stored_ids[p...] != 0)
    else
        ids_iterator = (stored_ids[p...] for p in position_iterator
                        if checkbounds(Bool, stored_ids, p...) && stored_ids[p...] != 0)
    end
    return ids_iterator
end

function nearby_ids(pos::NTuple{D, Int}, model::ABM{<:GridSpaceSingle{D,P}}, r = 1,
        get_offset_indices = offsets_within_radius # internal, see last function
    ) where {D,P}
    nindices = get_offset_indices(model, r)
    stored_ids = abmspace(model).stored_ids
    space_size = size(stored_ids)
    position_iterator = (pos .+ β for β in nindices)
    # check if we are far from the wall to skip bounds checks
    if all(i -> r < pos[i] <= space_size[i] - r, 1:D)
        ids_iterator = (stored_ids[p...] for p in position_iterator
                        if stored_ids[p...] != 0)
    else
        ids_iterator = (
            checkbounds(Bool, stored_ids, p...) ?
            stored_ids[p...] : stored_ids[mod1.(p, space_size)...]
            for p in position_iterator
            if stored_ids[mod1.(p, space_size)...] != 0 &&
            all(P[i] || checkbounds(Bool, axes(stored_ids, i), p[i]) for i in 1:D)
        )
    end
    return ids_iterator
end

# Contrary to `GridSpace`, we also extend here `nearby_ids(a::Agent)`.
# Because, we know that one agent exists per position, and hence we can skip the
# call to `filter(id -> id ≠ a.id, ...)` that happens in core/space_interaction_API.jl.
# Here we implement a new version for neighborhoods, similar to abusive_unremovable.jl.
# The extension uses the function `offsets_within_radius_no_0` from spaces/grid_general.jl
function nearby_ids(
    a::AbstractAgent, model::ABM{<:GridSpaceSingle}, r = 1)
    return nearby_ids(a.pos, model, r, offsets_within_radius_no_0)
end

function remove_all_from_space!(model::ABM{<:GridSpaceSingle})
    for p in positions(model)
        abmspace(model).stored_ids[p...] = 0
    end
end