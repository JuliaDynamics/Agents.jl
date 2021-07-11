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
struct GridSpace{D,P,W} <: DiscreteSpace
    s::Array{Vector{Int},D}
    metric::Symbol
    hoods::Dict{Float64,Hood{D}}
    hoods_tuple::Dict{NTuple{D,Float64},Hood{D}}
    pathfinder::W
end

"""
    GridSpace(d::NTuple{D, Int}; periodic = true, metric = :chebyshev, pathfinder = nothing)
Create a `GridSpace` that has size given by the tuple `d`, having `D ≥ 1` dimensions.
Optionally decide whether the space will be periodic and what will be the distance metric
used, which decides the behavior of e.g. [`nearby_ids`](@ref).
The position type for this space is `NTuple{D, Int}`, use [`GridAgent`](@ref) for convenience.
In our examples we typically use `Dims{D}` instead of `NTuple{D, Int}` (they are equivalent).
Valid positions have indices in the range `1:d[i]` for the `i`th dimension.

`:chebyshev` metric means that the `r`-neighborhood of a position are all
positions within the hypercube having side length of `2*floor(r)` and being centered in
the origin position.

`:euclidean` metric means that the `r`-neighborhood of a position are all positions whose
cartesian indices have Euclidean distance `≤ r` from the cartesian index of the given
position.

`pathfinder`: Optionally provide an instance of [`Pathfinding.Pathfinder`](@ref) to enable
pathfinding capabilities based on the A* algorithm, see [Path-finding](@ref) in the docs.

An example using `GridSpace` is the [Forest fire](@ref).
"""
function GridSpace(
    d::NTuple{D,Int};
    periodic::Bool = true,
    metric::Symbol = :chebyshev,
    pathfinder::W = nothing,
    moore = nothing,
) where {D,W}
    s = Array{Vector{Int},D}(undef, d)
    if moore ≠ nothing
        @warn "Keyword `moore` is deprecated, use `metric` instead."
        metric = moore == true ? :chebyshev : :euclidean
    end
    for i in eachindex(s)
        s[i] = Int[]
    end

    # TODO: This is bad design. `AStar` should not be mentioned here,
    # nor any `Pathfinding` business. This file should be "pure".
    astar = pathfinder === nothing ? nothing : Pathfinding.AStar(d, periodic, pathfinder)

    return GridSpace{D,periodic,typeof(astar)}(
        s,
        metric,
        Dict{Float64,Hood{D}}(),
        Dict{NTuple{D,Float64},Hood{D}}(),
        astar,
    )
end

#######################################################################################
# %% Implementation of space API
#######################################################################################
function random_position(model::ABM{<:GridSpace})
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

function move_agent!(a::A, pos::Tuple, model::ABM{<:GridSpace,A}) where {A<:AbstractAgent}
    remove_agent_from_space!(a, model)
    a.pos = pos
    add_agent_to_space!(a, model)
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
function initialize_neighborhood!(space::GridSpace{D}, r::Real) where {D}
    d = size(space.s)
    r0 = floor(Int, r)
    if space.metric == :euclidean
        # hypercube of indices
        hypercube = CartesianIndices((repeat([(-r0):r0], D)...,))
        # select subset of hc which is in Hypersphere
        βs = [β for β ∈ hypercube if LinearAlgebra.norm(β.I) ≤ r]
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

function initialize_neighborhood!(space::GridSpace{D}, r::NTuple{D,Real}) where {D}
    @assert space.metric == :chebyshev "Cannot use tuple based neighbor search with the Euclidean metric."
    d = size(space.s)
    r0 = (floor(Int, i) for i in r)
    βs = vec([CartesianIndex(a) for a in Iterators.product([(-ri):ri for ri in r0]...)])
    whole = Region(map(one, d), d)
    hood = Hood{D}(whole, βs)
    push!(space.hoods_tuple, float.(r) => hood)
    return hood
end

"""
    grid_space_neighborhood(α::CartesianIndex, space::GridSpace, r::Real)

Return an iterator over all positions within distance `r` from `α` according to the `space`.

The only reason this function is not equivalent with `nearby_positions` is because
`nearby_positions` skips the current position `α`, while `α` is always included in the
returned iterator (because the `0` index is always included in `βs`).

This function re-uses the source code of TimeseriesPrediction.jl, along with the
helper struct `Hood` and generates neighboring cartesian indices on the fly,
reducing the amount of computations necessary (i.e. we don't "find" new indices,
we only add a pre-determined amount of indices to `α`).
"""
function grid_space_neighborhood(α::CartesianIndex, space::GridSpace, r::Real)
    hood = if haskey(space.hoods, r)
        space.hoods[r]
    else
        initialize_neighborhood!(space, r)
    end
    _grid_space_neighborhood(α, space, hood)
end

"""
    grid_space_neighborhood(α::CartesianIndex, space::GridSpace, r::NTuple)

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
    space::GridSpace{D,true},
    hood,
) where {D}
    return ((mod1.(Tuple(α + β), hood.whole.maxi)) for β in hood.βs)
end

function _grid_space_neighborhood(
    α::CartesianIndex,
    space::GridSpace{D,false},
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

"""
    nearby_ids(pos, model::ABM{<:GridSpace}, r::Vector{Tuple{Int,UnitRange{Int}}})

Return an iterable of ids over specified dimensions of `space` with fine grained control
of distances from `pos` using each value of `r` via the (dimension, range) pattern.

**Note:** Only available for use with non-periodic chebyshev grids.

Example, with a `GridSpace((100, 100, 10))`: `r = [(1, -1:1), (3, 1:2)]` searches
dimension 1 one step either side of the current position (as well as the current
position) and the third dimension searches two positions above current.

For a complete tutorial on how to use this method, see [Battle Royale](@ref).
"""
function nearby_ids(
    pos::ValidPos,
    model::ABM{<:GridSpace},
    r::Vector{Tuple{Int,UnitRange{Int}}},
)
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
function positions(model::ABM{<:GridSpace})
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
    pathfinder = isnothing(space.pathfinder) ? "" : ", pathfinder=$(space.pathfinder)"
    s = "GridSpace with size $(size(space)), metric=$(space.metric), periodic=$(P)$pathfinder"
    print(io, s)
end
