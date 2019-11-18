@testset "Cellular automata 2D" begin
  using Agents.CA2D
  rules = (2,3,3)
  model = CA2D.build_model(rules=rules, dims=(100, 10), Moore=true)
  for i in 1:gridsize(model)
    if rand() < 0.1
      model.agents[i].status="1"
    end
  end
  runs = 2
  data = CA2D.ca_run(model, runs);
  @test size(data) == (1000, 5)
end