export ArraySpace

struct ArraySpace{D} <: AbstractSpace
    s::Array{Vector{Int}, D}
	periodic::Bool
	metric::Symbol
	# `hoods` is a preinitialized container of neighborhood cartesian indices
	hoods::Dict{Float64, Hood{Φ}}
end


"""
	GridSpace(d::NTuple{D, Int}; periodic = true, metric = :chebyshev)
Create a `GridSpace` that has size given by the tuple `d`, having `D` dimensions.
Optionally decide whether the space will be periodic and what will be the distance metric
used, which decides the behavior of e.g. [`space_neighbors`](@ref).
The position type for this space is `NTuple{D, Int}` and valid positions have indices
in the range `1:d[i]` for the `i`th dimension.

`:chebyshev` metric means that the `r`-neighborhood of a node are all
nodes within the hypercube having side length of `2*floor(r)` and being centered in the node.

`:euclidean` metric means all nodes whose cartesian indices have Euclidean distance `≤ r`
from the cartesian index of the given node.
"""
function ArraySpace(d::NTuple{D, Int}; periodic::Bool=true, metric::Symbol = :chebyshev) where {D}
    s = Array{Vector{Int}, D}(undef, d)
    for i in eachindex(s)
        s[i] = Int[]
    end
    return ArraySpace{D}(s, periodic, metric, Dict{Float64, Hood{Φ, periodic}}())
end

#######################################################################################
# %% Implementation of space API
#######################################################################################
function random_position(model::ABM{<:AbstractAgent, <: ArraySpace})
    Tuple(rand(CartesianIndices(model.space.s)))
end

function add_agent_to_space!(a::A, model::ABM{A, <: ArraySpace}) where {A<:AbstractAgent}
    push!(model.space.s[a.pos...], a.id)
    return a
end

function remove_agent_from_space!(a::A, model::ABM{A, <: ArraySpace}) where {A<:AbstractAgent}
    prev = model.space.s[a.pos...]
    ai = findfirst(i -> i == a.id, prev)
    deleteat!(prev, ai)
    return a
end

function move_agent!(a::A, pos::Tuple, model::ABM{A, <: ArraySpace}) where {A<:AbstractAgent}
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

"""
	Hood{Φ}
Internal struct for efficiently finding neighboring nodes to a given node.
It contains pre-initialized neighbor cartesian indices and delimiters of when the
neighboring indices would exceed the size of the underlying array.
"""
struct Hood{Φ} # type P stands for Periodic and is a boolean
	inner::Region{Φ}  # inner field far from boundary
	whole::Region{Φ}
	# `βs` are the actual neighborhood cartesian indices
	βs::Vector{CartesianIndex{Φ}}
end
struct Region{Φ}
	mini::NTuple{Φ,Int}
	maxi::NTuple{Φ,Int}
end

Base.length(r::Region{Φ}) where Φ = prod(r.maxi .- r.mini .+1)
function Base.in(idx, r::Region{Φ}) where Φ
	@inbounds for φ=1:Φ
		r.mini[φ] <= idx[φ] <= r.maxi[φ] || return false
 	end
 	return true
end

# This function calculates how large the inner region should be based on the neighborhood
# βs and the actual array size `d`
function inner_region(βs::Vector{CartesianIndex{Φ}}, d::NTuple{Φ, Int}) where Φ
	mini = Int[]
	maxi = Int[]
	for φ = 1:Φ
		js = map(β -> β[φ], βs) # jth entries
		mi, ma = extrema(js)
		push!(mini, 1 - min(mi, 0))
		push!(maxi, d[φ] - max(ma, 0))
	end
	return Region{Φ}((mini...,), (maxi...,))
end

import LinearAlgebra

function initialize_neighborhood!(space::ArraySpace{Φ}, r::Real) where {Φ}
	d = size(space.s)
	r0 = floor(Int, r)
	if space.metric == :euclidean
		# hypercube of indices
		hypercube = CartesianIndices((repeat([-r0:r0], Φ)...,))
		# select subset of hc which is in Hypersphere
		βs = [β for β ∈ hypercube if LinearAlgebra.norm(β.I) ≤ r]
	elseif space.metric == :chebyshev
		βs = [CartesianIndex(a) for a in Iterators.product([-r0:r0 for φ=1:Φ]...)]
	else
		error("Unknown metric type")
	end
	inner = inner_region(βs, d)
	whole = Region(map(one, d), d)
	hood = Hood{Φ, P}(inner, whole, βs)
	space.hoods[float(r)] = hood
	return hood
end


