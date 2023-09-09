# Some deprecations exist in submodules Pathfinding, OSM

@deprecate edistance euclidean_distance
@deprecate rem_node! rem_vertex!
@deprecate add_node! add_vertex!
@deprecate kill_agent! remove_agent!
@deprecate genocide! remove_all!
@deprecate UnkillableABM UnremovableABM

function ContinuousSpace(extent, spacing; kwargs...)
    @warn "Specifying `spacing` by position is deprecated. Use keyword `spacing` instead."
    return ContinuousSpace(extent; spacing = spacing, kwargs...)
end

"""
    seed!(model [, seed])

Reseed the random number pool of the model with the given seed or a random one,
when using a pseudo-random number generator like `MersenneTwister`.
"""
function seed!(model::ABM, args...)
    @warn "`seed!(model::ABM, ...)` is deprecated. Do `seed!(abmrng(model), ...)`."
    Random.seed!(abmrng(model), args...)
end

# From before the move to an interface for ABMs and making `ABM` abstract.
AgentBasedModel(args...; kwargs...) = SingleContainerABM(args...; kwargs...)


"""
    walk!(agent, rand, model)

Invoke a random walk by providing the `rand` function in place of
`direction`. For `AbstractGridSpace`, the walk will cover ±1 positions in all directions,
`ContinuousSpace` will reside within [-1, 1].

This functionality is deprecated. Use [`randomwalk!`](@ref) instead.
"""
function walk!(agent, ::typeof(rand), model::ABM{<:AbstractGridSpace{D}}; kwargs...) where {D}
    @warn "Producing random walks through `walk!` is deprecated. Use `randomwalk!` instead."
    walk!(agent, Tuple(rand(abmrng(model), -1:1, D)), model; kwargs...)
end

function walk!(agent, ::typeof(rand), model::ABM{<:ContinuousSpace{D}}) where {D}
    @warn "Producing random walks through `walk!` is deprecated. Use `randomwalk!` instead."
    walk!(agent, Tuple(2.0 * rand(abmrng(model)) - 1.0 for _ in 1:D), model)
end

# Fixed mass
export FixedMassABM
const FixedMassABM = SingleContainerABM{S,A,SizedVector{A}} where {S,A,C}

"""
    FixedMassABM(agent_vector [, space]; properties, kwargs...) → model

Similar to [`UnremovableABM`](@ref), but agents cannot be removed nor added.
Hence, all agents in the model must be provided in advance as a vector.
This allows storing agents into a `SizedVector`, a special vector with statically typed
size which is the same as the size of the input `agent_vector`.
This version of agent based model offers better performance than [`UnremovableABM`](@ref)
if the number of agents is important and used often in the simulation.

It is mandatory that the agent ID is exactly the same as its position
in the given `agent_vector`.
"""
function FixedMassABM(
    agents::AbstractVector{A},
    space::S = nothing;
    scheduler::F = Schedulers.fastest,
    properties::P = nothing,
    rng::R = Random.default_rng(),
    warn = true
) where {A<:AbstractAgent, S<:SpaceType,F,P,R<:AbstractRNG}
    @warn "`FixedMassABM` is deprecated and will be removed in future versions of Agents.jl."
    C = SizedVector{length(agents), A}
    fixed_agents = C(agents)
    # Validate that agent ID is the same as its order in the vector.
    for (i, a) in enumerate(agents)
        i ≠ a.id && throw(ArgumentError("$(i)-th agent had ID $(a.id) instead of $i."))
    end
    agent_validator(A, space, warn)
    return SingleContainerABM{S,A,C,F,P,R}(fixed_agents, space, scheduler, properties, rng, Ref(0))
end
nextid(model::FixedMassABM) = error("There is no `nextid` in a `FixedMassABM`. Most likely an internal error.")
function add_agent_to_model!(agent::A, model::FixedMassABM) where {A<:AbstractAgent}
    error("Cannot add agents in a `FixedMassABM`")
end
function remove_agent_from_model!(agent::A, model::FixedMassABM) where {A<:AbstractAgent}
    error("Cannot remove agents in a FixedMassABM`")
end
modelname(::SizedVector) = "FixedMassABM"

"""
    add_agent_single!(agent, model::ABM{<:DiscreteSpace}) → agent

Add the `agent` to a random position in the space while respecting a maximum of one agent
per position, updating the agent's position to the new one.

This function does nothing if there aren't any empty positions.
"""
function add_agent_single!(agent::A, model::ABM{<:DiscreteSpace,A}) where {A<:AbstractAgent}
    @warn "Adding agent with add_agent_single!(agent::AbstractAgent, model::ABM) is deprecated. 
           Use add_agent_single!([pos,] A::Type, model::ABM; kwargs...) or add_agent_single!([pos,] A::Type, model::ABM, args...)."
    position = random_empty(model)
    isnothing(position) && return nothing
    agent.pos = position
    add_agent_pos!(agent, model)
    return agent
end

"""
    add_agent!(agent::AbstractAgent [, pos], model::ABM) → agent
Add the `agent` to the model in the given position.
If `pos` is not given, the `agent` is added to a random position.
The `agent`'s position is always updated to match `position`, and therefore for `add_agent!`
the position of the `agent` is meaningless. Use [`add_agent_pos!`](@ref) to use
the `agent`'s position.

The type of `pos` must match the underlying space position type.
"""
function add_agent!(agent::AbstractAgent, model::ABM)
    @warn "Adding agent with add_agent!(agent::AbstractAgent, model::ABM) is deprecated. 
           Use add_agent!([pos,] A::Type, model::ABM; kwargs...) or add_agent!([pos,] A::Type, model::ABM, args...)."
    agent.pos = random_position(model)
    add_agent_pos!(agent, model)
end

function add_agent!(agent::AbstractAgent, pos::ValidPos, model::ABM)
    @warn "Adding agent with add_agent!(agent::AbstractAgent, pos::ValidPos, model::ABM) is deprecated. 
           Use add_agent!([pos,] A::Type, model::ABM; kwargs...) or add_agent!([pos,] A::Type, model::ABM, args...)."
    agent.pos = pos
    add_agent_pos!(agent, model)
end

function add_agent!(agent::A, model::ABM{Nothing,A}) where {A<:AbstractAgent}
    @warn "Adding agent with add_agent!(agent::AbstractAgent, model::ABM) is deprecated. 
           Use add_agent!([pos,] A::Type, model::ABM; kwargs...) or add_agent!([pos,] A::Type, model::ABM, args...)."
    add_agent_pos!(agent, model)
end
