export ContinuousSpace

struct ContinuousSpace{D,P,T<:AbstractFloat,F} <: AbstractSpace
    grid::GridSpace{D,P}
    update_vel!::F
    dims::NTuple{D,Int}
    spacing::T
    extent::NTuple{D,T}
end
Base.eltype(s::ContinuousSpace{D,P,T,F}) where {D,P,T,F} = T
defvel(a, m) = nothing

"""
    ContinuousSpace(extent::NTuple{D, <:Real}, spacing = min(extent...)/10; kwargs...)
Create a `D`-dimensional `ContinuousSpace` in range 0 to (but not including) `extent`.
`spacing` configures the compartment spacing that the space is divided in, in order to
accelerate nearest neighbor functions like [`nearby_ids`](@ref).
All dimensions in `extent` must be completely divisible by `spacing` (i.e. no
fractional remainder).
Your agent positions (field `pos`) must be of type `NTuple{D, <:Real}`,
use [`ContinuousAgent`](@ref) for convenience.
In addition it is useful for agents to have a field `vel::NTuple{D, <:Real}` to use
in conjunction with [`move_agent!`](@ref).

The keyword `periodic = true` configures whether the space is periodic or not. If set to
`false` an error will occur if an agent's position exceeds the boundary.

The keyword argument `update_vel!` is a **function**, `update_vel!(agent, model)` that updates
the agent's velocity **before** the agent has been moved, see [`move_agent!`](@ref).
You can of course change the agents' velocities
during the agent interaction, the `update_vel!` functionality targets spatial force
fields acting on the agents individually (e.g. some magnetic field).
By default no update is done this way.
If you use `update_vel!`, the agent type must have a field `vel::NTuple{D, <:Real}`.

There is no "best" choice for the value of `spacing`. If you need optimal performance it's
advised to set up a benchmark over a range of choices. The value matters most when searching
for neighbors. In [`Models.flocking`](@ref) for example, an optimal value for `spacing` is
66% of the search distance.
"""
function ContinuousSpace(
    extent::NTuple{D,X},
    spacing = min(extent...) / 10.0;
    update_vel! = defvel,
    periodic = true,
) where {D,X<:Real}
    @assert extent ./ spacing == floor.(extent ./ spacing) "All dimensions in `extent` must be completely divisible by `spacing`"
    s = GridSpace(floor.(Int, extent ./ spacing), periodic = periodic, metric = :euclidean)
    Z = X <: AbstractFloat ? X : Float64
    return ContinuousSpace(s, update_vel!, size(s), Z(spacing), Z.(extent))
end

function random_position(model::ABM{<:ContinuousSpace})
    map(dim -> rand(model.rng) * dim, model.space.extent)
end

pos2cell(pos::Tuple, model::ABM) = floor.(Int, pos ./ model.space.spacing) .+ 1
pos2cell(a::AbstractAgent, model::ABM) = pos2cell(a.pos, model)
function cell_center(pos::NTuple{D,F}, model) where {D,F}
    ε = model.space.spacing
    (pos2cell(pos, model) .- 1) .* ε .+ ε / 2
end
distance_from_cell_center(pos, model::ABM) =
    distance_from_cell_center(pos, cell_center(pos, model))
function distance_from_cell_center(pos::Tuple, center::Tuple)
    sqrt(sum(abs2.(pos .- center)))
end

function add_agent_to_space!(a::A, model::ABM{<:ContinuousSpace,A}) where {A<:AbstractAgent}
    push!(model.space.grid.s[pos2cell(a, model)...], a.id)
    return a
end

function remove_agent_from_space!(
    a::A,
    model::ABM{<:ContinuousSpace,A},
) where {A<:AbstractAgent}
    prev = model.space.grid.s[pos2cell(a, model)...]
    ai = findfirst(i -> i == a.id, prev)
    deleteat!(prev, ai)
    return a
end

function move_agent!(
    a::A,
    pos::Tuple,
    model::ABM{<:ContinuousSpace{D,periodic},A},
) where {A<:AbstractAgent,D,periodic}
    remove_agent_from_space!(a, model)
    if periodic
        pos = mod.(pos, model.space.extent)
    end
    a.pos = pos
    add_agent_to_space!(a, model)
end

