using DataFrames, SQLite
export ContinuousSpace, index!

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
  updateq::SQLite.Stmt
end

const COORDS = 'a':'z' # letters representing coordinates in database

"""
    ContinuousSpace(D::Int [, update_vel!]; periodic::Bool = false, extend = nothing, metric = "cityblock")
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

"""
function ContinuousSpace(D::Int, update_vel! = defvel;
  periodic = false, extend = nothing, metric = "cityblock")

  # TODO: implement using different metrics in space_neighbors
  @assert metric ∈ ("cityblock", "euclidean")
  periodic && @assert typeof(extend) <: NTuple{D} "`extend` must be ::NTuple{D} for periodic"
  # TODO: allow extend to be useful even without periodicity: agents bounce of walls then
  # (improve to do this `move_agent!`)

  db, q, q2, q3, q4 = prepare_database(D)
  ContinuousSpace(D, update_vel!, periodic, extend, metric, db, q, q2, q3, q4)
end

@deprecate Space(D::Int, update_vel!::Function) ContinuousSpace(D::Int, update_vel!::Function)

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
  searchq = "SELECT id FROM tab WHERE $(searchexpr)"[1:end-4]
  q2 = DBInterface.prepare(db, searchq)
  deleteq = "DELETE FROM tab WHERE id = ?"
  q3 = DBInterface.prepare(db, deleteq)
  updateexpr = strip(join("$x = ?," for x in COORDS[1:D]), ',')
  updateq = "UPDATE tab SET $updateexpr WHERE id = ?"
  q4 = DBInterface.prepare(db, updateq)
  return db, q, q2, q3, q4
end

defvel(a, m) = nothing

# TODO: re-check this at the end.
function Base.show(io::IO, abm::ContinuousSpace)
    s = "$(abm.D)-dimensional $(abm.periodic ? "periodic " : "")ContinuousSpace"
    abm.update_vel! ≠ defvel && (s *= " with velocity updates")
    print(io, s)
end

#######################################################################################
# SQLite database functions
#######################################################################################
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
    index!(model)
Index the database underlying the `ContinuousSpace` of the model.

This can drastically improve performance for retrieving data, but adding new
data can become slower because after each addition, index needs to be called again.

Lack of index won't be noticed for small databases. Only use it when you have
many agents and not many additions of agents.
"""
function index!(model)
  D = model.space.D
  expr = join("$x," for x in COORDS[1:D])
  DBInterface.execute(model.space.db, "CREATE INDEX pos ON tab ($(expr)id)")
end

#######################################################################################
# Extention of Agents.jl Model-Space interaction API
#######################################################################################
# central, low level function that is always called by all others!
function add_agent_pos!(agent::A, model::ABM{A, <: ContinuousSpace}) where {A<:AbstractAgent}
  DBInterface.execute(model.space.insertq, (agent.pos..., agent.id))
  model.agents[agent.id] = agent
  return agent
end

function biggest_id(model::ABM{A, <: ContinuousSpace}) where {A}
  db = model.space.db
  ids = collect_ids(DBInterface.execute(db, "select max(id) as id from tab"))
  id = ismissing(ids[1]) ? 0 : ids[1]
end

function randompos(space::ContinuousSpace)
  pos = Tuple(rand(space.D))
  space.extend ≠ nothing && (pos = pos .* space.extend)
  return pos
end

function add_agent!(agent::A, model::ABM{A, <: ContinuousSpace}) where {A<:AbstractAgent}
  agent.pos = randompos(model.space)
  add_agent_pos!(agent, model)
end

function add_agent!(agent::A, pos, model::ABM{A, <: ContinuousSpace}) where {A<:AbstractAgent}
  agent.pos = pos
  add_agent_pos!(agent, model)
end

# versions that create the agents
function add_agent!(model::ABM{A, <: ContinuousSpace}, args...) where {A<:AbstractAgent}
  add_agent!(randompos(model.space), model, args...)
end

function add_agent!(pos::Tuple, model::ABM{A, <: ContinuousSpace}, args...) where {A<:AbstractAgent}
  id = biggest_id(model) + 1
  agent = A(id, pos, args...)
  DBInterface.execute(model.space.insertq, (agent.pos..., id))
  model.agents[id] = agent
  return agent
end

"""
    move_agent!(agent::A, model::ABM{A, ContinuousSpace}, dt = 1.0)
Propagate the agent forwards one step according to its velocity,
_after_ updating the agent's velocity (see [`Space`](@ref)).

For this continuous space version of `move_agent!`, the "evolution algorithm"
is a trivial Euler scheme with `dt` the step size, i.e. the agent position is updated
as `agent.pos += agent.vel * dt`.
"""
function move_agent!(agent::A, model::ABM{A, S, F, P}, dt = 1.0) where {A<:AbstractAgent, S <: ContinuousSpace, F, P}
  model.space.update_vel!(agent, model)
  agent.pos = agent.pos .+ dt .* agent.vel
  if model.space.periodic
    agent.pos = mod.(agent.pos, model.space.extend)
  end
  DBInterface.execute(model.space.updateq, (agent.pos..., agent.id))
  return agent.pos
end

function kill_agent!(agent::AbstractAgent, model::ABM{A, S}) where {A, S<:ContinuousSpace}
  DBInterface.execute(model.space.deleteq, (agent.id,))
  delete!(model.agents, agent.id)
  return model
end

function genocide!(model::ABM{A, S}, n::Int) where {A, S<:ContinuousSpace}
  ids = strip(join("$id," for id in keys(model.agents) if id > n), ',')
  DBInterface.execute(model.space.db, "DELETE FROM tab WHERE id IN ($ids)")
  for id in keys(model.agents)
    id > n && (delete!(model.agents, id))
  end
  return model
end

function genocide!(model::ABM{A, S}, f::Function) where {A, S<:ContinuousSpace}
  ids = strip(join("$(agent.id)," for agent in values(model.agents) if f(agent)), ',')
  DBInterface.execute(model.space.db, "DELETE FROM tab WHERE id IN ($ids)")
  for agent in values(model.agents)
    f(agent) && (delete!(model.agents, agent.id))
  end
  return model
end

function genocide!(model::ABM{A, S}) where {A, S<:ContinuousSpace}
  DBInterface.execute(model.space.db, "DELETE FROM tab")
  for agent in model.agents
    delete!(model.agents, agent.id)
  end
end

# TODO: at the moment this function doesn't check the metric and uses only cityblock
# we can easily adjust to arbitrary metric by doing a final check
# filter!(...) where the filtering function checks distances w.r.t. `r`.
function space_neighbors(pos::Tuple, model, r::Real)
  left = pos .- r
  right = pos .+ r
  res = interlace(left, right)
  collect_ids(DBInterface.execute(model.space.searchq, res))
end

@generated function interlace(left::NTuple{D}, right::NTuple{D}) where {D}
  a = [[:(left[$i]), :(right[$i])] for i=1:D]
  b = vcat(a...)
  quote
    tuple($(b...))
  end
end
