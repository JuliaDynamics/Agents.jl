
@testset "Cellular automata 1D" begin
  using Agents.CA1D
  rules = Dict("111"=>"0", "110"=>"0", "101"=>"0", "100"=>"1", "011"=>"0",
  "010"=>"1", "001"=>"1", "000"=>"0")  # rule 22
  ncols = 101
  model = CA1D.build_model(rules=rules, ncols=ncols)
  model.agents[51].status="1"
  runs = 10
  data = CA1D.ca_run(model, runs);
  @test size(data) == (ncols*(runs+1), 4)
end

@testset "Cellular automata 2D" begin
  using Agents.CA2D
  rules = (2,3,3)
  dims=(100, 10)
  model = CA2D.build_model(rules=rules, dims=dims, Moore=true)
  for i in 1:nv(model)
    if rand() < 0.1
      model.agents[i].status="1"
    end
  end
  runs = 2
  data = CA2D.ca_run(model, runs);
  @test size(data) == ((dims[1]*dims[2])*(runs+1), 4)
end
