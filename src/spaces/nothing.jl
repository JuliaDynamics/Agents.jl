#=
This file implements the "agent-space interaction API" for `nothing`, ie
no space type
=#

function kill_agent!(agent::A, model::ABM{Nothing,A,Dict{Int,A}}) where {A<:AbstractAgent}
    delete!(model.agents, agent.id)
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
