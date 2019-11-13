mutable struct Tree{T<:Integer} <: AbstractAgent
  id::T
  pos::Tuple{T, T}
  status::Bool  # true is green and false is burning
end

# we can put the model initiation in a function
function model_initiation(;f, d, p, griddims, seed)
  Random.seed!(seed)

  space = Space(griddims, moore = true)

  properties = Dict(:f => f, :d => d, :p => p)
  forest = ABM(Tree, space; properties=properties, scheduler=random_activation)

  # create and add trees to each node with probability d, which determines the density of the forest
  for node in 1:gridsize(forest)
    pp = rand()
    if pp <= forest.properties[:d]
      tree = Tree(node, (1,1), true)
      add_agent!(tree, node, forest)
    end
  end
  return forest
end

function forest_step!(forest)
  shuffled_nodes = Random.shuffle(1:gridsize(forest))
  for node in shuffled_nodes  # randomly go through the cells and 
    if length(forest.space.agent_positions[node]) == 0  # the cell is empty, maybe a tree grows here?
      p = rand()
      if p <= forest.properties[:p]
        treeid = forest.agents[end].id +1
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
        if f <= forest.properties[:f]  # the tree ignites on fire
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
