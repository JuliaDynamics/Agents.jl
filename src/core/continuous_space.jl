using DataFrames, SQLite

#######################################################################################
# Continuous space structure
#######################################################################################
struct ContinuousSpace{F, E, M} <: AbstractSpace
  D::Int
  vel!::F
  periodic::Bool
  extend::E
  metric::String
  db::SQLite.DB
  insertq::SQLite.Stmt
  searchq::SQLite.Stmt
end

const COORDS = collect(Iterators.flatten(('x':'z', 'a':'w')))

"""
    Space(D::Int [, vel!]; periodic::Bool = false, extend = nothing, metric = "cityblock")
Create a *continuous* space of dimensionality `D`.
In this case, your agent positions (field `pos`) should be of type `NTuple{D, F}`
where `F <: AbstractFloat`.
In addition, the agent type must have a third field `vel::NTuple{D, F}` representing
the agent's velocity.

The optional argument `vel` is a **function**, `vel!(agent, model)` that updates
the agent's velocities **before** the agent has been moved, see [`move_agent!`](@ref).
By default no update is done this way (you can of course change the agents velocities
during the agent interaction, the `vel!` functionality targets arbitrary forces).

## Keywords

* `periodic = false` : whether continuous space is periodic or not
* `extend = nothing` : only useful

`periodic` specifies the boundary conditions of the space. If true, when an agent passes through one side of the space, it re-appears on the opposite side with the same velocity. 

## Notes
You can imagine the evolution algorithm as an Euler scheme with `dt = 1` (here the step).
"""
function Space(D::Int, vel = (x, y) -> nothing;
    periodic = false, extend = nothing, metric = "cityblock")

  @assert metric ∈ ("cityblock", "euclidean")
  # TODO: actually implement periodicity
  # TODO: allow extend to be something even without periodicity: agents bounce of walls then
  # (improve `move_agent!`)

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
  ContinuousSpace(D, vel, periodic, extend, metric, db, q, q2)
end

# TODO: re-check this at the end.
function Base.show(io::IO, abm::ContinuousSpace)
    s = "$(abm.D)-dimensional $(abm.periodic ? "periodic " : "")ContinuousSpace"
    print(io, s)
end

#######################################################################################
# SQLite database functions
#######################################################################################
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

# TODO: index! needs a better name
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

#######################################################################################
# Extention of Agents.jl API for continuous space
#######################################################################################
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

# TODO: change move this to arbitrary dimensions
"""
    move_agent!(agent::A, model::ABM{A, ContinuousSpace})
In the case of continuous space, `move_agent!` propagates the agent forwards one step
according to its velocity, _after_ updating the agent's velocity
(see [`Space(D::Int)`](@ref)).
"""
function move_agent!(agent::A, model::ABM{A, S, F, P}) where {A<:AbstractAgent, S <: ContinuousSpace, F, P}
  model.space.vel!(agent, model)
  agent.pos = agent.pos .+ agent.vel # explicitly vel is multipled by 1, the dt
  # TODO: here enforcing periodic b.c. should happen properly for arbitrary D
  newx, newy = agent.pos
  newx < 0.0 && (newx = newx + 1.0)
  newx > 1.0 && (newx = newx - 1.0)
  newy < 0.0 && (newy = newy + 1.0)
  newy > 1.0 && (newy = newy - 1.0)
  agent.pos = (newx, newy)
end
