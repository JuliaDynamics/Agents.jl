"""
    AbstractGridSpace{D,P}
Abstract type for grid-based spaces.
All instances have a field `stored_ids` which is simply the array
whose size is the same as the size of the space and whose cartesian
indices are the possible positions in the space.

Furthermore, all spaces should have at least the fields
* `indices_within_radius`
* `indices_within_radius_no_0`
which are `Dict{Float64,Vector{NTuple{D,Int}}}`, mapping radii
to vector of indices within each radius.

`D` is the dimension and `P` is whether the space is periodic (boolean).
"""
abstract type AbstractGridSpace{D,P} <: DiscreteSpace end

function positions(space::AbstractGridSpace)
    x = CartesianIndices(space.stored_ids)
    return (Tuple(y) for y in x)
end

# ALright, so here is the design for basic nearby_stuff looping.
# We initialize a vector of tuples of indices within radius `r` from origin position.
# We store this vector. When we have to loop over nearby_stuff, we call this vector
# and add it to the given position. That is what the concrete implementations of
# nearby_stuff do in the concrete spaces files.

"""
    indices_within_radius(model::ABM{<:AbstractGridSpace}, r::Real)
The function does two things:
1. If a vector of indices exists in the model, it returns that.
2. If not, it creates this vector, stores it in the model and then returns that.
"""
indices_within_radius(model::ABM, r::Real) = indices_within_radius(model.space, r::Real)
function indices_within_radius(
    space::AbstractGridSpace{D}, r::Real)::Vector{NTuple{D, Int}} where {D}
    if haskey(space.indices_within_radius, r)
        βs = space.indices_within_radius[r]
    else
        βs = initialize_neighborhood(space, r)
        space.indices_within_radius[float(r)] = βs
    end
    return βs::Vector{NTuple{D, Int}}
end

# Make grid space Abstract if indeed faster
function initialize_neighborhood(space::AbstractGridSpace{D}, r::Real) where {D}
    if space.metric == :euclidean
        r0 = ceil(Int, r)
        hypercube = CartesianIndices((repeat([(-r0):r0], D)...,))
        # select subset which is in Hypersphere
        βs = [Tuple(β) for β ∈ hypercube if LinearAlgebra.norm(β.I) ≤ r]
    elseif space.metric == :manhattan
        r0 = floor(Int, r)
        hypercube = CartesianIndices((repeat([(-r0):r0], D)...,))
        βs = [Tuple(β) for β ∈ hypercube if sum(abs.(β.I)) ≤ r0]
    elseif space.metric == :chebyshev
        r0 = floor(Int, r)
        βs = vec([Tuple(a) for a in Iterators.product([(-r0):r0 for φ in 1:D]...)])
    else
        error("Unknown metric type")
    end
    return βs::Vector{NTuple{D, Int}}
end

function random_position(model::ABM{<:AbstractGridSpace})
    Tuple(rand(model.rng, CartesianIndices(model.space.stored_ids)))
end


indices_within_radius_no_0(model::ABM, r::Real) =
    indices_within_radius_no_0(model.space, r::Real)
function indices_within_radius_no_0(
    space::AbstractGridSpace{D}, r::Real)::Vector{NTuple{D, Int}} where {D}
    if haskey(space.indices_within_radius_no_0, r)
        βs = space.indices_within_radius_no_0[r]
    else
        βs = initialize_neighborhood(space, r)
        z = ntuple(i -> 0, Val{D}())
        filter!(x -> x ≠ z, βs)
        space.indices_within_radius_no_0[float(r)] = βs
    end
    return βs::Vector{NTuple{D, Int}}
end

# `nearby_positions` is easy, uses same code as `GridSpaceSingle` but utilizes
# the above `indices_within_radius_no_0`
function nearby_positions(
        pos::ValidPos, model::ABM{<:AbstractGridSpace{D,false}}, r = 1
    ) where {D}
    stored_ids = model.space.stored_ids
    nindices = indices_within_radius_no_0(model, r)
    positions_iterator = (n .+ pos for n in nindices)
    return Base.Iterators.filter(
        pos -> checkbounds(Bool, stored_ids, pos...), positions_iterator
    )
end
function nearby_positions(
        pos::ValidPos, model::ABM{<:AbstractGridSpace{D,true}}, r = 1
    ) where {D}
    nindices = indices_within_radius_no_0(model, r)
    space_size = size(model.space)
    return (mod1.(n .+ pos, space_size) for n in nindices)
end

###################################################################
# pretty printing
###################################################################
Base.size(space::AbstractGridSpace) = size(space.stored_ids)

function Base.show(io::IO, space::AbstractGridSpace{D,P}) where {D,P}
    name = nameof(typeof(space))
    s = "$name with size $(size(space)), metric=$(space.metric), periodic=$(P)"
    print(io, s)
end
