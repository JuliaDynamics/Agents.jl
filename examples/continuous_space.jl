# # A simple continuous space model

# This is a proof of concept for continuous space.
# The final api can use ideas in this example.

using Agents, Random, DataFrames, SQLite, Plots
using DrWatson: @dict

mutable struct Agent{D, F<:AbstractFloat} <: AbstractAgent
  id::Int
  pos::NTuple{D, F}
  vel::NTuple{D, F}
  diameter::F
end

function model_initiation(;N=100, speed=0.005, space_resolution=0.001, seed=0)
  Random.seed!(seed)
  space = Space(2)
  model = ABM(Agent, space);  # TODO fix Base.show

  ## Add initial individuals
  for ind in 1:N
    pos = Tuple(rand(0.0:space_resolution:1.0, 2))
    vel = sincos(2π*rand()) .* speed
    dia = space_resolution * 10
    add_agent!(model, pos, vel, dia)
  end

  Agents.index!(model)

  return model
end

function agent_step!(agent, model)
  move_agent!(agent, model)
  collide!(agent, model)
end

function collide!(agent, model)
  db = model.space.db
  # TODO: This should use some function "neighbors" or "within_radius" or so...
  interaction_radius = agent.diameter
  xleft = agent.pos[1] - interaction_radius
  xright = agent.pos[1] + interaction_radius
  yleft = agent.pos[2] - interaction_radius
  yright = agent.pos[2] + interaction_radius
  r = Agents.collect_ids(DBInterface.execute(model.space.searchq, (xleft, xright, yleft, yright, agent.id)))
  length(r) == 0 && return
  # change direction
  firstcontact = id2agent(r[1], model)
  agent.vel, firstcontact.vel = (agent.vel[1], firstcontact.vel[2]), (firstcontact.vel[1], agent.vel[2])
end

model = model_initiation(N=100, speed=0.005, space_resolution=0.001);
step!(model, agent_step!, 500)

# ## Example animation
model = model_initiation(N=100, speed=0.005, space_resolution=0.001);
anim = @animate for i ∈ 1:100
  xs = [a.pos[1] for a in values(model.agents)];
  ys = [a.pos[2] for a in values(model.agents)];
  p1 = scatter(xs, ys, label="", xlims=[0,1], ylims=[0, 1], xgrid=false, ygrid=false,xaxis=false, yaxis=false)
  title!(p1, "Day $(i)")
  step!(model, agent_step!, 1)
end
gif(anim, "movement.gif", fps = 8);

# ![](social_distancing.gif)