"""
	grid_space_neighborhood(α::CartesianIndex, space::ArraySpace, r::Real)

Return an iterator over all positions within distance `r` from `α`.

The only reason this function is not equivalent with `node_neighbors` is because
`node_neighbors` skips the current position `α`, while `α` is always included in the
returned iterator (because the `0` index is always included in `βs`).
"""
function grid_space_neighborhood(α::CartesianIndex, space::ArraySpace, r::Real)
	hood = if hasindex(space.hoods, r)
		space.hoods[r]
	else
		initialize_neighborhood!(space, r)
	end

	# These iterators
	if isinner(α, hood)   # `α` won't reach the walls with this Hood
		return (Tuple(α + β) for β in hood.βs)
	elseif space.periodic # `α` WILL reach the walls and then loop
		return ((mod1.(Tuple(α+β), r.maxi)) for β in hood.βs)
	else                  # `α` WILL reach the walls and then stop
		return Iterators.filter(x -> x ∈ hood.whole, (Tuple(α + β) for β in hood.βs))
	end
	return nothing
end

grid_space_neighborhood(α, model::ABM, r) = grid_space_neighborhood!(model.space, α)



# USE THE FOLLOWING FUNCTION TO CREATE AN ITERATOR:
# we don't care about t argument or first [ ] of `s`. we only care about accessing
# s with `α` and `β`. `α` is the current center, the corrent position,
# while `β` are the nearby cartesian indices
# The end goal of this function is to create an iterator which is in fact equivalent with
# node positions
function (r::SpatioTemporalEmbedding{Φ,ConstantBoundary{T},X})(rvec,s,t,α) where {T,Φ,X}
	if α in r.inner
		@inbounds for n=1:X
			rvec[n] = s[ t + r.τ[n] ][ α + r.β[n] ]
		end
	else
		@inbounds for n=1:X
			rvec[n] = α + r.β[n] in r.whole ? s[ t+r.τ[n] ][ α+r.β[n] ] : r.boundary.b
		end
	end
	return nothing
end

function (r::SpatioTemporalEmbedding{Φ,PeriodicBoundary,X})(rvec,s,t,α) where {Φ,X}
	if α in r.inner
		@inbounds for n=1:X
			rvec[n] = s[ t + r.τ[n] ][ α + r.β[n] ]
		end
	else
		@inbounds for n=1:X
			rvec[n] = s[ t + r.τ[n] ][ project_inside(α + r.β[n], r.whole) ]
		end
	end
	return nothing
end


# This is used in periodic boundary conditions
function project_inside(α::CartesianIndex{Φ}, r::Hood{Φ, true}) where Φ
	CartesianIndex(mod.(α.I .-1, r.maxi).+1)
end

###################################################################
# %% neighbors
###################################################################
# TODO: Use the source code of TimeseriesPrediction.jl to select neighborhoods
# with a specific type: cityblock or indices_within_sphere
# If the operation `indices_within_sphere` is expensive, it can be stored
# (since we also store it in TimeseriesPrediction.jl)
# The function that does this index selection (where the indices are stored as cartesian indices)
# is then called in both node_neighbors and space_neighbors (because we want node_neighbors)
# to return tuples for ease of usage, while the conversion is not necessary for space_neighbors




export positions
function positions(model::ABM{<:AbstractAgent, <:ArraySpace})
    x = CartesianIndices(model.space.s)
    return (Tuple(y) for y in x)
end

function positions(model::ABM{<:AbstractAgent, <:ArraySpace}, by)
    itr = collect(positions(model))
    if by == :random
        shuffle!(itr)
    elseif by == :id
        # TODO: By id is wrong...?
        sort!(itr)
    else
        error("unknown `by`")
    end
    return itr
end

function get_node_contents(pos::Tuple, model::ABM{<:AbstractAgent, <:ArraySpace})
    return model.space.s[pos...]
end

# Code a version with explicit D = 2, r = 1 and moore and not periodic for quick benchmark
function node_neighbors(pos::Tuple, model::ABM{<:AbstractAgent, <:ArraySpace})
    d = size(model.space.s)
    rangex = max(1, pos[1]-1):min(d[1], pos[1]+1)
    rangey = max(1, pos[2]-1):min(d[2], pos[2]+1)
    # TODO: This includes current position
    near = Iterators.product(rangex, rangey)
end

function space_neighbors(pos::Tuple, model::ABM{<:AbstractAgent, <:ArraySpace})
    nn = node_neighbors(pos, model)
    s = model.space.s
    Iterators.flatten((s[i...] for i in nn))
end

function space_neighbors(agent::A, model::ABM{A,<:ArraySpace}, args...; kwargs...) where {A}
  all = space_neighbors(agent.pos, model, args...; kwargs...)
  Iterators.filter(!isequal(agent.id), all)
end

###################################################################
# %% pretty printing
###################################################################
function Base.show(io::IO, abm::ArraySpace)
    s = "Array space with size $(size(abm.s)), moore=$(abm.moore), and periodic=$(abm.periodic)"
    print(io, s)
end
