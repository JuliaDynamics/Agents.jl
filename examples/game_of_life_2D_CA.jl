# # Conway's game of life

# ![](game_of_life.gif)

# https://en.wikipedia.org/wiki/Conway%27s_Game_of_Life

using Agents
using AgentsPlots
using Plots
using Random

# ## 1. Define the rules

# Rules of Conway's game of life: DSRO (Death, Survival, Reproduction, Overpopulation).
# Cells die if the number of their living neighbors is <D or >O,
# survive if the number of their living neighbors is ≤S,
# come to life if their living neighbors are  ≥R and ≤O.
rules = (2, 3, 3, 3)

# ## 2. Build the model

# First, define an agent type. It needs to have the compulsary `id` and `pos` fields, as well as an `status` field that is `true` for cells that are alive and `false` otherwise.

mutable struct Cell <: AbstractAgent
  id::Int
  pos::Tuple{Int, Int}
  status::Bool
end

# The following function builds a 2D cellular automaton. `rules` is of type `Tuple{Int,Int,Int, Int}` representing DSRO.

# `dims` is a tuple of integers determining the width and height of the grid environment.
# `Moore` specifies whether cells connect to their diagonal neighbors.

# This function creates a model where all cells are "off".

function build_model(;rules::Tuple, dims=(100,100), Moore=true)
  space = GridSpace(dims, moore=Moore)
  properties = Dict(:rules => rules)
  model = ABM(Cell, space; properties = properties)
  node_idx = 1
  for x in 1:dims[1]
    for y in 1:dims[2]
      add_agent_pos!(Cell(node_idx, (x,y), false), model)
      node_idx += 1
    end
  end
  return model
end

# Now we define a stepping function for the model to apply the rules to agents.

function ca_step!(model)
  new_status = fill(false, nagents(model))
  for (agid, ag) in model.agents
    nlive = nlive_neighbors(ag, model)
    if ag.status == true && (nlive ≤ model.rules[4] && nlive ≥ model.rules[1])
        new_status[agid] = true
    elseif  ag.status == false && (nlive ≥ model.rules[3] && nlive ≤ model.rules[4])
        new_status[agid] = true
    end
  end

  for k in keys(model.agents)
    model.agents[k].status = new_status[k]
  end
end

function nlive_neighbors(ag, model)
  neighbors_coords = node_neighbors(ag, model)
  nlive = 0
  for nc in neighbors_coords
    nag = model.agents[Agents.coord2vertex((nc[2], nc[1]), model)]
    if nag.status == true
      nlive += 1
    end
  end
  return nlive
end

# now we can instantiate the model:
Random.seed!(120)
model = build_model(rules = rules, dims = (50, 50), Moore = true)

# Let's make some random cells on
for i in 1:nv(model)
  if rand() < 0.2
    model.agents[i].status = true
  end
end

# ## 3. Animate the model

# We use the `plotabm` function from `AgentsPlots.jl` package for creating an animation.

as(x) = 3
ac(x) = x[1].status == true ? :black : :white
am(x) = :square
anim = @animate for i in 0:100
  i > 0 && step!(model, dummystep, ca_step!, 1)
  p1 = plotabm(model; ac=ac, as=as, am=am)
end

# We can now save the animation to a gif.

gif(anim, "game_of_life.gif", fps = 5)
