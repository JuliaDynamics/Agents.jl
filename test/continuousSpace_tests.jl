@testset "Continuous space" begin

  # Basic model initialization
  space1 = ContinuousSpace(2; periodic = true, extend = (1, 1))
  space2 = ContinuousSpace(2; periodic = false, extend = (1, 1))
  space3 = ContinuousSpace(2; periodic = true, extend = (2, 1))
  space4 = ContinuousSpace(2; periodic = true, extend = (1, 2))
  space5 = ContinuousSpace(2; periodic = true, extend = (2, 2))
  space6 = ContinuousSpace(1; periodic = true, extend = (1,))
  space7 = ContinuousSpace(3; periodic = true, extend = (1,1,1))
  space8 = ContinuousSpace(3; periodic = false, extend = (1,1,1))

  @test space1.D == 2
  @test space2.D == 2
  @test space3.D == 2
  @test space4.D == 2
  @test space5.D == 2
  @test space6.D == 1
  @test space7.D == 3
  @test space8.D == 3

  model1 = ABM(Agent6, space1)
  model2 = ABM(Agent6, space2)
  model3 = ABM(Agent6, space3)
  model4 = ABM(Agent6, space4)
  model5 = ABM(Agent6, space5)
  model6 = ABM(Agent6, space6)

  @test nagents(model1) == 0
  @test Agents.collect_ids(DBInterface.execute(model1.space.db, "select id from tab")) == []

  # add_agent! with no existing agent (the agent is created)
  pos = (0.5, 0.5)
  vel = (0.2, 0.1)
  dia = 0.01
  add_agent!(pos, model1, vel, dia)
  @test Agents.collect_ids(DBInterface.execute(model1.space.db, "select id from tab")) == [1]
  dbrow = DBInterface.execute(model1.space.db, "select * from tab") |> DataFrame;
  @test dbrow[1, :a] == 0.5
  @test dbrow[1, :b] == 0.5

  # move_agent! without provided update_vel! function
  move_agent!(model1.agents[1], model1)
  dbrow = DBInterface.execute(model1.space.db, "select * from tab") |> DataFrame;
  @test dbrow[1, :a] == 0.7
  @test dbrow[1, :b] == 0.6
  @test dbrow[1, :a] == model1.agents[1].pos[1]
  @test dbrow[1, :b] == model1.agents[1].pos[2]

  kill_agent!(model1.agents[1], model1)
  dbrow = DBInterface.execute(model1.space.db, "select * from tab") |> DataFrame
  @test size(dbrow) == (0,0)

  # add_agent! with an existing agent
  agent = Agent6(2, pos, vel, dia)
  add_agent!(agent, model1)
  @test Agents.collect_ids(DBInterface.execute(model1.space.db, "select id from tab")) == [2]

  # agents within some range are found correctly (once this is implemented)
  agent2 = model1.agents[2]
  agent3 = Agent6(3, agent2.pos .+ 0.005, vel, dia)
  add_agent_pos!(agent3, model1)
  n_ids = space_neighbors(agent2, model1, agent2.diameter)
  @test length(n_ids) == 1
  @test n_ids[1] == 3
  n_ids = space_neighbors(agent2, model1, agent2.diameter/10)
  @test length(n_ids) == 0

  # test that it finds both
  n_ids = space_neighbors(agent2.pos, model1, agent2.diameter)
  @test sort!(n_ids) == [2, 3]
end
