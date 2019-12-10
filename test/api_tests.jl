using Agents, Test

mutable struct Agent1 <: AbstractAgent
  id::Int
  pos::Tuple{Int,Int}
end
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
mutable struct Agent0 <: AbstractAgent
  id::Int
end
# fastest
model = ABM(Agent0)
for i in 1:N; add_agent!(model); end
@test sort!(collect(keys(model.agents))) == 1:N

# by_id
model = ABM(Agent0; scheduler = by_id)
for i in 1:N; add_agent!(model); end

@test sort!(collect(keys(model.agents))) == 1:N

@test model.scheduler(model) == 1:N

using Random
Random.seed!(12)

# random
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
