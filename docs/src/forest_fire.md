```@meta
EditURL = "<unknown>/../Agents/examples/forest_fire.jl"
```

# Forest fire model

The forest fire model is defined as a cellular automaton on a grid.
A cell can be empty, occupied by a tree, or burning.
The model of [Drossel and Schwabl (1992)](https://en.wikipedia.org/wiki/Forest-fire_model)
is defined by four rules which are executed simultaneously:

1. A burning cell turns into an empty cell
1. A tree will burn if at least one neighbor is burning
1. A tree ignites with probability `f` even if no neighbor is burning
1. An empty space fills with a tree with probability `p`

The forest has an innate density `d`, which is the proportion of trees initialized as
green.
This model is an example that does _not_ have an `agent_step!` function. It only
uses a `model_step!`

## Defining the core structures

We start by defining the agent type

```@example forest_fire
using Agents, Random

mutable struct Tree <: AbstractAgent
    id::Int
    pos::Tuple{Int, Int}
    status::Bool  # true is green and false is burning
end
```

The agent type `Tree` has three fields: `id` and `pos`, which have to be there for any agent,
and a `status` field that we introduce for this specific model.
The `status` field will hold `true` for a green tree and `false` for a burning one.
All other model parameters go into the `AgentBasedModel`

We then make a setup function that initializes the model

```@example forest_fire
function model_initiation(; f, d, p, griddims, seed = 111)
    Random.seed!(seed)
    space = Space(griddims, moore = true)
    properties = Dict(:f => f, :d => d, :p => p)
    forest = AgentBasedModel(Tree, space; properties=properties)

    # create and add trees to each node with probability d,
    # which determines the density of the forest
    for node in nodes(forest)
        if rand() ≤ forest.properties[:d]
            add_agent!(node, forest, true)
        end
    end
    return forest
end

forest = model_initiation(f=0.05, d=0.8, p=0.05, griddims=(20, 20), seed=2)
```

## Defining the step!
Because of the way the forest fire model is defined, we only need a
stepping function for the model

```@example forest_fire
function forest_step!(forest)
  for node in nodes(forest, by = :random)
    nc = get_node_contents(node, forest)
    # the cell is empty, maybe a tree grows here
    if length(nc) == 0
        rand() ≤ forest.properties[:p] && add_agent!(node, forest, true)
    else
      tree = id2agent(nc[1], forest) # by definition only 1 agent per node
      if tree.status == false  # if it is has been burning, remove it.
        kill_agent!(tree, forest)
      else
        if rand() ≤ forest.properties[:f]  # the tree ignites spntaneously
          tree.status = false
        else  # if any neighbor is on fire, set this tree on fire too
          for cell in node_neighbors(node, forest)
            neighbors = get_node_contents(cell, forest)
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
```

as we discussed, there is no agent_step! function here, so we will just use `dummystep`.

## Running the model

```@example forest_fire
step!(forest, dummystep, forest_step!)
forest
```

```@example forest_fire
step!(forest, dummystep, forest_step!, 10)
forest
```

Now we can do some data collection as well

```@example forest_fire
forest = model_initiation(f=0.05, d=0.8, p=0.01, griddims=(20, 20), seed=2)
percentage(x) = count(x)/nv(forest)
agent_properties = Dict(:status => [percentage])

data = step!(forest, dummystep, forest_step!, 10, agent_properties)
```

Or we can run parallel/batch simulations
```julia
agent_properties = [:status, :pos]
data = step!(forest, dummystep, forest_step!, 10, agent_properties, when=when, replicates=10);
```

Remember that it is possible to explore a `DataFrame` visually and interactively
through `DataVoyager`, by doing
```julia
using DataVoyager
Voyager(data)
```

*This page was generated using [Literate.jl](https://github.com/fredrikekre/Literate.jl).*

