mutable struct Tree <: AbstractAgent
    id::Int
    pos::Tuple{Int,Int}
    status::Symbol  #:green, :burning, :burnt
end

"""
``` julia
forest_fire(;
    density = 0.8,
    griddims = (100, 100)
)
```
Same as in [Forest fire model](@ref).
"""
function forest_fire(; density = 0.7, griddims = (100, 100))
    space = GridSpace(griddims; periodic = false, metric = :euclidean)
    forest = AgentBasedModel(Tree, space)
    for position in positions(forest)
        if rand() < density
            state = position[1] == 1 ? :burning : :green
            add_agent!(position, forest, state)
        end
    end
    return forest, forest_agent_step!, dummystep
end

function forest_agent_step!(tree, forest)
    if tree.status == :burning
        for neighbor in nearby_agents(tree, forest)
            if neighbor.status == :green
                neighbor.status = :burning
            end
        end
        tree.status = :burnt
    end
end

