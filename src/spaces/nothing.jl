#=
This file implements the "agent-space interaction API" for `nothing`, ie
no space type. In contrast to all other extensions, here we have to extend
the `remove_agent!` and `add_agent!` functions directly,
otherwise they will try to add `nothing` to the agent position.
=#

# We need to extend this one, because otherwise there is a `pos` that
# is attempted to be given to the agent creation...
function add_agent!(A::Type{<:AbstractAgent}, model::ABM{Nothing}, args::Vararg{Any, N}; kwargs...) where {N}
    id = nextid(model)
    if isempty(kwargs)
        newagent = A(id, args...)
    else
        newagent = A(; id = id, kwargs...)
    end
    add_agent_pos!(newagent, model)
end

nearby_ids(agent::AbstractAgent, model::ABM{Nothing}, r = 1) = allids(model)
remove_agent_from_space!(agent, model::ABM{Nothing}) = nothing
add_agent_to_space!(agent, model::ABM{Nothing}) = nothing
remove_all_from_space!(::ABM{Nothing}) = nothing

