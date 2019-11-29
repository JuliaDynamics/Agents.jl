mutable struct Boltzmann{T<:Integer} <: AbstractAgent
  id::T
  wealth::T
end

function boltzmann_model(; numagents)
  model = ABM(Boltzmann{Int64}, scheduler=random_activation)
  for i in 1:numagents
    model.agents[i] = Boltzmann(i, 1)
  end
  return model
end

function Boltzmann_step!(agent::AbstractAgent, model::ABM)
  if agent.wealth == 0
    return
  else
    random_agent = model.agents[rand(keys(model.agents))]
    agent.wealth -= 1
    random_agent.wealth += 1
  end
end

@testset "Model tests" begin

  numagents = 20
  n = 10
  model = boltzmann_model(numagents=numagents)
  agent_properties = [:wealth]
  data = step!(model, Boltzmann_step!, n, agent_properties, when=1:n)
  @test size(data) == (numagents*(n+1), length(agent_properties)+2)

  nreps = 3
  data = step!(model, Boltzmann_step!, n, agent_properties, when=1:n, replicates=nreps)
  @test length(data) == nreps
end
