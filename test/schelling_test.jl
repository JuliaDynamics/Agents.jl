
@testset "Schelling example" begin
  Random.seed!(123)
  model = instantiate_modelS(numagents=370, griddims=(20,20), min_to_be_happy=3)
  agent_properties = [:pos, :mood, :group]
  when = 1:5
  data = step!(model, agent_step!, 2, agent_properties, when=when)

  @test data[1, :pos_1] == 261
  @test data[1, :pos_2] == 378
end