# # Forest fire model

# The forest fire model is defined as a cellular automaton on a grid.
# A cell can be empty, occupied by a tree, or burning.
# The model of [Drossel and Schwabl (1992)](https://en.wikipedia.org/wiki/Forest-fire_model)
# is defined by four rules which are executed simultaneously:
#
# 1. A burning cell turns into an empty cell
# 1. A tree will burn if at least one neighbor is burning
# 1. A tree ignites with probability `f` even if no neighbor is burning
# 1. An empty space fills with a tree with probability `p`

# The forest has an innate density `d`, which is the proportion of trees initialized as
# green.
# This model is an example that does _not_ have an `agent_step!` function. It only
# uses a `model_step!`

# ## Defining the types

# We start by defining the agent type
using Agents, Random

mutable struct Tree <: AbstractAgent
    id::Int
    pos::Tuple{Int, Int}
    status::Bool  # true is green and false is burning
end

# The agent type `Tree` has three fields: `id` and `pos`, which have to be there for any agent,
# and a `status` field that we introduce for this specific model.
# The `status` field will hold `true` for a green tree and `false` for a burning one.
# All other model parameters go into the `AgentBasedModel`

# We then make a setup function that initializes the model:
function model_initiation(; f, d, p, griddims, seed = 111)
    Random.seed!(seed)
    space = Space(griddims, moore = true)
    properties = Dict(:f => f, :d => d, :p => p)
    forest = ABM(Tree, space; properties=properties)

    # create and add trees to each node with probability d,
    # which determines the density of the forest
    for node in 1:gridsize(forest)
        pp = rand()
        if pp ≤ forest.properties[:d]
            tree = Tree(node, (1,1), true)
            add_agent!(tree, node, forest)
        end
    end
    return forest
end

forest = model_initiation(f=0.05, d=0.8, p=0.05, griddims=(20, 20), seed=2)

# ## Defining the step!
# Here we define the `model_step!` function:

function forest_step!(forest)
  shuffled_nodes = Random.shuffle(1:gridsize(forest))
  for node in shuffled_nodes  # randomly go through the cells and
    # the cell is empty, maybe a tree grows here?
    if length(forest.space.agent_positions[node]) == 0
      p = rand()
      if p ≤ forest.properties[:p]
        bigest_id = maximum(keys(forest.agents))
        treeid = bigest_id +1
        tree = Tree(treeid, (1,1), true)
        add_agent!(tree, node, forest)
      end
    else
      treeid = forest.space.agent_positions[node][1]  # id of the tree on this cell
      tree = id2agent(treeid, forest)  # the tree on this cell
      if tree.status == false  # if it is has been burning, remove it.
        kill_agent!(tree, forest)
      else
        f = rand()
        if f ≤ forest.properties[:f]  # the tree ignites on fire
          tree.status = false
        else  # if any neighbor is on fire, set this tree on fire too
          neighbor_cells = node_neighbors(tree, forest)
          for cell in neighbor_cells
            treeid = get_node_contents(cell, forest)
            if length(treeid) != 0  # the cell is not empty
              treen = id2agent(treeid[1], forest)
              if treen.status == false
                tree.status = false
                break
              end
            end
          end
        end
      end
    end
  end
end

# as we discussed, there is no agent_step! function here, so we will just use `dummystep`.
# Now we can run the model a bit:

step!(forest, dummystep, forest_step!)
nagents(forest)

#

step!(forest, dummystep, forest_step!, 10)
nagents(forest)

# Now we can do some data collection as well
forest = model_initiation(f=0.05, d=0.8, p=0.01, griddims=(20, 20), seed=2)
agent_properties = Dict(:status => [x -> count(x)/400])
when = 1:10


data = step!(forest, dummystep, forest_step!, 10, agent_properties, when=when)

average_green(x) = count(x)/400
agent_properties = Dict(:status => [average_green])
forest = model_initiation(f=0.05, d=0.8, p=0.01, griddims=(20, 20), seed=2)
data = step!(forest, dummystep, forest_step!, 10, agent_properties, when=when)

# We can perform some basic visualization of our model using `AgentsPlots`
using AgentsPlots
for i in 1:2
    visualize_2D_agent_distribution(data, forest, Symbol("pos_$i"), types=Symbol("status_$i"), savename="step_$i", cc=Dict(true=>"green", false=>"red"))
end
# TODO: save and display the plots

# 10. Running batch
agent_properties = [:status, :pos]
data = step!(forest, dummystep, forest_step!, 10, agent_properties, when=when, replicates=10)


# Remember that it is possible to explore a `DataFrame` visually and interactively
# through `DataVoyager`, by doing
# ```julia
# using DataVoyager
# Voyager(data)
# ```
