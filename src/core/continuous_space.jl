using DataFrames, SQLite
export ContinuousSpace, index!, update_space!

#######################################################################################
# Continuous space structure
#######################################################################################
struct ContinuousSpace{F, E} <: AbstractSpace
  D::Int
  update_vel!::F
  periodic::Bool
  extend::E
  metric::Symbol
  db::SQLite.DB
  insertq::SQLite.Stmt
  searchq::SQLite.Stmt
  deleteq::SQLite.Stmt
  updateq::SQLite.Stmt
  searchqNoId::SQLite.Stmt
end

const COORDS = 'a':'z' # letters representing coordinates in database

"""
    ContinuousSpace(D::Int [, update_vel!]; kwargs...)
Create a `ContinuousSpace` of dimensionality `D`.
In this case, your agent positions (field `pos`) should be of type `NTuple{D, F}`
where `F <: AbstractFloat`.
In addition, the agent type should have a third field `vel::NTuple{D, F}` representing
the agent's velocity to use [`move_agent!`](@ref).

The optional argument `update_vel!` is a **function**, `update_vel!(agent, model)` that updates
the agent's velocity **before** the agent has been moved, see [`move_agent!`](@ref).
You can of course change the agents' velocities
during the agent interaction, the `update_vel!` functionality targets arbitrary force
fields acting on the agents (e.g. some magnetic field).
By default no update is done this way.

Notice that if you need to write your own custom `move_agent` function, call
[`update_space!`](@ref) at the end, like in e.g. the [Bacterial Growth](@ref) example.

## Keywords
* `periodic = true` : whether continuous space is periodic or not
* `extend::NTuple{D} = ones` : Extent of space. The `d` dimension starts at 0
  and ends at `extend[d]`. If `periodic = true`, this is also when
  periodicity occurs. If `periodic ≠ true`, `extend` is only used at plotting.
* `metric = :cityblock` : metric that configures distances for finding nearest neighbors
  in the space. The other option is `:euclidean` but cityblock is faster (due to internals).

**Note:** if your model requires linear algebra operations for which tuples are not supported,
a performant solution is to convert between Tuple and SVector using
[StaticArrays.jl](https://github.com/JuliaArrays/StaticArrays.jl)
as follows: `s = SVector(t)` and back with `t = Tuple(s)`.
"""
function ContinuousSpace(D::Int, update_vel! = defvel;
  periodic = true, extend = Tuple(1.0 for i in 1:D), metric = :cityblock)

  @assert metric ∈ (:cityblock, :euclidean)
  @assert typeof(extend) <: NTuple{D} "extend must be a tuple of length(D)"
  @assert all(typeof(e) <: Real && e > 0 for e in extend) "extend must contain positive integers or floating point numbers"
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
  output = Vector{Int}(undef, 0)
  for row in skipmissing(q)
    push!(output, row[colname])
  end
  return output
end

"""
    index!(model)
Index the database underlying the `ContinuousSpace` of the model.

This can drastically improve performance for finding neighboring agents, but adding new
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
# add, move and kill
#######################################################################################
# central, low level function that is always called by all others!
function add_agent_pos!(agent::A, model::ABM{A, <: ContinuousSpace}) where {A<:AbstractAgent}
  DBInterface.execute(model.space.insertq, (agent.pos..., agent.id))
  model[agent.id] = agent
  return agent
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
function add_agent!(model::ABM{A, <: ContinuousSpace}, args...; kwargs...) where {A<:AbstractAgent}
  add_agent!(randompos(model.space), model, args...; kwargs...)
end

function add_agent!(pos::Tuple, model::ABM{A, <: ContinuousSpace}, args...; kwargs...) where {A<:AbstractAgent}
  id = nextid(model)
  agent = A(id, pos, args...; kwargs...)
  add_agent_pos!(agent, model)
end

"""
    move_agent!(agent::A, model::ABM{A, ContinuousSpace}, dt = 1.0)
Propagate the agent forwards one step according to its velocity,
_after_ updating the agent's velocity (see [`ContinuousSpace`](@ref)).
Also take care of periodic boundary conditions.

For this continuous space version of `move_agent!`, the "evolution algorithm"
is a trivial Euler scheme with `dt` the step size, i.e. the agent position is updated
as `agent.pos += agent.vel * dt`.

Notice that if you want the agent to instantly move to a specified position, do
`agent.pos = pos` and then `update_space!(agent, model)`.
"""
function move_agent!(agent::A, model::ABM{A, S, F, P}, dt = 1.0) where {A<:AbstractAgent, S <: ContinuousSpace, F, P}
  model.space.update_vel!(agent, model)
  agent.pos = agent.pos .+ dt .* agent.vel
  if model.space.periodic
    agent.pos = mod.(agent.pos, model.space.extend)
  end
  update_space!(model, agent)
  return agent.pos
end

"""
    move_agent!(agent::A, model::ABM{A, ContinuousSpace}, vel::NTuple{D, N}, dt = 1.0)
