# # A simple continuous space model

# This is a proof of concept for continuous space.
# The final api can use ideas in this example.

using Agents, Random, DataFrames, SQLite, Plots
using DrWatson: @dict
import Agents: Space
import Base.show

# TODO
function Base.show(io::IO, abm::ContinuousSpace)
    # s = "$(nameof(typeof(abm))) with $(nv(abm)) nodes and $(ne(abm)) edges"
    s = "A ContinuousSpace"
    print(io, s)
end

mutable struct Agent <: AbstractAgent
  id::Int
  pos::Tuple{Float64, Float64}
  dir::Float64  # direction of movement
end

struct ContinuousSpace <: AbstractSpace  
  db::SQLite.DB
  movesize
  space_resolution
  interaction_radius
end

"Initializes a database with an empty table."
function ContinuousSpace(;movesize=0.005, resolution=3, interaction_radius=10.0^(-resolution))
  db = SQLite.DB()
  stmt = "CREATE TABLE tab (
    x REAL,
    y REAL,
    id INTEGER,
    PRIMARY KEY (x, y))"
  DBInterface.execute(db, stmt)
  
  ContinuousSpace(db, movesize, resolution, interaction_radius)
end

Space(;movesize, resolution, interaction_radius=10.0^(-resolution)) = ContinuousSpace(movesize=movesize,resolution=resolution,interaction_radius=interaction_radius)

function fill_db!(model::ABM)
  agents = values(model.agents)
  db = space.db
  insertstmt = "INSERT INTO tab (x, y, id) VALUES (?, ?, ?)"
  q = DBInterface.prepare(db, insertstmt)
  for agent in agents
    p1, p2 = round.(agent.pos, digits=model.space.resolution)
    DBInterface.execute(q, [p1, p2, agent.id])
  end
  DBInterface.execute(db, "CREATE INDEX pos ON tab (x,y,id)")
end

function model_initiation(;N=100, movesize=0.005, space_resolution=3, seed=0)
  Random.seed!(seed)
  space = Space(movesize=movesize, resolution=space_resolution)
  model = ABM(Agent, space);  # TODO fix Base.show
  
  ## Add initial individuals
  for ind in 1:N
    pos = Tuple(round.(rand(2), digits=space_resolution))
    add_agent!(model, pos, rand(0:0.01:2π)) # TODO fix add_agent!
  end
 
  # Fill space.db with agents
  fill_db!(model)

  return model
end

function agent_step!(agent, model)
  move!(agent, model)
  collide!(agent, model)
end

function move!(agent, model)
  newx = agent.pos[1] + (model.space.movesize * cos(agent.dir))
  newy = agent.pos[2] + (model.space.movesize * sin(agent.dir))
  newx < 0.0 && (newx = newx + 1.0)
  newx > 1.0 && (newx = newx - 1.0)
  newy < 0.0 && (newy = newy + 1.0)
  newy > 1.0 && (newy = newy - 1.0)
  agent.pos = (newx, newy)
end

function collide!(agent, model)
  db = model.space.db
  interaction_radius = model.space.interaction_radius
  xleft = agent.pos[1] - interaction_radius
  xright = agent.pos[1] + interaction_radius
  yleft = agent.pos[2] - interaction_radius
  yright = agent.pos[2] + interaction_radius
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


