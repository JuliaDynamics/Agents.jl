# # Forest fire model

# ```@raw html
# <video width="auto" controls autoplay loop>
# <source src="../forest.mp4" type="video/mp4">
# </video>
# ```

# The forest fire model is defined as a cellular automaton on a grid.
# A position can be empty or occupied by a tree which is ok, burning or burnt.
# We implement a slightly different ruleset to that of
# [Drossel and Schwabl (1992)](https://en.wikipedia.org/wiki/Forest-fire_model),
# so that our implementation can be compared with other ABM frameworks
#
# 1. A burning position turns into a burnt position
# 1. A tree will burn if at least one neighbor is burning

# The forest has an innate `density`, which is the proportion of trees initialized as
# `green`, however all trees that reside on the left side of the grid are `burning`.
# The model is also available from the `Models` module as [`Models.forest_fire`](@ref).

# ## Defining the core structures

# Cellular automata don't necessarily require an agent-like structure. Here we will
# demonstrate how a model focused solution is possible.
using Agents, Random
using CairoMakie

mutable struct Automata <: AbstractAgent
    id::Int
end
nothing # hide

# The agent type `Automata` is effectively a dummy agent, for which we will invoke
# [`dummystep`](@ref) when stepping the model.

# We then make a setup function that initializes the model.
function forest_fire(; density = 0.7, griddims = (100, 100))
    offsets = [Tuple(i == j ? 1 : 0 for i in 1:2) for j in 1:2]
    offsets = vcat(offsets, [.-dir for dir in offsets])
    ## The `trees` field is coded such that
    ## Empty = 0, Green = 1, Burning = 2, Burnt = 3
    ## `offsets` is a quick way of identifying euclidean neighbors.
    forest = ABM(Automata; properties = (trees = zeros(Int, griddims), offsets = offsets))
    for I in CartesianIndices(forest.trees)
        if rand(forest.rng) < density
            ## Set the trees at the left edge on fire
            forest.trees[I] = I[1] == 1 ? 2 : 1
        end
    end
    return forest
end

# Notice we have not even required the use of a space for this simple model.

forest = forest_fire()

# ## Defining the step!

function tree_step!(forest)
    nx, ny = size(forest.trees)
    ## Find trees that are burning (coded as 2)
    for I in findall(isequal(2), forest.trees)
        ## Look up all euclidean neighbors
        neighbors = Iterators.filter(
            x -> 1 <= x[1] <= nx && 1 <= x[2] <= ny,
            (I.I .+ n for n in forest.offsets),
        )
        for idx in neighbors
            ## If a neighbor is Green (1), set it on fire (2)
            if forest.trees[idx...] == 1
                forest.trees[idx...] = 2
            end
        end
        ## Finally, any burning tree is burnt out (2)
        forest.trees[I] = 3
    end
end
nothing # hide

# ## Running the model

Agents.step!(forest, dummystep, tree_step!, 1)
count(t == 3 for t in forest.trees) # Number of burnt trees on step 1

#

Agents.step!(forest, dummystep, tree_step!, 10)
count(t == 3 for t in forest.trees) # Number of burnt trees on step 11

# Now we can do some data collection as well using an aggregate function `percentage`:

Random.seed!(2)
forest = forest_fire(griddims = (20, 20))
burnt_percentage(f) = count(t == 3 for t in f.trees) / prod(size(f.trees))
mdata = [burnt_percentage]

_, data = run!(forest, dummystep, tree_step!, 10; mdata)
data

# Now let's plot the model. We use green for unburnt trees, red for burning and a
# dark red for burnt.
forest = forest_fire()
Agents.step!(forest, dummystep, tree_step!, 1)

treecolor = cgrad([:white, :green, :red, :darkred]; categorical = true)
trees = Observable(forest.trees)
fig = Figure(resolution = (600, 600))
GLMakie.heatmap(fig[1, 1], trees; colormap = treecolor)
fig

# or animate it
Random.seed!(10)
forest = forest_fire(density = 0.6)
trees = Observable(forest.trees)
fig = Figure(resolution = (600, 600))
GLMakie.heatmap(fig[1, 1], trees; colormap = treecolor, colorrange = (0, 3))
record(fig, "forest.mp4"; framerate = 5) do io
    for j in 1:20
        recordframe!(io)
        Agents.step!(forest, dummystep, tree_step!, 5)
        trees[] = trees[]
    end
    recordframe!(io)
end
nothing # hide
# ```@raw html
# <video width="auto" controls autoplay loop>
# <source src="../forest.mp4" type="video/mp4">
# </video>
# ```
