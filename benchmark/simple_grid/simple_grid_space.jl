##########################################################################################
# Implementation of SoloGridSpace
##########################################################################################
using Agents
using Agents: AbstractGridSpace, Hood, ValidPos, grid_space_neighborhood
import Agents: add_agent_to_space!, remove_agent_from_space!, nearby_ids

# Stores agents in an array whose entry is the agent id.
# empty positions have ID 0, which means that ID 0 is a reserved quantity.
struct SoloGridSpace{D,P} <: AbstractGridSpace{D,P}
    s::Array{Int,D}
    metric::Symbol
    hoods::Dict{Float64,Hood{D}}
    hoods_tuple::Dict{NTuple{D,Float64},Hood{D}}
end
function SoloGridSpace(d::NTuple{D,Int}; periodic = true, metric = :chebyshev) where {D}
    s = zeros(Int, d)
    return SoloGridSpace{D,periodic}(s, metric,
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
    iterator = (model.space.s[i...] for i in nn)
    return Base.Iterators.filter(x -> x ≠ 0, iterator)
end
# However we do need to extend this:
Base.isempty(pos, model::ABM{<:SoloGridSpace}) = model.space.s[pos...] == 0

# lol it's ridiculous how easy this was...

##########################################################################################
# Recreated Schelling
##########################################################################################
mutable struct SoloGridSpaceAgent <: AbstractAgent
    id::Int
    pos::NTuple{2, Int} # Notice that position type depends on space-to-be-used
    group::Int
    happy::Bool
end

# Notice that these functions are fully identical with the GridSpace version.
function initialize_sologridspace()
    space = SoloGridSpace(grid_size; periodic = false)
    properties = Dict(:min_to_be_happy => min_to_be_happy)
    rng = Random.Xoshiro(1234)
    model = ABM(SoloGridSpaceAgent, space; properties, rng)
    N = grid_size[1]*grid_size[2]*grid_occupation
    for n in 1:N
        group = n < N / 2 ? 1 : 2
        agent = SoloGridSpaceAgent(n, (1, 1), group, false)
        add_agent_single!(agent, model)
    end
    return model
end

function agent_step_sologridspace!(agent, model)
    nearby_same = 0
    for neighbor in nearby_agents(agent, model)
        if agent.group == neighbor.group
            nearby_same += 1
        end
    end
    if nearby_same ≥ model.min_to_be_happy
        agent.happy = true
    else
        move_agent_single!(agent, model)
    end
    return
end

model_sologridspace = initialize_sologridspace()
println("Benchmarking SoloGridSpace version")
@btime step!($model_sologridspace, agent_step_sologridspace!)