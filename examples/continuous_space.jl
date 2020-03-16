# # A simple continuous space model

# This is a proof of concept for continuous space.
# The final api can use ideas in this example.

using Agents, Random, DataFrames, SQLite, Plots
using DrWatson: @dict

mutable struct Agent <: AbstractAgent
  id::Int
  pos::Tuple{Float64, Float64}
  dir::Float64  # direction of movement
end

function model_initiation(;N=100, movesize=0.005, space_resolution=3, seed=0)
  Random.seed!(seed)
  # Create a database of agent positions
  # A database allows fast access to agents within any area.
  db = SQLite.DB()
  stmt = "CREATE TABLE tab (
    x REAL,
    y REAL,
    id INTEGER,
    PRIMARY KEY (x, y))"
  DBInterface.execute(db, stmt)

  interaction_radius = 10.0^(-space_resolution)
  properties = @dict(movesize, db, space_resolution, interaction_radius)
  model = ABM(Agent; properties=properties)
  
  ## Add initial individuals
  insertstmt = "INSERT INTO tab (x, y, id) VALUES (?, ?, ?)"
  q = DBInterface.prepare(db, insertstmt)
  for ind in 1:N
    pos = Tuple(round.(rand(2), digits=space_resolution))
    add_agent!(model, pos, rand(0:0.01:2π)) # Susceptible
    DBInterface.execute(q, [pos[1], pos[2], ind])
  end
  DBInterface.execute(db, "CREATE INDEX pos ON tab (x,y)")
 
  return model
end

function agent_step!(agent, model)
  move!(agent, model)
  collide!(agent, model)
end

function move!(agent, model)
  newx = agent.pos[1] + (model.properties[:movesize] * cos(agent.dir))
  newy = agent.pos[2] + (model.properties[:movesize] * sin(agent.dir))
  newx < 0.0 && (newx = newx + 1.0)
  newx > 1.0 && (newx = newx - 1.0)
  newy < 0.0 && (newy = newy + 1.0)
  newy > 1.0 && (newy = newy - 1.0)
  agent.pos = (newx, newy)
end

function collide!(agent, model)
  prop = model.properties
  db = model.properties[:db]
  xleft = agent.pos[1] - prop[:interaction_radius]
  xright = agent.pos[1] + prop[:interaction_radius]
  yleft = agent.pos[2] - prop[:interaction_radius]
  yright = agent.pos[2] + prop[:interaction_radius]
  searchstmt = "SELECT id FROM tab WHERE x BETWEEN $xleft AND $xright AND y BETWEEN $yleft AND $yright AND id != $(agent.id)"
  r = DBInterface.execute(db, searchstmt) |> DataFrame
  size(r,1) == 0 && return
  # change direction
  firstcontact = id2agent(r[1,:id], model)
  agent.dir, firstcontact.dir = firstcontact.dir, agent.dir
end

model = model_initiation(N=100, movesize=0.005)
step!(model, agent_step!, 500)

# ## Example animation
model = model_initiation(N=100, movesize=0.005)
anim = @animate for i ∈ 1:100
  xs = [a.pos[1] for a in values(model.agents)];
  ys = [a.pos[2] for a in values(model.agents)];
  p1 = scatter(xs, ys, label="", xlims=[0,1], ylims=[0, 1], xgrid=false, ygrid=false,xaxis=false, yaxis=false)
  title!(p1, "Day $(i)")
  step!(model, agent_step!, 1)
end
gif(anim, "movement.gif", fps = 8);

# ![](social_distancing.gif)


