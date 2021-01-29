using Agents, Random, LinearAlgebra
Random.seed!(42)

@agent Particle ContinuousAgent{2} begin
    radius::Float64
    is_stuck::Bool
    spin_axis::Array{Float64,1}
end

Particle(
    id::Int,
    radius::Float64,
    spin_clockwise::Bool;
    pos = (0.0, 0.0),
    is_stuck = false,
) = Particle(
    id,
    pos,
    (0.0, 0.0),
    radius,
    is_stuck,
    [0.0, 0.0, spin_clockwise ? -1.0 : 1.0],
)

rand_circle() = (θ = rand(0.0:0.1:359.9); (cos(θ), sin(θ)))
particle_radius(min_radius::Float64, max_radius::Float64) =
    min_radius <= max_radius ? rand(min_radius:0.01:max_radius) : min_radius

function initialize_model(;
    initial_particles::Int = 100,
    space_extents::NTuple{2,Float64} = (150.0, 150.0),
    speed = 0.5,
    vibration = 0.55,
    attraction = 0.45,
    spin = 0.55,
    clockwise_fraction = 0.,
    min_radius = 1.,
    max_radius = 2.,
)
    properties = Dict(
        :speed => speed,   # dt multiplier
        :vibration => vibration,  # position offset
        :attraction => attraction,  # absolute attraction value
        :spin => spin,   # absolute tangential velocity
        :clockwise_fraction => clockwise_fraction,
        :min_radius => min_radius,
        :max_radius => max_radius,
        :spawn_count => 0,
    )
    space = ContinuousSpace(space_extents, 1.0; periodic = true)
    model = ABM(Particle, space; properties)
    center = space_extents ./ 2.0
    for i = 1:initial_particles
        particle = Particle(
            i,
            particle_radius(min_radius, max_radius),
            rand() < clockwise_fraction,
        )
        add_agent!(particle, model)
    end
    particle = Particle(
        initial_particles + 1,
        particle_radius(min_radius, max_radius),
        true;
        pos = center,
        is_stuck = true,
    )
    add_agent_pos!(particle, model)
    return model
end

function agent_step!(agent::Particle, model)
    agent.is_stuck && return

    for id in nearby_ids(agent.pos, model, agent.radius)
        if model[id].is_stuck
            agent.is_stuck = true
            model.spawn_count += 1
            return
        end
    end
    radial = model.space.extent ./ 2.0 .- agent.pos
    radial = radial ./ norm(radial)
    tangent = Tuple(cross([radial..., 0.0], agent.spin_axis)[1:2])
    agent.vel =
        (
            radial .* model.attraction .+ tangent .* model.spin .+
            rand_circle() .* model.vibration
        ) ./ (agent.radius^2.0)
    move_agent!(agent, model, model.speed)
end

function model_step!(model)
    while model.spawn_count > 0
        particle = Particle(
            nextid(model),
            particle_radius(model.min_radius, model.max_radius),
            rand() < model.clockwise_fraction;
            pos = (rand_circle() .+ 1.0) .* model.space.extent .* 0.49,
        )
        add_agent_pos!(particle, model)
        model.spawn_count -= 1
    end
end

model = initialize_model()

using InteractiveDynamics, GLMakie

particle_color(a::Particle) = a.is_stuck ? :red : :blue
particle_size(a::Particle) = 3.8 * a.radius
params = (
    :attraction => 0.0:0.01:2.0,
    :speed => 0.0:0.01:2.0,
    :vibration => 0.0:0.01:2.0,
    :spin => 0.0:0.01:2.0,
    :clockwise_fraction => 0.0:0.01:1.0,
    :min_radius => 0.5:0.01:3.0,
    :max_radius => 0.5:0.01:3.0,
)

abm_data_exploration(
    model,
    agent_step!,
    model_step!,
    params;
    ac = particle_color,
    as = particle_size,
    am = '⚪',
)
