# # A simple continuous space model

# This is a proof of concept for continuous space.
# The final api can use ideas in this example.

using Agents, Random, DataFrames, SQLite, Plots
using DrWatson: @dict
import Agents: Space
import Base.show
import Agents: add_agent!

mutable struct Agent{T<:Int,F<:AbstractFloat} <: AbstractAgent
  id::T
  pos::Tuple{F, F}
  vel::Tuple{F, F}  # velocity: speed and direction
  diameter::F
end

struct ContinuousSpace <: AbstractSpace  
  db::SQLite.DB
  insertq::SQLite.Stmt
  searchq::SQLite.Stmt
end

"Initializes a database with an empty table."
function ContinuousSpace()
  db = SQLite.DB()
  stmt = "CREATE TABLE tab (
    x REAL,
    y REAL,
    id INTEGER PRIMARY KEY)"
  DBInterface.execute(db, stmt)
  insertstmt = "INSERT INTO tab (x, y, id) VALUES (?, ?, ?)"
  q = DBInterface.prepare(db, insertstmt)
  searchq = "SELECT id FROM tab WHERE x BETWEEN ? AND ? AND y BETWEEN ? AND ? AND id != ?"
  q2 = DBInterface.prepare(db, searchq)
  ContinuousSpace(db, q, q2)
end

"Add many agents to the database"
function fill_db!(agents, model::ABM{A, S}) where {A, S<:ContinuousSpace}
  db = model.space.db
  for agent in agents
    p1, p2 = agent.pos
    DBInterface.execute(model.space.insertq, [p1, p2, agent.id])
  end
end

"""
Indexing the database can drastically improve retrieving data, but adding new
data can become slower because after each addition, index needs to be reworked.

Lack of index won't be noticed for small databases. Only use it when you have 
many agents and not many additions of agents.
"""
function index!(model)
  DBInterface.execute(model.space.db, "CREATE INDEX pos ON tab (x,y,id)")
end

# TODO
function Base.show(io::IO, abm::ContinuousSpace)
    s = "A ContinuousSpace"
    print(io, s)
end

function add_agent!(model::ABM{A, S}, properties...) where {A, S<:ContinuousSpace}
  db = model.space.db
  idq = DBInterface.execute(db, "select max(id) as maxid from tab") |> DataFrame
  id = ismissing(idq[1,1]) ? 1 : idq[1,1]+1
  agent = A(id, properties...)
  p1, p2 = agent.pos
  DBInterface.execute(model.space.insertq, (p1, p2, id))
  model.agents[id] = agent
  return agent
end

function model_initiation(;N=100, speed=0.005, space_resolution=0.001, seed=0)
  Random.seed!(seed)
  space = ContinuousSpace()
  model = ABM(Agent, space);  # TODO fix Base.show
  
  ## Add initial individuals
  for ind in 1:N
    pos = Tuple(rand(0.0:space_resolution:1.0, 2))
    vel = (speed, rand(0:0.01:2π))
    dia = space_resolution * 10
    add_agent!(model, pos, vel, dia)
  end
 
  index!(model)

  return model
end

function agent_step!(agent, model)
  move!(agent)
  collide!(agent, model)
end

function move!(agent)
  newx = agent.pos[1] + (agent.vel[1] * cos(agent.vel[2]))
  newy = agent.pos[2] + (agent.vel[1] * sin(agent.vel[2]))
  newx < 0.0 && (newx = newx + 1.0)
  newx > 1.0 && (newx = newx - 1.0)
  newy < 0.0 && (newy = newy + 1.0)
  newy > 1.0 && (newy = newy - 1.0)
  agent.pos = (newx, newy)
end

function collide!(agent, model)
  db = model.space.db
  interaction_radius = agent.diameter
  xleft = agent.pos[1] - interaction_radius
  xright = agent.pos[1] + interaction_radius
  yleft = agent.pos[2] - interaction_radius
  yright = agent.pos[2] + interaction_radius
  r = DBInterface.execute(model.space.searchq, (xleft, xright, yleft, yright, agent.id)) |> DataFrame
  size(r,1) == 0 && return
  # change direction
  firstcontact = id2agent(r[1,:id], model)
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


