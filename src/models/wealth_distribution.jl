mutable struct WealthAgent <: AbstractAgent
    id::Int
    wealth::Int
end

"""
    wealth_distribution(; numagents = 100, initwealth = 1)
Same as in [Wealth Distribution model](@ref).
"""
function wealth_distribution(; numagents = 100, initwealth = 1)
    model = ABM(WealthAgent, scheduler = random_activation)
    for i in 1:numagents
        add_agent!(model, initwealth)
    end
    return model, agent_step!, dummystep
end

function agent_step!(agent, model)
    agent.wealth == 0 && return # do nothing
    ragent = random_agent(model)
    agent.wealth -= 1
    ragent.wealth += 1
end