export GridSpaceSingle

struct GridSpaceSingle{D,P} <: AbstractGridSpace{D,P}
    s::Array{Int,D}
    metric::Symbol
    neighboring_indices::Dict{Float64,Vector{NTuple{D,Int}}}
    neighboring_indices_no_0::Dict{Float64,Vector{NTuple{D,Int}}}
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

function add_agent_to_space!(a::A, model::ABM{<:GridSpaceSingle,A}) where {A<:AbstractAgent}
    model.space.s[a.pos...] = a.id
    return a
end
function remove_agent_from_space!(a::A, model::ABM{<:GridSpaceSingle,A}) where {A<:AbstractAgent}
    model.space.s[a.pos...] = 0
    return a
end
# `random_position` comes from `AbstractGridSpace` in spaces/grid.jl
# move_agent! does not need be implemented.
# The generic version at core/space_interaction_API.jl covers it.
# `random_empty` also comes from spaces_discrete.jl as long as we extend:
Base.isempty(pos, model::ABM{<:GridSpaceSingle}) = model.space.s[pos...] == 0

# Here we implement a new version for neighborhoods, similar to abusive_unkillable.jl.
indices_within_radius(model::ABM, r::Real) = indices_within_radius(model.space, r::Real)
indices_within_radius_no_0(model::ABM, r::Real) = indices_within_radius_no_0(model.space, r::Real)
function indices_within_radius(space::GridSpaceSingle{D}, r::Real)::Vector{NTuple{D, Int}} where {D}
    if haskey(space.neighboring_indices, r)
        space.neighboring_indices[r]
    else
        βs = initialize_neighborhood(space, r)
        space.neighboring_indices[float(r)] = βs
    end
    return nindices
end
function indices_within_radius_no_0(space::GridSpaceSingle{D}, r::Real)::Vector{NTuple{D, Int}} where {D}
    if haskey(space.neighboring_indices_no_0, r)
        space.neighboring_indices_no_0[r]
    else
        βs = initialize_neighborhood(space, r)
        z = ntuple(i -> 0, Val{D}())
        filter!(x -> x ≠ z, βs)
        space.neighboring_indices_no_0[float(r)] = βs
    end
end

@inline function indices_within_radius_no_origin(
    space::GridSpaceSingle{D}, r::Real)::Vector{NTuple{D, Int}} where {D}
    dict = space.neighboring_indices_no_origin
    if haskey(dict, r)
        nindices = dict[r]
    else
        nindices = init_neighborhood(space, r)
        zero_pos = ntuple(x -> 0, Val{D}())
        filter!(x -> x ≠ zero_pos, nindices)
        dict[r] = nindices
    end
    return nindices
end

# Make grid space Abstract if indeed faster
function initialize_neighborhood(space::GridSpaceSingle{D}, r::Real) where {D}
    r0 = floor(Int, r)
    if space.metric == :euclidean
        # hypercube of indices
        hypercube = CartesianIndices((repeat([(-r0):r0], D)...,))
        # select subset of hc which is in Hypersphere
        βs = [Tuple(β) for β ∈ hypercube if LinearAlgebra.norm(β.I) ≤ r]
    elseif space.metric == :manhattan
        hypercube = CartesianIndices((repeat([(-r0):r0], D)...,))
        βs = [β for β ∈ hypercube if sum(abs.(β.I)) ≤ r0]
    elseif space.metric == :chebyshev
        βs = vec([Tuple(a) for a in Iterators.product([(-r0):r0 for φ in 1:D]...)])
    else
        error("Unknown metric type")
    end
    return βs
end

# And finally extend `nearby_ids` given a position
function nearby_ids(pos::NTuple{D, Int}, model::ABM{<:GridSpaceSingle{D,true}}, r = 1;
    get_nearby_indices = indices_within_radius) where {D}
    nindices = get_nearby_indices(model, r)
    space_array = model.space.s
    space_size = size(space_array)
    array_accesses_iterator = (space_array[(mod1.(pos .+ β, space_size))...] for β in nindices)
    # Notice that not all positions are valid; some are empty! Need to filter:
    valid_pos_iterator = Base.Iterators.filter(x -> x ≠ 0, array_accesses_iterator)
    return valid_pos_iterator
end

function nearby_ids(pos::NTuple{D, Int}, model::ABM{<:GridSpaceSingle{D,false}}, r = 1;
    get_nearby_indices = indices_within_radius) where {D}
    nindices = get_nearby_indices(model, r)
    space_array = model.space.s
    positions_iterator = (pos .+ β for β in nindices)
    # Here we combine in one filtering step both valid accesses to the space array
    # but also that the accessed location is not empty (i.e., id is not 0)
    valid_pos_iterator = Base.Iterators.filter(
        pos -> checkbounds(Bool, space_array, pos...) && space_array[pos...] ≠ 0,
        positions_iterator
    )
    return (space_array[pos...] for pos in valid_pos_iterator)
end

function nearby_ids(a::A, model::ABM{<:GridSpaceSingle{D,false},A}, r = 1) where {D,A<:AbstractAgent}
    return nearby_ids(a.pos, model, r; get_nearby_indices = indices_within_radius_no_0)
end
