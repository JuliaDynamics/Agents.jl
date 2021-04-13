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
using InteractiveDynamics
using CairoMakie

@agent Automata GridAgent{2} begin end
nothing # hide

# The agent type `Automata` is effectively a dummy agent, for which we will invoke
# [`dummystep`](@ref) when stepping the model.

# We then make a setup function that initializes the model.
function forest_fire(; density = 0.7, griddims = (100, 100))
    space = GridSpace(griddims; periodic = false, metric = :euclidean)
    ## The `trees` field is coded such that
    ## Empty = 0, Green = 1, Burning = 2, Burnt = 3
    forest = ABM(Automata, space; properties = (trees = zeros(Int, griddims),))
    for I in CartesianIndices(forest.trees)
        if rand(forest.rng) < density
            ## Set the trees at the left edge on fire
            forest.trees[I] = I[1] == 1 ? 2 : 1
        end
    end
    return forest
end

forest = forest_fire()

# ## Defining the step!

function tree_step!(forest)
    ## Find trees that are burning (coded as 2)
    for I in findall(isequal(2), forest.trees)
        for idx in nearby_positions(I.I, forest)
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

plotkwargs = (
    add_colorbar = false,
    heatarray = :trees,
    heatkwargs = (
        colorrange = (0, 3),
        colormap = cgrad([:white, :green, :red, :darkred]; categorical = true),
    ),
)
fig, _ = abm_plot(model; plotkwargs...)
fig

# or animate it
Random.seed!(10)
forest = forest_fire(density = 0.6)
add_agent!(forest) # Add one dummy agent so that abm_video will allow us to plot.
abm_video(
    "forest.mp4",
    forest,
    dummystep,
    tree_step!;
    as = 0,
    framerate = 5,
    frames = 20,
    spf = 5,
    title = "Forest Fire",
    plotkwargs...,
)
nothing # hide
# ```@raw html
# <video width="auto" controls autoplay loop>
# <source src="../forest.mp4" type="video/mp4">
# </video>
# ```
