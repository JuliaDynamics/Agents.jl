# # Two-dimensional cellular automata
# Agents.jl provides a module (CA2D) to create and plot 2D cellular automata.

using Agents
using AgentsPlots
using Plots

# ## 1. Define the rule and agent object

# Rules of Conway's game of life: DSRO (Death, Survival, Reproduction, Overpopulation).
# Cells die if the number of their living neighbors is <D or >O,
# survive if the number of their living neighbors is ≤S,
# come to life if their living neighbors are  ≥R and ≤O.
rules = (2, 3, 3, 3)

mutable struct Cell <: AbstractAgent
  id::Int
  pos::Tuple{Int, Int}
  status::Bool
end

# ## 2. Build the model

"""
    build_model(;rules::Tuple, dims=(100,100), Moore=true)

Builds a 2D cellular automaton. `rules` is of type `Tuple{Integer,Integer,Integer}`. The numbers are DSR (Death, Survival, Reproduction). Cells die if the number of their living neighbors are <D, survive if the number of their living neighbors are <=S, come to life if their living neighbors are as many as R. `dims` is the x and y size a grid. `Moore` specifies whether cells should connect to their diagonal neighbors.
"""
function build_model(;rules::Tuple, dims=(100,100), Moore=true)
  space = GridSpace(dims, moore=Moore)
  properties = Dict(:rules => rules, :Moore=>Moore)
  model = ABM(Cell, space; properties = properties, scheduler=by_id)
  node_idx = 1
  for x in 1:dims[1]
    for y in 1:dims[2]
      add_agent_pos!(Cell(node_idx, (x,y), false), model)
      node_idx += 1
    end
  end
  return model
end

# Now we define a stepping function for the model to apply the rules to agents
# This function creates a model where all cells are "off".
function ca_step!(model)
  new_status = Array{Bool}(undef, nagents(model))
  for (agid, ag) in model.agents
    neighbors_coords = node_neighbors(ag, model)
    nlive = 0
    for nc in neighbors_coords
      nag = model.agents[Agents.coord2vertex(nc, model)]
      if nag.status == true
        nlive += 1
      end
    end

    if ag.status == true
      if nlive > model.properties[:rules][4] || nlive < model.properties[:rules][1]
        new_status[agid] = false
      else
        new_status[agid] = true
      end
    else
      if nlive ≥ model.properties[:rules][3] && nlive ≤ model.properties[:rules][4]
        new_status[agid] = true
      else
        new_status[agid] = false
      end
    end
  end

  for k in keys(model.agents)
    model.agents[k].status = new_status[k]
  end
end

model = build_model(rules = rules, dims = (100, 100), Moore = true)

# Let's make some random cells on
for i in 1:nv(model)
    if rand() < 0.1
        model.agents[i].status = true
    end
end

# ## 3. Animate the model

# We use the `plotabm` function from `AgentsPlots.jl` package for creating an animation.

runs = 30
as(x) = 1.5
ac(x) = x[1].status == true ? :black : :white
am(x) = :square
anim = @animate for i in 1:runs
    step!(model, dummystep, ca_step!, 1)
    p1 = plotabm(model; ac=ac, as=as, am=am)
end

# We can now save the animation to a gif.

AgentsPlots.gif(anim, "game_of_life.gif")

