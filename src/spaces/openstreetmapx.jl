export OpenStreetMapXSpace, OSMXPos, OSMXAgent, get_ENU, get_coordinates


struct OpenStreetMapXSpace <: Agents.AbstractSpace    
    osmmap::OpenStreetMapX.MapData
    nodes_agents::Vector{Set{Int}} # all agents that are at a node or on route from node to another one
end


"""
    OpenStreetMapXSpace(m::OpenStreetMapX.MapData)

Create a space for agents on a map loaded by the `OpenStreetMapX`. 
The location of agents within the space is presented by an `OSMXPos` obeject
"""
OpenStreetMapXSpace(m::OpenStreetMapX.MapData) =
    OpenStreetMapXSpace(m, [Set{Int}() for _ in 1:nv(m.g)] )


"""
    OSMXPos(node1::Int, node2::Int, trav::Float64)

Represents a location of an agent betwen nodes `node1` and `node2` who has 
travelled `trav` percentage distance between those two points. 
Note that `trav` needs to be between `0.0` and `1.0`. 

If `node1 == node2` than this means that the agent is located at an exact
node and in that case the value of `trav` is irrelevant. 

Note that it is not required for `node1` and `node2` to be connected 
by a road. This makes possible to represent scenarios such as drones flying
between various points of interests in the city. 

Finally, note that this structure is immutable. There is a separate constructor to handle the movement situation.  
"""
struct OSMXPos
    node1::Int # starting node
    node2::Int # target node
    trav::Float64 #travelled %
end    

OSMXPos(node1::Int, node2::Int) = OSMXPos(node1, node2, 0.0) #agent decided to head to node 2
OSMXPos(node::Int) = OSMXPos(node, node) # agent arrived to node

"""
Creates a new location for an agent on the base of previous location.
"""
function OSMXPos(pos::OSMXPos, delta::Float64)
    trav = pos.trav + delta
    trav >= 1.0 && return OSMXPos(pos.node2)
    trav <= 0.0 && return OSMXPos(pos.node1)
    return OSMXPos(pos.node1, pos.node2, trav)
end

"""
Creates an agent moving on a `OpenStreetMapXSpace` located
at the positio `pos` with an optional set of custom properties `T`.
"""
@with_kw mutable struct OSMXAgent{T} <: AbstractAgent where T
    id::Int    
    pos::OSMXPos
    props::T
    path::Dict{Int,Int} = Dict{Int,Int}() #seqence of nodes
    path_distances::Dict{Int,Float64} = Dict{Int,Float64}() # distance from each node in the sequence
end
OSMXAgent(id::Int, pos::OSMXPos, props::T) where T = OSMXAgent{T}(id=id, pos=pos,props=props)
OSMXAgent(id::Int, pos::OSMXPos) = OSMXAgent{Nothing}(id, pos, nothing)

"""
Return a list of neighbour nodes in `space` for a given `node`. 
"""
function nearby_ids(space::OpenStreetMapXSpace, node::Int)
    neighbors(space.osmmap.g, node)
end

"""
Adds an `agent` to the `model`.
"""
function add_agent!(agent::OSMXAgent{P}, model::ABM{OSMXAgent{P}, OpenStreetMapXSpace}) where P
    push!(model.space.nodes_agents[agent.pos.node1], agent.id)
    model.agents[agent.id]=agent
end

"""
Moves an `agent` to a new position `pos` within the space of a `model`.
"""
function move_agent!(agent::OSMXAgent{P}, pos::OSMXPos, model::ABM{OSMXAgent{P}, OpenStreetMapXSpace}) where P
    if pos.node1 !== agent.pos.node1
        delete!(model.space.nodes_agents[agent.pos.node1], agent.id)
        push!(model.space.nodes_agents[pos.node1], agent.id)
    end
    agent.pos = pos
end

"""
Inject a new travel path to an agent.
The starting point of the path is the node location of the agent 
and the destination is choosen randomply.  
"""
function generate_random_path!(agent::OSMXAgent{P}, model::ABM{OSMXAgent{P}, OpenStreetMapXSpace}) where P 
    nodes = Int[]
    while length(nodes) < 2
        n2 = rand(1:nv(model.space.osmmap.g))
        nodes =  getindex.(Ref(model.space.osmmap.v), 
                shortest_route(model.space.osmmap,model.space.osmmap.n[agent.pos.node1],
                                model.space.osmmap.n[n2])[1])
    end
    empty!(agent.path)
    setindex!.(Ref(agent.path), nodes[2:end], nodes[1:end-1])
    for i in 1:(length(nodes)-1)
        agent.path_distances[nodes[i]] = model.space.osmmap.w[nodes[i], nodes[i+1]]
    end
end

"""
Moves an `agent` within the space of a `model` in the current agents direction 
by `delta_meters` meters. 
If the agent reaches a new node it stops it movement and stays there.

If the agent is starting at a node she selects a new node on its path.
If no nodes are available an new path is generated for the agent via 
calling the new_path_generator function.
"""
function move_agent!(agent::OSMXAgent{P}, model::ABM{OSMXAgent{P}, OpenStreetMapXSpace}, 
        delta_meters::Float64, new_path_generator::Function=generate_random_path!) where P    
    if agent.pos.node1 == agent.pos.node2
        #selecting new travel destination if none exists
        if ! (agent.pos.node1 in keys(agent.path))            
            new_path_generator(agent, model)
        end     
        node2 = agent.path[agent.pos.node1]        
        trav = delta_meters/agent.path_distances[agent.pos.node1]
        if trav >= 1.0
            pos = OSMXPos(node2)
        else
            pos = OSMXPos(agent.pos.node1, node2, trav)
        end        
    else
        pos = OSMXPos(agent.pos, delta_meters/agent.path_distances[agent.pos.node1])
    end 
    move_agent!(agent, pos, model)    
end

"""
Removes an `agent` from the `model` and its space
"""
function kill_agent!(agent::OSMXAgent, model::ABM{OSMXAgent{P}, OpenStreetMapXSpace}) where P
    delete!(model.space.nodes_agents[agent.pos.node1], agent.id)
    pop!(model.agents, agent.id)
end
"""
Returns the nodes not further than `r` edges from the given `node`.
"""
function space_neighbors(node::Int, model::ABM{OSMXAgent{P}, OpenStreetMapXSpace}, r) where P
    neighborhood(model.space.osmmap.g, node, r)
end

"""
Returns `ENU` coordinates for a given `node` in the `model`.

`OpenStreetMapX.distance()` can be used subsequently to calculate 
the distances between nodes. 
"""
function get_ENU(node::Int, model::ABM{OSMXAgent{P}, OpenStreetMapXSpace}) where P
    model.space.osmmap.nodes[model.space.osmmap.n[node]]
end

"""
Returns 2-dimensional coordinates of an agent that can be used for plotting 
"""
function get_coordinates(agent, model)
    pos1 = get_ENU(agent.pos.node1, model)
    pos2 = get_ENU(agent.pos.node2, model)
    (getX(pos1)*(1-agent.pos.trav)+getX(pos2)*(agent.pos.trav),
     getY(pos1)*(1-agent.pos.trav)+getY(pos2)*(agent.pos.trav))
end
