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
@agent struct GridAgent{D}(NoSpaceAgent)
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
# !! Important !! Notice that all implementation of different position metrics 
# should start by calling `calculate_hyperrectangle` since the calculated hyperrectagle 
# respects the periodicity of the space.

function calculate_hyperrectangle(space::AbstractGridSpace{D,true}, r) where {D}
    space_size = spacesize(space)
    if r < minimum(space_size) ÷ 2
        hyperrect = Iterators.product((-r:r for _ in 1:D)...)
    else
        odd_s, half_s = space_size .% 2, space_size .÷ 2
        r_dims = min.(r, half_s)
        from_to = (-rm:rm-(rm == hs && os == 0)
                   for (rm, hs, os) in zip(r_dims, half_s, odd_s))
        hyperrect = Iterators.product(from_to...)
    end
    return hyperrect
end
function calculate_hyperrectangle(space::AbstractGridSpace{D,false}, r) where {D}
    space_size = spacesize(space)
    if r < minimum(space_size)
        hyperrect = Iterators.product((-r:r for _ in 1:D)...) 
    else
        r_dims = min.(r, space_size)
        hyperrect = Iterators.product((-rm:rm for rm in r_dims)...)
    end
    return hyperrect
end
function calculate_hyperrectangle(space::AbstractGridSpace{D,P}, r) where {D,P}
    space_size = spacesize(space)
    r_notover = [p_d ? r < s_d ÷ 2 : r < s_d for (p_d, s_d) in zip(P, space_size)]
    if all(r_notover)
        hyperrect = Iterators.product((-r:r for _ in 1:D)...) 
    else
        odd_s, half_s = space_size .% 2, space_size .÷ 2
        r_dims_P = min.(r, half_s)
        r_dims_notP = min.(r, space_size)
        from_to = (P[i] ? 
                    (-r_dims_P[i]:r_dims_P[i]-(r_dims_P[i] == half_s[i] && odd_s[i] == 0)) : 
                    (-r_dims_notP[i]:r_dims_notP[i]) for i in 1:D)
        hyperrect = Iterators.product(from_to...)
    end
    return hyperrect
end

"""
    offsets_within_radius(model::ABM{<:AbstractGridSpace}, r::Real)
The function does two things:
1. If a vector of indices exists in the model, it returns that.
2. If not, it creates this vector, stores it in the model and then returns that.
"""
offsets_within_radius(model::ABM, r::Real) = offsets_within_radius(abmspace(model), r)
function offsets_within_radius(space::AbstractGridSpace{D}, r::Real) where {D}
    i = floor(Int, r + 1)
    offsets = space.offsets_within_radius
    if i <= length(offsets) && !isempty(offsets[i])
        βs = offsets[i]
    else
        r₀ = i - 1
        βs = calculate_offsets(space, r₀)
        append_offsets!(offsets, i, βs, D)
    end
    return βs
end

"""
    offsets_at_radius(model::ABM{<:AbstractGridSpace}, r::Real)
The function does two things:
1. If a vector of indices exists in the model, it returns that.
2. If not, it creates this vector, stores it in the model and then returns that.
"""
offsets_at_radius(model::ABM, r::Real) = offsets_at_radius(abmspace(model), r)
function offsets_at_radius(space::AbstractGridSpace{D}, r::Real) where {D}
    i = floor(Int, r + 1)
    offsets = space.offsets_at_radius
    if i <= length(offsets) && !isempty(offsets[i])
        βs = offsets[i]
    else
        r₀ = i - 1
        βs = calculate_offsets(space, r₀)
        if space.metric == :manhattan
            filter!(β -> sum(abs.(β)) == r₀, βs)
        elseif space.metric == :chebyshev
            filter!(β -> maximum(abs.(β)) == r₀, βs)
        end
        append_offsets!(offsets, i, βs, D)
    end
    return βs
end

function calculate_offsets(space::AbstractGridSpace{D}, r::Int) where {D}
    hyperrect = calculate_hyperrectangle(space, r)
    if space.metric == :euclidean
        βs = [β for β ∈ hyperrect if sum(β.^2) ≤ r^2]
    elseif space.metric == :manhattan
        βs = [β for β ∈ hyperrect if sum(abs.(β)) ≤ r]
    elseif space.metric == :chebyshev
        βs = vec([β for β ∈ hyperrect])
    else
        error("Unknown metric type")
    end
    length(βs) == 0 && push!(βs, ntuple(i -> 0, D)) # ensure 0 is there
    return βs
end

function append_offsets!(offsets, i, βs, D)
    incr = i - length(offsets)
    if incr > 0
        resize!(offsets, i)
        @inbounds for j in i-incr+1:i
            offsets[j] = Vector{NTuple{D,Int}}()
        end
    end
    append!(offsets[i], βs)
