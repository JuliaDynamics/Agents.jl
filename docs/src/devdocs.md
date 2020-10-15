# Developer Docs

## Creating a new space type
Creating a new space type within Agents.jl is quite simple and requires the extension of only 5 methods to support the entire Agents.jl API. The exact specifications on how to create a new space type are contained within the file: [`[src/core/space_interaction_API.jl]`](https://github.com/JuliaDynamics/Agents.jl/blob/master/src/core/space_interaction_API.jl).

In principle, the following should be done:

1. Think about what the agent position type should be.
1. Think about how the space type will keep track of the agent positions, so that it is possible to implement the function [`nearby_ids`](@ref).
1. Implement the `struct` that represents your new space, while making it a subtype of `AbstractSpace`.
1. Extend `random_position(model)`.
1. Think about how the positions of agents will be updated as agents are moved, added or killed.
1. Extend `move_agent!(agent, pos, model), add_agent_to_space!(agent, model), remove_agent_from_space!(agent, model)`.
1. Extend `nearby_ids(position, model, r)`.

And that's it!
