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
# TODO: Use the source code of TimeseriesPrediction.jl to select neighborhoods
# with a specific type: cityblock or indices_within_sphere
# If the operation `indices_within_sphere` is expensive, it can be stored
# (since we also store it in TimeseriesPrediction.jl)
# The function that does this index selection (where the indices are stored as cartesian indices)
# is then called in both node_neighbors and space_neighbors (because we want node_neighbors)
# to return tuples for ease of usage, while the conversion is not necessary for space_neighbors

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
        # TODO: By id is wrong...?
        sort!(itr)
    else
        error("unknown `by`")
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

function space_neighbors(pos::Tuple, model::ABM{<:AbstractAgent, <:ArraySpace})
    nn = node_neighbors(pos, model)
    s = model.space.s
    Iterators.flatten((s[i...] for i in nn))
end

function space_neighbors(agent::A, model::ABM{A,<:ArraySpace}, args...; kwargs...) where {A}
  all = space_neighbors(agent.pos, model, args...; kwargs...)
  Iterators.filter(!isequal(agent.id), all)
end

###################################################################
# %% pretty printing
###################################################################
function Base.show(io::IO, abm::ArraySpace)
    s = "Array space with size $(size(abm.s)), moore=$(abm.moore), and periodic=$(abm.periodic)"
    print(io, s)
end