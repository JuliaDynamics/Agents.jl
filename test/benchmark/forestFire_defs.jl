mutable struct Tree <: AbstractAgent
    id::Int
    pos::Tuple{Int,Int}
    status::Bool  # true is green and false is burning
end

function model_initiation(; f = 0.02, d = 0.8, p = 0.01, griddims=(100,100), seed = 111)
    Random.seed!(seed)
    space = GridSpace(griddims, moore = true)
    properties = Dict(:f => f, :d => d, :p => p)
    forest = AgentBasedModel(Tree, space; properties = properties)

    ## create and add trees to each node with probability d,
    ## which determines the density of the forest
    for node in nodes(forest)
        if rand() ≤ forest.d
            add_agent!(node, forest, true)
        end
    end
    return forest
end

function forest_step!(forest)
  for node in nodes(forest, by = :random)
    nc = get_node_contents(node, forest)
    ## the cell is empty, maybe a tree grows here
    if length(nc) == 0
        rand() ≤ forest.p && add_agent!(node, forest, true)
    else
      tree = forest[nc[1]] # by definition only 1 agent per node
      if tree.status == false  # if it is has been burning, remove it.
        kill_agent!(tree, forest)
      else
        if rand() ≤ forest.f  # the tree ignites spontaneously
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