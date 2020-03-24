# # A model of social distancing for spread of disease.

# This is a model similar to our SIR model of disease spread.
# But instead of having different cities, we let agents move in one continuous
# space and transfer the disease if they come into contact with one another. # This model is partly inspired by
# [this article](https://www.washingtonpost.com/graphics/2020/world/corona-simulator/).

# For a detailed description of the basics of the model, see the SIR example.

using Agents, Random, Plots
using DrWatson: @dict

# Let us first create a simple model were balls move around in a continuous space:


mutable struct Agent{D, F<:AbstractFloat} <: AbstractAgent
  id::Int
  pos::NTuple{D, F}
  vel::NTuple{D, F}
  diameter::F
  moved::Bool
end

function model_initiation(;N=100, speed=0.005, diameter=0.01, seed=0)
  Random.seed!(seed)
  space = ContinuousSpace(2; periodic = true, extend = (1, 1))
  model = ABM(Agent, space);

  ## Add initial individuals
  for ind in 1:N
    pos = Tuple(rand(2))
    vel = sincos(2π*rand()) .* speed
    add_agent!(pos, model, vel, diameter, false)
  end

  Agents.index!(model)
  return model
end

function agent_step!(agent, model)
  move_agent!(agent, model)
  collide!(agent, model)
end

function collide!(agent, model)
  agent.moved && return
  r = space_neighbors(agent.pos, model, agent.diameter)
  length(r) == 0 && return
  # change direction
  for contactid in 1:length(r)
    contact = id2agent(r[contactid], model)
    if contact.moved == false
      agent.vel, contact.vel = (agent.vel[1], contact.vel[2]), (contact.vel[1], agent.vel[2])
      contact.moved = true
    end
  end
  agent.moved=true
end

function model_step!(model)
  for agent in values(model.agents)
    agent.moved = false
  end
end

# ## Example animation
model = model_initiation(N=200, speed=0.005, diameter=0.01);
colors = rand(200)
@time anim = @animate for i ∈ 1:100
  xs = [a.pos[1] for a in values(model.agents)];
  ys = [a.pos[2] for a in values(model.agents)];
  p1 = scatter(xs, ys, label="", marker_z=colors, xlims=[0,1], ylims=[0, 1], xgrid=false, ygrid=false,xaxis=false, yaxis=false)
  title!(p1, "Day $(i)")
  step!(model, agent_step!, model_step!, 1)
end
gif(anim, "movement.gif", fps = 8);

# ![](social_distancing.gif)

# We can now add move functionality to these agents. They can be infected with a disease and transfer the disease to other agents around them.

mutable struct Agent2{D, F<:AbstractFloat} <: AbstractAgent
  id::Int
  pos::NTuple{D, F}
  vel::NTuple{D, F}
  moved::Bool
  days_infected::Int  # number of days since is infected
  status::Symbol  # 1: S, 2: I, 3:R
end

function model_initiation(;infection_period = 30, moveprob = 0.4,
  reinfection_probability = 0.05,
  detection_time = 14, death_rate = 0.02, β_und=0.6, β_det=0.05, N=100,
  speed=0.005, transmission_radius=0.01, initial_infected=5, seed=0)

  Random.seed!(seed)
  properties = @dict(β_und, β_det, infection_period, reinfection_probability,
  detection_time, death_rate, transmission_radius, moveprob)
  space = ContinuousSpace(2; periodic = true, extend = (1, 1))
  model = ABM(Agent2, space, properties=properties)

  ## Add initial individuals
  for ind in 1:N
    pos = Tuple(rand(2))
    vel = sincos(2π*rand()) .* speed
    status = ind <= initial_infected ? :I : :S
    add_agent!(pos, model, vel, false, 0, status)
  end

  Agents.index!(model)
  return model
end

function agent_step!(agent, model)
  if rand() < model.properties[:moveprob]
    move_agent!(agent, model)
  end
  transmit!(agent, model)
  update!(agent, model)
  recover_or_die!(agent, model)
end

function transmit!(agent, model)
  agent.status == :S && return
  r = space_neighbors(agent.pos, model, model.properties[:transmission_radius])
  length(r) == 1 && return
  # change direction
  for contactid in 1:length(r)
    if contactid == agent.id
      continue  
    end
    contact = id2agent(r[contactid], model)
    if contact.moved == false
      agent.vel, contact.vel = (agent.vel[1], contact.vel[2]), (contact.vel[1], agent.vel[2])
      contact.moved = true
    end
  end
  if agent.status == :I
    for contactid in 1:length(r)
      contact = id2agent(r[contactid], model)
      if contact.status == :S || (contact.status == :R && rand() ≤ model.properties[:reinfection_probability])
        contact.status = :I
      end
    end
  end
  agent.moved = true
end

update!(agent, model) = agent.status == :I && (agent.days_infected += 1)

function recover_or_die!(agent, model)
  if agent.days_infected ≥ model.properties[:infection_period]
    if rand() ≤ model.properties[:death_rate]
      kill_agent!(agent, model)
    else
      agent.status = :R
      agent.days_infected = 0
    end
  end
end

function model_step!(model)
  for agent in values(model.agents)
    agent.moved = false
  end
end

# Lets observe disease spread with different amounts of agent movements. First, agents move with a probability of 0.9.

model = model_initiation(N=400,moveprob = 0.9, initial_infected=30);
colordict = Dict(:I=>"red", :S=>"black", :R=>"green")
anim = @animate for i ∈ 1:200
  xs = [a.pos[1] for a in values(model.agents)];
  ys = [a.pos[2] for a in values(model.agents)];
  colors = [colordict[a.status] for a in values(model.agents)];
  p1 = scatter(xs, ys, color=colors, label="", xlims=[0,1], ylims=[0, 1], xgrid=false, ygrid=false,xaxis=false, yaxis=false)
  title!(p1, "Day $(i)")
  step!(model, agent_step!, 1)
end
gif(anim, "social_distancing0.9.gif", fps = 8);

# ![](social_distancing0.9.gif)

# And now reduce the movement probability to 0.5.

model = model_initiation(N=400,moveprob = 0.5, initial_infected=30);
anim = @animate for i ∈ 1:200
  xs = [a.pos[1] for a in values(model.agents)];
  ys = [a.pos[2] for a in values(model.agents)];
  colors = [colordict[a.status] for a in values(model.agents)];
  p1 = scatter(xs, ys, color=colors, label="", xlims=[0,1], ylims=[0, 1], xgrid=false, ygrid=false,xaxis=false, yaxis=false)
  title!(p1, "Day $(i)")
  step!(model, agent_step!, 1)
end
gif(anim, "social_distancing0.5.gif", fps = 8);

# ![](social_distancing0.5.gif)

# The number of infected clearly reduces.