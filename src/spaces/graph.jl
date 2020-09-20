export GraphSpace

#######################################################################################
# Basic space definition
#######################################################################################
struct GraphSpace{G} <: DiscreteSpace
    graph::G
    s::Vector{Vector{Int}}
end

"""
    GraphSpace(graph::AbstractGraph)
Create a `GraphSpace` instance that is underlined by an arbitrary graph from
[LightGraphs.jl](https://github.com/JuliaGraphs/LightGraphs.jl).
The position type for this space is `Int`.
"""
function GraphSpace(graph::G) where {G<:AbstractGraph}
    agent_positions = [Int[] for i in 1:LightGraphs.nv(graph)]
    return GraphSpace{G}(graph, agent_positions)
end

"""
    nv(model::ABM)
Return the number of positions (vertices) in the `model` space.
"""
LightGraphs.nv(abm::ABM{<:Any,<:GraphSpace}) = LightGraphs.nv(abm.space.graph)

"""
    ne(model::ABM)
Return the number of edges in the `model` space.
"""
LightGraphs.ne(abm::ABM{<:Any,<:GraphSpace}) = LightGraphs.ne(abm.space.graph)

function Base.show(io::IO, space::GraphSpace)
    print(
        io,
        "$(nameof(typeof(space))) with $(nv(space.graph)) positions and $(ne(space.graph)) edges",
    )
end


#######################################################################################
# Agents.jl space API
#######################################################################################
random_position(model::ABM{<:AbstractAgent,<:GraphSpace}) = rand(1:nv(model))

function remove_agent_from_space!(
    agent::A,
    model::ABM{A,<:GraphSpace},
) where {A<:AbstractAgent}
    agentpos = agent.pos
    p = agents_in_pos(agentpos, model)
    splice!(p, findfirst(a -> a == agent.id, p))
    return model
end

function move_agent!(
    agent::A,
    pos::ValidPos,
    model::ABM{A,<:GraphSpace},
) where {A<:AbstractAgent}
    oldpos = agent.pos
    p = agents_in_pos(oldpos, model)
    splice!(p, findfirst(a -> a == agent.id, p))
    agent.pos = pos
    push!(agents_in_pos(agent.pos, model), agent.id)
    return agent
end

function add_agent_to_space!(
    agent::A,
    model::ABM{A,<:DiscreteSpace},
) where {A<:AbstractAgent}
    push!(agents_in_pos(agent.pos, model), agent.id)
    return agent
end

# The following two is for the discrete space API:
"""
    agents_in_pos(position, model::ABM{A, <:DiscreteSpace})

Return the ids of agents in the position corresponding to `position`.
"""
agents_in_pos(n::Integer, model::ABM{A,<:GraphSpace}) where {A} = model.space.s[n]
# NOTICE: The return type of `agents_in_pos` must support `length` and `isempty`!

positions(model::ABM{<:AbstractAgent,<:GraphSpace}) = 1:nv(model)

#######################################################################################
# Neighbors
#######################################################################################
function nearby_agents(pos::Int, model::ABM{A,<:GraphSpace}, args...; kwargs...) where {A}
    np = nearby_positions(pos, model, args...; kwargs...)
    # TODO: Use flatten here or something for performance?
    # `model.space.s[nn]...` allocates, because it creates a new array!
    # Also `vcat` allocates a second time
    # We include the current position in the search since we are searching over space
    vcat(model.space.s[pos], model.space.s[np]...)
end

function nearby_positions(
    position::Integer,
    model::ABM{A,<:GraphSpace};
    neighbor_type::Symbol = :default,
) where {A}
    @assert neighbor_type ∈ (:default, :all, :in, :out)
    neighborfn = if neighbor_type == :default
        LightGraphs.neighbors
    elseif neighbor_type == :in
        LightGraphs.inneighbors
    elseif neighbor_type == :out
        LightGraphs.outneighbors
    else
        LightGraphs.all_neighbors
    end
    neighborfn(model.space.graph, position)
end

function nearby_positions(
    position::Integer,
    model::ABM{A,<:GraphSpace},
    radius::Integer;
    kwargs...,
) where {A}
    neighbor_positions = Set(nearby_positions(position, model; kwargs...))
    included_positions = Set()
    for rad in 2:radius
        templist = Vector{Int}()
        for np in neighbor_positions
            if !in(np, included_positions)
                newns = nearby_positions(np, model; kwargs...)
                for newnp in newnps
                    push!(templist, newnp)
                end
            end
        end
        for tt in templist
            push!(neighbor_positions, tt)
        end
    end
    nlist = collect(neighbor_positions)
    j = findfirst(a -> a == position, nlist)
    if j != nothing
        deleteat!(nlist, j)
    end
    return nlist
end
