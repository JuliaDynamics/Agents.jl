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
    space = GridSpace(griddims)
    properties = Dict(:f => f, :d => d, :p => p)
    forest = AgentBasedModel(Tree, space; properties = properties)

    ## create and add trees to each node with probability d,
    ## which determines the density of the forest
    for node in nodes(forest)
        if rand() ≤ forest.d
            add_agent!(node, forest, true)
        end
    end
    return forest, dummystep, forest_model_step!
end

function forest_model_step!(forest)
    for node in nodes(forest, :random)
        np = agents_in_pos(node, forest)
        ## the position is empty, maybe a tree grows here
        if length(np) == 0
            rand() ≤ forest.p && add_agent!(node, forest, true)
        else
            tree = forest[np[1]] # by definition only 1 agent per position
            if tree.status == false  # if it is has been burning, remove it.
                kill_agent!(tree, forest)
            else
                if rand() ≤ forest.f  # the tree ignites spontaneously
                    tree.status = false
                else  # if any neighbor is on fire, set this tree on fire too
                    for pos in nearby_positions(node, forest)
                        neighbors = agents_in_pos(pos, forest)
                        length(neighbors) == 0 && continue
                        if any(n -> !forest.agents[n].status, neighbors)
                            tree.status = false
                            break
                        end
                    end
                end
            end
        end
    end
end
