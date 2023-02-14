#=
This file implements the "agent-space interaction API" for `nothing`, ie
no space type
=#

function add_agent_to_space!(::A, ::ABM{Nothing,A}) where {A<:AbstractAgent}
    nothing
end
function remove_agent_from_space!(::A, ::ABM{Nothing,A}) where {A<:AbstractAgent}
    nothing
end
nearby_ids(position, model::ABM{Nothing}, r = 1) = allids(model)
