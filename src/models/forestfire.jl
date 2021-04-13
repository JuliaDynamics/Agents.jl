mutable struct Automata <: AbstractAgent
    id::Int
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
    offsets = [Tuple(i == j ? 1 : 0 for i in 1:2) for j in 1:2]
    offsets = vcat(offsets, [.-dir for dir in offsets])
    forest = ABM(Automata; properties = (trees = zeros(Int, griddims), offsets = offsets))
    # Empty = 0, Green = 1, Burning = 2, Burnt = 3
    for I in CartesianIndices(forest.trees)
        if rand(forest.rng) < density
            forest.trees[I] = I[1] == 1 ? 2 : 1
        end
    end
    return forest, dummystep, forest_model_step!
end

function forest_model_step!(forest)
    nx, ny = size(forest.trees)
    for I in findall(isequal(2), forest.trees)
        neighbors = Iterators.filter(
            x -> 1 <= x[1] <= nx && 1 <= x[2] <= ny,
            (I.I .+ n for n in forest.offsets),
        )
        for idx in neighbors
            if forest.trees[idx...] == 1
                forest.trees[idx...] = 2
            end
        end
        forest.trees[I] = 3
    end
end