Propagate the agent forwards one step according to `vel` and the model's space, with `dt` as the time step. (`update_vel!` is not used)
"""
function move_agent!(agent::A, model::ABM{A,S,F,P}, vel::NTuple{D, N}, dt = 1.0) where {A <: AbstractAgent, S <: ContinuousSpace, F, P, D, N <: AbstractFloat}
      agent.pos = agent.pos .+ dt .* vel
      if model.space.periodic
        agent.pos = mod.(agent.pos, model.space.extend)
      end
      update_space!(model, agent)
      return agent.pos
end

"""
    update_space!(model::ABM{A, ContinuousSpace}, agent)
Update the internal representation of continuous space to match the new position of
the agent (useful in custom `move_agent` functions).
"""
function update_space!(model::ABM{A,<:ContinuousSpace}, agent) where {A}
  DBInterface.execute(model.space.updateq, (agent.pos..., agent.id))
end

function kill_agent!(agent::AbstractAgent, model::ABM{A,<:ContinuousSpace}) where {A}
  DBInterface.execute(model.space.deleteq, (agent.id,))
  delete!(model.agents, agent.id)
  return model
end

function genocide!(model::ABM{A,<:ContinuousSpace}, n::Int) where {A}
  ids = strip(join("$id," for id in keys(model.agents) if id > n), ',')
  DBInterface.execute(model.space.db, "DELETE FROM tab WHERE id IN ($ids)")
  for id in keys(model.agents)
    id > n && (delete!(model.agents, id))
  end
  return model
end

function genocide!(model::ABM{A,<:ContinuousSpace}, f::Function) where {A}
  ids = strip(join("$(agent.id)," for agent in values(model.agents) if f(agent)), ',')
  DBInterface.execute(model.space.db, "DELETE FROM tab WHERE id IN ($ids)")
  for agent in values(model.agents)
    f(agent) && (delete!(model.agents, agent.id))
  end
  return model
end

function genocide!(model::ABM{A,<:ContinuousSpace}) where {A}
  DBInterface.execute(model.space.db, "DELETE FROM tab")
  for agent in values(model.agents)
    delete!(model.agents, agent.id)
  end
end

#######################################################################################
# neighboring agents
#######################################################################################
function space_neighbors(pos::Tuple, model::ABM{A, <:ContinuousSpace}, r::Real) where {A}
  left = pos .- r
  right = pos .+ r
  res = interlace(left, right)
  ids = collect_ids(DBInterface.execute(model.space.searchqNoId, res))
  if model.space.metric == :euclidean
    filter!(i -> sqrt(sum(abs2.(model[i].pos .- pos))) ≤ r, ids)
  end
  ids
end

function space_neighbors(agent::A, model::ABM{A, <:ContinuousSpace}, r::Real) where {A<:AbstractAgent}
  left = agent.pos .- r
  right = agent.pos .+ r
  res = interlace(left, right)
  ids = collect_ids(DBInterface.execute(model.space.searchq, (res...,agent.id)))
  if model.space.metric == :euclidean
    filter!(i -> sqrt(sum(abs2.(model[i].pos .- agent.pos))) ≤ r, ids)
  end
  ids
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
space's metric. Valid only in continuous space.
Return `nothing` if no agent is within distance `r`.
"""
function nearest_neighbor(agent, model, r)
  n = space_neighbors(agent, model, r)
  length(n) == 0 && return nothing
  d, j = Inf, 0
  for i in 1:length(n)
    if model.space.metric == :euclidean
      @inbounds dnew = sqrt(sum(abs2.(agent.pos .- model[n[i]].pos)))
    elseif model.space.metric == :cityblock
      @inbounds dnew = sum(abs.(agent.pos .- model[n[i]].pos))
    end
    _, j = findmin(d)
    if dnew < d
      d, j = dnew, i
    end
  end
  return @inbounds model[n[j]]
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
    interacting_pairs(model, r, method; scheduler = model.scheduler)
Return an iterator that yields unique pairs of agents `(a1, a2)` that are close
neighbors to each other, within some interaction radius `r`.

This function is usefully combined with `model_step!`, when one wants to perform
some pairwise interaction across all pairs of close agents once
(and does not want to trigger the event twice, both with `a1` and with `a2`, which
is unavoidable when using `agent_step!`).

The argument `method` provides three pairing scenarios
- `:all`: return every pair of agents that are within radius `r` of each other,
  not only the nearest ones.
- `:nearest`: agents are only paired with their true nearest neighbor
  (existing within radius `r`).
  Each agent can only belong to one pair, therefore if two agents share the same nearest
  neighbor only one of them (sorted by id) will be paired.
