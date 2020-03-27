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

  # create and add trees to each node with probability d, which determines the density of the forest
  for node in 1:nv(forest)
    pp = rand()
    if pp <= forest.properties[:d]
      # Set all trees in the first column on fire.
      if id2agent(node, model).pos[1] == 1
        tree = Tree(node, (1,1), 2)
      else
        tree = Tree(node, (1,1), 1)
      end
      add_agent!(tree, node, forest)
    end
  end
  return forest
end

function tree_step!(Tree, forest)
  if Tree.status == 2
    Tree.status = 3
    neighbor_cells = node_neighbors(tree, forest)
    for cell in neighbor_cells
      treeid = get_node_contents(cell, forest)
      if length(treeid) != 0 # the cell is not empty
        treen = forest.agents[treeid[1]]
        if treen.status == 1
          treen.status = 2
        end
      end
    end
  end
end
