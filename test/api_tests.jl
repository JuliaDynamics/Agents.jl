using Agents, Test, Random, LightGraphs
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
    @test_logs (:warn, "Agent struct should be mutable. Try adding the `mutable` keyword infront of `struct` in your agent definition.") ABM(ImmutableAgent)
    agent = ImmutableAgent(1)
    @test_logs (:warn, "Agent struct should be mutable. Try adding the `mutable` keyword infront of `struct` in your agent definition.") ABM(agent)
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
    @test_throws ArgumentError ABM(Agent3, ContinuousSpace(2))
    @test_throws ArgumentError ABM(agent, ContinuousSpace(2))
    # Cannot use Agent4 in a continuous space context since it has no `vel` field
    @test_throws ArgumentError ABM(Agent4, ContinuousSpace(2))
    agent = Agent4(1, (1,1), 5)
    @test_throws ArgumentError ABM(agent, ContinuousSpace(2))
    # Shouldn't use DiscreteVelocity in a continuous space context since `vel` has an invalid type
    @test_logs (:warn, "`vel` field in Agent struct should be of type `NTuple{<:AbstractFloat}` when using ContinuousSpace.") ABM(DiscreteVelocity, ContinuousSpace(2))
    agent = DiscreteVelocity(1, (1,1), (2,3), 2.4)
    @test_logs (:warn, "`vel` field in Agent struct should be of type `NTuple{<:AbstractFloat}` when using ContinuousSpace.") ABM(agent, ContinuousSpace(2))
    # Warning is suppressed if flag is set
    @test Agents.agenttype(ABM(agent, ContinuousSpace(2); warn=false)) <: AbstractAgent
    # Shouldn't use ParametricAgent since it is not a concrete type
    @test_logs (:warn, "Agent struct should be a concrete type. If your agent is parametrically typed, you're probably seeing this warning because you gave `Agent` instead of `Agent{Float64}` (for example) to this function. You can also create an instance of your agent and pass it to this function.") ABM(ParametricAgent, GridSpace((1,1)))
    # Warning is suppressed if flag is set
    @test Agents.agenttype(ABM(ParametricAgent, GridSpace((1,1)); warn=false)) <: AbstractAgent
    # ParametricAgent{Int} is the correct way to use such an agent
    @test Agents.agenttype(ABM(ParametricAgent{Int}, GridSpace((1,1)))) <: AbstractAgent
    #Type inferance using an instance can help users here
    agent = ParametricAgent(1, (1,1), 5, "Info")
    @test Agents.agenttype(ABM(agent, GridSpace((1,1)))) <: AbstractAgent
end

mutable struct Agent2 <: AbstractAgent
  id::Int
  pos::Int
  f1::Bool
  f2::Int
end

Agent2(id, pos; f1, f2) = Agent2(id, pos, f1, f2)

model1 = ABM(Agent1, Space((3,3)))

model1 = ABM(Agent1, GridSpace((3,3)))

agent = add_agent!((1,1), model1)
@test agent.pos == (1, 1)
@test agent.id == 1
pos1 = get_node_contents((1,1), model1)
@test length(pos1) == 1
@test pos1[1] == 1

move_agent!(agent, (2,2), model1)
@test agent.pos == (2,2)
pos1 = get_node_contents((1,1), model1)
@test length(pos1) == 0
pos2 = get_node_contents((2,2), model1)
@test pos2[1] == 1

# %% Scheduler tests
N = 1000

# by_id
model = ABM(Agent0; scheduler = by_id)
for i in 1:N; add_agent!(model); end
@test sort!(collect(keys(model.agents))) == 1:N
@test model.scheduler(model) == 1:N

# fastest
Random.seed!(12)
model = ABM(Agent0; scheduler = fastest)
for i in 1:N; add_agent!(model); end
@test sort!(collect(model.scheduler(model))) == 1:N

# random
Random.seed!(12)
model = ABM(Agent0; scheduler = random_activation)
for i in 1:N; add_agent!(model); end
@test model.scheduler(model)[1:3] == [913, 522, 637] # reproducibility test

# partial
Random.seed!(12)
model = ABM(Agent0; scheduler = partial_activation(0.1))
for i in 1:N; add_agent!(model); end

a = model.scheduler(model)
@test length(a) < N
@test a[1] == 74 # reproducibility test

# by property
model = ABM(Agent2; scheduler = property_activation(:weight))
for i in 1:N; add_agent!(model, rand()/rand()); end

