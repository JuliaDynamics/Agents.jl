mutable struct WealthInSpace <: AbstractAgent
    id::Int
    pos::NTuple{2,Int}
    wealth::Int
end

"""
``` julia
wealth_distribution(; 
    dims = (25, 25),
    wealth = 1,
    M = 1000
)
```
Same as in [Wealth distribution model](@ref).
"""
function wealth_distribution(; dims = (25, 25), wealth = 1, M = 1000)
    space = GridSpace(dims, periodic = true)
    model = ABM(WealthInSpace, space; scheduler = random_activation)
    for i in 1:M # add agents in random nodes
        add_agent!(model, wealth)
    end
    return model, wealth_distribution_agent_step!, dummystep
end

function wealth_distribution_agent_step!(agent, model)
    agent.wealth == 0 && return # do nothing
    agent_node = coord2vertex(agent.pos, model)
    neighboring_positions = nearby_positions(agent_node, model)
    push!(neighboring_positions, agent_node) # also consider current position
    rnode = rand(neighboring_positions) # the position that we will exchange with
    available_ids = get_node_contents(rnode, model)
    if length(available_ids) > 0
        random_neighbor_agent = model[rand(available_ids)]
        agent.wealth -= 1
        random_neighbor_agent.wealth += 1
    end
end
