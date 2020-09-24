mutable struct Tree <: AbstractAgent
    id::Int
    pos::Tuple{Int,Int}
    status::Bool  # true is green and false is burning
end

"""
``` julia
forest_fire(;
    f = 0.02,
    d = 0.8,
    p = 0.01,
    griddims = (100, 100),
    seed = 111
)
```
Same as in [Forest fire model](@ref).
"""
function forest_fire(; f = 0.02, d = 0.8, p = 0.01, griddims = (100, 100), seed = 111)
    Random.seed!(seed)
    space = GridSpace(griddims; periodic = false)
    properties = Dict(:f => f, :d => d, :p => p)
    forest = AgentBasedModel(Tree, space; properties = properties)
    for position in positions(forest)
        if rand() ≤ forest.d
            add_agent!(position, forest, true)
        end
    end
    return forest, dummystep, forest_model_step!
end

function forest_model_step!(forest)
    for pos in positions(forest, :random)
        trees = agents_in_position(pos, forest)
        if length(trees) == 0
            rand() ≤ forest.p && add_agent!(pos, forest, true)
        else
            tree = first(trees) # by definition only 1 agent per position
            if rand() ≤ forest.f || any(n -> !n.status, nearby_agents(tree, forest))
                # the tree randomly ignites or is set on fire if a neighbor is burning
                tree.status = false
            end
        end
    end
end
