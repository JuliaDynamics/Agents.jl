#=
This file implements the "agent-space interaction API" for `nothing`, ie
no space type
=#

function kill_agent!(agent::A, model::ABM{A,Nothing}) where {A<:AbstractAgent}
    delete!(model.agents, agent.id)
end