Random.seed!(12)
a = model.scheduler(model)

ids = collect(keys(model.agents))
properties = [model.agents[id].weight for id in ids]

@test ids[sortperm(properties)] == a

@testset "sample!" begin
  model = ABM(Agent2)
  for i in 1:20; add_agent!(model, rand()/rand()); end
  allweights = [i.weight for i in values(model.agents)]
  mean_weights = sum(allweights)/length(allweights)
  sample!(model, 12, :weight)
  @test Agents.nagents(model) == 12
  allweights = [i.weight for i in values(model.agents)]
  mean_weights_new = sum(allweights)/length(allweights)
  @test mean_weights_new > mean_weights

  model.agents[1].weight = 2
  model.agents[2].weight = 3
  @test model.agents[1].weight == 2
  @test model.agents[2].weight == 3

  sample!(model, 40, :weight)
  @test Agents.nagents(model) == 40

  model2 = ABM(Agent3, GridSpace((10, 10)))
  for i in 1:20; add_agent_single!(Agent3(i, (1,1), rand()/rand()), model2); end
  allweights = [i.weight for i in values(model2.agents)]
  mean_weights = sum(allweights)/length(allweights)
  sample!(model2, 12, :weight)
  @test Agents.nagents(model2) == 12
  allweights = [i.weight for i in values(model2.agents)]
  mean_weights_new = sum(allweights)/length(allweights)
  @test mean_weights_new > mean_weights

  sample!(model2, 40, :weight)
  @test Agents.nagents(model2) == 40
end

@testset "add_agent!" begin
  properties = Dict(:x1=>1)
  space = Space(complete_digraph(10))
  model = AgentBasedModel(Agent2, space; properties=properties)
  attributes = (f1=true,f2=1)
  add_agent!(1, model, attributes...)
  attributes = (f2=1,f1=true)
  add_agent!(1, model; attributes...)
  @test model.agents[1].id != model.agents[2].id
  @test model.agents[1].pos == model.agents[2].pos
  @test model.agents[1].f1 == model.agents[2].f1
  @test model.agents[1].f2 == model.agents[2].f2
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
  move_agent!(agent, model)
  @test agent.pos != new_pos

  # GridSpace
  model = ABM(Agent1, GridSpace((5,5)))
  agent = add_agent!((2,4), model)
  move_agent!(agent, (1,3), model)
  @test agent.pos == (1,3)
  move_agent!(agent, model)
  @test agent.pos != (1,3)
  model = ABM(Agent1, GridSpace((2,1)))
  agent = add_agent!((1,1), model)
  move_agent_single!(agent, model)
  @test agent.pos == (2,1)
  agent2 = add_agent!((1,1), model)
  move_agent_single!(agent2, model)
  # Agent shouldn't move since the grid is saturated
  @test agent2.pos == (1,1)

  # ContinuousSpace
  model = ABM(Agent6, ContinuousSpace(2))
  agent = add_agent!((0.0,0.0), model, (1.0,0.0), 1.0)
  move_agent!(agent, model)
  @test agent.pos == (1.0,0.0)
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
  # GridSpace
  model = ABM(Agent1, GridSpace((5,5)))
  add_agent!((1,3), model)
  add_agent!((1,3), model)
  add_agent!((5,2), model)
  @test nagents(model) == 3
  for agent in get_node_agents((1,3), model)
    kill_agent!(agent, model)
  end
  @test nagents(model) == 1
  # ContinuousSpace
  model = ABM(Agent6, ContinuousSpace(2))
  add_agent!((0.7,0.1), model, (15,20), 5.0)
  add_agent!((0.2,0.9), model, (8,35), 1.7)
  @test nagents(model) == 2
  kill_agent!(id2agent(1,model), model)
  @test nagents(model) == 1
end

@testset "genocide!" begin
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

  # Testing genocide!(model::ABM, f::Function) when the function is invalid (i.e. does not return a bool)
  for i in 1:20
    agent = Agent3(i, (1,1), i*2)
    add_agent_single!(agent, model)
  end
  @test_throws TypeError genocide!(model, a -> a.id)

  # Testing genocide!(model::ABM, f::Function) with a named function
  # No need to replenish population since the last test fails
  function complex_logic(agent::A) where A <: AbstractAgent
    if first(agent.pos) <= 5 && agent.weight > 25
      true
    else
      false
    end
  end
  genocide!(model, complex_logic)
  @test nagents(model) == 17
end
