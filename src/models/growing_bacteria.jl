mutable struct SimpleCell <: AbstractAgent
    id::Int
    pos::NTuple{2,Float64}
    length::Float64
    orientation::Float64
    growthprog::Float64
    growthrate::Float64

    ## node positions/forces
    p1::NTuple{2,Float64}
    p2::NTuple{2,Float64}
    f1::NTuple{2,Float64}
    f2::NTuple{2,Float64}
end

function SimpleCell(id, pos, l, φ, g, γ)
    a = SimpleCell(id, pos, l, φ, g, γ, (0.0, 0.0), (0.0, 0.0), (0.0, 0.0), (0.0, 0.0))
    update_nodes!(a)
    return a
end

"""
``` julia
growing_bacteria()
```
Same as in [Bacterial Growth](@ref).
"""
function growing_bacteria()
    space = ContinuousSpace((14, 9), 1.0; periodic = false)
    model = ABM(
        SimpleCell,
        space,
        properties = Dict(:dt => 0.005, :hardness => 1e2, :mobility => 1.0),
    )

    add_agent!((6.5, 4.0), model, 0.0, 0.3, 0.0, 0.1)
    add_agent!((7.5, 4.0), model, 0.0, 0.0, 0.0, 0.1)

    return model, growing_bacteria_agent_step!, growing_bacteria_model_step!
end

function update_nodes!(a::SimpleCell)
    offset = 0.5 * a.length .* unitvector(a.orientation)
    a.p1 = a.pos .+ offset
    a.p2 = a.pos .- offset
end

# Some geometry convenience functions
unitvector(φ) = reverse(sincos(φ))
cross2D(a, b) = a[1] * b[2] - a[2] * b[1]

# ## Stepping functions

function growing_bacteria_model_step!(model)
    for a in allagents(model)
        if a.growthprog ≥ 1
            ## When a cell has matured, it divides into two daughter cells on the
            ## positions of its nodes.
            add_agent!(a.p1, model, 0.0, a.orientation, 0.0, 0.1 * rand() + 0.05)
            add_agent!(a.p2, model, 0.0, a.orientation, 0.0, 0.1 * rand() + 0.05)
            kill_agent!(a, model)
        else
            ## The rest lengh of the internal spring grows with time. This causes
            ## the nodes to physically separate.
            uv = unitvector(a.orientation)
            internalforce = model.hardness * (a.length - a.growthprog) .* uv
            a.f1 = -1 .* internalforce
            a.f2 = internalforce
        end
    end
    ## Bacteria can interact with more than on other cell at the same time, therefore,
    ## we need to specify the option `:all` in `interacting_pairs`
    for (a1, a2) in interacting_pairs(model, 2.0, :all)
        interact!(a1, a2, model)
    end
end

function growing_bacteria_agent_step!(agent::SimpleCell, model::ABM)
    fsym, compression, torque = transform_forces(agent)
    new_pos = agent.pos .+ model.dt * model.mobility .* fsym
    move_agent!(agent, new_pos, model)
    agent.length += model.dt * model.mobility .* compression
    agent.orientation += model.dt * model.mobility .* torque
    agent.growthprog += model.dt * agent.growthrate
    update_nodes!(agent)
    return agent.pos
end

# ### Helper functions
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

function noderepulsion(p1::NTuple{2,Float64}, p2::NTuple{2,Float64}, model::ABM)
    delta = p1 .- p2
    distance = norm(delta)
    if distance ≤ 1
        uv = delta ./ distance
        return (model.hardness * (1 - distance)) .* uv
    end
    return (0, 0)
end

function transform_forces(agent::SimpleCell)
    ## symmetric forces (CM movement)
    fsym = agent.f1 .+ agent.f2
    ## antisymmetric forces (compression, torque)
    fasym = agent.f1 .- agent.f2
    uv = unitvector(agent.orientation)
    compression = dot(uv, fasym)
    torque = 0.5 * cross2D(uv, fasym)
    return fsym, compression, torque
end
