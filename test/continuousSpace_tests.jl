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
  
  # move_agent! with a velocity argument
  add_agent!(pos, model1, vel, dia)
  @test Agents.collect_ids(DBInterface.execute(model1.space.db, "select id from tab")) == [1]
  dbrow = DBInterface.execute(model1.space.db, "select * from tab") |> DataFrame;
  @test dbrow[1, :a] == 0.5
  @test dbrow[1, :b] == 0.5
  
  move_agent!(model1.agents[1], model1, (0.3, 0.5))
  @test dbrow[1, :a] == 0.8
  @test dbrow[1, :b] == 1.0
  @test dbrow[1, :a] == model1.agents[1].pos[1]
  @test dbrow[1, :b] == model1.agents[1].pos[2]
  
  kill_agent!(model1.agents[1], model1)
  dbrow = DBInterface.execute(model1.space.db, "select * from tab") |> DataFrame
  @test size(dbrow) == (0,0)

  # add_agent! with an existing agent
  agent = Agent6(2, pos, vel, dia)
  add_agent!(agent, model1)
  @test Agents.defvel(agent, model) == nothing
  @test Agents.collect_ids(DBInterface.execute(model1.space.db, "select id from tab")) == [2]

  # agents within some range are found correctly
  agent2 = model1.agents[2]
  agent3 = Agent6(3, agent2.pos .+ 0.005, vel, dia)
  add_agent_pos!(agent3, model1)
  n_ids = space_neighbors(agent2, model1, agent2.weight)
  @test length(n_ids) == 1
  @test n_ids[1] == 3
  n_ids = space_neighbors(agent2, model1, agent2.weight/10)
  @test length(n_ids) == 0

  # test that it finds both
  n_ids = space_neighbors(agent2.pos, model1, agent2.weight)
  @test sort!(n_ids) == [2, 3]

  # test various metrics
  c = ABM(Agent6, ContinuousSpace(2; extend = (2.0, 2.0), metric = :cityblock))
  e = ABM(Agent6, ContinuousSpace(2; extend = (2.0, 2.0), metric = :euclidean))
  r = sqrt(2) - 0.2
  for (i, φ) in enumerate(range(0; stop = 2π, length = 10))
    a = Agent6(i, (1, 1) .+ r .* sincos(φ), (0.0, 0.0), 0.0)
    add_agent_pos!(a, c)
    add_agent_pos!(a, e)
  end
  @test length(space_neighbors((1, 1), c, r)) == 10
  @test 4 < length(space_neighbors((1, 1), e, r)) < 10
end

@testset "Interacting pairs" begin
  space = ContinuousSpace(2, extend = (10, 10), periodic = false, metric = :euclidean)
  model = ABM(Agent6, space; scheduler = fastest)
  model = ABM(Agent6, space; scheduler = model -> sort!(collect(keys(model.agents));rev=true))
  pos = [
    (7.074386436066224, 4.963014649338054)
    (5.831962448496828, 4.926297135685473)
    (5.122087781793935, 5.300031210394806)
    (3.9715633336430156, 4.8106570045816675)
  ]
  for i in 1:4
    add_agent_pos!(Agent6(i+2, pos[i], (0.0, 0.0), 0), model)
  end
  pairs = interacting_pairs(model, 2.0, :scheduler).pairs
  @test length(pairs) == 2
  fi = [p[1] for p in pairs]
  se = [p[2] for p in pairs]
  @test fi == unique(fi)
  @test se == unique(se)
  for id in fi
    @test id ∉ se
  end
  pairs = interacting_pairs(model, 2.0, :all).pairs
  @test length(pairs) == 5
  @test (3, 6) ∉ pairs

  space2 = ContinuousSpace(2, extend = (10, 10), periodic = false, metric = :euclidean)
  model2 = ABM(Agent6, space2; scheduler = by_id)
  for i in 1:4
    add_agent_pos!(Agent6(i, pos[i], (0.0, 0.0), 0), model2)
  end
  # Note that length here is not the same as the test above with the same function
  # call. This is due to the `scheduler` order of operation
  pairs = interacting_pairs(model2, 2.0, :scheduler).pairs
  @test length(pairs) == 3
  # A more expensive search (in memory, not time), but guarantees true nearest neighbors
  pairs = interacting_pairs(model2, 2.0, :nearest).pairs
  @test length(pairs) == 2
  pairs = interacting_pairs(model2, 2.0, :all).pairs
  @test length(pairs) == 5
  @test (1, 4) ∉ pairs
end
