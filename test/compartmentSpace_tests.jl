@testset "Continuous space" begin

  # Basic model initialization
  space1 = CompartmentSpace((1, 1), 0.1; periodic = true)
  space2 = CompartmentSpace((1, 1), 0.1; periodic = false)
  space3 = CompartmentSpace((2, 1), 0.1; periodic = true)
  space4 = CompartmentSpace((1, 2), 0.1; periodic = true)
  space5 = CompartmentSpace((2, 2), 0.1; periodic = true)
  space6 = CompartmentSpace((1, ), 0.1; periodic = true)
  space7 = CompartmentSpace((1, 1, 1), 0.1; periodic = true)
  space8 = CompartmentSpace((1, 1, 1), 0.1; periodic = false)

  @test length(space1.dims) == 2
  @test length(space2.dims) == 2
  @test length(space3.dims) == 2
  @test length(space4.dims) == 2
  @test length(space5.dims) == 2
  @test length(space6.dims) == 1
  @test length(space7.dims) == 3
  @test length(space8.dims) == 3

  @test_throws ArgumentError CompartmentSpace((-1,1), 0.1) # Cannot have negative extent
  @test_throws MethodError CompartmentSpace([1,1], 0.1) # Must be a tuple
  @test_throws MethodError CompartmentSpace(("one",1.0), 0.1) # Must contain reals

  model1 = ABM(Agent6, space1)
  model2 = ABM(Agent6, space2)
  model3 = ABM(Agent6, space3)
  model4 = ABM(Agent6, space4)
  model5 = ABM(Agent6, space5)
  model6 = ABM(Agent6, space6)

  @test nagents(model1) == 0
  @test model1.agents == Dict()

  # add_agent! with no existing agent (the agent is created)
  pos = (0.5, 0.5)
  vel = (0.2, 0.1)
  dia = 0.01
  add_agent!(pos, model1, vel, dia)
  @test collect(keys(model1.agents)) == [1]
  @test model1[1].pos == (0.5, 0.5)

  # move_agent! without provided update_vel! function
  move_agent!(model1[1], model1)
  @test model1[1].pos == (0.7, 0.6)

  kill_agent!(model1.agents[1], model1)
  @test length(model1.agents) == 0

  # add_agent! with an existing agent
  agent = Agent6(2, pos, vel, dia)
  add_agent!(agent, model1)
  @test Agents.defvel2(agent, model1) == nothing
  @test collect(keys(model1.agents)) == [2]

  # agents within some range are found correctly
  agent2 = model1[2]
  agent3 = Agent6(3, agent2.pos .+ 0.005, vel, dia)
  add_agent_pos!(agent3, model1)
  n_ids = nearby_ids(agent2, model1, agent2.weight, exact=true)
  @test n_ids == [3]
  n_ids = nearby_ids(agent2, model1, agent2.weight/2, exact=true)
  @test n_ids == []

  # test that it finds both
  n_ids = nearby_ids(agent2.pos, model1, agent2.weight)
  @test sort!(n_ids) == [2, 3]

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
  space = CompartmentSpace((10, 10), 0.2, periodic = false)
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
  @test length(pairs) == 3
  @test (3, 6) ∉ pairs

  space2 = CompartmentSpace((10, 10), 0.1,periodic = false)
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
  @test length(pairs) == 3
  pairs = interacting_pairs(model2, 2.5, :all).pairs
  @test length(pairs) == 5
  @test (1, 4) ∉ pairs

  space3 = CompartmentSpace((1,1), 0.1, periodic = false)
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
  space = CompartmentSpace((1,1), 0.1; periodic = true)
  model = ABM(Agent6, space)
  pos = [(0.01, 0.01),(0.2,0.2),(0.5,0.5)]
  for i in pos
    add_agent!(i,model,(0.0,0.0),1.0)
  end
  pairs = collect(interacting_pairs(model, 0.29, :all))
  @test length(pairs) == 1
  (a,b) = first(pairs)
  @test (a.id, b.id) == (1,2)
  # Before the #288 fix, this would return (2,3) as a pair
  # which has a euclidean distance of 0.42
  pairs = collect(interacting_pairs(model, .3, :all))
  @test length(pairs) == 1
  (a,b) = first(pairs)
  @test (a.id, b.id) == (1,2)
end

@testset "nearest neighbor" begin 
  space = CompartmentSpace((1,1), 0.1; periodic = true)
  model = ABM(Agent9, space)
  pos = [(0.01, 0.01),(0.2, 0.01),(0.2, 0.2),(0.5, 0.5)]
  for i in pos
    add_agent!(i,model,(0.0,0.0),nothing)
  end

  for agent in allagents(model)
    agent.f1 = nearest_neighbor(agent, model, sqrt(2)).id
  end

  @test model.agents[1].f1 == 2
  @test model.agents[2].f1 == 1
  @test model.agents[3].f1 == 2
  @test model.agents[4].f1 == 3
end
