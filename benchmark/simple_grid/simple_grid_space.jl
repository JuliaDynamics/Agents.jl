##########################################################################################
# Implementation of SoloGridSpace
##########################################################################################
using Agents
using Agents: AbstractGridSpace, Hood, ValidPos
import Agents: add_agent_to_space!, remove_agent_from_space!, nearby_ids
import Agents: grid_space_neighborhood, initialize_neighborhood!
using LinearAlgebra

# Stores agents in an array whose entry is the agent id.
# empty positions have ID 0, which means that ID 0 is a reserved quantity.
struct SoloGridSpace{D,P} <: AbstractGridSpace{D,P}
    s::Array{Int,D}
    metric::Symbol
    neighboring_indices::Dict{Float64,Vector{NTuple{D,Int}}}
    neighboring_indices_no_0::Dict{Float64,Vector{NTuple{D,Int}}}
end
function SoloGridSpace(d::NTuple{D,Int}; periodic = true, metric = :chebyshev) where {D}
    s = zeros(Int, d)
    return SoloGridSpace{D,periodic}(s, metric,
        Dict{Float64,Vector{NTuple{D,Int}}}(), Dict{Float64,Vector{NTuple{D,Int}}}(),
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
# `random_position` comes from `AbstractGridSpace` in spaces/grid.jl
# move_agent! does not need be implemented.
# The generic version at core/space_interaction_API.jl covers it.
# `random_empty` also comes from spaces_discrete.jl as long as we extend:
Base.isempty(pos, model::ABM{<:SoloGridSpace}) = model.space.s[pos...] == 0

# Here we implement a new version for neighborhoods, similar to abusive_unkillable.jl.
indices_within_radius(model::ABM, r::Real) = indices_within_radius(model.space, r::Real)
indices_within_radius_no_0(model::ABM, r::Real) = indices_within_radius_no_0(model.space, r::Real)
function indices_within_radius(space::SoloGridSpace{D}, r::Real)::Vector{NTuple{D, Int}} where {D}
    if haskey(space.neighboring_indices, r)
        space.neighboring_indices[r]
    else
        βs = initialize_neighborhood(space, r)
        space.neighboring_indices[float(r)] = βs
    end
end
function indices_within_radius_no_0(space::SoloGridSpace{D}, r::Real)::Vector{NTuple{D, Int}} where {D}
    if haskey(space.neighboring_indices_no_0, r)
        space.neighboring_indices_no_0[r]
    else
        βs = initialize_neighborhood(space, r)
        z = ntuple(i -> 0, Val{D}())
        filter!(x -> x ≠ z, βs)
        space.neighboring_indices_no_0[float(r)] = βs
    end
end

# Make grid space Abstract if indeed faster
function initialize_neighborhood(space::SoloGridSpace{D}, r::Real) where {D}
    r0 = floor(Int, r)
    if space.metric == :euclidean
        # hypercube of indices
        hypercube = CartesianIndices((repeat([(-r0):r0], D)...,))
        # select subset of hc which is in Hypersphere
        βs = [Tuple(β) for β ∈ hypercube if LinearAlgebra.norm(β.I) ≤ r]
    elseif space.metric == :manhattan
        hypercube = CartesianIndices((repeat([(-r0):r0], D)...,))
        βs = [β for β ∈ hypercube if sum(abs.(β.I)) <= r0]
    elseif space.metric == :chebyshev
        βs = vec([Tuple(a) for a in Iterators.product([(-r0):r0 for φ in 1:D]...)])
    else
        error("Unknown metric type")
    end
    return βs
end

# And finally extend `nearby_ids` given a position
# TODO: Check if making functionals instead of closures is faster
function nearby_ids(pos::NTuple{D, Int}, model::ABM{<:SoloGridSpace{D,true}}, r = 1;
    get_nearby_indices = indices_within_radius) where {D}
    nindices = get_nearby_indices(model, r)
    space_array = model.space.s
    space_size = size(space_array)
    array_accesses_iterator = (space_array[(mod1.(pos .+ β, space_size))...] for β in nindices)
    # Notice that not all positions are valid; some are empty! Need to filter:
    valid_pos_iterator = Base.Iterators.filter(x -> x ≠ 0, array_accesses_iterator)
    return valid_pos_iterator
end

function nearby_ids(pos::NTuple{D, Int}, model::ABM{<:SoloGridSpace{D,false}}, r = 1;
    get_nearby_indices = indices_within_radius) where {D}
    nindices = get_nearby_indices(model, r)
    space_array = model.space.s
    positions_iterator = (pos .+ β for β in nindices)
    # Here we combine in one filtering step both valid accesses to the space array
    # but also that the accessed location is not empty (i.e., id is not 0)
    valid_pos_iterator = Base.Iterators.filter(
        pos -> checkbounds(Bool, space_array, pos...) && space_array[pos...] ≠ 0,
        positions_iterator
    )
    return (space_array[pos...] for pos in valid_pos_iterator)
end

function nearby_ids(a::A, model::ABM{<:SoloGridSpace{D,false},A}, r = 1) where {D,A<:AbstractAgent}
    return nearby_ids(a.pos, model, r; get_nearby_indices = indices_within_radius_no_0)
end


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
    rng = Random.Xoshiro(rand(UInt))
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
    nearby_same = count_nearby_same(agent, model)
    if nearby_same ≥ model.min_to_be_happy
        agent.happy = true
    else
        move_agent_single!(agent, model)
    end
    return
end
function count_nearby_same(agent, model)
    nearby_same = 0
    for neighbor in nearby_agents(agent, model)
        if agent.group == neighbor.group
            nearby_same += 1
        end
    end
    return nearby_same
end

model_sologridspace = initialize_sologridspace()
println("Benchmarking SoloGridSpace version")
@btime step!($model_sologridspace, agent_step_sologridspace!) setup = (model_sologridspace = initialize_sologridspace())

println("Benchmarking SoloGridSpace version: count nearby same")
model = initialize_sologridspace()
@btime count_nearby_same(agent, model) setup = (agent = random_agent(model))
