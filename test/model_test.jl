@testset "Model tests" begin

  numagents = 20
  steps = 10
  model = boltzmann_model(numagents=numagents)
  agent_properties = [:wealth]
  data = step!(model, Boltzmann_step!, steps, agent_properties, when=1:steps)
  @test size(data) == (numagents, steps+1)

  nreps = 3
  data = step!(model, Boltzmann_step!, steps, agent_properties, when=1:steps, replicates=nreps)
  @test length(data) == nreps
end