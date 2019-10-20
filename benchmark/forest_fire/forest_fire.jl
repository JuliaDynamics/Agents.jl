#########################
### Forest fire model ###
#########################
using Agents
using Random

mutable struct Tree{T<:Integer} <: AbstractAgent
  id::T
  pos::Tuple{T, T}
  status::T  # 1 is green, 2 is burning, 3 is burned
end

mutable struct Forest{T<:AbstractSpace, Y<:AbstractVector, Z<:AbstractFloat} <: AbstractModel
  space::T
  agents::Y
  scheduler::Function
  d::Z  # forest density
end

mutable struct MyGrid{T<:Integer, Y<:AbstractVector} <: AbstractSpace
  dimensions::Tuple{T, T}
  space::SimpleGraph
  agent_positions::Y
end

function model_initiation(;d, griddims, seed)
  Random.seed!(seed)
  # initialize the model
  # we start the model without creating the agents first
  agent_positions = [Int64[] for i in 1:gridsize(griddims)]
  mygrid = MyGrid(griddims, grid(griddims, false, false), agent_positions)
  forest = Forest(mygrid, Array{Tree}(undef, 0), random_activation, d)

  # create and add trees to each node with probability d, which determines the density of the forest. If a tree is on one edge of the grid (x=0), set it on fire.
  idcounter = 0
  for node in 1:gridsize(forest.space.dimensions)
    pp = rand()
    if pp <= forest.d
      idcounter += 1
      if vertex2coord(node, forest)[1] == 1
        tree = Tree(idcounter, (1,1), 2)
      else
        tree = Tree(idcounter, (1,1), 1)
      end
      add_agent!(tree, node, forest)
    end
  end
  return forest
end

function forest_step!(forest)
  shuffled_nodes = Random.shuffle(1:length(forest.agents))
  still_burning = false
  for node in shuffled_nodes  # randomly go through the trees
    tree = forest.agents[node]
    if tree.status == 2  # if it is has been burning
      still_burning = true
      tree.status = 3
      # set its neighbor trees on fire
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
  if still_burning == false
    return "All trees burned down."
  end
end
