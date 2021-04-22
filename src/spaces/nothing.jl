#=
This file implements the "agent-space interaction API" for `nothing`, ie
no space type
=#

function kill_agent!(agent::A, model::ABM{Nothing,A}) where {A<:AbstractAgent}
    index = findfirst(x -> x == agent.id, model.agents.id)
    index !== nothing && deleteat!(model.agents.id, index)
end

function add_agent!(agent::A, model::ABM{Nothing,A}) where {A<:AbstractAgent}
    add_agent_pos!(agent, model)
end

function add_agent_pos!(agent::A, model::ABM{Nothing,A}) where {A<:AbstractAgent}
    model[agent.id] = agent
    return model[agent.id]
end

function add_agent!(
        model::ABM{Nothing, A},
        properties...;
        kwargs...,
    ) where {A<:AbstractAgent}
    add_agent_pos!(A(nextid(model), properties...; kwargs...), model)
end
