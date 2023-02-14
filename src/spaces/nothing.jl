#=
This file implements the "agent-space interaction API" for `nothing`, ie
no space type. In contrast to all other extensions, here we have to extend
the `kill_agent!` and `add_agent!` functions directly,
otherwise they will try to add `nothing` to the agent position.
=#

function add_agent_to_space!(::A, ::ABM{Nothing,A}) where {A<:AbstractAgent}
    nothing
end

function add_agent!(agent::A, model::ABM{Nothing,A}) where {A<:AbstractAgent}
    add_agent_pos!(agent, model)
end

function add_agent!(A::Type{<:AbstractAgent}, model::ABM{Nothing}, properties...; kwargs...)
    id = nextid(model)
    newagent = A(id, properties...; kwargs...)
    add_agent_pos!(newagent, model)
end

nearby_ids(position, model::ABM{Nothing}, r = 1) = allids(model)
remove_agent_from_space!(agent, model::ABM{Nothing}) = nothing
add_agent_to_space!(agent, model::ABM{Nothing}) = nothing