"""
    move_agent!(agent::A, model::ABM{<:ContinuousSpace,A}, dt::Real = 1.0)
Propagate the agent forwards one step according to its velocity,
_after_ updating the agent's velocity (if configured, see [`ContinuousSpace`](@ref)).
Also take care of periodic boundary conditions.

For this continuous space version of `move_agent!`, the "evolution algorithm"
is a trivial Euler scheme with `dt` the step size, i.e. the agent position is updated
as `agent.pos += agent.vel * dt`. If you want to move the agent to a specified position, do
`move_agent!(agent, pos, model)`.
"""
function move_agent!(
    agent::A,
    model::ABM{<:ContinuousSpace,A},
    dt::Real = 1.0,
) where {A<:AbstractAgent}
    model.space.update_vel!(agent, model)
    pos = agent.pos .+ dt .* agent.vel
    move_agent!(agent, pos, model)
    return agent.pos
end

#######################################################################################
# %% Neighbors and stuff
#######################################################################################
function nearby_ids(
    pos::ValidPos,
    model::ABM{<:ContinuousSpace{D,A,T}},
    r = 1;
    exact = false,
) where {D,A,T}
    if exact
        grid_r_max = r < model.space.spacing ? T(1) : r / model.space.spacing + T(1)
        grid_r_certain = grid_r_max - T(1.2) * sqrt(D)
        focal_cell = CartesianIndex(pos2cell(pos, model))
        allcells = grid_space_neighborhood(focal_cell, model, grid_r_max)
        if grid_r_max >= 1
            certain_cells = grid_space_neighborhood(focal_cell, model, grid_r_certain)
            certain_ids =
                Iterators.flatten(ids_in_position(cell, model) for cell in certain_cells)

            uncertain_cells = setdiff(allcells, certain_cells) # This allocates, but not sure if there's a better way.
            uncertain_ids =
                Iterators.flatten(ids_in_position(cell, model) for cell in uncertain_cells)

            additional_ids = Iterators.filter(
                i -> edistance(pos, model[i].pos, model) ≤ r,
                uncertain_ids,
            )

            return Iterators.flatten((certain_ids, additional_ids))
        else
            all_ids = Iterators.flatten(ids_in_position(cell, model) for cell in allcells)
            return Iterators.filter(i -> edistance(pos, model[i].pos, model) ≤ r, all_ids)
        end
    else
        δ = distance_from_cell_center(pos, cell_center(pos, model))
        grid_r = (r + δ) / model.space.spacing
        return nearby_ids_cell(pos, model, grid_r)
    end
end

grid_space_neighborhood(α, model::ABM{<:ContinuousSpace}, r) =
    grid_space_neighborhood(α, model.space.grid, r)

function nearby_ids_cell(pos::ValidPos, model::ABM{<:ContinuousSpace}, r = 1)
    nn = grid_space_neighborhood(CartesianIndex(pos2cell(pos, model)), model, r)
    s = model.space.grid.s
    Iterators.flatten((s[i...] for i in nn))
end

function nearby_positions(pos::ValidPos, model::ABM{<:ContinuousSpace}, r = 1)
    nn = grid_space_neighborhood(CartesianIndex(pos2cell(pos, model)), model, r)
    Iterators.filter(!isequal(pos), nn)
end

function positions(model::ABM{<:ContinuousSpace})
    x = CartesianIndices(model.space.grid.s)
    return (Tuple(y) for y in x)
end

function ids_in_position(pos::ValidPos, model::ABM{<:ContinuousSpace})
    return model.space.grid.s[pos...]
end

################################################################################
### Pretty printing
################################################################################
function Base.show(io::IO, space::ContinuousSpace{D,P}) where {D,P}
    s = "$(P ? "periodic" : "") continuous space with $(join(space.dims, "×")) divisions"
    space.update_vel! ≠ defvel && (s *= " with velocity updates")
    print(io, s)
end

#######################################################################################
# Continuous space exclusive local neighborhood
#######################################################################################
export nearest_neighbor, elastic_collision!, interacting_pairs

"""
    nearest_neighbor(agent, model::ABM{<:ContinuousSpace}, r) → nearest
Return the agent that has the closest distance to given `agent`.
Return `nothing` if no agent is within distance `r`.
"""
function nearest_neighbor(
    agent::A,
    model::ABM{<:ContinuousSpace,A},
    r;
    exact = false,
) where {A}
    n = collect(nearby_ids(agent, model, r; exact))
    length(n) == 0 && return nothing
    d, j = Inf, 1
    for i in 1:length(n)
        @inbounds dnew = edistance(agent.pos, model[n[i]].pos, model)
        if dnew < d
            d, j = dnew, i
        end
    end
    return @inbounds model[n[j]]
