Random.seed!(223)

@testset "data_collector" begin
  forest = model_initiation(f=0.05, d=0.8, p=0.01, griddims=(20, 20), seed=2);
  agent_properties = Dict(:status => [length, count])
  when = 1:10
  data = step!(forest, dummystep, forest_step!, 10, agent_properties, when=when);
  @test size(data) == (11, 3)
  
  forest = model_initiation(f=0.05, d=0.8, p=0.01, griddims=(20, 20), seed=2);
  agent_properties = Dict(:status => [length, count])
  when = 1:10
  data = step!(forest, dummystep, forest_step!, 10, agent_properties, when=when,
  step0=false);
  @test size(data) == (when[end], 3)

  forest = model_initiation(f=0.05, d=0.8, p=0.01, griddims=(20, 20), seed=2);
  agent_properties = Dict(:status => [length, count])
  when = 1:10
  data = step!(forest, dummystep, forest_step!, 10, agent_properties, when=when,
  step0=false, replicates=3);
  @test size(data) == (when[end]*3, 4)

  agent_properties = [:status]
  forest = model_initiation(f=0.05, d=0.8, p=0.01, griddims=(20, 20), seed=2);
  data = step!(forest, dummystep, forest_step!, 10, agent_properties, when=when);
  @test size(data) == (993, 3)

  agent_properties = [:status]
  forest = model_initiation(f=0.05, d=0.8, p=0.01, griddims=(20, 20), seed=2);
  data = step!(forest, dummystep, forest_step!, 10, agent_properties, when=when,
  replicates=1);
  @test size(data) == (993, 4)

  forest = model_initiation(f=0.05, d=0.8, p=0.01, griddims=(20, 20), seed=2);
  agent_properties = [:status]
  when = 1:10
  data = step!(forest, dummystep, forest_step!, 10, agent_properties, when=when,
  step0=false);
  @test size(data) == (666, 3)
end