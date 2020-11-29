mutable struct BadAgent <: AbstractAgent
    useless::Int
    pos::Int
end
mutable struct BadAgentId <: AbstractAgent
    id::Float64
end
struct ImmutableAgent <: AbstractAgent
    id::Int
end
mutable struct DiscreteVelocity <: AbstractAgent
    id::Int
    pos::NTuple{2, Float64}
    vel::NTuple{2, Int}
    diameter::Float64
end
mutable struct ParametricAgent{T <: Integer} <: AbstractAgent
    id::T
    pos::NTuple{2, T}
    weight::T
    info::String
end


@testset "Model construction" begin
    # Shouldn't use ImmutableAgent since it cannot be edited
    agent = ImmutableAgent(1)
    @test_logs (:warn, "AgentType should be mutable. Try adding the `mutable` keyword infront of `struct` in your agent definition.") ABM(agent)
    # Warning is suppressed if flag is set
    @test Agents.agenttype(ABM(agent; warn=false)) <: AbstractAgent
    # Cannot use BadAgent since it has no `id` field
    @test_throws ArgumentError ABM(BadAgent)
    agent = BadAgent(1,1)
    @test_throws ArgumentError ABM(agent)
    # Cannot use BadAgent in a grid space context since `pos` has an invalid type
    @test_throws ArgumentError ABM(BadAgent, GridSpace((1,1)))
    @test_throws ArgumentError ABM(agent, GridSpace((1,1)))
    # Cannot use BadAgentId since `id` has an invalid type
    @test_throws ArgumentError ABM(BadAgentId)
    agent = BadAgentId(1.0)
    @test_throws ArgumentError ABM(agent)
    # Cannot use Agent0 in a grid space context since it has no `pos` field
    @test_throws ArgumentError ABM(Agent0, GridSpace((1,1)))
    agent = Agent0(1)
    @test_throws ArgumentError ABM(agent, GridSpace((1,1)))
    # Cannot use Agent3 in a graph space context since `pos` has an invalid type
    @test_throws ArgumentError ABM(Agent3, GraphSpace(Agents.Graph(1)))
    agent = Agent3(1, (1,1), 5.3)
    @test_throws ArgumentError ABM(agent, GraphSpace(Agents.Graph(1)))
    # Cannot use Agent3 in a continuous space context since `pos` has an invalid type
    @test_throws ArgumentError ABM(Agent3, ContinuousSpace((1,1), 0.1))
    @test_throws ArgumentError ABM(agent, ContinuousSpace((1,1), 0.1))
    # Cannot use Agent4 in a continuous space context since it has no `vel` field
    @test_throws ArgumentError ABM(Agent4, ContinuousSpace((1,1), 0.1))
    agent = Agent4(1, (1,1), 5)
    @test_throws ArgumentError ABM(agent, ContinuousSpace((1,1), 0.1))
    # Shouldn't use DiscreteVelocity in a continuous space context since `vel` has an invalid type
    @test_logs (:warn, "`vel` field in Agent struct should be of type `NTuple{<:AbstractFloat}` when using ContinuousSpace.") ABM(DiscreteVelocity, ContinuousSpace((1,1), 0.1))
    agent = DiscreteVelocity(1, (1,1), (2,3), 2.4)
    @test_logs (:warn, "`vel` field in Agent struct should be of type `NTuple{<:AbstractFloat}` when using ContinuousSpace.") ABM(agent, ContinuousSpace((1,1), 0.1))
    # Warning is suppressed if flag is set
    @test Agents.agenttype(ABM(agent, ContinuousSpace((1,1), 0.1); warn=false)) <: AbstractAgent
    # Shouldn't use ParametricAgent since it is not a concrete type
    @test_logs (:warn, "AgentType is not concrete. If your agent is parametrically typed, you're probably seeing this warning because you gave `Agent` instead of `Agent{Float64}` (for example) to this function. You can also create an instance of your agent and pass it to this function. If you want to use `Union` types for mixed agent models, you can silence this warning.") ABM(ParametricAgent, GridSpace((1,1)))
    # Warning is suppressed if flag is set
    @test Agents.agenttype(ABM(ParametricAgent, GridSpace((1,1)); warn=false)) <: AbstractAgent
    # ParametricAgent{Int} is the correct way to use such an agent
    @test Agents.agenttype(ABM(ParametricAgent{Int}, GridSpace((1,1)))) <: AbstractAgent
    #Type inferance using an instance can help users here
    agent = ParametricAgent(1, (1,1), 5, "Info")
    @test Agents.agenttype(ABM(agent, GridSpace((1,1)))) <: AbstractAgent
    #Mixed agents
    @test Agents.agenttype(ABM(Union{Agent0,Agent1}; warn=false)) <: AbstractAgent
    @test_logs (:warn, "AgentType is not concrete. If your agent is parametrically typed, you're probably seeing this warning because you gave `Agent` instead of `Agent{Float64}` (for example) to this function. You can also create an instance of your agent and pass it to this function. If you want to use `Union` types for mixed agent models, you can silence this warning.") ABM(Union{Agent0,Agent1})
    @test_throws ArgumentError ABM(Union{Agent0,BadAgent}; warn=false)
