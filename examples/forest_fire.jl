# # Forest fire model

# ![](forest.gif)

# The forest fire model is defined as a cellular automaton on a grid.
# A position can be empty or occupied by a tree which is ok, burning or burnt.
# We implement a slightly different ruleset to that of
# [Drossel and Schwabl (1992)](https://en.wikipedia.org/wiki/Forest-fire_model),
# so that our implementation can be compared with other ABM frameworks
#
# 1. A burning position turns into a burnt position
# 1. A tree will burn if at least one neighbor is burning

# The forest has an innate `density`, which is the proportion of trees initialized as
# `green`, however all trees that reside at `x=1` on the grid are `burning`.
# The model is also available from the `Models` module as [`Models.forest_fire`](@ref).

# ## Defining the core structures

# We start by defining the agent type
using Agents, Random, AgentsPlots
gr() # hide

mutable struct Tree <: AbstractAgent
    id::Int
    pos::Tuple{Int,Int}
    status::Symbol  #:green, :burning, :burnt
end
nothing # hide

# The agent type `Tree` has three fields: `id` and `pos`, which have to be there for any agent,
# and a `status` field that we introduce for this specific model.
# The `status` field will be `:green` when the tree is ok, `:burning` when on fire,
# and finally `:burnt`.

# We then make a setup function that initializes the model.
function forest_fire(; density = 0.7, griddims = (100, 100))
    space = GridSpace(griddims; periodic = false, metric = :euclidean)
    forest = AgentBasedModel(Tree, space)
    ## create and add trees to each position with a probability
    ## determined by the `density`.
    for position in positions(forest)
        if rand() < density
            ## Set the trees at position x=1 on fire
            state = position[1] == 1 ? :burning : :green
            add_agent!(position, forest, state)
        end
    end
    return forest
end

forest = forest_fire()

# ## Defining the step!
# Because of the way the forest fire model is defined, we only need a
# stepping function for the agents

function tree_step!(tree, forest)
    ## The current tree is burning
    if tree.status == :burning
        ## Find all green neighbors and set them on fire
        for neighbor in nearby_agents(tree, forest)
            if neighbor.status == :green
                neighbor.status = :burning
            end
        end
        tree.status = :burnt
    end
end
nothing # hide

# ## Running the model

step!(forest, tree_step!, 1)
count(t->t.status == :burnt, allagents(forest))

#

step!(forest, tree_step!, 10)
count(t->t.status == :burnt, allagents(forest))

# Now we can do some data collection as well using an aggregate function `percentage`:

Random.seed!(2)
forest = forest_fire(griddims = (20, 20))
burnt_percentage(m) = count(t->t.status == :burnt, allagents(m)) / length(positions(m))
mdata = [burnt_percentage]

_, data = run!(forest, tree_step!, 10; mdata)
data

# Now let's plot the model. We use green for unburnt trees, red for burning and a
# dark red for burnt.
forest = forest_fire()
step!(forest, tree_step!, 1)

function treecolor(a)
    color = :green
    if a.status == :burning
        color = :red
    elseif a.status == :burnt
        color = :darkred
    end
    color
end

plotabm(forest; ac = treecolor, ms = 5, msw = 0)

# or animate it
cd(@__DIR__) #src
forest = forest_fire(density = 0.6)
anim = @animate for i in 0:10
    i > 0 && step!(forest, tree_step!, 5)
    p1 = plotabm(forest; ac = treecolor, ms = 5, msw = 0)
    title!(p1, "step $(i)")
end

gif(anim, "forest.gif", fps = 2)
