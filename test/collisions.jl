@testset "collisions" begin

speed = 0.01
function model_initiation(; diameter=0.01)
  Random.seed!(12345)
  space = ContinuousSpace(2; periodic = true, extend = (1.0, 1.0))
  model = ABM(Agent7, space);

  ## Add initial individuals
  for ind in 1:100
    pos = Tuple(rand(2))
    vel = sincos(2π*rand()) .* speed
    add_agent!(pos, model, vel, diameter, false)
  end
  return model
end

function collide!(agent, model)
  agent.moved && return
  contact = nearest_neighbor(agent, model, agent.weight)
  contact == nothing && return
  elastic_collision!(agent, contact)
  agent.moved = contact.moved = true
end

function agent_step!(agent, model)
  move_agent!(agent, model)
  collide!(agent, model)
end

function model_step!(model)
  for agent in allagents(model)
    agent.moved = false
  end
end

model = model_initiation()

function kinetic(model)
  K = sum(sum(abs2.(a.vel)) for a in allagents(model))
  p = (0.0, 0.0)
  for a in allagents(model)
    p = p .+ a.vel
  end
  return K, p
end

K0, p0 = kinetic(model)
initvels = [id2agent(i, model).vel for i in 1:100]

step!(model, agent_step!, model_step!, 100)

for id in 1:100
  @show id
  @test initvels[id] ≠ id2agent(id, model).vel
end

K1, p1 = kinetic(model)

# @test
