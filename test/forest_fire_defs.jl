# from the forest fire model in the `examples` directory
mutable struct Tree <: AbstractAgent
  id::Integer
  pos::Tuple{Integer, Integer, Integer}
  status::Bool  # true is green and false is burning
end

mutable struct Forest <: AbstractModel
  space::AbstractSpace
  agents::Array{AbstractAgent}
  scheduler::Function
  f::Float64  # probability that a tree will ignite
  d::Float64  # forest density
  p::Float64  # probability that a tree will grow in an empty space
end

mutable struct MyGrid <: AbstractSpace
  dimensions::Tuple{Integer, Integer, Integer}
  space
  agent_positions::Array  # an array of arrays for each grid node
end


function model_initiation(;f, d, p, griddims, seed)
  Random.seed!(seed)
  agent_positions = [Array{Integer}(undef, 0) for i in 1:gridsize(griddims)]
  mygrid = MyGrid(griddims, grid(griddims, true, true), agent_positions)
  forest = Forest(mygrid, Array{Tree}(undef, 0), random_activation, f, d, p)
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

function model_initiation(;f, d, p, griddims, seed)
  Random.seed!(seed)
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