end

function random_position(model::ABM{<:AbstractGridSpace})
    Tuple(rand(abmrng(model), CartesianIndices(abmspace(model).stored_ids)))
end

offsets_within_radius_no_0(model::ABM, r::Real) = offsets_within_radius_no_0(abmspace(model), r)
function offsets_within_radius_no_0(space::AbstractGridSpace{D}, r::Real) where {D}
    i = floor(Int, r + 1)
    offsets = space.offsets_within_radius_no_0
    if i <= length(offsets) && !isempty(offsets[i])
        βs = offsets[i]
    else
        r₀ = i - 1
        βs = calculate_offsets(space, r₀)
        z = ntuple(i -> 0, D)
        filter!(x -> x ≠ z, βs)
        append_offsets!(offsets, i, βs, D)
    end
    return βs
end

# `nearby_positions` is easy, uses same code as `neaby_ids` of `GridSpaceSingle` but
# utilizes the above `offsets_within_radius_no_0`. We complicated it a bit more because
# we want to be able to re-use it in `ContinuousSpace`, so we allow it to either
# find positions with the 0 or without.
function nearby_positions(pos::ValidPos, model::ABM{<:AbstractGridSpace}, args::Vararg{Any, N}) where {N}
    return nearby_positions(pos, abmspace(model), args...)
end
function nearby_positions(
        pos::ValidPos, space::AbstractGridSpace{D,false}, r = 1,
        get_indices_f = offsets_within_radius_no_0 # NOT PUBLIC API! For `ContinuousSpace`.
    ) where {D}
    nindices = get_indices_f(space, r)
    space_size = spacesize(space)
    # check if we are far from the wall to skip bounds checks
    if all(i -> r < pos[i] <= space_size[i] - r, 1:D)
        return (n .+ pos for n in nindices)
    else
        stored_ids = space.stored_ids
        return (n .+ pos for n in nindices if checkbounds(Bool, stored_ids, (n .+ pos)...))
    end
end
function nearby_positions(
        pos::ValidPos, space::AbstractGridSpace{D,true}, r = 1,
        get_indices_f = offsets_within_radius_no_0 # NOT PUBLIC API! For `ContinuousSpace`.
    ) where {D}
    nindices = get_indices_f(space, r)
    space_size = spacesize(space)
    # check if we are far from the wall to skip bounds checks
    if all(i -> r < pos[i] <= space_size[i] - r, 1:D)
        return (n .+ pos for n in nindices)
    else
        stored_ids = space.stored_ids
        return (checkbounds(Bool, stored_ids, (n .+ pos)...) ? 
                n .+ pos : mod1.(n .+ pos, space_size) for n in nindices)
    end
end
function nearby_positions(
    pos::ValidPos, space::AbstractGridSpace{D,P}, r = 1,
    get_indices_f = offsets_within_radius_no_0 # NOT PUBLIC API! For `ContinuousSpace`.
) where {D,P}
    stored_ids = space.stored_ids
    nindices = get_indices_f(space, r)
    space_size = size(space)
    # check if we are far from the wall to skip bounds checks
    if all(i -> r < pos[i] <= space_size[i] - r, 1:D)
        return (n .+ pos for n in nindices)
    else
        return (
            checkbounds(Bool, stored_ids, (n .+ pos)...) ?
            n .+ pos : mod1.(n .+ pos, space_size)
            for n in nindices
            if all(P[i] || checkbounds(Bool, axes(stored_ids,i), n[i]+pos[i]) for i in 1:D)
        )
    end
end

function random_nearby_position(pos::ValidPos, model::ABM{<:AbstractGridSpace{D,false}}, r=1; kwargs...) where {D}
    nindices = offsets_within_radius_no_0(abmspace(model), r)
    stored_ids = abmspace(model).stored_ids
    rng = abmrng(model)
    while true
        chosen_offset = rand(rng, nindices)
        chosen_pos = pos .+ chosen_offset
        checkbounds(Bool, stored_ids, chosen_pos...) && return chosen_pos
    end
end

function random_nearby_position(pos::ValidPos, model::ABM{<:AbstractGridSpace{D,true}}, r=1; kwargs...) where {D}
    nindices = offsets_within_radius_no_0(abmspace(model), r)
    stored_ids = abmspace(model).stored_ids
    chosen_offset = rand(abmrng(model), nindices)
    chosen_pos = pos .+ chosen_offset
    checkbounds(Bool, stored_ids, chosen_pos...) && return chosen_pos
    return mod1.(chosen_pos, spacesize(model))
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
