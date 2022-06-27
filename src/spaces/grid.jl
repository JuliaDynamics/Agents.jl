"""
    AbstractGridSpace{D,P}
Abstract type for grid-based spaces.
All instances have a field `s` which is simply the array
whose size is the same as the size of the space and whose cartesian
indices are the possible positions in the space.
`D` is the dimension and `P` is whether the space is periodic (boolean).
"""
abstract type AbstractGridSpace{D,P} <: DiscreteSpace end
export GridSpace

struct Region{D}
    mini::NTuple{D,Int}
    maxi::NTuple{D,Int}
end

"""
    Hood{D}
Internal struct for efficiently finding neighboring positions to a given position.
It contains pre-initialized neighbor cartesian indices and delimiters of when the
neighboring indices would exceed the size of the underlying array.
"""
struct Hood{D}
    whole::Region{D} # allowed values (only useful for non periodic)
    βs::Vector{CartesianIndex{D}} # neighborhood cartesian indices
end

# type P stands for Periodic and is a boolean
struct GridSpace{D,P} <: AbstractGridSpace{D,P}
    s::Array{Vector{Int},D}
    metric::Symbol
    hoods::Dict{Float64,Hood{D}}
    hoods_tuple::Dict{NTuple{D,Float64},Hood{D}}
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
    d::NTuple{D,Int};
    periodic::Bool = true,
    metric::Symbol = :chebyshev,
    pathfinder = nothing,
) where {D,W}
    s = Array{Vector{Int},D}(undef, d)

    if !isnothing(pathfinder)
        @error "Pathfinders are no longer part of GridSpace"
    end

    for i in eachindex(s)
        s[i] = Int[]
    end

    return GridSpace{D,periodic}(
        s,
        metric,
        Dict{Float64,Hood{D}}(),
        Dict{NTuple{D,Float64},Hood{D}}(),
    )
end

#######################################################################################
# %% Implementation of space API
#######################################################################################
function random_position(model::ABM{<:AbstractGridSpace})
    Tuple(rand(model.rng, CartesianIndices(model.space.s)))
end

function add_agent_to_space!(a::A, model::ABM{<:GridSpace,A}) where {A<:AbstractAgent}
    push!(model.space.s[a.pos...], a.id)
    return a
end

function remove_agent_from_space!(a::A, model::ABM{<:GridSpace,A}) where {A<:AbstractAgent}
    prev = model.space.s[a.pos...]
    ai = findfirst(i -> i == a.id, prev)
    deleteat!(prev, ai)
    return a
end

##########################################################################################
# %% Structures for collecting neighbors on a grid
##########################################################################################
# Most of the source code in this section comes from TimeseriesPrediction.jl, specifically
# the file github.com/JuliaDynamics/TimeseriesPrediction.jl/src/spatiotemporalembedding.jl
# It creates a performant envinroment where the cartesian indices of a given neighborhood
# of given radious and metric type are stored and re-used for each search.

Base.length(r::Region{D}) where {D} = prod(r.maxi .- r.mini .+ 1)

function Base.in(idx, r::Region{D}) where {D}
    @inbounds for φ in 1:D
        r.mini[φ] <= idx[φ] <= r.maxi[φ] || return false
    end
    return true
end

# This function initializes the standard cartesian indices that needs to be added to some
# index `α` to obtain its neighborhood
function initialize_neighborhood!(space::AbstractGridSpace{D}, r::Real) where {D}
    d = size(space.s)
    r0 = floor(Int, r)
    if space.metric == :euclidean
        # hypercube of indices
        hypercube = CartesianIndices((repeat([(-r0):r0], D)...,))
        # select subset of hc which is in Hypersphere
        βs = [β for β ∈ hypercube if LinearAlgebra.norm(β.I) ≤ r]
    elseif space.metric == :manhattan
        hypercube = CartesianIndices((repeat([(-r0):r0], D)...,))
        βs = [β for β ∈ hypercube if sum(abs.(β.I)) <= r0]
    elseif space.metric == :chebyshev
        βs = vec([CartesianIndex(a) for a in Iterators.product([(-r0):r0 for φ in 1:D]...)])
    else
        error("Unknown metric type")
    end
    whole = Region(map(one, d), d)
    hood = Hood{D}(whole, βs)
    space.hoods[float(r)] = hood
    return hood
end

