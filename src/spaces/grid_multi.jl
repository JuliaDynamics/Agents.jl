export GridSpace

# type P stands for Periodic and is a boolean
struct GridSpace{D,P} <: AbstractGridSpace{D,P}
    stored_ids::Array{Vector{Int},D}
    extent::NTuple{D,Int}
    metric::Symbol
    offsets_at_radius::Dict{Int,Vector{NTuple{D,Int}}}
    offsets_within_radius::Dict{Int,Vector{NTuple{D,Int}}}
    offsets_within_radius_no_0::Dict{Int,Vector{NTuple{D,Int}}}
    indices_within_radius_tuple::Dict{NTuple{D,Int},Vector{NTuple{D,Int}}}
end
spacesize(space::GridSpace) = space.extent

"""
    GridSpace(d::NTuple{D, Int}; periodic = true, metric = :chebyshev)
Create a `GridSpace` that has size given by the tuple `d`, having `D ≥ 1` dimensions.
Optionally decide whether the space will be periodic and what will be the distance metric.
The position type for this space is `NTuple{D, Int}`, use [`GridAgent`](@ref) for convenience.
Valid positions have indices in the range `1:d[i]` for the `i`-th dimension.

An example using `GridSpace` is [Schelling's segregation model](@ref).

## Distance specification
The typical terminology when searching neighbors in agent based modelling is
"Von Neumann" neighborhood or "Moore" neighborhoods. However, because Agents.jl
provides a much more powerful infrastructure for finding neighbors, both in
arbitrary dimensions but also of arbitrary neighborhood size, this established
terminology is no longer appropriate.
Instead, distances that define neighborhoods are specified according to a proper metric
space, that is both well defined for any distance, and applicable to any dimensionality.

The allowed metrics are (and see docs online for a plotted example):

- `:chebyshev` metric means that the `r`-neighborhood of a position are all
  positions within the hypercube having side length of `2*floor(r)` and being centered in
  the origin position. This is similar to "Moore" for `r = 1` and two dimensions.

- `:manhattan` metric means that the `r`-neighborhood of a position are all positions whose
  cartesian indices have Manhattan distance `≤ r` from the cartesian index of the origin
  position. This similar to "Von Neumann" for `r = 1` and two dimensions.

- `:euclidean` metric means that the `r`-neighborhood of a position are all positions whose
  cartesian indices have Euclidean distance `≤ r` from the cartesian index of the origin
  position.

## Advanced dimension-dependent distances in Chebyshev metric
If `metric = :chebyshev`, some advanced specification of distances is allowed when providing
`r` to functions like [`nearby_ids`](@ref).
1. `r::NTuple{D,Int}` such as `r = (5, 2)`. This would mean a distance of 5 in the first
   dimension and 2 in the second. This can be useful when different coordinates in the space
   need to be searched with different ranges, e.g., if the space corresponds to a full
   building, with the third dimension the floor number.
2. `r::Vector{Tuple{Int,UnitRange{Int}}}` such as `r = [(1, -1:1), (3, 1:2)]`.
   This allows explicitly specifying the difference between position indices in each
   specified dimension. The example `r = [(1, -1:1), (3, 1:2)]` when given to e.g.,
   [`nearby_ids`](@ref), would search dimension 1 one step of either side of the current
   position (as well as the current position since `0 ∈ -1:1`) and would search
   the third dimension one and two positions above current.
   Unspecified dimensions (like the second in this example) are
   searched throughout all their possible ranges.

See the
[Battle Royale](https://juliadynamics.github.io/AgentsExampleZoo.jl/dev/examples/battle/)
example for usage of this advanced specification of dimension-dependent distances
where one dimension is used as a categorical one.
"""
function GridSpace(
        d::NTuple{D,Int}; periodic::Bool = true, metric::Symbol = :chebyshev
    ) where {D}
    stored_ids = Array{Vector{Int},D}(undef, d)
    for i in eachindex(stored_ids)
        stored_ids[i] = Int[]
    end
    return GridSpace{D,periodic}(
        stored_ids,
        d,
        metric,
        Dict{Int,Vector{NTuple{D,Int}}}(),
        Dict{Int,Vector{NTuple{D,Int}}}(),
        Dict{Int,Vector{NTuple{D,Int}}}(),
        Dict{NTuple{D,Int},Vector{NTuple{D,Int}}}(),
    )
