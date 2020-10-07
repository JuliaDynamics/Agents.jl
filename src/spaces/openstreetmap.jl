export OpenStreetMapSpace

struct OpenStreetMapSpace <: DiscreteSpace
    m::OpenStreetMapX.MapData
    edges::Vector{SimpleWeightedEdge{Int,Float64}}
    s::Vector{Vector{Tuple{Int,Float64}}}
end

function OpenStreetMapSpace(path::AbstractString)
    m = get_map_data(path, use_cache = false, trim_to_connected_graph = true)
    graph = SimpleWeightedDiGraph(m.w)
    # Store an array of edges so we don't constantly collect them
    es = collect(edges(graph))
    # Each edge stores the id of each agent, and its position along the edge.
    # Since the graph is weighted, we know the direction. Speed is not considered
    # in the space
    agent_positions = [Tuple{Int,Float64}[] for i in 1:ne(graph)]
    return OpenStreetMapSpace(m, es, agent_positions)
end

function Base.show(io::IO, s::OpenStreetMapSpace)
    print(
        io,
        "OpenStreetMapSpace with $(length(s.m.roadways)) roadways and $(length(s.m.intersections)) intersections",
    )
end

pos2edge(pos::Tuple{Int,Int,Float64}) = SimpleWeightedEdge(pos...)

function edge_id(pos::Tuple{Int,Int,Float64}, model)
    edge = pos2edge(pos)
    eidx = findfirst(e -> e == edge, model.space.edges)
    isnothing(eidx) && error("Invalid position for OpenStreetMapSpace")
    eidx
end

#######################################################################################
# Agents.jl space API
#######################################################################################

function random_position(model::ABM{<:AbstractAgent,<:OpenStreetMapSpace})
    e = model.space.edges[rand(keys(model.space.edges))]
    (src(e), dst(e), rand() * weight(e))
end

function add_agent_to_space!(
    agent::A,
    model::ABM{A,<:OpenStreetMapSpace},
) where {A<:AbstractAgent}
    eidx = edge_id(agent.pos, model)
    push!(model.space.s[eidx], (agent.id, agent.pos[3]))
    return agent
end

function remove_agent_from_space!(a::A, model::ABM{A,<:OpenStreetMapSpace}) where {A<:AbstractAgent}
    prev = model.space.s[edge_id(a.pos, model)]
    ai = findfirst(i -> i[1] == a.id, prev)
    deleteat!(prev, ai)
    return a
end
