using BenchmarkTools, Test

n = initialize_model()
@btime step!($n, $agent_step!) teardown = (@test count(i -> i.type == :sheep, allagents(n)) > 0 &&
       count(i -> i.type == :wolf, allagents(n)) > 0)
