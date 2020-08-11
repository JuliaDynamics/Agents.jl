using Agents, Test, Random


# Interactions are tested with the forest fire model

@testset "Agent-Space interactions" begin

  model, agent_step!, model_ste! = Models.forest_fire(f=0.1, d=0.8, p=0.1, griddims=(20, 20), seed=2)

  agent = model.agents[1]
  move_agent!(agent, (3,4), model)  # node number 63
  @test agent.pos == (3,4)
  @test agent.id ∈ model.space.agent_positions[63]

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
