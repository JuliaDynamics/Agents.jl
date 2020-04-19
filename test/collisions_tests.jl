@testset "collisions" begin

speed = 0.002
dt = 1.0
diameter = 0.015
function model_initiation()
  Random.seed!(12345)
  space = ContinuousSpace(2; periodic = true, extend = (1.0, 1.0))
  model = ABM(Agent6, space; properties = Dict(:c => 0));

  ## Add initial individuals
  for ind in 1:100
    pos = Tuple(rand(2))
    # these agents have infinite mass and 0 velocity. They are fixed.
    if ind > 50
      vel = sincos(2π*rand()) .* speed
      mass = 1.33
    else
      vel = (0.0, 0.0)
      mass = Inf
    end

    add_agent!(pos, model, vel, mass)
  end
  return model
end

agent_step!(agent, model) =  move_agent!(agent, model, dt)

function model_step!(model)
  ipairs = interacting_pairs(model, diameter)
  for (a1, a2) in ipairs
    e = elastic_collision!(a1, a2, :weight)
    if e
      model.properties[:c] += 1
    end
  end
end

function kinetic(model)
  K = sum(sum(abs2.(a.vel)) for a in allagents(model))
  p = (0.0, 0.0)
  for a in allagents(model)
    p = p .+ a.vel
  end
  return K, p
end

model = model_initiation()
initvels = [model[i].vel for i in 1:100]
x = count(!isapprox(initvels[id][1], model[id].vel[1]) for id in 1:100)
@test x == 0

K0, p0 = kinetic(model)
step!(model, agent_step!, model_step!, 10)
ipairs = interacting_pairs(model, diameter)
@test length(ipairs) ≠ 100
@test_broken length(ipairs) ≠ 0

step!(model, agent_step!, model_step!, 10)
x = count(any(initvels[id] .≠ model[id].vel) for id in 1:100)

y = count(!any(initvels[id] .≈ model[id].vel) for id in 1:50)
@test y == 0


# x should be at least the amount of collisions happened
@test_broken x > 0
@test_broken model.properties[:c] > 0
K1, p1 = kinetic(model)
@test K1 ≈ K0
# The following test is valid for non-infinite masses only
# @test p1[1] ≈ p0[1]
# @test p1[2] ≈ p0[2]


# using Plots
# pyplot()
# model = model_initiation()
# colors = [a.id for a in allagents(model)]
# anim = @animate for i ∈ 1:200
#   xs = [a.pos[1] for a in values(model.agents)];
#   ys = [a.pos[2] for a in values(model.agents)];
#   p1 = scatter(xs, ys, label="", marker_z=colors, xlims=[0,1], ylims=[0, 1], colorbar_title = "Agent ID")
#   title!(p1, "step $(i)")
#   step!(model, agent_step!, model_step!, round(Int, 1/dt))
#   println("step $i")
# end
# gif(anim, "movement.gif", fps = 45);

end
