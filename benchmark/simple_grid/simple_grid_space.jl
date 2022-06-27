##########################################################################################
# Implementation of SoloGridSpace
##########################################################################################
using Agents: DiscreteSpace, Hood
# Stores agents in an array whose entry is the agent id.
# empty positions have ID 0, which means that ID 0 is a reserved quantity.
struct SoloGridSpace{D,P} <: AbstractGridSpace
    s::Array{Int,D}
    metric::Symbol
    hoods::Dict{Float64,Hood{D}}
    hoods_tuple::Dict{NTuple{D,Float64},Hood{D}}
end

function SoloGridSpace(d::NTuple{D,Int}; periodic = true, metric = :chebyshev) where {D}
    s = zeros(Int, d)
    return GridSpace{D,periodic}(s, metric,
        Dict{Float64,Hood{D}}(),
        Dict{NTuple{D,Float64},Hood{D}}(),
    )
end

function add_agent_to_space!(a::A, model::ABM{<:SoloGridSpace,A}) where {A<:AbstractAgent}
    model.space.s[a.pos...] = a.id
    return a
end
function remove_agent_from_space!(a::A, model::ABM{<:SoloGridSpace,A}) where {A<:AbstractAgent}
    model.space.s[a.pos...] = 0
    return a
end
# `random_position` comes from `AbstractGridSpace` in spaces/grid.jl.
# move_agent! does not need be implemented.
# The generic version at core/space_interaction_API.jl covers it.
# `grid_space_neighborhood` also comes from spaces/grid.jl
function nearby_ids(pos::ValidPos, model::ABM{<:SoloGridSpace}, r = 1)
    nn = grid_space_neighborhood(CartesianIndex(pos), model, r)
    s = model.space.s
    iterator = (s[i...] for i in nn)
    return Base.Iterators.filter(x -> x ≠ 0, iterator)
end

# lol it's ridiculous how easy this was...

##########################################################################################
# Recreated Schelling
##########################################################################################
