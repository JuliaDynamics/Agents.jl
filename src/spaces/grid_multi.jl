export GridSpace

# type P stands for Periodic and is a boolean
struct GridSpace{D,P} <: AbstractGridSpace{D,P}
    stored_ids::Array{Vector{Int},D}
    metric::Symbol
    indices_within_radius::Dict{Float64,Vector{NTuple{D,Int}}}
    indices_within_radius_no_0::Dict{Float64,Vector{NTuple{D,Int}}}
    indices_within_radius_tuple::Dict{NTuple{D,Float64},Vector{NTuple{D,Int}}}
end

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
provides a much more powerful infastructure for finding neighbors, both in
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
If `metric = :chebyshev`, some advanved specification of distances is allowed when providing
`r` to functions like [`nearby_ids`](@ref).
1. `r::NTuple{Int,D}` such as `r = (5, 2)`. This would mean a distance of 5 in the first
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
        metric,
        Dict{Float64,Vector{NTuple{D,Int}}}(),
        Dict{Float64,Vector{NTuple{D,Int}}}(),
        Dict{NTuple{D,Float64},Vector{NTuple{D,Int}}}(),
    )
end

#######################################################################################
# %% Implementation of space API
#######################################################################################
function add_agent_to_space!(a::A, model::ABM{<:GridSpace,A}) where {A<:AbstractAgent}
    push!(model.space.stored_ids[a.pos...], a.id)
    return a
end

function remove_agent_from_space!(a::A, model::ABM{<:GridSpace,A}) where {A<:AbstractAgent}
    prev = model.space.stored_ids[a.pos...]
    ai = findfirst(i -> i == a.id, prev)
    deleteat!(prev, ai)
    return a
end

##########################################################################################
# %% Structures for collecting neighbors on a grid
##########################################################################################
# `indices_within_radius` and creating them comes from the spaces/grid_general.jl.
# The code for `nearby_ids(pos, model, r::Real)` is very similar to `GridSpaceSingle`.

function nearby_ids(pos::NTuple{D, Int}, model::ABM{<:GridSpace{D,true}}, r = 1) where {D}
    nindices = get_nearby_indices(model, r)
    stored_ids = model.space.stored_ids
    space_size = size(stored_ids)
    array_accesses_iterator = (stored_ids[(mod1.(pos .+ β, space_size))...] for β in nindices)
    return Iterators.flatten(stored_ids[i...] for i in array_accesses_iterator)
end

function nearby_ids(pos::NTuple{D, Int}, model::ABM{<:GridSpace{D,false}}, r = 1;
    get_nearby_indices = indices_within_radius) where {D}
    nindices = get_nearby_indices(model, r)
    stored_ids = model.space.stored_ids
    positions_iterator = (pos .+ β for β in nindices)
    # Not sure if this will work:
    return Iterators.flatten(@inbounds(stored_ids[i...]) for i in positions_iterator if checkbounds(Bool, stored_ids, i...))
end

function nearby_positions(pos::ValidPos, model::ABM{<:GridSpace}, r = 1)
    nindices = get_nearby_indices(model, r)

    nn = grid_space_neighborhood(CartesianIndex(pos), model, r)
    Iterators.filter(!isequal(pos), nn)
end



# TODO: Re-write this to create its own `indices_within_radius_tuple` like GridSpaceSinelg

# This case is rather special. It's the dimension-specific search range.
# TODO: Make it use the `Hood` code infastructure
function nearby_ids(
    pos::ValidPos,
    model::ABM{<:GridSpace},
    r::Vector{Tuple{Int,UnitRange{Int}}},
)
    @assert model.space.metric == :chebyshev
    dims = first.(r)
    vidx = []
    for d in 1:ndims(model.space.stored_ids)
        idx = findall(dim -> dim == d, dims)
        dim_range = isempty(idx) ? Colon() :
            bound_range(pos[d] .+ last(r[only(idx)]), d, model.space)
        push!(vidx, dim_range)
    end
    s = view(model.space.stored_ids, vidx...)
    Iterators.flatten(s)
end

function bound_range(unbound, d, space::GridSpace{D,false}) where {D}
    return range(max(unbound.start, 1), stop = min(unbound.stop, size(space)[d]))
end


#######################################################################################
# %% Further discrete space functions
#######################################################################################
function ids_in_position(pos::ValidPos, model::ABM{<:GridSpace})
    return model.space.stored_ids[pos...]
end