- `:scheduler`: agents are scanned according to the given keyword `scheduler`
  (by default the model's scheduler), and each scanned
  agent is paired to its nearest neighbor. Similar to `:nearest`, each agent can belong
  to only one pair. This functionality is useful e.g. when you want some agents to be
  paired "guaranteed", even if some other agents might be nearest to each other.
- `:types`: For mixed agent models only. Return every pair of agents within radius `r`
  (similar to `:all`), only capturing pairs of differing types. For example, a model of
  `Union{Sheep,Wolf}` will only return pairs of `(Sheep, Wolf)`. In the case of multiple
  agent types, *e.g.* `Union{Sheep, Wolf, Grass}`, skipping pairings that involve
  `Grass`, can be achived by a [`scheduler`](@ref Schedulers) that doesn't schedule `Grass`
  types, *i.e.*: `scheduler = [a.id for a in allagents(model) of !(a isa Grass)]`.
"""
function interacting_pairs(model::ABM, r::Real, method; scheduler = model.scheduler)
    @assert method ∈ (:scheduler, :nearest, :all, :types)
    pairs = Tuple{Int,Int}[]
    if method == :nearest
        true_pairs!(pairs, model, r)
    elseif method == :scheduler
        scheduler_pairs!(pairs, model, r, scheduler)
    elseif method == :all
        all_pairs!(pairs, model, r)
    elseif method == :types
        type_pairs!(pairs, model, r, scheduler)
    end
    return PairIterator(pairs, model.agents)
end

function scheduler_pairs!(pairs::Vector{Tuple{Int,Int}}, model::ABM, r::Real, scheduler)
    #TODO: This can be optimized further I assume
    for id in scheduler(model)
        # Skip already checked agents
        any(isequal(id), p[2] for p in pairs) && continue
        a1 = model[id]
        a2 = nearest_neighbor(a1, model, r)
        # This line ensures each neighbor exists in only one pair:
        if a2 ≠ nothing && !any(isequal(a2.id), p[2] for p in pairs)
            push!(pairs, (id, a2.id))
        end
    end
end

function all_pairs!(pairs::Vector{Tuple{Int,Int}}, model::ABM, r::Real)
    for a in allagents(model)
        for nid in space_neighbors(a, model, r)
            # Sort the pair to overcome any uniqueness issues
            new_pair = isless(a.id, nid) ? (a.id, nid) : (nid, a.id)
            new_pair ∉ pairs && push!(pairs, new_pair)
        end
    end
end

function true_pairs!(pairs::Vector{Tuple{Int,Int}}, model::ABM, r::Real)
    distances = Vector{Float64}(undef, 0)
    for a in allagents(model)
        nn = nearest_neighbor(a, model, r)
        nn == nothing && continue
        # Sort the pair to overcome any uniqueness issues
        new_pair = isless(a.id, nn.id) ? (a.id, nn.id) : (nn.id, a.id)
        if new_pair ∉ pairs
            # We also need to check if our current pair is closer to each
            # other than any pair using our first id already in the list,
            # so we keep track of nn distances.
            dist = pair_distance(a.pos, model[nn.id].pos, model.space.metric)

            idx = findfirst(x -> first(new_pair) == x, first.(pairs))
            if idx == nothing
                push!(pairs, new_pair)
                push!(distances, dist)
            elseif idx != nothing && distances[idx] > dist
                # Replace this pair, it is not the true neighbor
                pairs[idx] = new_pair
                distances[idx] = dist
            end
        end
    end
end

function type_pairs!(pairs::Vector{Tuple{Int,Int}}, model::ABM, r::Real, scheduler)
    # We don't know ahead of time what types the scheduler will provide. Get a list.
    available_types = unique(typeof(model[id]) for id in scheduler(model))
    for id in scheduler(model)
        for nid in space_neighbors(model[id], model, r)
            neigbor_type = typeof(model[nid])
            if neigbor_type ∈ available_types && neigbor_type !== typeof(model[id])
                # Sort the pair to overcome any uniqueness issues
                new_pair = isless(id, nid) ? (id, nid) : (nid, id)
                new_pair ∉ pairs && push!(pairs, new_pair)
            end
        end
    end
end

function pair_distance(pos1, pos2, metric::Symbol)
    if metric == :euclidean
        sqrt(sum(abs2.(pos1 .- pos2)))
    elseif metric == :cityblock
        sum(abs.(pos1 .- pos2))
    end
end

struct PairIterator{A}
    pairs::Vector{Tuple{Int,Int}}
    agents::Dict{Int,A}
end

Base.length(iter::PairIterator) = length(iter.pairs)
function Base.iterate(iter::PairIterator, i = 1)
    i > length(iter) && return nothing
    p = iter.pairs[i]
    id1, id2 = p
    return (iter.agents[id1], iter.agents[id2]), i + 1
end
