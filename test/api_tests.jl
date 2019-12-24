using Agents, Test, Random, Suppressor

model1 = ABM(Agent1, Space((3,3)))

agent = add_agent!((1,1), model1)
@test agent.pos == (1, 1)
@test agent.id == 1
pos1 = model1.space.agent_positions[coord2vertex((1,1), model1)]
@test length(pos1) == 1
@test pos1[1] == 1

move_agent!(agent, (2,2), model1)

@test agent.pos == (2,2)
pos1 = model1.space.agent_positions[coord2vertex((1,1), model1)]
@test length(pos1) == 0
pos2 = model1.space.agent_positions[coord2vertex((2,2), model1)]
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

  model2 = ABM(Agent5, Space((10, 10)))
  for i in 1:20; add_agent!(Agent5(i, i, rand()/rand()), model2); end
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

@testset "show" begin
  model = ABM(Agent0, nothing)
  shown = @capture_out show(model)
  @test shown == "AgentBasedModel with 0 agents of type Agent0\n no space\n scheduler: fastest"

  model = ABM(Agent1, Space((3,3)))
  add_agent!((1,1), model)
  shown = @capture_out show(model)
  @test shown == "AgentBasedModel with 1 agents of type Agent1\n space: GridSpace with 9 nodes and 12 edges\n scheduler: fastest"

  properties = Dict(:foo => 42)
  model = ABM(Agent1, Space((3,3)); properties=properties, scheduler=random_activation)
  add_agent!((1,1), model)
  add_agent!((1,2), model)
  shown = @capture_out show(model)
  @test shown == "AgentBasedModel with 2 agents of type Agent1\n space: GridSpace with 9 nodes and 12 edges\n scheduler: random_activation\n properties: Dict(:foo => 42)"
end