end

@testset "sample!" begin
  Random.seed!(6459)
  model = ABM(Agent2)
  for i in 1:20; add_agent!(model, rand()/rand()); end
  allweights = [i.weight for i in values(model.agents)]
  mean_weights = sum(allweights)/length(allweights)
  sample!(model, 12, :weight)
  @test Agents.nagents(model) == 12
  allweights = [i.weight for i in values(model.agents)]
  mean_weights_new = sum(allweights)/length(allweights)
  @test mean_weights_new > mean_weights
  sample!(model, 40, :weight)
  @test Agents.nagents(model) == 40
  allweights = [i.weight for i in values(model.agents)]
  mean_weights_new = sum(allweights)/length(allweights)
  @test mean_weights_new > mean_weights

  Random.seed!(6459)
  model2 = ABM(Agent3, GridSpace((10, 10)))
  for i in 1:20; add_agent_single!(Agent3(i, (1,1), rand()/rand()), model2); end
  @test sample!(model2, 10, :weight) == nothing
  allweights = [i.weight for i in values(model2.agents)]
  mean_weights = sum(allweights)/length(allweights)
  sample!(model2, 12, :weight)
  @test Agents.nagents(model2) == 12
  allweights = [i.weight for i in values(model2.agents)]
  mean_weights_new = sum(allweights)/length(allweights)
  @test mean_weights_new > mean_weights

  sample!(model2, 40, :weight)
  @test Agents.nagents(model2) == 40

  Random.seed!(6459)
  #Guarantee all starting weights are unique
  model3 = ABM(Agent2)
  while true
    for i in 1:20; add_agent!(model3, rand()/rand()); end
    allweights = [i.weight for i in values(model3.agents)]
    allunique(allweights) && break
  end
  # Cannot draw 50 samples out of a pool of 20 without replacement
  @test_throws ErrorException sample!(model3, 50, :weight; replace=false)
  sample!(model3, 15, :weight; replace=false)
  allweights = [i.weight for i in values(model3.agents)]
  @test allunique(allweights)
  model3 = ABM(Agent2)
  while true
    for i in 1:20; add_agent!(model3, rand()/rand()); end
    allweights = [i.weight for i in values(model3.agents)]
    allunique(allweights) && break
  end
  sample!(model3, 100, :weight; replace=true)
  allweights = [i.weight for i in values(model3.agents)]
  @test !allunique(allweights)
end

@testset "add_agent! (discrete)" begin
  properties = Dict(:x1=>1)
  space = GraphSpace(complete_digraph(10))
  model = ABM(Agent7, space; properties=properties)
  attributes = (f1=true,f2=1)
  add_agent!(1, model, attributes...)
  attributes = (f2=1,f1=true)
  add_agent!(1, model; attributes...)
  @test model.agents[1].id != model.agents[2].id
  @test model.agents[1].pos == model.agents[2].pos
  @test model.agents[1].f1 == model.agents[2].f1
  @test model.agents[1].f2 == model.agents[2].f2
  @test add_agent_single!(model, attributes...).pos ∈ 1:10
  for id in 4:11
      agent = Agent7(id, 2, attributes...)
      add_agent_single!(agent, model)
  end
  @test !has_empty_positions(model)
  agent = Agent7(12,5, attributes...)
  add_agent_single!(agent, model)
  @test_throws KeyError model[12]
  add_agent!(agent, model)
  @test model[12].pos ∈ 1:10

  agent = Agent7(13,5, attributes...)
  @test add_agent!(agent, 3, model).pos == 3

  model = ABM(Agent1, GridSpace((10,10)))
  agent = Agent1(1,(3,6))
  @test add_agent!(agent, (7,8), model).pos == (7,8)