function initialize_neighborhood!(space::AbstractGridSpace{D}, r::NTuple{D,Real}) where {D}
    @assert space.metric == :chebyshev "Can only use tuple based neighbor search with the Chebyshev metric."
    d = size(space.s)
    r0 = (floor(Int, i) for i in r)
    βs = vec([CartesianIndex(a) for a in Iterators.product([(-ri):ri for ri in r0]...)])
    whole = Region(map(one, d), d)
    hood = Hood{D}(whole, βs)
    push!(space.hoods_tuple, float.(r) => hood)
    return hood
end

"""
    grid_space_neighborhood(α::CartesianIndex, space::AbstractGridSpace, r::Real)

Return an iterator over all positions within distance `r` from `α` according to the `space`.

The only reason this function is not equivalent with `nearby_positions` is because
`nearby_positions` skips the current position `α`, while `α` is always included in the
returned iterator (because the `0` index is always included in `βs`).

This function re-uses the source code of TimeseriesPrediction.jl, along with the
helper struct `Hood` and generates neighboring cartesian indices on the fly,
reducing the amount of computations necessary (i.e. we don't "find" new indices,
we only add a pre-determined amount of indices to `α`).
"""
function grid_space_neighborhood(α::CartesianIndex, space::AbstractGridSpace, r::Real)
    hood = if haskey(space.hoods, r)
        space.hoods[r]
    else
        initialize_neighborhood!(space, r)
    end
    _grid_space_neighborhood(α, space, hood)
end

"""
    grid_space_neighborhood(α::CartesianIndex, space::AbstractGridSpace, r::NTuple)

Return an iterator over all positions within distances of the tuple `r`, from `α`
according to the `space`. `r` must have as many elements as `space` has dimensions.
For example, with a `GridSpace((10, 10, 10))` : `r = (1, 7, 9)`.
"""
function grid_space_neighborhood(
    α::CartesianIndex,
    space::GridSpace{D},
    r::NTuple{D,Real},
) where {D}
    hood = if haskey(space.hoods_tuple, r)
        space.hoods_tuple[r]
    else
        initialize_neighborhood!(space, r)
    end
    _grid_space_neighborhood(α, space, hood)
end

function _grid_space_neighborhood(
    α::CartesianIndex,
    space::AbstractGridSpace{D,true},
    hood,
) where {D}
    return ((mod1.(Tuple(α + β), hood.whole.maxi)) for β in hood.βs)
end

function _grid_space_neighborhood(
    α::CartesianIndex,
    space::AbstractGridSpace{D,false},
    hood,
) where {D}
    return Iterators.filter(x -> x ∈ hood.whole, (Tuple(α + β) for β in hood.βs))
end

grid_space_neighborhood(α, model::ABM, r) = grid_space_neighborhood(α, model.space, r)

##########################################################################################
# %% Extend neighbors API for spaces
##########################################################################################
function nearby_ids(pos::ValidPos, model::ABM{<:GridSpace}, r = 1)
    nn = grid_space_neighborhood(CartesianIndex(pos), model, r)
    s = model.space.s
    Iterators.flatten((s[i...] for i in nn))
end

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
    for d in 1:ndims(model.space.s)
        idx = findall(dim -> dim == d, dims)
        dim_range = isempty(idx) ? Colon() :
            bound_range(pos[d] .+ last(r[only(idx)]), d, model.space)
        push!(vidx, dim_range)
    end
    s = view(model.space.s, vidx...)
    Iterators.flatten(s)
end

function bound_range(unbound, d, space::GridSpace{D,false}) where {D}
    return range(max(unbound.start, 1), stop = min(unbound.stop, size(space)[d]))
end

function nearby_positions(pos::ValidPos, model::ABM{<:GridSpace}, r = 1)
    nn = grid_space_neighborhood(CartesianIndex(pos), model, r)
    Iterators.filter(!isequal(pos), nn)
end

#######################################################################################
# %% Further discrete space functions
#######################################################################################
function positions(model::ABM{<:AbstractGridSpace})
    x = CartesianIndices(model.space.s)
    return (Tuple(y) for y in x)
end

function ids_in_position(pos::ValidPos, model::ABM{<:GridSpace})
    return model.space.s[pos...]
end

###################################################################
# %% pretty printing
###################################################################
Base.size(space::GridSpace) = size(space.s)

function Base.show(io::IO, space::GridSpace{D,P}) where {D,P}
    s = "GridSpace with size $(size(space)), metric=$(space.metric), periodic=$(P)"
    print(io, s)
end
