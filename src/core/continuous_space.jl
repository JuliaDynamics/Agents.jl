using DataFrames, SQLite

#######################################################################################
# Continuous space structure
#######################################################################################
struct ContinuousSpace{F, E} <: AbstractSpace
  D::Int
  update_vel!::F
  periodic::Bool
  extend::E
  metric::String
  db::SQLite.DB
  insertq::SQLite.Stmt
  searchq::SQLite.Stmt
  deleteq::SQLite.Stmt
end

const COORDS = 'a':'z' # letters representing coordinates in database

# TODO: name `vel!` is not good, too short. Find something better.
"""
    Space(D::Int [, update_vel!]; periodic::Bool = false, extend = nothing, metric = "cityblock")
Create a `ContinuousSpace` of dimensionality `D`.
In this case, your agent positions (field `pos`) should be of type `NTuple{D, F}`
where `F <: AbstractFloat`.
In addition, the agent type must have a third field `vel::NTuple{D, F}` representing
the agent's velocity.

The optional argument `update_vel!` is a **function**, `update_vel!(agent, model)` that updates
the agent's velocities **before** the agent has been moved, see [`move_agent!`](@ref).
You can of course change the agents velocities
during the agent interaction, the `update_vel!` functionality targets arbitrary forces.
By default no update is done this way.

## Keywords

* `periodic = false` : whether continuous space is periodic or not
* `extend = nothing` : currently only useful in periodic space. If `periodic = true`
  `extend` must be a `NTuple{D}`, where each entry is the extent of each dimension
  (after which periodicity happens. All dimensions start at 0).

## Notes
You can imagine the evolution algorithm as an Euler scheme with `dt = 1` (here the step).
"""
function Space(D::Int, update_vel! = defvel;
  periodic = false, extend = nothing, metric = "cityblock")

  # TODO: implement using different metrics in space_neighbors
  @assert metric ∈ ("cityblock", "euclidean")
  periodic && @assert typeof(extend) <: NTuple{D} "`extend` must be ::NTuple{D} for periodic"
  # TODO: allow extend to be useful even without periodicity: agents bounce of walls then
  # (improve to do this `move_agent!`)

  db, q, q2, q3 = prepare_database(D)
  ContinuousSpace(D, update_vel!, periodic, extend, metric, db, q, q2, q3)
end

function prepare_database(D)
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
  deleteexpr = "DELETE FROM tab WHERE id = ?"
  q3 = DBInterface.prepare(db, deleteexpr)
  return db, q, q2, q3
end

defvel(a, m) = nothing

# TODO: re-check this at the end.
function Base.show(io::IO, abm::ContinuousSpace)
    s = "$(abm.D)-dimensional $(abm.periodic ? "periodic " : "")ContinuousSpace"
    update_vel! ≠ defvel && (s *= " with velocity updates")
    print(io, s)
end

#######################################################################################
# SQLite database functions
#######################################################################################
# TODO: is this function used anywhere anymore, since add_agent! does the adding?
"Add many agents to the database"
function fill_db!(agents, model::ABM{A, S}) where {A, S<:ContinuousSpace}
  db = model.space.db
  for agent in agents
    DBInterface.execute(model.space.insertq, (agent.pos..., agent.id))
  end
end

"Collect IDs from an SQLite.Query where IDs are stored in `colname`"
function collect_ids(q::SQLite.Query, colname=:id)
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
# TODO: improve the doc string of add_agent! to somehow reflect that it works
# universaly for any space
function add_agent!(model::ABM{A, <:ContinuousSpace}, properties...) where {A}
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

"""
    move_agent!(agent::A, model::ABM{A, ContinuousSpace})
In the case of continuous space, `move_agent!` propagates the agent forwards one step
according to its velocity, _after_ updating the agent's velocity
(see [`Space`](@ref)).
"""
function move_agent!(agent::A, model::ABM{A, S, F, P}) where {A<:AbstractAgent, S <: ContinuousSpace, F, P}
  model.space.update_vel!(agent, model)
  agent.pos = agent.pos .+ agent.vel # explicitly vel is multipled by 1, the dt
  if model.space.periodic
    agent.pos = mod.(agent.pos, model.space.extend)
  end
  return agent.pos
end

function kill_agent!(agent::AbstractAgent, model::ABM{A, S}) where {A, S<:ContinuousSpace}
  DBInterface.execute(model.space.deleteq, (agent.id,))
  delete!(model.agents, agent.id)
  return model
end

function genocide!(agentIDs::AbstractArray{Int}, model::ABM{A, S}) where {A, S<:ContinuousSpace}
  DBInterface.execute(model.space.db,
  "DELETE FROM tab WHERE id IN $(Tuple(agentIDs))")
  for id in agentIDs
    delete!(model.agents, id)
  end
  return model
end

function genocide!(agents::AbstractArray, model::ABM{A, S}) where {A, S<:ContinuousSpace}
  DBInterface.execute(model.space.db,
  "DELETE FROM tab WHERE id IN $(Tuple([a.id for a in agents]))"
  )
  for agent in agents
    delete!(model.agents, agent.id)
  end
  return model
end

function genocide!(model::ABM{A, S}) where {A, S<:ContinuousSpace}
  DBInterface.execute(model.space.db, "DELETE FROM tab")
  for agent in model.agents
    delete!(model.agents, agent.id)
  end
end