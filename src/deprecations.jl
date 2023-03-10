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
    walk!(agent, Tuple(rand(model.rng, -1:1, D)), model; kwargs...)
end

function walk!(agent, ::typeof(rand), model::ABM{<:ContinuousSpace{D}}) where {D}
    @warn "Producing random walks through `walk!` is deprecated. Use `randomwalk!` instead."
    walk!(agent, Tuple(2.0 * rand(model.rng) - 1.0 for _ in 1:D), model)
end

"""
    kill_agent!(agent::AbstractAgent, model::ABM)
    kill_agent!(id::Int, model::ABM)

Remove an agent from the model.

This functionality is deprecated. Use [`remove_agent!`](@ref) instead.
"""
function kill_agent!(a::AbstractAgent, model::ABM)
    @warn "Removing agents through `kill_agent!` is deprecated. Use `remove_agent!` instead."
    remove_agent_from_model!(a, model)
    remove_agent_from_space!(a, model)
end

function kill_agent!(id::Integer, model::ABM)
    @warn "Removing agents through `kill_agent!` is deprecated. Use `remove_agent!` instead."
    kill_agent!(model[id], model)
end

"""
    genocide!(model::ABM)
Kill all the agents of the model.

This functionality is deprecated. Use [`remove_all!`](@ref) instead.
"""
function genocide!(model::ABM)
    @warn "Removing all agents through `genocide!` is deprecated. Use `remove_all!` instead."
    for a in allagents(model)
        kill_agent!(a, model)
    end
    model.maxid[] = 0
end

"""
    genocide!(model::ABM, n::Int)
Kill the agents whose IDs are larger than n.

This functionality is deprecated. Use [`remove_all!`](@ref) instead.
"""
function genocide!(model::ABM, n::Integer)
    @warn "Removing a group of agents through `genocide!` is deprecated. Use `remove_all!` instead."
    for id in allids(model)
        id > n && kill_agent!(id, model)
    end
    model.maxid[] = n
end

"""
    genocide!(model::ABM, IDs)
Kill the agents with the given IDs.

This functionality is deprecated. Use [`remove_all!`](@ref) instead.
"""
function genocide!(model::ABM, ids)
    @warn "Removing a group of agents through `genocide!` is deprecated. Use `remove_all!` instead."
    for id in ids
        kill_agent!(id, model)
    end
end

"""
    genocide!(model::ABM, f::Function)
Kill all agents where the function `f(agent)` returns `true`.

This functionality is deprecated. Use [`remove_all!`](@ref) instead.
"""
function genocide!(model::ABM, f::Function)
    @warn "Removing a group of agents through `genocide!` is deprecated. Use `remove_all!` instead."
    for a in allagents(model)
        f(a) && kill_agent!(a, model)
    end
end

"""
    UnkillableABM(AgentType [, space]; properties, kwargs...) → model

Similar to [`StandardABM`](@ref), but agents cannot be removed, only added.
This allows storing agents more efficiently in a standard Julia `Vector` (as opposed to
the `Dict` used by [`StandardABM`](@ref), yielding faster retrieval and iteration over agents.

It is mandatory that the agent ID is exactly the same as the agent insertion
order (i.e., the 5th agent added to the model must have ID 5). If not,
an error will be thrown by [`add_agent!`](@ref).

This functionality is deprecated. Use [`UnremovableABM`](@ref) instead.
"""
function UnkillableABM(args...; kwargs...)
    @warn "The concrete ABM implementation known as `UnkillableABM` is deprecated. Use `UnremovableABM` instead."
    return SingleContainerABM(args...; kwargs..., container=Vector)
end