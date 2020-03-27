### Interactions are tested with the forest fire model
mutable struct Tree <: AbstractAgent
  id::Int
  pos::Tuple{Int, Int}
  status::Bool  # true is green and false is burning
end

# we can put the model initiation in a function
function forest_initiation(;f, d, p, griddims, seed)
  Random.seed!(seed)

  space = GridSpace(griddims, moore = true)

  properties = Dict(:f => f, :d => d, :p => p)
  forest = ABM(Tree, space; properties=properties, scheduler=random_activation)

  # create and add trees to each node with probability d, which determines the density of the forest
  for node in 1:nv(forest)
    pp = rand()
    if pp <= forest.properties[:d]
      tree = Tree(node, (1,1), true)
      add_agent!(tree, node, forest)
    end
  end
  return forest
end

function forest_step!(forest)
  for node in nodes(forest; by = :random)
    if length(forest.space.agent_positions[node]) == 0  # the cell is empty, maybe a tree grows here?
      p = rand()
      if p <= forest.properties[:p]
        bigest_id =  maximum(keys(forest.agents))
        treeid = bigest_id +1
        tree = Tree(treeid, (1,1), true)
        add_agent!(tree, node, forest)
      end
    else
      treeid = forest.space.agent_positions[node][1]  # id of the tree on this cell
      tree = forest[treeid] # the tree on this cell
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
              treen = forest[treeid[1]]
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


@testset "Agent-Space interactions" begin

  model = forest_initiation(f=0.1, d=0.8, p=0.1, griddims=(20, 20), seed=2)  # forest fire model

  agent = model.agents[1]
  move_agent!(agent, (3,4), model)  # node number 63
  @test agent.pos == (3,4)
  @test agent.id in model.space.agent_positions[63]

  new_pos = move_agent!(agent, model)
  @test agent.id in get_node_contents(new_pos, model)

  add_agent!(agent, (2,9), model)
  @test agent.pos == (2,9)
  @test agent.id in get_node_contents((2,9), model)
  @test agent.id in get_node_contents(new_pos, model)

  model1 = ABM(Agent1, GridSpace((3,3)))
  add_agent!(1, model1)
  @test model1.agents[1].pos == (1, 1)
  add_agent!((2,1), model1)
  @test model1.agents[2].pos == (2, 1)

  model2 = ABM(Agent4, GridSpace((3,3)))
  add_agent!(1, model2, 3)
  @test model2.agents[1].pos == (1,1)
  @test 1 in model2.space.agent_positions[1]
  add_agent!((2,1), model2, 2)
  @test model2.agents[2].pos == (2,1)
  @test 2 in model2.space.agent_positions[2]
  ag = add_agent!(model2, 12)
  @test ag.id in get_node_contents(ag, model2)

  @test agent.id in get_node_contents(agent, model)

  ii = model.agents[length(model.agents)]
  @test model[ii.id] == model.agents[ii.id]

  agent = model.agents[1]
  kill_agent!(agent, model)
  @test_throws KeyError model[1]
  @test !in(1, get_node_contents(agent, model))
end