end

using LinearAlgebra

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
  neighbor only one of them (sorted by distance, then by next id in `scheduler`) will be
  paired.
- `:types`: For mixed agent models only. Return every pair of agents within radius `r`
  (similar to `:all`), only capturing pairs of differing types. For example, a model of
  `Union{Sheep,Wolf}` will only return pairs of `(Sheep, Wolf)`. In the case of multiple
  agent types, *e.g.* `Union{Sheep, Wolf, Grass}`, skipping pairings that involve
  `Grass`, can be achived by a [`scheduler`](@ref Schedulers) that doesn't schedule `Grass`
  types, *i.e.*: `scheduler(model) = (a.id for a in allagents(model) if !(a isa Grass))`.

Example usage in [Bacterial Growth](@ref).
"""
function interacting_pairs(
    model::ABM{<:ContinuousSpace},
    r::Real,
    method;
    scheduler = model.scheduler,
    exact = true,
)
    @assert method ∈ (:nearest, :all, :types)
    pairs = Tuple{Int,Int}[]
    if method == :nearest
        true_pairs!(pairs, model, r, scheduler)
    elseif method == :all
        all_pairs!(pairs, model, r, exact = exact)
    elseif method == :types
        type_pairs!(pairs, model, r, scheduler, exact = exact)
    end
    return PairIterator(pairs, model.agents)
end

function all_pairs!(
    pairs::Vector{Tuple{Int,Int}},
    model::ABM{<:ContinuousSpace},
    r::Real;
    exact = true,
)
    for a in allagents(model)
        for nid in nearby_ids(a, model, r; exact)
            # Sort the pair to overcome any uniqueness issues
            new_pair = isless(a.id, nid) ? (a.id, nid) : (nid, a.id)
            new_pair ∉ pairs && push!(pairs, new_pair)
        end
    end
end

function true_pairs!(pairs::Vector{Tuple{Int,Int}}, model::ABM{<:ContinuousSpace}, r::Real, scheduler)
    distances = Vector{Float64}(undef, 0)
    for a in (model[id] for id in scheduler(model))
        nn = nearest_neighbor(a, model, r)
        nn === nothing && continue
        # Sort the pair to overcome any uniqueness issues
        new_pair = isless(a.id, nn.id) ? (a.id, nn.id) : (nn.id, a.id)
        if new_pair ∉ pairs
            # We also need to check if our current pair is closer to each
            # other than any pair using our first id already in the list,
            # so we keep track of nn distances.
            dist = edistance(a.pos, nn.pos, model)

            idx = findfirst(x -> first(new_pair) == x, first.(pairs))
            if idx === nothing
                push!(pairs, new_pair)
                push!(distances, dist)
            elseif idx !== nothing && distances[idx] > dist
                # Replace this pair, it is not the true neighbor
                pairs[idx] = new_pair
                distances[idx] = dist
            end
        end
    end
    to_remove = Int[]
    for doubles in symdiff(unique(Iterators.flatten(pairs)), collect(Iterators.flatten(pairs)))
        # This list is the set of pairs that have two distances in the pair list.
        # The one with the largest distance value must be dropped.
        fidx = findfirst(isequal(doubles), first.(pairs))
        if fidx !== nothing
            lidx = findfirst(isequal(doubles), last.(pairs))
            largest = distances[fidx] <= distances[lidx] ? lidx : fidx
            push!(to_remove, largest)
        else
            # doubles are not from first sorted, there could be more than one.
            idxs = findall(isequal(doubles), last.(pairs))
            to_keep = findmin(map(i->distances[i], idxs))[2]
            deleteat!(idxs, to_keep)
            append!(to_remove, idxs)
        end
    end
    deleteat!(pairs, unique!(sort!(to_remove)))
end

function type_pairs!(
    pairs::Vector{Tuple{Int,Int}},
    model::ABM{<:ContinuousSpace},
    r::Real,
    scheduler;
    exact = true,
)
    # We don't know ahead of time what types the scheduler will provide. Get a list.
    available_types = unique(typeof(model[id]) for id in scheduler(model))
    for id in scheduler(model)
        for nid in nearby_ids(model[id], model, r, exact = exact)
            neigbor_type = typeof(model[nid])
            if neigbor_type ∈ available_types && neigbor_type !== typeof(model[id])
                # Sort the pair to overcome any uniqueness issues
                new_pair = isless(id, nid) ? (id, nid) : (nid, id)
                new_pair ∉ pairs && push!(pairs, new_pair)
            end
        end
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

#######################################################################################
# FMP Algorithm
#######################################################################################
export fmp_update_vel!, fmp_update_interacting_pairs!, FMP_Parameters, fmp_parameter_init

"""
    FMP_Parameters
