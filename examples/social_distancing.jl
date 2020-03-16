# # A model of social distancing for spread of disease.

# This is a model similar to our SIR model of disease spread. But instead of having different cities, we let agents move in one continuous space and transfer the disease if they come into contact with one another. This model is partly inspired by [this article](https://www.washingtonpost.com/graphics/2020/world/corona-simulator/).

# For a detailed description of the basics of the model, see the SIR example.

# We note that Agents.jl does not have an API for modeling continuous space. As we implement it, this page will be updated as well.

using Agents, Random, DataFrames, SQLite, Plots
using DrWatson: @dict

mutable struct Agent <: AbstractAgent
  id::Int
  pos::Tuple{Float64, Float64}
  dir::Float64  # direction of movement
  days_infected::Int  # number of days since is infected
  status::Symbol  # 1: S, 2: I, 3:R
end

function model_initiation(;infection_period = 30, moveprob = 0.4,
  reinfection_probability = 0.05,
  detection_time = 14, death_rate = 0.02, β_und=0.6, β_det=0.05, N=100,
  movement=0.005, transmission_radius=0.0001, initial_infected=5, seed=0)
  Random.seed!(seed)
  # movedist = Normal(0, movement)
  # Create a database of agent positions
  # A database allows fast access to agents within any area.
  db = SQLite.DB()
  stmt = "CREATE TABLE tab (
    x REAL,
    y REAL,
    id INTEGER,
    PRIMARY KEY (x, y))"
  DBInterface.execute(db, stmt)

  properties = @dict(β_und, β_det, infection_period, reinfection_probability,
  detection_time, death_rate, movement, transmission_radius, moveprob, db)
  model = ABM(Agent; properties=properties)
  
  ## Add initial individuals
  insertstmt = "INSERT INTO tab (x, y, id) VALUES (?, ?, ?)"
  q = DBInterface.prepare(db, insertstmt)
  for ind in 1:N
    pos = Tuple(rand(2))
    add_agent!(model, pos, rand(0:0.01:2π), 0, :S) # Susceptible
    DBInterface.execute(q, [pos[1], pos[2], ind])
  end
  DBInterface.execute(db, "CREATE INDEX pos ON tab (x,y)")
  # Infect one individual
  for ind in rand(1:N, initial_infected)
    model.agents[ind].status = :I
  end
  
  return model
end

function agent_step!(agent, model)
  move!(agent, model)
  transmit!(agent, model)
  update!(agent, model)
  recover_or_die!(agent, model)
end

function move!(agent, model)
  rand() > model.properties[:moveprob] && return
  newx = agent.pos[1] + (model.properties[:movement] * cos(agent.dir))
  newy = agent.pos[2] + (model.properties[:movement] * sin(agent.dir))
  newx < 0.0 && (newx = newx + 1.0)
  newx > 1.0 && (newx = newx - 1.0)
  newy < 0.0 && (newy = newy + 1.0)
  newy > 1.0 && (newy = newy - 1.0)
  agent.pos = (newx, newy)
end

function transmit!(agent, model)
  agent.status == :S && return
  prop = model.properties
  db = model.properties[:db]
  xleft = agent.pos[1] - prop[:transmission_radius]
  xright = agent.pos[1] + prop[:transmission_radius]
  yleft = agent.pos[2] - prop[:transmission_radius]
  yright = agent.pos[2] + prop[:transmission_radius]
  searchstmt = "SELECT id FROM tab WHERE x BETWEEN $xleft AND $xright AND y BETWEEN $yleft AND $yright AND id != $(agent.id)"
  r = DBInterface.execute(db, searchstmt) |> DataFrame
  size(r,1) == 0 && return
  
  for contactID in r[!, :id]
    contact = id2agent(contactID, model)
    if contact.status == :S || (contact.status == :R && rand() ≤ prop[:reinfection_probability])
      contact.status = :I
    end
  end
  # change direction
  firstcontact = id2agent(r[1,:id], model)
  agent.dir, firstcontact.dir = firstcontact.dir, agent.dir
end

update!(agent, model) = agent.status == :I && (agent.days_infected += 1)

function recover_or_die!(agent, model)
  if agent.days_infected ≥ model.properties[:infection_period]
    if rand() ≤ model.properties[:death_rate]
      kill_agent!(agent, model)
      delstmt = "DELETE FROM tab WHERE id = $(agent.id)"
      DBInterface.execute(model.properties[:db], delstmt)
    else
      agent.status = :R
      agent.days_infected = 0
    end
  end
end

model = model_initiation(moveprob=0.4, transmission_radius=0.02, N=200, death_rate = 0.01)

infected(x) = count(i == :I for i in x)
recovered(x) = count(i == :R for i in x)
data_to_collect = Dict(:status => [infected, recovered, length])
data = step!(model, agent_step!, 500, data_to_collect)
data[1:10, :]

# ## Example animation
model = model_initiation(moveprob=0.9, movement=0.005, transmission_radius=0.02, N=100, death_rate = 0.01)
colordict = Dict(:I=>"red", :S=>"black", :R=>"green")
anim = @animate for i ∈ 1:100
  xs = [a.pos[1] for a in values(model.agents)];
  ys = [a.pos[2] for a in values(model.agents)];
  colors = [colordict[a.status] for a in values(model.agents)];
  p1 = scatter(xs, ys, color=colors, label="", xlims=[0,1], ylims=[0, 1], xgrid=false, ygrid=false,xaxis=false, yaxis=false)
  title!(p1, "Day $(i)")
  step!(model, agent_step!, 1)
end
gif(anim, "social_distancing.gif", fps = 8);

# ![](social_distancing.gif)