end

#######################################################################################
# %% Implementation of space API
#######################################################################################
function add_agent_to_space!(a::A, model::ABM{<:GridSpace,A}) where {A<:AbstractAgent}
    push!(abmspace(model).stored_ids[a.pos...], a.id)
    return a
end

function remove_agent_from_space!(a::A, model::ABM{<:GridSpace,A}) where {A<:AbstractAgent}
    prev = abmspace(model).stored_ids[a.pos...]
    ai = findfirst(i -> i == a.id, prev)
    deleteat!(prev, ai)
    return a
end

##########################################################################################
# nearby_stuff for GridSpace
##########################################################################################
# `offsets_within_radius` and creating them comes from the spaces/grid_general.jl.
# The code for `nearby_ids(pos, model, r::Real)` is different from `GridSpaceSingle`.
# Turns out, nested calls to `Iterators.flatten` were bad for performance,
# and Julia couldn't completely optimize everything.
# Instead, here we create a dedicated iterator for going over IDs.

# We allow this to be used with space directly because it is reused in `ContinuousSpace`.
nearby_ids(pos::NTuple, model::ABM{<:GridSpace}, r::Real = 1) = nearby_ids(pos, abmspace(model), r)
function nearby_ids(pos::NTuple{D, Int}, space::GridSpace{D,P}, r::Real = 1) where {D,P}
    nindices = offsets_within_radius(space, r)
    L = length(nindices)
    stored_ids = space.stored_ids
    space_size = spacesize(space)
    nocheck = all(i -> r < pos[i] <= space_size[i] - r, 1:D)
    return GridSpaceIdIterator{P, D}(stored_ids, nindices, pos, L, space_size, nocheck)
end

# Iterator struct. State is `(pos_i, inner_i)` with `pos_i` the index to the nearby indices
# P is Boolean, and means "periodic".
struct GridSpaceIdIterator{P,D}
    stored_ids::Array{Vector{Int},D}  # Reference to array in grid space
    indices::Vector{NTuple{D,Int}}    # Result of `offsets_within_radius` pretty much
    origin::NTuple{D,Int}             # origin position nearby is measured from
    L::Int                            # length of `indices`
    space_size::NTuple{D,Int}         # size of `stored_ids`
    nocheck::Bool                     # skip bound checks if we are far from the edges
end
Base.eltype(::Type{<:GridSpaceIdIterator}) = Int # It returns IDs
Base.IteratorSize(::Type{<:GridSpaceIdIterator}) = Base.SizeUnknown()

# Initialize iteration
function Base.iterate(iter::GridSpaceIdIterator)
    @inbounds begin
    stored_ids, indices, L, origin, nocheck = getproperty.(
        Ref(iter), (:stored_ids, :indices, :L, :origin, :nocheck))
    combine, invalid = nocheck ? (combine_positions_nocheck, invalid_access_nocheck) :
                                 (combine_positions, invalid_access)
    pos_i = 1
    pos_index = combine(indices[pos_i], origin, iter)
    # First, check if the position index is valid (bounds checking)
    # AND whether the position is empty. If not, proceed to next position index.
    while invalid(pos_index, iter)
        pos_i += 1
        # Stop iteration if `pos_index` exceeded the amount of positions
        pos_i > L && return nothing
        pos_index = combine(indices[pos_i], origin, iter)
    end
    # We have a valid position index and a non-empty position
    ids_in_pos = stored_ids[pos_index...]
    id = ids_in_pos[1]
    end
    return (id, (pos_i, 2, ids_in_pos))
end

