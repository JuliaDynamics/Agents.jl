Random.seed!(223)

@testset "data_collector" begin
  forest = forest_initiation(f=0.05, d=0.8, p=0.01, griddims=(20, 20), seed=2);
  agent_properties = Dict(:status => [length, count])
  when = 1:10
  data = step!(forest, dummystep, forest_step!, 10, agent_properties, when=when);
  @test size(data) == (11, 3)

  forest = forest_initiation(f=0.05, d=0.8, p=0.01, griddims=(20, 20), seed=2);
  agent_properties = Dict(:status => [length, count])
  when = 1:10
  data = step!(forest, dummystep, forest_step!, 10, agent_properties, when=when,
  step0=false);
  @test size(data) == (when[end], 3)

  forest = forest_initiation(f=0.05, d=0.8, p=0.01, griddims=(20, 20), seed=2);
  agent_properties = Dict(:status => [length, count])
  when = 1:10
  data = step!(forest, dummystep, forest_step!, 10, agent_properties, when=when,
  step0=false, replicates=3);
  @test size(data) == (when[end]*3, 4)

  agent_properties = [:status]
  forest = forest_initiation(f=0.05, d=0.8, p=0.01, griddims=(20, 20), seed=2);
  data = step!(forest, dummystep, forest_step!, 10, agent_properties, when=when);
  @test size(data) == (993, 3)

  agent_properties = [:status]
  forest = forest_initiation(f=0.05, d=0.8, p=0.01, griddims=(20, 20), seed=2);
  data = step!(forest, dummystep, forest_step!, 10, agent_properties, when=when,
  replicates=1);
  @test size(data) == (993, 4)

  forest = forest_initiation(f=0.05, d=0.8, p=0.01, griddims=(20, 20), seed=2);
  agent_properties = [:status]
  when = 1:10
  data = step!(forest, dummystep, forest_step!, 10, agent_properties, when=when,
  step0=false);
  @test size(data) == (666, 3)

  forest = forest_initiation(f=0.05, d=0.8, p=0.01, griddims=(20, 20), seed=2);
  agent_properties = [:status]
  n(forest::ABM) = sum(i.status for i in values(forest.agents)) <= 200
  when = 1:10
  data = step!(forest, dummystep, forest_step!, n, agent_properties, when=when);
  @test n(forest) == true
  maxstep = maximum(data.step)
  @test sum(data[data.step .== (maxstep-1), :status]) > 200
end

@testset "paramscan" begin
  agent_properties = Dict(:status => [length, count])
  n=10
  when = 1:n
  parameters = Dict(:f=>[0.05,0.07], :d=>[0.6, 0.7, 0.8], :p=>0.01,
  :griddims=>(20, 20), :seed=>2)
  data = paramscan(parameters, forest_initiation;
       properties=agent_properties, n = n, agent_step! = dummystep,
       model_step! = forest_step!)
  @test size(data) == ((n+1)*6, 5)  # 6 is the number of combinations of changing params
  data = paramscan(parameters, forest_initiation;
       properties=agent_properties, n = n, agent_step! = dummystep,
       model_step! = forest_step!, include_constants=true)
  @test size(data) == ((n+1)*6, 8)  # 6 is the number of combinations of changing params, 8 is 5+3, where 3 is the number of constant parameters

  agent_properties = [:status]
  data = paramscan(parameters, forest_initiation;
      properties=agent_properties, n = n, agent_step! = dummystep,
      model_step! = forest_step!)
  @test unique(data.step) == collect(0:10)
  @test unique(data.f) == [0.07,0.05]
  @test unique(data.d) == [0.8, 0.7, 0.6]
end

@testset "paramscan with replicates" begin
  agent_properties = Dict(:status => [length, count])
  n=10
  when = 1:n
  replicates=3
  parameters = Dict(:f=>[0.05,0.07], :d=>[0.6, 0.7, 0.8], :p=>0.01,
  :griddims=>(20, 20), :seed=>2)
  data = paramscan(parameters, forest_initiation;
       properties=agent_properties, n = n, agent_step! = dummystep,
       model_step! = forest_step!, replicates=replicates)
  @test size(data) == (((n+1)*6)*replicates, 6)  # the first 6 is the number of combinations of changing params
end
