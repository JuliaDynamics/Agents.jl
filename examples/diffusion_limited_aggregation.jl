using Agents, Random, LinearAlgebra
Random.seed!(42)

mutable struct Particle <: AbstractAgent
    id::Int
    pos::NTuple{2,Float64}
    vel::NTuple{2,Float64}
    radius::Float64
    is_stuck::Bool
end

Particle(id, radius; pos = (0.0, 0.0), is_stuck = false) =
    Particle(id, pos, (0.0, 0.0), radius, is_stuck)

properties = Dict(
    :speed => 0.5,   # dt multiplier
    :wiggle => 0.55,  # position offset
    :attraction => 0.45,  # absolute attraction value
    :twist => 0.55,   # absolute tangential velocity
    :spawn_count => 0,
    :particle_radius => 1.0,
)

rand_circle() = Tuple(normalize(rand(2) .- 0.5))

function agent_step!(agent::Particle, model)
    if agent.is_stuck
        return
    end
    for id in nearby_ids(agent.pos, model, agent.radius)
        if model[id].is_stuck
            agent.is_stuck = true
            model.spawn_count += 1
            return
        end
    end
    radial = model.space.extent ./ 2.0 .- agent.pos
    radnorm = norm(radial)
    nradial = radial ./ radnorm
    tangent = Tuple(cross([nradial..., 0.0], [0.0, 0.0, 1.0])[1:2])
    move_agent!(
        agent,
        agent.pos .+ Tuple(normalize(rand(2) .- 0.5)) .* model.wiggle .* model.speed,
        model,
    )
    agent.vel = nradial .* model.attraction .+ tangent .* model.twist
    move_agent!(agent, model, model.speed)
end

function model_step!(model)
    while model.spawn_count > 0
        particle = Particle(
            nextid(model),
            model.particle_radius;
            pos = rand_circle() .* model.space.extent[1] ./ 2.0 .+
                  model.space.extent ./ 2.0,
        )
        add_agent!(particle, model)
        model.spawn_count -= 1
    end
end

function initialize_model(;
    initial_particles::Int = 100,
    space_extents::NTuple{2,Float64} = (150.0, 150.0),
    props = properties,
)
    space = ContinuousSpace(space_extents, 1.0; periodic = true)
    model = ABM(Particle, space; properties)
    center = space_extents ./ 2.0
    for i = 1:initial_particles
        particle = Particle(i, properties[:particle_radius])
        add_agent!(particle, model)
    end
    particle = Particle(
        initial_particles + 1,
        properties[:particle_radius];
        pos = center,
        is_stuck = true,
    )
    add_agent_pos!(particle, model)
    return model
end

model = initialize_model()
particle_color(a::Particle) = a.is_stuck ? :red : :blue
params = Dict(
    :attraction => 0.0:0.01:2.0,
    :speed => 0.0:0.01:2.0,
    :wiggle => 0.0:0.01:2.0,
    :twist => 0.0:0.01:2.0,
)

interactive_abm(
    model,
    agent_step!,
    model_step!,
    params;
    ac = particle_color,
    as = 3.3,
    am = '⚫',
)
