@agent Particle ContinuousAgent{2} begin
    radius::Float64
    is_stuck::Bool
    spin_axis::Array{Float64,1}
end

"""
``` julia
fractal_growth(;
    initial_particles::Int = 100,
    space_extents::NTuple{2,Float64} = (150.0, 150.0),
    speed = 0.5,
    vibration = 0.55,
    attraction = 0.45,
    spin = 0.55,
    clockwise_fraction = 0.0,
    min_radius = 1.0,
    max_radius = 2.0,
)
```
Same as in [Fractal Growth](@ref).
"""
function fractal_growth(;
    initial_particles::Int = 100,
    space_extents::NTuple{2,Float64} = (150.0, 150.0),
    speed = 0.5,
    vibration = 0.55,
    attraction = 0.45,
    spin = 0.55,
    clockwise_fraction = 0.0,
    min_radius = 1.0,
    max_radius = 2.0,
)
    properties = Dict(
        :speed => speed,
        :vibration => vibration,
        :attraction => attraction,
        :spin => spin,
        :clockwise_fraction => clockwise_fraction,
        :min_radius => min_radius,
        :max_radius => max_radius,
        :spawn_count => 0,
    )
    space = ContinuousSpace(space_extents, 1.0; periodic = true)
    model = ABM(Particle, space; properties)
    center = space_extents ./ 2.0
    for i in 1:initial_particles
        particle = Particle(
            i,
            particle_radius(min_radius, max_radius, model.rng),
            rand(model.rng) < clockwise_fraction,
        )
        add_agent!(particle, model)
    end
    particle = Particle(
        initial_particles + 1,
        particle_radius(min_radius, max_radius, model.rng),
        true;
        pos = center,
        is_stuck = true,
    )
    add_agent_pos!(particle, model)
    return model, fractal_agent_step!, fractal_model_step!
end

function fractal_agent_step!(agent::Particle, model)
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
            rand_circle(model.rng) .* model.vibration
        ) ./ (agent.radius^2.0)
    move_agent!(agent, model, model.speed)
end

function fractal_model_step!(model)
    while model.spawn_count > 0
        particle = Particle(
            nextid(model),
            particle_radius(model.min_radius, model.max_radius, model.rng),
            rand(model.rng) < model.clockwise_fraction;
            pos = (rand_circle(model.rng) .+ 1.0) .* model.space.extent .* 0.49,
        )
        add_agent_pos!(particle, model)
        model.spawn_count -= 1
    end
end

Particle(
    id::Int,
    radius::Float64,
    spin_clockwise::Bool;
    pos = (0.0, 0.0),
    is_stuck = false,
) = Particle(id, pos, (0.0, 0.0), radius, is_stuck, [0.0, 0.0, spin_clockwise ? -1.0 : 1.0])

rand_circle(rng) = (θ = rand(rng, 0.0:0.1:359.9); (cos(θ), sin(θ)))
particle_radius(min_radius::Float64, max_radius::Float64, rng) =
    min_radius <= max_radius ? rand(rng, min_radius:0.01:max_radius) : min_radius
