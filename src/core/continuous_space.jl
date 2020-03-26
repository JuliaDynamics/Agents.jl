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
  searchqNoId::SQLite.Stmt
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
* `extend::NTuple{D} = ones` : Extend of space. The `d` dimension starts at 0
  and ends at `extend[d]`. If `periodic = true`, this is also when
  periodicity occurs. If `periodic ≠ true`, `extend` is only used at plotting.
"""
function ContinuousSpace(D::Int, update_vel! = defvel;
  periodic = false, extend = ntuple(one, D), metric = "cityblock")

  # TODO: implement using different metrics in space_neighbors
  @assert metric ∈ ("cityblock", "euclidean")

  # TODO: allow extend to be useful even without periodicity: agents bounce of walls then
  # (improve to do this `move_agent!`)

  db, q, q2, q3, q4, q5 = prepare_database(D)
  ContinuousSpace(D, update_vel!, periodic, extend, metric, db, q, q2, q3, q4, q5)
end

# Deprecate Space constructor
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
  searchq = "SELECT id FROM tab WHERE $(searchexpr)id != ?"
  q2 = DBInterface.prepare(db, searchq)
  deleteq = "DELETE FROM tab WHERE id = ?"
  q3 = DBInterface.prepare(db, deleteq)
  updateexpr = strip(join("$x = ?," for x in COORDS[1:D]), ',')
  updateq = "UPDATE tab SET $updateexpr WHERE id = ?"
  q4 = DBInterface.prepare(db, updateq)
  searchexpr2 = join("$x BETWEEN ? AND ? AND " for x in COORDS[1:D])
  searchq2 = "SELECT id FROM tab WHERE $(searchexpr2)"[1:end-4]
  q5 = DBInterface.prepare(db, searchq2)
  return db, q, q2, q3, q4, q5
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
_after_ updating the agent's velocity (see [`ContinuousSpace`](@ref)).

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
"""
    space_neighbors(pos::Tuple, model::ABM, r::Real)
Return IDs of all agents within radius `r` from a particular position `pos` for any space.
"""
function space_neighbors(pos::Tuple, model, r::Real)
  left = pos .- r
  right = pos .+ r
  res = interlace(left, right)
  collect_ids(DBInterface.execute(model.space.searchqNoId, res))
end

"""
    space_neighbors(agent::AbstractAgent, model::ABM, r::Real)
Return neighbours of a particular agent, within radius `r` for any space.
"""
function space_neighbors(agent::A, model::ABM{A, <:ContinuousSpace}, r::Real) where {A<:AbstractAgent}
  left = agent.pos .- r
  right = agent.pos .+ r
  res = interlace(left, right)
  collect_ids(DBInterface.execute(model.space.searchq, (res...,agent.id)))
end

@generated function interlace(left::NTuple{D}, right::NTuple{D}) where {D}
  a = [[:(left[$i]), :(right[$i])] for i=1:D]
  b = vcat(a...)
  quote
    tuple($(b...))
  end
end

#######################################################################################
# Continuous space exclusive
#######################################################################################
export nearest_neighbor, elastic_collision!, interacting_pairs

"""
    nearest_neighbor(agent, model, r) → nearest
Return the agent that has the closest distance to given `agent`, according to the
space's metric.
Valid only in continuous space.
"""
function nearest_neighbor(agent, model, r)
  n = space_neighbors(agent, model, r)
  length(n) == 0 && return nothing
  d, j = Inf, 0
  for i in 1:length(n)
    @inbounds dnew = sqrt(sum(abs2.(agent.pos .- id2agent(n[i], model).pos)))
    _, j = findmin(d)
    if dnew < d
      d, j = dnew, i
    end
  end
  return id2agent(n[j], model)
end

using LinearAlgebra

"""
    elastic_collision!(a, b, f = nothing)
Resolve a (hypothetical) elastic collision between the two agents `a, b`.
They are assumed to be disks of equal size touching tangentially.
Their velocities (field `vel`) are adjusted for an elastic collision happening between them.
This function works only for two dimensions.
Notice that collision only happens if both disks face each other, to avoid
collision-after-collision.

If `f` is a `Symbol`, then the agent property `f`, e.g. `:mass`, is taken as a mass
to weight the two agents for the collision. By default no weighting happens.

One of the two agents can have infinite "mass", and then acts as an immovable object
that specularly reflects the other agent. In this case of course momentum is not
conserved, but kinetic energy is still conserved.
"""
function elastic_collision!(a, b, f = nothing)
  # Do elastic collision according to
  # https://en.wikipedia.org/wiki/Elastic_collision#Two-dimensional_collision_with_two_moving_objects
  v1, v2, x1, x2 = a.vel, b.vel, a.pos, b.pos
  length(v1) != 2 && error("This function works only for two dimensions.")
  r1 = x1 .- x2; r2 = x2 .- x1
  m1, m2 = f == nothing ? (1.0, 1.0) : (getfield(a, f), getfield(b, f))
  # mass weights
  m1 == m2 == Inf && return false
  if m1 == Inf
    @assert v1 == (0, 0) "An agent with ∞ mass cannot have nonzero velocity"
    dot(r1, v2) ≤ 0 && return false
    v1 = ntuple(x -> zero(eltype(v1)), length(v1))
    f1, f2 = 0.0, 2.0
  elseif m2 == Inf
    @assert v2 == (0, 0) "An agent with ∞ mass cannot have nonzero velocity"
    dot(r2, v1) ≤ 0 && return false
    v2 = ntuple(x -> zero(eltype(v1)), length(v1))
    f1, f2 = 2.0, 0.0
  else
    # Check if disks face each other, to avoid double collisions
    !(dot(r2, v1) > 0 && dot(r2, v1) > 0) && return false
    f1 = (2m2/(m1+m2))
    f2 = (2m1/(m1+m2))
  end
  ken = norm(v1)^2 + norm(v2)^2
  dx = a.pos .- b.pos
  dv = a.vel .- b.vel
  n = norm(dx)^2
  n == 0 && return false # do nothing if they are at the same position
  a.vel = v1 .- f1 .* ( dot(v1 .- v2, r1) / n ) .* (r1)
  b.vel = v2 .- f2 .* ( dot(v2 .- v1, r2) / n ) .* (r2)
  return true
end

"""
    interacting_pairs(model, r)
Return an iterator that yields pairs of agents `(a1, a2)` that are closest
neighbors to each other, within some interaction radius `r`.

This function is usefully combined with `model_step!`, when one wants to perform
some pairwise interaction across all pairs of closest agents once
(and does not want to trigger the event twice, both with `a1` and with `a2`, which
is unavoidable when using `agent_step!`).

Internally uses [`nearest_neighbor`](@ref).
"""
function interacting_pairs(model, r)
  pairs = Tuple{Int, Int}[]
  #TODO: This can be optimized further I assume
  for id in keys(model.agents)
    # Skip already checked agents
    any(isequal(id), p[2] for p in pairs) && continue
    a1 = id2agent(id, model)
    a2 = nearest_neighbor(a1, model, r)
    a2 ≠ nothing && push!(pairs, (id, a2.id))
  end
  return PairIterator(pairs, model.agents)
end

struct PairIterator{A}
  pairs::Vector{Tuple{Int, Int}}
  agents::Dict{Int, A}
end

Base.length(iter::PairIterator) = length(iter.pairs)
function Base.iterate(iter::PairIterator, i = 1)
  i > length(iter) && return nothing
  p = iter.pairs[i]
  id1, id2 = p
  return (iter.agents[id1], iter.agents[id2]), i+1
end
