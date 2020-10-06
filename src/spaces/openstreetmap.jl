export OpenStreetMapSpace

struct OpenStreetMapSpace <: DiscreteSpace
    m::OpenStreetMapX.MapData
    graph::SimpleDiGraph
    s::Vector{Vector{Int}}
end

function OpenStreetMapSpace(m::OpenStreetMapX.MapData)
    agent_positions = [Int[] for i in 1:LightGraphs.nv(m.g)]
    return OpenStreetMapSpace(m, m.g, agent_positions)
end

function Base.show(io::IO, s::OpenStreetMapSpace)
    print(
        io,
        "OpenStreetMapSpace with $(length(s.m.roadways)) roadways and $(length(s.m.intersections)) intersections",
    )
end

#######################################################################################
# Agents.jl space API
#######################################################################################
random_position(model::ABM{<:AbstractAgent,<:OpenStreetMapSpace}) = rand(1:nv(model))
