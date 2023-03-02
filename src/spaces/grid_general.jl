export GridAgent

"""
    AbstractGridSpace{D,P}
Abstract type for grid-based spaces.
All instances have a field `stored_ids` which is simply the array
whose size is the same as the size of the space and whose cartesian
indices are the possible positions in the space.

Furthermore, all spaces should have at least the fields
* `offsets_within_radius`
* `offsets_within_radius_no_0`
which are `Dict{Float64,Vector{NTuple{D,Int}}}`, mapping radii
to vector of indices within each radius.

`D` is the dimension and `P` is whether the space is periodic (boolean).
"""
abstract type AbstractGridSpace{D,P} <: DiscreteSpace end

"""
    GridAgent{D} <: AbstractAgent
The minimal agent struct for usage with `D`-dimensional [`GridSpace`](@ref).
It has an additional `pos::NTuple{D,Int}` field. See also [`@agent`](@ref).
"""
@agent GridAgent{D} NoSpaceAgent begin
    pos::NTuple{D, Int}
end

function positions(space::AbstractGridSpace)
    x = CartesianIndices(space.stored_ids)
    return (Tuple(y) for y in x)
end

npositions(space::AbstractGridSpace) = length(space.stored_ids)

# ALright, so here is the design for basic nearby_stuff looping.
# We initialize a vector of tuples of indices within radius `r` from origin position.
# We store this vector. When we have to loop over nearby_stuff, we call this vector
# and add it to the given position. That is what the concrete implementations of
# nearby_stuff do in the concrete spaces files.

"""
    offsets_within_radius(model::ABM{<:AbstractGridSpace}, r::Real)
The function does two things:
1. If a vector of indices exists in the model, it returns that.
2. If not, it creates this vector, stores it in the model and then returns that.
"""
offsets_within_radius(model::ABM, r::Real) = offsets_within_radius(model.space, r::Real)
function offsets_within_radius(
    space::AbstractGridSpace{D}, r::Real)::Vector{NTuple{D, Int}} where {D}
    r₀ = floor(Int, r)
    if haskey(space.offsets_within_radius, r₀)
        βs = space.offsets_within_radius[r₀]
    else
        βs = calculate_offsets(space, r₀)
        space.offsets_within_radius[r₀] = βs
    end
    return βs::Vector{NTuple{D, Int}}
end

"""
    offsets_at_radius(model::ABM{<:AbstractGridSpace}, r::Real)
The function does two things:
1. If a vector of indices exists in the model, it returns that.
2. If not, it creates this vector, stores it in the model and then returns that.
"""
offsets_at_radius(model::ABM, r::Real) = offsets_at_radius(model.space, r::Real)
function offsets_at_radius(
    space::AbstractGridSpace{D}, r::Real
)::Vector{NTuple{D, Int}} where {D}
    r₀ = floor(Int, r)
    if haskey(space.offsets_at_radius, r₀)
        βs = space.offsets_at_radius[r₀]
    else
        βs = calculate_offsets(space, r₀)
        if space.metric == :manhattan
            filter!(β -> sum(abs.(β)) == r₀, βs)
            space.offsets_at_radius[r₀] = βs
        elseif space.metric == :chebyshev
            filter!(β -> maximum(abs.(β)) == r₀, βs)
            space.offsets_at_radius[r₀] = βs
        end
    end
    return βs::Vector{NTuple{D,Int}}
end

# Make grid space Abstract if indeed faster
function calculate_offsets(space::AbstractGridSpace{D}, r::Int) where {D}
    hypercube = Iterators.product(repeat([-r:r], D)...)
    if space.metric == :euclidean
        # select subset which is in Hypersphere
        βs = [β for β ∈ hypercube if sum(β.^2) ≤ r^2]
    elseif space.metric == :manhattan
        βs = [β for β ∈ hypercube if sum(abs.(β)) ≤ r]
    elseif space.metric == :chebyshev
        βs = vec([β for β ∈ hypercube])
    else
        error("Unknown metric type")
    end
    length(βs) == 0 && push!(βs, ntuple(i -> 0, Val(D))) # ensure 0 is there
    return βs::Vector{NTuple{D, Int}}
end

function random_position(model::ABM{<:AbstractGridSpace})
    Tuple(rand(model.rng, CartesianIndices(model.space.stored_ids)))
end

offsets_within_radius_no_0(model::ABM, r::Real) =
    offsets_within_radius_no_0(model.space, r::Real)
function offsets_within_radius_no_0(
    space::AbstractGridSpace{D}, r::Real)::Vector{NTuple{D, Int}} where {D}
    r₀ = floor(Int, r)
    if haskey(space.offsets_within_radius_no_0, r₀)
        βs = space.offsets_within_radius_no_0[r₀]
    else
        βs = calculate_offsets(space, r₀)
        z = ntuple(i -> 0, Val(D))
        filter!(x -> x ≠ z, βs)
        space.offsets_within_radius_no_0[r₀] = βs
    end
    return βs::Vector{NTuple{D, Int}}
end

# `nearby_positions` is easy, uses same code as `neaby_ids` of `GridSpaceSingle` but
# utilizes the above `offsets_within_radius_no_0`. We complicated it a bit more because
# we want to be able to re-use it in `ContinuousSpace`, so we allow it to either
# find positions with the 0 or without.
function nearby_positions(pos::ValidPos, model::ABM{<:AbstractGridSpace}, args...)
    return nearby_positions(pos, model.space, args...)
end
function nearby_positions(
        pos::ValidPos, space::AbstractGridSpace{D,false}, r = 1,
        get_indices_f = offsets_within_radius_no_0 # NOT PUBLIC API! For `ContinuousSpace`.
    ) where {D}
    stored_ids = space.stored_ids
    nindices = get_indices_f(space, r)
    positions_iterator = (n .+ pos for n in nindices)
    return Base.Iterators.filter(
        pos -> checkbounds(Bool, stored_ids, pos...), positions_iterator
    )
end
function nearby_positions(
        pos::ValidPos, space::AbstractGridSpace{D,true}, r = 1,
        get_indices_f = offsets_within_radius_no_0 # NOT PUBLIC API! For `ContinuousSpace`.
    ) where {D}
    nindices = get_indices_f(space, r)
    space_size = size(space)
    return (mod1.(n .+ pos, space_size) for n in nindices)
end

###################################################################
# pretty printing
###################################################################
Base.size(space::AbstractGridSpace) = size(space.stored_ids)
spacesize(space::AbstractGridSpace) = size(space)

function Base.show(io::IO, space::AbstractGridSpace{D,P}) where {D,P}
    name = nameof(typeof(space))
    s = "$name with size $(size(space)), metric=$(space.metric), periodic=$(P)"
    print(io, s)
end
