
function forest_step!(forest)
  shuffled_nodes = shuffle(1:gridsize(forest.space.dimensions))
  for node in shuffled_nodes  # randomly go through the cells and 
    if length(forest.space.agent_positions[node]) == 0  # the cell is empty, maybe a tree grows here?
      p = rand()
      if p <= forest.p
        treeid = forest.agents[end].id +1
        tree = Tree(treeid, (1,1,1), true)
        add_agent_to_grid!(tree, node, forest)
        push!(forest.agents, tree)
      end
    else
      treeid = forest.space.agent_positions[node][1]  # id of the tree on this cell
      tree = id_to_agent(treeid, forest)  # the tree on this cell
      if tree.status == false  # if it is has been burning, remove it.
        kill_agent!(tree, forest)
      else
        f = rand()
        if f <= forest.f  # the tree ignites on fire
          tree.status = false
        else  # if any neighbor is on fire, set this tree on fire too
          neighbor_cells = node_neighbors(tree, forest)
          for cell in neighbor_cells
            treeid = get_node_contents(cell, forest)
            if length(treeid) != 0  # the cell is not empty
              treen = id_to_agent(treeid[1], forest)
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

# we can put the model initiation in a function
function model_initiation(;f, d, p, griddims)
  # initialize the model
  # we start the model without creating the agents first
  agent_positions = [Array{Integer}(undef, 0) for i in 1:gridsize(griddims)]
  mygrid = MyGrid(griddims, grid(griddims, true, true), agent_positions)
  forest = Forest(mygrid, Array{Tree}(undef, 0), random_activation, f, d, p)

  # create and add trees to each node with probability d, which determines the density of the forest
  for node in 1:gridsize(forest.space.dimensions)
    pp = rand()
    if pp <= forest.d
      tree = Tree(node, (1,1,1), true)
      add_agent_to_grid!(tree, node, forest)
      push!(forest.agents, tree)
    end
  end
  return forest
end
