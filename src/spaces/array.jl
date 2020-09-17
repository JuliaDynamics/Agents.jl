export ArraySpace

struct ArraySpace{D} <: AbstractSpace
    s::Array{Vector{Int}, D}
    moore::Bool
    periodic::Bool
end

function ArraySpace(d::NTuple{D, Int}, moore::Bool=true, periodic::Bool=true) where {D}
    s = Array{Vector{Int}, D}(undef, d)
    for i in eachindex(s)
        s[i] = Int[]
    end
    return ArraySpace{D}(s, moore, periodic)
end

#######################################################################################
# %% Implementation of space API
#######################################################################################
function random_position(model::ABM{<:AbstractAgent, <: ArraySpace})
    Tuple(rand(CartesianIndices(model.space.s)))
end

function add_agent_to_space!(a::A, model::ABM{A, <: ArraySpace}) where {A<:AbstractAgent}
    push!(model.space.s[a.pos...], a.id)
    return a
end

function remove_agent_from_space!(a::A, model::ABM{A, <: ArraySpace}) where {A<:AbstractAgent}
    prev = model.space.s[a.pos...]
    ai = findfirst(i -> i == a.id, prev)
    deleteat!(prev, ai)
    return a
end

function move_agent!(a::A, pos::Tuple, model::ABM{A, <: ArraySpace}) where {A<:AbstractAgent}
    remove_agent_from_space!(a, model)
    a.pos = pos
    add_agent_to_space!(a, model)
end


###################################################################
# %% neighbors
###################################################################
export positions
function positions(model::ABM{<:AbstractAgent, <:ArraySpace})
    x = CartesianIndices(model.space.s)
    return (Tuple(y) for y in x)
end

function positions(model::ABM{<:AbstractAgent, <:ArraySpace}, by)
    itr = collect(positions(model))
    if by == :random
        shuffle!(itr)
    elseif by == :id
        sort!(itr)
    else
        error("unknown by")
    end
    return itr
end

function get_node_contents(pos::Tuple, model::ABM{<:AbstractAgent, <:ArraySpace})
    return model.space.s[pos...]
end

# Code a version with explicit D = 2, r = 1 and moore and not periodic for quick benchmark
function node_neighbors(pos::Tuple, model::ABM{<:AbstractAgent, <:ArraySpace})
    d = size(model.space.s)
    rangex = max(1, pos[1]-1):min(d[1], pos[1]+1)
    rangey = max(1, pos[2]-1):min(d[2], pos[2]+1)
    # TODO: This includes current position
    near = Iterators.product(rangex, rangey)
end

# Collecting version:
function space_neighbors(pos::Tuple, model::ABM{<:AbstractAgent, <:ArraySpace})
    nn = node_neighbors(pos, model)
    ids = Int[]
    for n in nn
        append!(ids, model.space.s[n...])
    end
    return ids
end

function space_neighbors(agent::A, model::ABM{A,<:ArraySpace}, args...; kwargs...) where {A}
  all = space_neighbors(agent.pos, model, args...; kwargs...)
  d = findfirst(isequal(agent.id), all)
  d ≠ nothing && deleteat!(all, d)
  return all
end

# Iterator version
# function space_neighbors(agent::A, model::ABM{A,<:ArraySpace}, args...; kwargs...) where {A}
#   all = space_neighbors(agent.pos, model, args...; kwargs...)
#   d = findfirst(isequal(agent.id), all)
#   d ≠ nothing && deleteat!(all, d)
#   return all
# end