end

@testset "add_agent! (continuous)" begin
  properties = Dict(:x1=>1)
  space2d = ContinuousSpace((1,1), 0.1; periodic=true)
  model = ABM(Agent8, space2d; properties=properties)
  attributes = (f1=true,f2=1)
  add_agent!(model, attributes...)
  attributes = (f2=1,f1=true)
  add_agent!(model; attributes...)
  @test model.agents[1].id != model.agents[2].id
  @test model.agents[1].f1 == model.agents[2].f1
  @test model.agents[1].f2 == model.agents[2].f2
  agent = Agent8(3, (0,0), false, 6)
  @test 0 <= add_agent!(agent, model).pos[1] <= 1
  agent.id = 4
  @test add_agent!(agent, (0.5, 0.5), model).pos[1] ≈ 0.5 atol=1e-3
end

@testset "move_agent!" begin
  # GraphSpace
  model = ABM(Agent5, GraphSpace(path_graph(6)))
  agent = add_agent!(model, 5.3)
  init_pos = agent.pos
  # Checking specific indexing
  move_agent!(agent, rand([i for i in 1:6 if i != init_pos]), model)
  new_pos = agent.pos
  @test new_pos != init_pos
  # Checking a random move
  ni = 0; init_pos = agent.pos
  while agent.pos == init_pos
      move_agent!(agent, model)
  end
  @test ni < Inf

  # GridSpace
  model = ABM(Agent1, GridSpace((5,5)))
  agent = add_agent!((2,4), model)
  move_agent!(agent, (1,3), model)
  @test agent.pos == (1,3)
  ni = 0; init_pos = agent.pos
  while agent.pos == init_pos
      move_agent!(agent, model)
  end
  @test ni < Inf

  model = ABM(Agent1, GridSpace((2,1)))
  agent = add_agent!((1,1), model)
  move_agent_single!(agent, model)
  @test agent.pos == (2,1)
  agent2 = add_agent!((1,1), model)
  move_agent_single!(agent2, model)
  # Agent shouldn't move since the grid is saturated
  @test agent2.pos == (1,1)

  # ContinuousSpace
  model = ABM(Agent6, ContinuousSpace((1,1), 0.1))
  agent = add_agent!((0.0, 0.0), model, (0.5, 0.0), 1.0)
  move_agent!(agent, model)
  @test agent.pos == (0.5, 0.0)
end

@testset "kill_agent!" begin
  # No Space
  model = ABM(Agent0)
  add_agent!(model)
  agent = add_agent!(model)
  @test nagents(model) == 2
  kill_agent!(agent, model)
  @test nagents(model) == 1
  # GraphSpace
  model = ABM(Agent5, GraphSpace(path_graph(6)))
  add_agent!(model, 5.3)
  add_agent!(model, 2.7)
  @test nagents(model) == 2
  kill_agent!(model.agents[1], model)
  @test nagents(model) == 1
  kill_agent!(2, model)
  @test nagents(model) == 0
  # GridSpace
  model = ABM(Agent1, GridSpace((5,5)))
  add_agent!((1,3), model)
  add_agent!((1,3), model)
  add_agent!((5,2), model)
  @test nagents(model) == 3
  for id in copy(ids_in_position((1,3), model))
    kill_agent!(id, model)
  end
  @test nagents(model) == 1
  # ContinuousSpace
  model = ABM(Agent6, ContinuousSpace((1,1), 0.1))
  add_agent!((0.7,0.1), model, (15,20), 5.0)
  add_agent!((0.2,0.9), model, (8,35), 1.7)
  @test nagents(model) == 2
  kill_agent!(model[1], model)
  @test nagents(model) == 1
end

