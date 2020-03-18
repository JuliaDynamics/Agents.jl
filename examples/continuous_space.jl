# # A simple continuous space model

# This is a proof of concept for continuous space.
# The final api can use ideas in this example.

using Agents, Random, DataFrames, SQLite, Plots
using DrWatson: @dict
import Agents: Space
import Base.show
import Agents: add_agent!

const COORDS = collect(Iterators.flatten(('x':'z', 'a':'w')))

mutable struct Agent{D, F<:AbstractFloat} <: AbstractAgent
  id::Int
  pos::NTuple{D, F}
  vel::NTuple{D, F}  # velocity: speed and direction
  diameter::F
end

struct ContinuousSpace{E} <: AbstractSpace
  D::Int
  periodic::Bool
  extend::E
  db::SQLite.DB
  insertq::SQLite.Stmt
  searchq::SQLite.Stmt
end

"""
    Space(D::Int [, vel!]; periodic::Bool = false, extend = nothing)
Create a *continuous* space of dimensionality `D`.
In this case, your agent positions (field `pos`) should be of type `NTuple{D, F}`
where `F <: AbstractFloat`.
In addition, the agent type must have a third field `vel::NTuple{D, F}` representing
the agent's velocity.

The optional argument `vel` is a **function**, `vel!(agent, model)` that updates
the agent's velocities **before** the agent has been moved, see [`move_agent!`](@ref).
By default no update is done this way (you can of course change the agents velocities
during the agent interaction, the `vel!` functionality targets arbitrary forces).

# TODO: talk about periodicity

## Notes
You can imagine the evolution algorithm as an Euler scheme with `dt = 1` (here the step).
"""
function Space(D::Int = 2, vel = nothing; periodic = false, extend = nothing)
  # TODO: actually implement periodicity
  db = SQLite.DB()
  dimexpression = join("$x REAL, " for x in COORDS[1:D])
  stmt = "CREATE TABLE tab ("*dimexpression*"id INTEGER PRIMARY KEY)"
  DBInterface.execute(db, stmt)
  insertedxpression = join("$x, " for x in COORDS[1:D])
  qmarks = join("?, " for _ in 1:D)
  insertstmt = "INSERT INTO tab ($(insertedxpression)id) VALUES ($(qmarks)?)"
  q = DBInterface.prepare(db, insertstmt)
  searchexpr = join("$x BETWEEN ? AND ? AND " for x in COORDS[1:D])
  searchq = "SELECT id FROM tab WHERE $(searchexpr)id != ?"
  q2 = DBInterface.prepare(db, searchq)
  ContinuousSpace(D, periodic, extend, db, q, q2)
end

"Add many agents to the database"
function fill_db!(agents, model::ABM{A, S}) where {A, S<:ContinuousSpace}
  db = model.space.db
  for agent in agents
    DBInterface.execute(model.space.insertq, (agent.pos..., agent.id))
  end
end

"Collect IDs from an SQLite.Query where IDs are stored in `colname`"
function collect_ids(q::SQLite.Query; colname=:id)
  output = Union{Int, Missing}[]
  for row in q
    push!(output, row[colname])
  end
  return output
end

"""
Indexing the database can drastically improve retrieving data, but adding new
data can become slower because after each addition, index needs to be reworked.

Lack of index won't be noticed for small databases. Only use it when you have
many agents and not many additions of agents.
"""
function index!(model)
  D = model.space.D
  expr = join("$x," for x in COORDS[1:D])
  DBInterface.execute(model.space.db, "CREATE INDEX pos ON tab ($(expr)id)")
end

# TODO: re-check this at the end.
function Base.show(io::IO, abm::ContinuousSpace)
    s = "$(abm.D)-dimensional $(abm.periodic ? "periodic " : "")ContinuousSpace"
    print(io, s)
end

# TODO: This should also have a version with random position
function add_agent!(model::ABM{A, S}, properties...) where {A, S<:ContinuousSpace}
  db = model.space.db

  # TODO: This seems ineficient... Is there no way to directly get maximum of
  # the column "id" of the database? There _has_ to be a way for it.
  ids = collect_ids(DBInterface.execute(db, "select max(id) as id from tab"))
  id = ismissing(ids[1]) ? 1 : ids[1]+1
  agent = A(id, properties...)
  DBInterface.execute(model.space.insertq, (agent.pos..., id))
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

# TODO: change move! to instead be an overload of move_agent!
# and to call `vel!` first on the agent.

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
  r = collect_ids(DBInterface.execute(model.space.searchq, (xleft, xright, yleft, yright, agent.id)))
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
