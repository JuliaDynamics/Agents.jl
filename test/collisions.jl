@testset "collisions" begin

speed = 0.01
function model_initiation(;N=100, diameter=0.01, seed=0)
  Random.seed!(seed)
  space = ContinuousSpace(2; periodic = true, extend = (1.0, 1.0))
  model = ABM(Agent6, space);

  ## Add initial individuals
  for ind in 1:N
    pos = Tuple(rand(2))
    vel = sincos(2π*rand()) .* speed
    add_agent!(pos, model, vel, diameter, false)
  end
end
