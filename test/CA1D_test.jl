
@testset "Cellular automata 1D" begin
  using Agents.CA1D
  rules = Dict("111"=>"0", "110"=>"0", "101"=>"0", "100"=>"1", "011"=>"0", "010"=>"1", "001"=>"1", "000"=>"0")  # rule 22
  model = CA1D.build_model(rules=rules, ncols=101)
  model.agents[51].status="1"
  runs = 10
  data = CA1D.ca_run(model, runs);
  @test size(data) == (101, 21)
end