@testset "genocide!" begin
  # Testing no space
  model = ABM(Agent0)
  for i in 1:10
      a = Agent0(i)
      add_agent!(a, model)
  end
  genocide!(model)
  @test nagents(model) == 0
  for i in 1:10
      a = Agent0(i)
      add_agent!(a, model)
  end
  genocide!(model, 5)
  @test nagents(model) == 5
  genocide!(model, a -> a.id < 3)
  @test nagents(model) == 3

  model = ABM(Agent3, GridSpace((10, 10)))

  # Testing genocide!(model::ABM)
  for i in 1:20
    agent = Agent3(i, (1,1), rand())
    add_agent_single!(agent, model)
  end
  genocide!(model)
  @test nagents(model) == 0

  # Testing genocide!(model::ABM, n::Int)
  for i in 1:20
    # Explicitly override agents each time we replenish the population,
    # so we always start the genocide with 20 agents.
    agent = Agent3(i, (1,1), rand())
    add_agent_single!(agent, model)
  end
  genocide!(model, 10)
  @test nagents(model) == 10

  # Testing genocide!(model::ABM, f::Function) with an anonymous function
  for i in 1:20
    agent = Agent3(i, (1,1), rand())
    add_agent_single!(agent, model)
  end
  @test nagents(model) == 20
  genocide!(model, a -> a.id > 5)
  @test nagents(model) == 5

  Random.seed!(6465)
  # Testing genocide!(model::ABM, f::Function) when the function is invalid
  # (i.e. does not return a bool)
  for i in 1:20
    agent = Agent3(i, (rand(1:10), rand(1:10)), i*2)
    add_agent_pos!(agent, model)
  end
  @test_throws TypeError genocide!(model, a -> a.id)
  N = nagents(model)

  # Testing genocide!(model::ABM, f::Function) with a named function
  # No need to replenish population since the last test fails
  function complex_logic(agent::A) where A <: AbstractAgent
    if agent.pos[1] <= 5 && agent.weight > 25
      true
    else
      false
    end
  end
  genocide!(model, complex_logic)
  @test nagents(model) < N

  space2d = ContinuousSpace((1,1), 0.1; periodic=true)
  model = ABM(Agent8, space2d)
  attributes = (f1=true,f2=1)
  for _ in 1:10 add_agent!(model, attributes...) end
  genocide!(model)
  @test nagents(model) == 0
  for _ in 1:10 add_agent!(model, attributes...) end
  genocide!(model, 5)
  @test nagents(model) == 5
  genocide!(model, a -> a.id < 3)
  @test nagents(model) == 3
end

mutable struct Daisy <: AbstractAgent
  id::Int
  pos::Tuple{Int, Int}
  breed::String
end
mutable struct Land <: AbstractAgent
  id::Int
  pos::Tuple{Int, Int}
  temperature::Float64
end
@testset "fill space" begin
  space = GridSpace((10, 10))
  model = ABM(Land, space)
  fill_space!(model, 15)
  @test nagents(model) == 100
  for a in allagents(model)
    @test a isa Land
    @test a.temperature == 15
  end

  space = GridSpace((10, 10))
  model = ABM(Union{Daisy, Land}, space; warn = false)
  fill_space!(Daisy, model, "black")
  @test nagents(model) == 100
  for a in values(model.agents)
    @test a isa Daisy
    @test a.breed == "black"
  end

  space = GridSpace((10, 10), periodic = true)
  model = ABM(Union{Daisy, Land}, space; warn = false)
  temperature(pos) = (pos[1]/10, ) # make it Tuple!
  fill_space!(Land, model, temperature)
  @test nagents(model) == 100
  for a in values(model.agents)
    @test a.temperature == a.pos[1]/10
  end

end

@testset "random agent" begin
    space = GridSpace((10, 10))
    model = ABM(Union{Daisy, Land}, space; warn = false)
    fill_space!(Daisy, model, "black")
    add_agent!(Land(999, (1, 1), 999), model)

    a = random_agent(model)
    @test typeof(a) <: Union{Daisy, Land}

    c1(a) = a isa Land
    a = random_agent(model, c1)
    @test a.id == 999

    c2(a) = a isa Float64
    a = random_agent(model, c2)
    @test isnothing(a)
end

@testset "model step order" begin
    function model_step!(model)
        for a in allagents(model)
            if a.weight > 1.0
                model.count += 1
            end
        end
    end
    function agent_step!(a, model)
        a.weight += 1
    end

    for bool in (true, false)
        model = ABM(Agent2; properties = Dict(:count => 0))
        for i in 1:100
            add_agent!(model, rand())
        end
        step!(model, model_step!, agent_step!, 1, bool)
        if bool
            @test model.count == 100
        else
            @test model.count == 0
        end
    end
end