# For performance we need a different method of starting the iteration
# and another one that continues iteration. Second case uses the explicitly
# known knowledge of `pos_i` being a valid position index.
function Base.iterate(iter::GridSpaceIdIterator, state)
    @inbounds begin
    stored_ids, indices, L, origin, nocheck = getproperty.(
        Ref(iter), (:stored_ids, :indices, :L, :origin, :nocheck))
    combine, invalid = nocheck ? (combine_positions_nocheck, invalid_access_nocheck) :
                                 (combine_positions, invalid_access)
    pos_i, inner_i, ids_in_pos = state
    if inner_i > length(ids_in_pos)
        # we have exhausted IDs in current position, so we reset and go to next
        pos_i += 1
        # Stop iteration if `pos_index` exceeded the amount of positions
        pos_i > L && return nothing
        inner_i = 1
        pos_index = combine(indices[pos_i], origin, iter)
        # Of course, we need to check if we have valid index
        while invalid(pos_index, iter)
            pos_i += 1
            pos_i > L && return nothing
            pos_index = combine(indices[pos_i], origin, iter)
        end
        ids_in_pos = stored_ids[pos_index...]
    end
    # We reached the next valid position and non-empty position
    id = ids_in_pos[inner_i]
    return (id, (pos_i, inner_i + 1, ids_in_pos))
    end
end

# Instructs how to combine two positions. Just to avoid code duplication for periodic
combine_positions(pos, origin, ::GridSpaceIdIterator{false}) = pos .+ origin
@inline function combine_positions(pos, origin, iter::GridSpaceIdIterator{true})
    npos, space_size, stored_ids = pos .+ origin, iter.space_size, iter.stored_ids
    # checking for bounds is less expensive than calling mod1
    checkbounds(Bool, stored_ids, npos...) ? npos : mod1.(npos, space_size)
end
combine_positions_nocheck(pos, origin, ::GridSpaceIdIterator) = pos .+ origin

# Must return `true` if the access is invalid
@inline function invalid_access(pos_index, iter::GridSpaceIdIterator{false})
    valid_bounds = checkbounds(Bool, iter.stored_ids, pos_index...)
    return !valid_bounds || @inbounds isempty(iter.stored_ids[pos_index...])
end
invalid_access(pos_index, iter::GridSpaceIdIterator{true}) = @inbounds isempty(iter.stored_ids[pos_index...])
invalid_access_nocheck(pos_index, iter::GridSpaceIdIterator) = @inbounds isempty(iter.stored_ids[pos_index...])

##########################################################################################
# nearby_stuff with special access r::Tuple
##########################################################################################
# TODO: We can re-write this to create its own `indices_within_radius_tuple`.
# This would also allow it to work for any metric, not just Chebyshev!

function nearby_ids(pos::ValidPos, model::ABM{<:GridSpace}, r::NTuple{D,Int}) where {D}
    # simply transform `r` to the Vector format expected by the below function
    newr = [(i, -r[i]:r[i]) for i in 1:D]
    nearby_ids(pos, model, newr)
end

function nearby_ids(
    pos::ValidPos,
    model::ABM{<:GridSpace},
    r::Vector{Tuple{Int64, UnitRange{Int64}}},
)
    @assert abmspace(model).metric == :chebyshev
    dims = first.(r)
    vidx = []
    for d in 1:ndims(abmspace(model).stored_ids)
        idx = findall(dim -> dim == d, dims)
        dim_range = isempty(idx) ? Colon() :
            bound_range(pos[d] .+ last(r[only(idx)]), d, abmspace(model))
        push!(vidx, dim_range)
    end
    s = view(abmspace(model).stored_ids, vidx...)
    Iterators.flatten(s)
end

function bound_range(unbound, d, space::GridSpace{D,false}) where {D}
    return range(max(unbound.start, 1), stop = min(unbound.stop, spacesize(space)[d]))
end


#######################################################################################
# %% Further discrete space functions
#######################################################################################
ids_in_position(pos::ValidPos, model::ABM{<:GridSpace}) = ids_in_position(pos, abmspace(model))
function ids_in_position(pos::ValidPos, space::GridSpace)
    return space.stored_ids[pos...]
end
