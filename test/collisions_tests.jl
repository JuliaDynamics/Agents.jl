@testset "collisions" begin

speed = 0.002
diameter = 0.015
function model_initiation()
  Random.seed!(12345)
  space = ContinuousSpace(2; periodic = true, extend = (1.0, 1.0))
  model = ABM(Agent6, space; properties = Dict(:c => 0));

  ## Add initial individuals
  for ind in 1:100
    pos = Tuple(rand(2))
    vel = sincos(2π*rand()) .* speed
    add_agent!(pos, model, vel, diameter)
  end
  return model
end

agent_step!(agent, model) =  move_agent!(agent, model)

function model_step!(model)
  ipairs = interacting_pairs(model, diameter)
  for (a1, a2) in ipairs
    e = elastic_collision!(a1, a2)
    if e
      model.properties[:c] += 2
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
initvels = [id2agent(i, model).vel for i in 1:100]
x = count(!isapprox(initvels[id][1], id2agent(id, model).vel[1]) for id in 1:100)
@test x == 0

K0, p0 = kinetic(model)
step!(model, agent_step!, model_step!, 10)
ipairs = interacting_pairs(model, diameter)
@test length(ipairs) ≠ 100
@test length(ipairs) ≠ 0

step!(model, agent_step!, model_step!, 10)
x = count(!isapprox(initvels[id][1], id2agent(id, model).vel[1]) for id in 1:100)
# x can never be odd here, because only pairs of agents can change their velocities
@test iseven(x)
# x should be the same as the amount of collisions that happened.
# If not, some agent changes velocity outside of collision (which should not happen
# in this model)
@test x == model.properties[:c] # test that at least 10 agents have collided

K1, p1 = kinetic(model)
@test K1 ≈ K0
@test p1[1] ≈ p0[1]
@test p1[2] ≈ p0[2]


# using Plots
# pyplot()
# model = model_initiation()
# colors = [a.id for a in allagents(model)]
# anim = @animate for i ∈ 1:200
#   xs = [a.pos[1] for a in values(model.agents)];
#   ys = [a.pos[2] for a in values(model.agents)];
#   p1 = scatter(xs, ys, label="", marker_z=colors, xlims=[0,1], ylims=[0, 1], colorbar_title = "Agent ID")
#   title!(p1, "step $(i)")
#   step!(model, agent_step!, model_step!, 1)
#   println("step $i")
# end
# gif(anim, "movement.gif", fps = 45);

end
