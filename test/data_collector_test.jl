Random.seed!(223)

@testset "data_collector" begin
  forest = model_initiation(f=0.05, d=0.8, p=0.01, griddims=(20, 20, 1), seed=2);
  agent_properties = [:status, :pos]
  aggregators = [length, count]
  steps_to_collect_data = collect(1:10);
  data = step!(dummy_agent_step, forest_step!, forest, 10, agent_properties, steps_to_collect_data)
  @test size(data)[2] == 21
  colnames = names(data)
  @test colnames[1] == :id
  @test colnames[end] == :pos_10

  agent_properties = [:status]
  forest = model_initiation(f=0.05, d=0.8, p=0.01, griddims=(20, 20, 1), seed=2);
  data = step!(dummy_agent_step, forest_step!, forest, 10, agent_properties, aggregators, steps_to_collect_data);
  @test size(data) == (10,3)
end
