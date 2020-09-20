#########################
### Forest fire model ###
#########################
using Agents
using Random

mutable struct Tree <: AbstractAgent
  id::Int
  pos::Tuple{Int, Int}
  status::Int  # 1: green, 2: burning, 3: burned
end

# we can put the model initiation in a function
function model_initiation(;d, griddims, seed)
  Random.seed!(seed)

  space = GridSpace(griddims, moore = true)

  properties = Dict(:d => d)
  forest = ABM(Tree, space; properties=properties, scheduler=random_activation)

  # create and add trees to each position with probability d, which determines the density of the forest
  for pos in positions(forest)
    pp = rand()
    if pp <= forest.properties[:d]
      # Set all trees in the first column on fire.
      if pos[1] == 1
        tree = Tree(pos, (1,1), 2)
      else
        tree = Tree(pos, (1,1), 1)
      end
      add_agent!(tree, pos, forest)
    end
  end
  return forest
end

function tree_step!(tree, forest)
  if tree.status == 2
    tree.status = 3
    for pos in nearby_positions(tree, forest)
      treeid = agents_in_pos(pos, forest)
      if length(treeid) != 0 # the position is not empty
        treen = forest.agents[treeid[1]]
        if treen.status == 1
          treen.status = 2
        end
      end
    end
  end
end
