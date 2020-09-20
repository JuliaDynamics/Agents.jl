using Agents, Random

mutable struct Tree <: AbstractAgent
    id::Int
    pos::Tuple{Int, Int}
    status::Bool  # true is green and false is burning
end

function model_initiation(; f, p, griddims)
    space = GridSpace(griddims, periodic = false)
    properties = Dict(:f => f, :p => p)
    forest = AgentBasedModel(Tree, space; properties=properties)
    for pos in positions(forest)
        add_agent!(pos, forest, true)
    end
    return forest
end


# f is combustion prob., p is regrowth prob.
println("time to initialize model")
@time forest = model_initiation(f=0.0001, p=0.01, griddims=(400, 400))

# ## Defining the step!
# Because of the way the forest fire model is defined, we only need a
# stepping function for the model

function forest_step!(forest)
  for pos in positions(forest, by = :random)
    ap = agents_in_pos(pos, forest)
    ## the position is empty, maybe a tree grows here
    if length(ap) == 0
        rand() ≤ forest.properties[:p] && add_agent!(pos, forest, true)
    else
      tree = forest[ap[1]] # by definition only 1 agent per position
      if tree.status == false  # if it is has been burning, remove it.
        kill_agent!(tree, forest)
      else
        if rand() ≤ forest.properties[:f]  # the tree ignites spntaneously
          tree.status = false
        else  # if any neighbor is on fire, set this tree on fire too
          for n_pos in nearby_positions(pos, forest)
            neighbors = agents_in_pos(n_pos, forest)
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

println("time to do a single step!")
step!(forest, dummystep, forest_step!) # compile
@time for i in 1:50
           step!(forest, dummystep, forest_step!)
       end
