#########################
### Forest fire model ###
#########################
using Agents
using Random

mutable struct Tree{T<:Integer} <: AbstractAgent
  id::T
  pos::Tuple{T, T}
  status::Bool  # true is green and false is burning
end

mutable struct Forest{T<:AbstractSpace, Y<:AbstractVector, Z<:AbstractFloat} <: AbstractModel
  space::T
  agents::Y
  scheduler::Function
  f::Z  # probability that a tree will ignite
  d::Z  # forest density
  p::Z  # probability that a tree will grow in an empty space
end

mutable struct MyGrid{T<:Integer, Y<:AbstractVector} <: AbstractSpace
  dimensions::Tuple{T, T}
  space
  agent_positions::Y  # an array of arrays for each grid node
end

# we can put the model initiation in a function
function model_initiation(;f, d, p, griddims, seed)
  Random.seed!(seed)
  # initialize the model
  # we start the model without creating the agents first
  agent_positions = [Int64[] for i in 1:gridsize(griddims)]
  mygrid = MyGrid(griddims, grid(griddims, false, true), agent_positions)
  forest = Forest(mygrid, Array{Tree}(undef, 0), random_activation, f, d, p)

  # create and add trees to each node with probability d, which determines the density of the forest
  for node in 1:gridsize(forest.space.dimensions)
    pp = rand()
    if pp <= forest.d
      tree = Tree(node, (1,1), true)
      add_agent!(tree, node, forest)
    end
  end
  return forest
end

function forest_step!(forest)
  shuffled_nodes = Random.shuffle(1:gridsize(forest.space.dimensions))
  for node in shuffled_nodes  # randomly go through the cells and 
    if length(forest.space.agent_positions[node]) == 0  # the cell is empty, maybe a tree grows here?
      p = rand()
      if p <= forest.p
        treeid = forest.agents[end].id +1
        tree = Tree(treeid, (1,1), true)
        add_agent!(tree, node, forest)
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


forest = model_initiation(f=0.05, d=0.8, p=0.01, griddims=(20, 20), seed=2)
agent_properties = [:status, :pos]
steps_to_collect_data = collect(1:10)

# aggregators = [length, count]
# data = step!(dummystep, forest_step!, forest, 10, agent_properties, aggregators, steps_to_collect_data)
data = step!(dummystep, forest_step!, forest, 10, agent_properties, steps_to_collect_data)

# 9. explore data visually
visualize_data(data)

# or plot trees on a grid
for i in 1:10
  visualize_2D_agent_distribution(data, forest, Symbol("pos_$i"), types=Symbol("status_$i"), savename="step_$i", cc=Dict(true=>"green_ryb", false=>"red"))
end

# 10. Running batch
agent_properties = [:status, :pos]
data = batchrunner(dummystep, forest_step!, forest, 10, agent_properties, steps_to_collect_data, 10)
# Create a column with the mean and std of the :status_count columns from differen steps.
columnnames = vcat([:status_count], [Symbol("status_count_$i") for i in 1:9])
using StatsBase
# combine_columns!(data, columnnames, [StatsBase.mean, StatsBase.std])

# optionally write the results to file
write_to_file(df=data, filename="forest_model.csv")
