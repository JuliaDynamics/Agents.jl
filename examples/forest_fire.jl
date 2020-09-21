# # Forest fire model

# ![](forest.gif)

# The forest fire model is defined as a cellular automaton on a grid.
# A position can be empty, occupied by a tree, or burning.
# The model of [Drossel and Schwabl (1992)](https://en.wikipedia.org/wiki/Forest-fire_model)
# is defined by four rules which are executed simultaneously:
#
# 1. A burning position turns into an empty position
# 1. A tree will burn if at least one neighbor is burning
# 1. A tree ignites with probability `f` even if no neighbor is burning
# 1. An empty space fills with a tree with probability `p`

# The forest has an innate density `d`, which is the proportion of trees initialized as
# green.
# This model is an example that does _not_ have an `agent_step!` function. It only
# uses a `model_step!`.
# It is also available from the `Models` module as [`Models.forest_fire`](@ref).

# ## Defining the core structures

# We start by defining the agent type
using Agents, Random, AgentsPlots
gr() # hide

mutable struct Tree <: AbstractAgent
    id::Int
    pos::Tuple{Int,Int}
    status::Bool  # true is green and false is burning
end
nothing # hide

# The agent type `Tree` has three fields: `id` and `pos`, which have to be there for any agent,
# and a `status` field that we introduce for this specific model.
# The `status` field will hold `true` for a green tree and `false` for a burning one.
# All other model parameters go into the `AgentBasedModel`.

# We then make a setup function that initializes the model.
function model_initiation(; f = 0.02, d = 0.8, p = 0.01, griddims = (100, 100), seed = 111)
    Random.seed!(seed)
    space = GridSpace(griddims, moore = true)
    properties = Dict(:f => f, :d => d, :p => p)
    forest = AgentBasedModel(Tree, space; properties = properties)

    ## create and add trees to each position with probability d,
    ## which determines the density of the forest
    for position in positions(forest)
        if rand() ≤ forest.d
            add_agent!(position, forest, true)
        end
    end
    return forest
end

forest = model_initiation(f = 0.05, d = 0.8, p = 0.05, griddims = (20, 20), seed = 2)

# ## Defining the step!
# Because of the way the forest fire model is defined, we only need a
# stepping function for the model

function forest_step!(forest)
    for position in positions(forest, by = :random)
        np = ids_in_position(position, forest)
        ## the position is empty, maybe a tree grows here
        if length(np) == 0
            rand() ≤ forest.p && add_agent!(position, forest, true)
        else
            tree = forest[np[1]] # by definition only 1 agent per position
            if tree.status == false  # if it is has been burning, remove it.
                kill_agent!(tree, forest)
            else
                if rand() ≤ forest.f  # the tree ignites spontaneously
                    tree.status = false
                else  # if any neighbor is on fire, set this tree on fire too
                    for pos in nearby_positions(position, forest)
                        neighbors = ids_in_position(pos, forest)
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
nothing # hide

# as we discussed, there is no agent_step! function here, so we will just use `dummystep`.

# ## Running the model

step!(forest, dummystep, forest_step!, 1)
forest

#

step!(forest, dummystep, forest_step!, 10)
forest

# Now we can do some data collection as well using an aggregate function `percentage`:

forest = model_initiation(griddims = (20, 20), seed = 2)
percentage(x) = count(x) / nv(forest)
adata = [(:status, percentage)]

data, _ = run!(forest, dummystep, forest_step!, 10; adata = adata)
data

# Now let's plot the model using green and red color for alive/burning
forest = model_initiation()
step!(forest, dummystep, forest_step!, 1)
treecolor(a) = a.status == 1 ? :green : :red
plotabm(forest; ac = treecolor, ms = 6, msw = 0)

# or animate it
cd(@__DIR__) #src
forest = model_initiation(f = 0.005)
anim = @animate for i in 0:20
    i > 0 && step!(forest, dummystep, forest_step!, 1)
    p1 = plotabm(forest; ac = treecolor, ms = 6, msw = 0)
    title!(p1, "step $(i)")
end

gif(anim, "forest.gif", fps = 2)
