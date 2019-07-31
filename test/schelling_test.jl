Random.seed!(123)

@testset "Schelling example" begin
  model = instantiate_modelS(numagents=370, griddims=(20,20), min_to_be_happy=3)
  agent_properties = [:pos, :mood, :group]
  steps_to_collect_data = collect(1:2)
  data = step!(agent_step!, model, 2, agent_properties, steps_to_collect_data)

  @test data[1, :pos_1] == 261
  @test data[1, :pos_2] == 363

  i = 1
  visualize_2D_agent_distribution(data, model, Symbol("pos_$i"), types=Symbol("group_$i"), savename="step_$i", cc=Dict(0=>"blue", 1=>"red"))

  rm("./step_1.pdf")

  @test Agents.grid0D() == Agents.Graph(1)
end