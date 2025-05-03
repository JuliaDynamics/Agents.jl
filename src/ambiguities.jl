
# non-functional ambiguity fixes

add_agent!(::AbstractAgent, ::Union{Function, Type}, ::AgentBasedModel, ::Vararg{Any, N}; kwargs...) where N = error()
add_agent!(::AbstractAgent, ::AgentBasedModel, ::AgentBasedModel) = error()
add_agent!(::AgentBasedModel, ::Union{Function, Type}, ::AgentBasedModel, ::Vararg{Any, N}; kwargs...) where N = error()
add_agent!(::AgentBasedModel, ::AgentBasedModel, ::Vararg{Any, N}; kwargs...) where N = error()
