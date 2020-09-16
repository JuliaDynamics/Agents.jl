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

  @test_throws AssertionError ContinuousSpace(2; extend = (-1,1)) # Cannot have negative extent
  @test_throws AssertionError ContinuousSpace(2; extend = [1,1]) # Must be a tuple
  @test_throws AssertionError ContinuousSpace(2; extend = (1,1,1)) # Must be length D
  @test_throws AssertionError ContinuousSpace(2; extend = ("one",1.0)) # Must contain reals

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
  @test Agents.defvel(agent, model1) == nothing
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

mutable struct AgentU1 <: AbstractAgent
  id::Int
  pos::NTuple{2,Float64}
  vel::NTuple{2,Float64}
end

mutable struct AgentU2 <: AbstractAgent
  id::Int
  pos::NTuple{2,Float64}
  vel::NTuple{2,Float64}
end

function ignore_six(model::ABM{A,S,F,P}) where {A,S,F,P}
  [a.id for a in allagents(model) if !(typeof(a) <: Agent6)]
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
  @test length(pairs) == 2
  # A more expensive search (in memory, not time), but guarantees true nearest neighbors
  pairs = interacting_pairs(model2, 2.0, :nearest).pairs
  @test length(pairs) == 2
  pairs = interacting_pairs(model2, 2.0, :all).pairs
  @test length(pairs) == 5
  @test (1, 4) ∉ pairs

  space3 = ContinuousSpace(2, extend = (1, 1), periodic = false, metric = :euclidean)
  model3 = ABM(Union{Agent6, AgentU1, AgentU2}, space3; warn = false)
  for i in 1:10
    add_agent_pos!(Agent6(i, (i/10, i/10), (0.0, 0.0), 0), model3)
  end
  for i in 11:20
    add_agent_pos!(AgentU1(i, (i/10-1, 0.5), (0.0, 0.0)), model3)
  end
  for i in 21:30
    add_agent_pos!(AgentU2(i, (0.45, i/10-2), (0.0, 0.0)), model3)
  end
  pairs = interacting_pairs(model3, 0.1, :types).pairs
  @test length(pairs) == 7
  for (a,b) in pairs
      @test typeof(model3[a]) !== typeof(model3[b])
  end
  @test (3, 6) ∉ pairs

  # Test that we have at least some Agent6's in this match
  @test any(typeof(model3[a]) <: Agent6 || typeof(model3[b]) <: Agent6 for (a,b) in pairs)
  pairs = interacting_pairs(model3, 0.2, :types; scheduler = ignore_six).pairs
  @test length(pairs) == 12
  # No Agent6's when using the ignore_six scheduler
  @test all(!(typeof(model3[a]) <: Agent6) && !(typeof(model3[b]) <: Agent6) for (a,b) in pairs)

  # Fix #288
  space = ContinuousSpace(2; periodic = true, extend = (1,1), metric=:euclidean)
  model = ABM(Agent6, space)
  pos = [(0.0, 0.0),(0.2, 0.2),(0.5, 0.5)]
  for i in pos
    add_agent!(i,model,(0.0,0.0),1.0)
  end
  pairs = interacting_pairs(model, .29, :all)
  @test length(pairs) == 1
  (a,b) = first(pairs)
  @test (a.id, b.id) == (1,2)
  # Before the #288 fix, this would return (2,3) as a pair
  # which has a euclidean distance of 0.42
  pairs = interacting_pairs(model, .3, :all)
  @test length(pairs) == 1
  (a,b) = first(pairs)
  @test (a.id, b.id) == (1,2)
end

@testset "nearest neighbor" begin 
  space = ContinuousSpace(2; periodic = true, extend = (1,1), metric = :euclidean)
  model = ABM(Agent9, space)
  pos = [(0.0, 0.0),(0.2, 0.0),(0.2, 0.2),(0.5, 0.5)]
  for i in pos
    add_agent!(i,model,(0.0,0.0),nothing)
  end

  for agent in values(model.agents)
    agent.f1 = nearest_neighbor(agent, model, sqrt(2)).id
  end

  @test model.agents[1].f1 == 2
  @test model.agents[2].f1 == 1
  @test model.agents[3].f1 == 2 ## This is evaluated as 1
  @test model.agents[4].f1 == 3
end