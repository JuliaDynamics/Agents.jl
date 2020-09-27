export CompartmentSpace

struct CompartmentSpace{D,P,F} <: AbstractSpace
    grid::GridSpace{D,P}
    update_vel!::F
    dims::NTuple{D, Int}
end

defvel2(a, m) = nothing

function CompartmentSpace(d::NTuple{D,Real}, spacing;
    update_vel! = defvel2, periodic = true) where {D}
    s = GridSpace(floor.(Int, d ./ spacing), periodic=periodic, metric=:euclidean)
    return CompartmentSpace(s, update_vel!, size(s))
end

"""
random_position(model) → pos
Return a random position in the model's space (always with appropriate Type).
"""
function random_position(model::ABM{A, <:CompartmentSpace{D}}) where {A,D}
    pos = Tuple(rand(D) .* model.space.dims)
end

pos2cell(pos::Tuple) = ceil.(Int, pos)
pos2cell(a::AbstractAgent) = pos2cell(a.pos)

function add_agent_to_space!(a::A, model::ABM{A,<:CompartmentSpace}) where 
    {A<:AbstractAgent}
    push!(model.space.grid.s[pos2cell(a)...], a.id)
    return a
end

function remove_agent_from_space!(a::A, model::ABM{A,<:CompartmentSpace}) where 
    {A<:AbstractAgent}
    prev = model.space.grid.s[pos2cell(a)...]
    ai = findfirst(i -> i == a.id, prev)
    deleteat!(prev, ai)
    return a
end

function move_agent!(a::A, pos::Tuple, model::ABM{A,<:CompartmentSpace{D,periodic}}) where {A<:AbstractAgent, D, periodic}
    remove_agent_from_space!(a, model)
    if periodic
        pos = mod.(pos, model.space.dims)
    end
    a.pos = pos
    add_agent_to_space!(a, model)
end

"""
move_agent!(agent::A, model::ABM{A, CompartmentSpace}, dt = 1.0)
Propagate the agent forwards one step according to its velocity,
_after_ updating the agent's velocity (see [`CompartmentSpace`](@ref)).
Also take care of periodic boundary conditions.

For this continuous space version of `move_agent!`, the "evolution algorithm"
is a trivial Euler scheme with `dt` the step size, i.e. the agent position is updated
as `agent.pos += agent.vel * dt`.

Notice that if you want the agent to instantly move to a specified position, do
    `move_agent!(agent, pos, model)`.
"""
function move_agent!(agent::A, model::ABM{A, <: CompartmentSpace}, dt::Real = 1.0) where {A <: AbstractAgent}
    model.space.update_vel!(agent, model)
    pos = agent.pos .+ dt .* agent.vel
    move_agent!(agent, pos, model)
    return agent.pos
end

#######################################################################################
# %% Neighbors and stuff
#######################################################################################

grid_space_neighborhood(α, model::ABM{<:AbstractAgent, <:CompartmentSpace}, r) =
grid_space_neighborhood(α, model.space.grid, r)

function nearby_ids(pos::ValidPos, model::ABM{<:AbstractAgent,<:CompartmentSpace}, r = 1)
    nn = grid_space_neighborhood(CartesianIndex(pos2cell(pos)), model, r)
    s = model.space.grid.s
    Iterators.flatten((s[i...] for i in nn))
end

function nearby_positions(pos::ValidPos, model::ABM{<:AbstractAgent,<:CompartmentSpace}, r = 1)
    nn = grid_space_neighborhood(CartesianIndex(pos2cell(pos)), model, r)
    Iterators.filter(!isequal(pos), nn)
end

function positions(model::ABM{<:AbstractAgent,<:CompartmentSpace})
    x = CartesianIndices(model.space.grid.s)
    return (Tuple(y) for y in x)
end

function ids_in_position(pos::ValidPos, model::ABM{<:AbstractAgent,<:CompartmentSpace})
    return model.space.grid.s[pos...]
end

cell_center(pos::Tuple) = getindex.(modf.(pos), 2) .+ 0.5
distance_from_cell_center(pos::Tuple, center) = sqrt(sum(abs2.(pos .- center)))

"""
space_neighbors(position, model::ABM, r=1; kwargs...) → ids

Return an iterator of the ids of the agents within "radius" `r` of the given `position`
(which must match type with the spatial structure of the `model`).
"""
function space_neighbors(pos, model::ABM{<:AbstractAgent,<:CompartmentSpace}, r=1; exact=false)
    center = cell_center(pos)
    focal_cell = ceil.(Int, center)
    if exact
        newr = ceil.(Int, r)
        corner_of_largest_square_in_circle = floor.(Int, pos .+ newr)
        max_distance = corner_of_largest_square_in_circle[1] - focal_cell[1]
        final_ids = Int[] # TODO make it an iterator
        allcells = nearby_positions(focal_cell, model, newr)
        for cell in allcells
            if !any(x-> x> max_distance, abs.(cell .- focal_cell)) # certain cell
                ids = ids_in_position(cell, model)
                final_ids = vcat(final_ids, ids)
            else # uncertain cell
                ids = ids_in_position(cell, model)
                filter!(i -> sqrt(sum(abs2.(pos .- model[i]))) ≤ rnew, ids)
                final_ids = vcat(final_ids, ids)
            end
        end
        return final_ids
    else
        δ = distance_from_cell_center(pos, center)
        newr = ceil.(Int, r+δ)
        return nearby_ids(focal_cell, model, newr)
    end
end
    
    
################################################################################
### Pretty printing
################################################################################
function Base.show(io::IO, space::CompartmentSpace{D,P}) where {D, P}
    s = "$(P ? "periodic" : "") continuous space with $(join(space.dims, "×")) divisions"
    space.update_vel! ≠ defvel && (s *= " with velocity updates")
    print(io, s)
end
    