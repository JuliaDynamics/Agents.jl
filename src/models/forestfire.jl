@agent Automata GridAgent{2} begin end

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
    forest = ABM(Automata, space; properties = (trees = zeros(Int, griddims),))
    for I in CartesianIndices(forest.trees)
        if rand(forest.rng) < density
            forest.trees[I] = I[1] == 1 ? 2 : 1
        end
    end
    return forest, dummystep, forest_model_step!
end

function forest_model_step!(forest)
    for I in findall(isequal(2), forest.trees)
        for idx in nearby_positions(I.I, forest)
            if forest.trees[idx...] == 1
                forest.trees[idx...] = 2
            end
        end
        forest.trees[I] = 3
    end
end
