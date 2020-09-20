export GridSpace

struct Region{D}
    mini::NTuple{D,Int}
    maxi::NTuple{D,Int}
end

"""
    Hood{D}
Internal struct for efficiently finding neighboring nodes to a given node.
It contains pre-initialized neighbor cartesian indices and delimiters of when the
neighboring indices would exceed the size of the underlying array.
"""
struct Hood{D} # type P stands for Periodic and is a boolean
    inner::Region{D}  # inner field far from boundary
    whole::Region{D}
    # `βs` are the actual neighborhood cartesian indices
    βs::Vector{CartesianIndex{D}}
end

struct GridSpace{D,P} <: DiscreteSpace
    s::Array{Vector{Int},D}
    metric::Symbol
    # `hoods` is a preinitialized container of neighborhood cartesian indices
    hoods::Dict{Float64,Hood{D}}
end


"""
    GridSpace(d::NTuple{D, Int}; periodic = true, metric = :chebyshev)
Create a `GridSpace` that has size given by the tuple `d`, having `D ≥ 1` dimensions.
Optionally decide whether the space will be periodic and what will be the distance metric
used, which decides the behavior of e.g. [`space_neighbors`](@ref).
The position type for this space is `NTuple{D, Int}` and valid nodes have indices
in the range `1:d[i]` for the `i`th dimension.

`:chebyshev` metric means that the `r`-neighborhood of a node are all
nodes within the hypercube having side length of `2*floor(r)` and being centered in the node.

`:euclidean` metric means that the `r`-neighborhood of a node are all nodes whose cartesian
indices have Euclidean distance `≤ r` from the cartesian index of the given node.
"""
function GridSpace(
        d::NTuple{D,Int};
        periodic::Bool = true,
        metric::Symbol = :chebyshev,
        moore = nothing
    ) where {D}
    s = Array{Vector{Int},D}(undef, d)
    if moore ≠ nothing
        @warn "Keyword `moore` is deprecated, use `metric` instead."
        metric = moore == true ? :chebyshev : :euclidean
    end
    for i in eachindex(s)
        s[i] = Int[]
    end
    return GridSpace{D,periodic}(s, metric, Dict{Float64,Hood{D}}())
end

#######################################################################################
# %% Implementation of space API
#######################################################################################
function random_position(model::ABM{<:AbstractAgent,<:GridSpace})
    Tuple(rand(CartesianIndices(model.space.s)))
end

function add_agent_to_space!(a::A, model::ABM{A,<:GridSpace}) where {A<:AbstractAgent}
    push!(model.space.s[a.pos...], a.id)
    return a
end

function remove_agent_from_space!(a::A, model::ABM{A,<:GridSpace}) where {A<:AbstractAgent}
    prev = model.space.s[a.pos...]
    ai = findfirst(i -> i == a.id, prev)
    deleteat!(prev, ai)
    return a
end

function move_agent!(a::A, pos::Tuple, model::ABM{A,<:GridSpace}) where {A<:AbstractAgent}
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

# This function calculates how large the inner region should be based on the neighborhood
# βs and the actual array size `d`
function inner_region(βs::Vector{CartesianIndex{D}}, d::NTuple{D,Int}) where {D}
    mini = Int[]
    maxi = Int[]
    for φ in 1:D
        js = map(β -> β[φ], βs) # jth entries
        mi, ma = extrema(js)
        push!(mini, 1 - min(mi, 0))
        push!(maxi, d[φ] - max(ma, 0))
    end
    return Region{D}((mini...,), (maxi...,))
end

# This function initializes the standard cartesian indices that needs to be added to some
# index `α` to obtain its neighborhood
import LinearAlgebra
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
    inner = inner_region(βs, d)
    whole = Region(map(one, d), d)
    hood = Hood{D}(inner, whole, βs)
    space.hoods[float(r)] = hood
    return hood
end


"""
    grid_space_neighborhood(α::CartesianIndex, space::GridSpace, r::Real)

Return an iterator over all nodes within distance `r` from `α` according to the `space`.

The only reason this function is not equivalent with `node_neighbors` is because
`node_neighbors` skips the current position `α`, while `α` is always included in the
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

function _grid_space_neighborhood(
    α::CartesianIndex,
    space::GridSpace{D,true},
    hood,
) where {D}
    # if α ∈ hood.inner     # `α` won't reach the walls with this Hood
    #   return Base.Generator(β -> Tuple(α + β), hood.βs)
    # else                  # `α` WILL reach the walls and then loop
    #   return Base.Generator(β-> mod1.(Tuple(α+β), hood.whole.maxi), hood.βs)
    # end

    # Here you will notice that we actually do not make a separation of whether the
    # point α is near to the wall or not, and always take the modulo nevertheless.
    # The reason is that Generators depend on the function used, and thus they would be
    # type unstable if different function was used for different value of α.
    # To make it type stable we would have to collect the result, but apparently
    # this makes it slower because of allocations... so better take the mod1 always.

    return ((mod1.(Tuple(α + β), hood.whole.maxi)) for β in hood.βs)
end

function _grid_space_neighborhood(
    α::CartesianIndex,
    space::GridSpace{D,false},
    hood,
) where {D}
    # if α ∈ hood.inner     # `α` won't reach the walls with this Hood
    #   return Iterators.filter(always_true, (Tuple(α + β) for β in hood.βs))
    # else                  # `α` WILL reach the walls and then stop
    #   return Iterators.filter(x -> x ∈ hood.whole, (Tuple(α + β) for β in hood.βs))
    # end
    return Iterators.filter(x -> x ∈ hood.whole, (Tuple(α + β) for β in hood.βs))
end

grid_space_neighborhood(α, model::ABM, r) = grid_space_neighborhood(α, model.space, r)

##########################################################################################
# %% Extend neighbors API for spaces
##########################################################################################
function space_neighbors(pos::ValidPos, model::ABM{<:AbstractAgent,<:GridSpace}, r = 1)
    nn = grid_space_neighborhood(CartesianIndex(pos), model, r)
    s = model.space.s
    Iterators.flatten((s[i...] for i in nn))
    # IterWrapper(Iterators.flatten((s[i...] for i in nn)))
end

struct IterWrapper{S}
    iter::S
end
Base.eltype(::Type{IterWrapper}) = Int
Base.IteratorEltype(::Type{IterWrapper}) = HasEltype()
Base.iterate(iter::IterWrapper) = iterate(iter.iter)
Base.iterate(iter::IterWrapper, state) = iterate(iter.iter, state)

function node_neighbors(pos::ValidPos, model::ABM{<:AbstractAgent,<:GridSpace}, r = 1)
    nn = grid_space_neighborhood(CartesianIndex(pos), model, r)
    Iterators.filter(!isequal(pos), nn)
end


#######################################################################################
# %% Further discrete space  functions
#######################################################################################
function nodes(model::ABM{<:AbstractAgent,<:GridSpace})
    x = CartesianIndices(model.space.s)
    return (Tuple(y) for y in x)
end

function get_node_contents(pos::ValidPos, model::ABM{<:AbstractAgent,<:GridSpace})
    return model.space.s[pos...]
end

###################################################################
# %% pretty printing
###################################################################
Base.size(space::GridSpace) = size(space.s)
function Base.show(io::IO, space::GridSpace{D, P}) where {D, P}
    s = "GridSpace with size $(size(space)), metric=$(space.metric) and periodic=$(P)"
    print(io, s)
end
