using Agents
using LinearAlgebra

"""
    SimpleCell <: AbstractAgent
A simple bacterial cell, modelled by two soft disks linked with a spring.
Based on an (as of 04/2020) unpublished model by Yoav G. Pollack and Philip Bittihn
"""
mutable struct SimpleCell <: AbstractAgent
    id::Int

    pos::NTuple{2, Float64}
    length::Float64
    orientation::Float64
    growthprog::Float64

    growthrate::Float64

    # node positions/forces
    p1::NTuple{2, Float64}
    p2::NTuple{2, Float64}
    
    f1::NTuple{2, Float64}
    f2::NTuple{2, Float64}

    function SimpleCell(id, pos, l, φ, g, γ)
        a = new(id, pos, l, φ, g, γ, (0.0, 0.0), (0.0, 0.0),  (0.0, 0.0), (0.0, 0.0))
        update_nodes!(a)
        return a
    end
end


"""
    update_nodes!(agent::SimpleCell)
Updates the node positions `agent.p1` and `agent.p2` from the cell coordinates
""" 
function update_nodes!(a::SimpleCell)
    offset = 0.5 * a.length .* unitvector(a.orientation)
    a.p1 = a.pos .+ offset
    a.p2 = a.pos .- offset
end


unitvector(φ) = reverse(sincos(φ))
cross2D(a, b) = a[1]*b[2] - a[2]*b[1]    


## API functions ###########################################################################

function model_step!(model)
    for a in allagents(model)
        if a.growthprog ≥ 1
            # split old cells into daughters
            add_agent!(a.p1, model, 0.0, a.orientation, 0.0, 0.1*rand() + 0.05)
            add_agent!(a.p2, model, 0.0, a.orientation, 0.0, 0.1*rand() + 0.05)
            kill_agent!(a, model)
        else
            # compute internal spring compression
            uv = unitvector(a.orientation)
            internalforce = model.properties[:hardness]*(a.length - a.growthprog) .* uv
            a.f1 = -1 .* internalforce
            a.f2 = internalforce
        end
    end

    for (a1, a2) in interacting_pairs(model, 2, :all)
        interact!(a1, a2, model)
    end
end


# use custom move_agent! because this model doesn't work well with defaults
function agent_step!(agent::SimpleCell, model::ABM)
    fsym, compression, torque = transform_forces(agent)
    # overdamped dynamics, v ∝ F
    agent.pos = agent.pos .+ model.dt*model.properties[:mobility].*fsym
    agent.length += model.dt*model.properties[:mobility].*compression
    agent.orientation += model.dt*model.properties[:mobility].*torque
    agent.growthprog += model.dt*agent.growthrate
    update_nodes!(agent)
    
    if model.space.periodic
        agent.pos = mod.(agent.pos, model.space.extend)
    end
    
    Agents.DBInterface.execute(model.space.updateq, (agent.pos..., agent.id))
    return agent.pos
end


## Helper functions ########################################################################

"""
    interact!(a1::SimpleCell, a2::SimpleCell, model)
Computes the interactions between two [`SimpleCell`](@ref)s using 
[`noderepulsion`](@ref)
"""
function interact!(a1::SimpleCell, a2::SimpleCell, model)
    
    n11 = noderepulsion(a1.p1, a2.p1, model)
    n12 = noderepulsion(a1.p1, a2.p2, model)
    n21 = noderepulsion(a1.p2, a2.p1, model)
    n22 = noderepulsion(a1.p2, a2.p2, model)
   
    a1.f1 = @. a1.f1 + (n11 + n12)
    a1.f2 = @. a1.f2 + (n21 + n22)

    a2.f1 = @. a2.f1 - (n11 + n21)
    a2.f2 = @. a2.f2 - (n12 + n22)

end


"""
    noderepulsion(p1, p2, model) → force
Returns the repulsive force due to the interaction of nodes at `p1` and `p2`
"""
function noderepulsion(p1::NTuple{2, Float64}, p2::NTuple{2, Float64}, model::ABM)
    delta = p1 .- p2
    distance = norm(delta)

    if distance ≤ 1
        uv = delta./distance
        return (model.properties[:hardness]*(1 - distance)).*uv
    end

    return (0, 0)
end


"""
    transform_forces(agent::SimpleCell) → fsym, compression, torque
Transforms the node forces into forces on the cell coordinates. 
"""
function transform_forces(agent::SimpleCell)
    # symmetric forces (CM movement)
    fsym = agent.f1 .+ agent.f2
    # antisymmetric forces (compression, torque)
    fasym = agent.f1 .- agent.f2
    uv = unitvector(agent.orientation)
    compression = dot(uv, fasym)
    torque = 0.5*cross2D(uv, fasym)

    return fsym, compression, torque
end


## simulation script #######################################################################

space = ContinuousSpace(2, extend = (10, 10), periodic = false, metric = :euclidean)
model = ABM(SimpleCell, space, properties = Dict(:dt => 0.005, :hardness => 1e2,
                                                 :mobility => 1.0))

add_agent!((5.0, 5.0), model, 0.0, 0.3, 0.0, 0.1)
add_agent!((6.0, 5.0), model, 0.0, 0.0, 0.0, 0.1)


nmax = 8000
adata, = run!(model, agent_step!, model_step!, nmax;
              adata = [:pos, :length, :orientation, :growthprog, :p1, :p2, :f1, :f2])


#= 
# temporary plotting function, uncomment for pretty pictures

using PyPlot
uniquecolor(id) = Tuple(matplotlib.colors.hsv_to_rgb(((id*Base.MathConstants.φ)%1, 0.8, 0.95)))
for i ∈ 1:100:nmax
    cla()
    xlim(0, 10)
    ylim(0, 10)
    gca().set_aspect("equal")
    data = sort!(adata[adata.step .== i, :], :id)
    for r ∈ eachrow(data)
        c1 = matplotlib.patches.Circle(r.p1, 0.5, color = uniquecolor(r.id), zorder=100)
        c2 = matplotlib.patches.Circle(r.p2, 0.5, color = uniquecolor(r.id), zorder=100)
   
        gca().add_patch(c1)
        gca().add_patch(c2)
    end
    title("n = "*string(i))
    sleep(0.01)
end
=#
