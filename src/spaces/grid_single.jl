# This file defines the `GridSpaceSingle`. Notice that a lot of the space functionality
# comes from `AbstractGridSpace`, i.e., it is shared with `GridSpace`.
# This shared functionality is in the spaces/grid_general.jl file.
# The space also inherits a lot of discrete space functionality from spaces/discrete.jl.

# The way we make `GridSpaceSingle` faster is by having an array that directly
# stores IDs for each space position, and using ID=0 as an empty position.
export GridSpaceSingle

# type P stands for Periodic and is a boolean
struct GridSpaceSingle{D,P} <: AbstractGridSpace{D,P}
    stored_ids::Array{Int,D}
    metric::Symbol
    indices_within_radius::Dict{Float64,Vector{NTuple{D,Int}}}
    indices_within_radius_no_0::Dict{Float64,Vector{NTuple{D,Int}}}
end

"""
    GridSpaceSingle(d::NTuple{D, Int}; periodic = true, metric = :chebyshev)
This is a specialized version of [`GridSpace`](@ref) that allows only one
agent per position, and utilizes this knowledge to offer significant performance
gains versus [`GridSpace`](@ref).

This space **reserves agent ID = 0 for internal usage.** Agents should be initialized
with non-zero IDs, either positive or negative. This is not checked internally.

All arguments and keywords behave exactly as in [`GridSpace`](@ref).
"""
function GridSpaceSingle(d::NTuple{D,Int}; periodic = true, metric = :chebyshev) where {D}
    s = zeros(Int, d)
    return GridSpaceSingle{D,periodic}(s, metric,
        Dict{Float64,Vector{NTuple{D,Int}}}(), Dict{Float64,Vector{NTuple{D,Int}}}(),
    )
end
# Implementation of space API
function add_agent_to_space!(a::A, model::ABM{<:GridSpaceSingle,A}) where {A<:AbstractAgent}
    model.space.stored_ids[a.pos...] = a.id
    return a
end
function remove_agent_from_space!(a::A, model::ABM{<:GridSpaceSingle,A}) where {A<:AbstractAgent}
    model.space.stored_ids[a.pos...] = 0
    return a
end
# `random_position` comes from `AbstractGridSpace` in spaces/grid_general.jl
# move_agent! does not need be implemented.
# The generic version at core/space_interaction_API.jl covers it.
# `random_empty` comes from spaces/discrete.jl as long as we extend:
Base.isempty(pos, model::ABM{<:GridSpaceSingle}) = model.space.stored_ids[pos...] == 0
# And we also need to extend the iterator of empty positions
function empty_positions(model::ABM{<:GridSpaceSingle})
    Iterators.filter(i -> model.space.stored_ids[i...] == 0, positions(model))
end

#######################################################################################
# Implementation of nearby_stuff
#######################################################################################
# The following functions utilize the 1-agent-per-posiiton knowledge,
# hence giving faster nearby looping than `GridSpace`.
# Notice that the code here is a near duplication of `nearby_positions`
# defined in spaces/grid_general.jl. Unfortunately
# the duplication is necessary because `nearby_ids(pos, ...)` should in principle
# contain the id at the given `pos` as well.

function nearby_ids(pos::NTuple{D, Int}, model::ABM{<:GridSpaceSingle{D,true}}, r = 1;
    get_nearby_indices = indices_within_radius) where {D}
    nindices = get_nearby_indices(model, r)
    stored_ids = model.space.stored_ids
    space_size = size(stored_ids)
    array_accesses_iterator = (stored_ids[(mod1.(pos .+ β, space_size))...] for β in nindices)
    # Notice that not all positions are valid; some are empty! Need to filter:
    valid_pos_iterator = Base.Iterators.filter(x -> x ≠ 0, array_accesses_iterator)
    return valid_pos_iterator
end

function nearby_ids(pos::NTuple{D, Int}, model::ABM{<:GridSpaceSingle{D,false}}, r = 1;
    get_nearby_indices = indices_within_radius) where {D}
    nindices = get_nearby_indices(model, r)
    stored_ids = model.space.stored_ids
    positions_iterator = (pos .+ β for β in nindices)
    # Here we combine in one filtering step both valid accesses to the space array
    # but also that the accessed location is not empty (i.e., id is not 0)
    array_accesses_iterator = Base.Iterators.filter(
        pos -> checkbounds(Bool, stored_ids, pos...) && stored_ids[pos...] ≠ 0,
        positions_iterator
    )
    return (stored_ids[pos...] for pos in array_accesses_iterator)
end

# Contrary to `GridSpace`, we also extend here `nearby_ids(a::Agent)`.
# Because, we know that one agent exists per position, and hence we can skip the
# call to `filter(id -> id ≠ a.id, ...)` that happens in core/space_interaction_API.jl.
# Here we implement a new version for neighborhoods, similar to abusive_unkillable.jl.
# The extension uses the function `indices_within_radius_no_0` from spaces/grid_general.jl
function nearby_ids(
    a::A, model::ABM{<:GridSpaceSingle{D,false},A}, r = 1) where {D,A<:AbstractAgent}
    return nearby_ids(a.pos, model, r; get_nearby_indices = indices_within_radius_no_0)
end