The parameters for the FMP model as defined in the [FMP paper](https://arxiv.org/abs/1909.05415). The helper function `fmp_parameter_init` is used to initialize the struct with default parameters. The default values in `fmp_parameter_init` generally reflect the parameterization from the original paper. The available FMP parameters are:
- `rho`: Positive repulsive gradient; dictates the magnitude of the repulsive force as a function of inter-agent distance.
- `rho_obstacle`: Positive repulsive gradient for objects; similar to `rho` but used for agent-object repulsive forces.
- `c1`, `c2`: Positive constant values used in the navigational feedback computation.
- `vmax`: Maximum velocity of the agents.
- `d`: Agent diameter
- `r`: Function for computing interactive radius. `r` is the threshold distance for interagent repulsive forces. 
- `obstacle_list`: list of obstacles in the state space
- `interaction_array`: n x n boolean array (n = number of agents) where `interaction_array[i,j]=1`
indicates that the ith and jth agents are interacting. Used so that `interacting_pairs` is only called
once per iteration rather than every time `update_vel` is called.
- `agents`: an iterator of the interacting agents from `interacting_pairs` at each time step.
"""
mutable struct FMP_Parameters
    rho::Float64
    rho_obstacle::Float64
    c1::Float64
    c2::Float64
    vmax::Float64
    d::Float64
    r::Float64
    obstacle_list::Array{Int64}
    interaction_array::Array{Bool}
    agents::Dict{Int64, Any}
    FMP_Parameters() = new()
end

"""
    fmp_update_interacting_pairs!(model)
Updates `FMP_Parameters.interaction_array` with the current array of interacting agents by calling
`interacting_pairs`. It does this once per model step to reduce the potential overhead of calling
`interacting_pairs` each time `update_vel` is called. 
"""
function fmp_update_interacting_pairs!(
    model::ABM{<:ContinuousSpace},
    )

    # get list of interacting_pairs within some radius
    agent_iter = interacting_pairs(model, model.FMP_params.r, :all)
    for agent_id in keys(model.agents)
        Ni = Int64[]
        Gi = Int64[]
        for (i,j) in agent_iter.pairs
            # handle agent-agent interactions
            if i == agent_id && model.agents[j].type == :A
                append!(Ni, j)
            elseif j == agent_id && model.agents[i].type == :A
                append!(Ni, i)
            # handle agent-goal interactions
            elseif i == agent_id && model.agents[j].type == :T
                append!(Gi, j)
            elseif j == agent_id && model.agents[i].type == :T
                append!(Gi, i)
            end
        end

        model.agents[agent_id].Ni = Ni
        model.agents[agent_id].Gi = Gi
    end

end

"""
    fmp_parameter_init()
A convenience function for initializing the FMP_Parameters struct with typical FMP
parameters. Users can modify the FMP algorithm parameters through the usage of 
keyword arguments. Possible keyword arguments are `rho`, `rho_obstacle`, `c1`, `c2`, `vmax`, `d` and `obstacle_list`. All keywords definitions can be found in the documentation for the `FMP_Parameter` struct. 
"""
function fmp_parameter_init(;
    rho = 7.5e6,
    rho_obstacle = 7.5e6,
    c1 = 10,
    c2 = 10,
    vmax = 0.1,
    d = 0.02,
    obstacle_list=[],
) where {D,P,T,M}

    r = (3*vmax^2/(2*rho))^(1/3)+d
    FMP_params = FMP_Parameters()
    FMP_params.rho = rho
    FMP_params.rho_obstacle = rho_obstacle
    FMP_params.c1 = c1
    FMP_params.c2 = c2
    FMP_params.vmax = vmax
    FMP_params.d = d
    FMP_params.r = r
    FMP_params.obstacle_list = obstacle_list
    return FMP_params
end


"""
    fmp_update_vel!(model, FMP_params)
Implements the [Force Based Motion Planning (FMP) algorithm](https://arxiv.org/abs/1909.05415)
to handle interagent collisions. 

Example usage in [Force Based Motion Planning](@ref).

The FMP algorithm that determines the three primary forces being experienced by an agent
each time `fmp_update_vel!` is called. The three forces are:

- Repulsive force: analogous to a "magnetic" repulsion based on proximity of agent and other agents in the state space.
- Navigational force: an attractive force drawing an agent to its goal position
- Obstacle force: similar to repulsive force but generated by proximity to objects in the state space

After computing the resultant vectors from each component, an overall resultant vector is computed. This is then capped based on the global max velocity constraint. This final velocity is passed into the agents struct.

"""
function fmp_update_vel!(
    agent::AbstractAgent,
    model::ABM{<:ContinuousSpace},
    )

    # move_this_agent_to_new_position(i) in FMP paper
    # compute forces and resultant velocities
    fiR = repulsive_force(model, agent)
    fiGamma = navigational_feedback(model, agent)
    fiObject = obstacle_feedback(model, agent)
    ui = fiR .+ fiGamma .+ fiObject
    vi = model.agents[agent.id].vel .+ ui .* model.dt
    vi = cap_velocity(model.FMP_params.vmax, vi)

    # update agent velocities
    agent.vel = vi
end

"""
Function to calculate the resultant velocity vector from the repulsive component of the FMP
algorithm.
"""
function repulsive_force(model::AgentBasedModel, agent)
    # compute repulsive force for each agent
    # note the "." before most math operations, required for component wise tuple math
    f = ntuple(i->0, length(agent.vel))
    for j in agent.Ni
        dist = norm(model.agents[j].pos .- agent.pos)
        if dist == 0.0
            dist = 1e-10  # was getting error for agents in same position
        end
        if dist < model.FMP_params.r
            force = -model.FMP_params.rho * (dist - model.FMP_params.r)^2
            distnorm = (model.agents[j].pos .- agent.pos) ./dist
            f = f .+ (force .* distnorm)
        end
    end

    # targets/objects do not experience repulsive feedback
    if agent.type == :O || agent.type == :T
        return  ntuple(i->0, length(agent.vel))
    else
        return f
    end
end

"""
Function to calculate the resultant velocity vector from the navigational component of the FMP
algorithm.
"""
function navigational_feedback(model::AgentBasedModel, agent)
    # compute navigational force for each agent
    # note the "." before most math operations, required for component wise tuple math
    f = (-model.FMP_params.c1 .* (agent.pos .- agent.tau)) .+ (- model.FMP_params.c2 .* agent.vel)
    if agent.type == :T
        return  ntuple(i->0, length(agent.vel))  # targets to not experience navigational feedback
    else
        return f
    end
end

"""
Function to calculate the resultant velocity vector from the obstacle avoidance component
of the FMP algorithm.
"""
function obstacle_feedback(model::AgentBasedModel, agent)
    # determine obstacle avoidance feedback term
    # note the "." before most math operations, required for component wise tuple math
    f = ntuple(i->0, length(agent.vel))

    for id in model.FMP_params.obstacle_list
        # the original paper defines z as p_j-r_j-p_i in equation 17/18
        #   in the paper r_j is treated a vector, however it makes more sense to
        #   treat as a scalar quantity so we take the norm, then subtract the radius
        #   (j is obstacle (id) and i is agent (i))
        dist = norm(model.agents[id].pos  .- agent.pos) - model.agents[id].radius
        if dist < agent.radius
            force = -model.FMP_params.rho_obstacle * (dist - model.agents[id].radius)^2
            distnorm = (model.agents[id].pos .- agent.pos) ./ norm(model.agents[id].pos .- agent.pos)
            f = f .+ (force .* distnorm)
        end
    end
    if agent.type == :O || agent.type == :T
        return ntuple(i->0, length(agent.vel))
    else
        return f
    end
end

"""
Function to bound computed velocities based on globally set vmax parameter.
"""
function cap_velocity(vmax, vel)
    # bound velocity by vmax
    # note the "." before most math operations, required for component wise tuple math
    if norm(vel) > vmax
        vi = (vel ./ norm(vel)) .* vmax
        return vi
    else
        return vel
    end
end
