# # Model of Fractal Growth

# This model follows the process known as diffusion-limited aggregation to simulate the growth of fractals.
# It is a kinetic process that consists of randomly diffusing particles giving rise to fractal-like structures
# resembling those observed naturally.

# The environment is a two dimensional continuous space world. Agents are particles that diffuse and aggregate to form
# fractals. Initially, there are particles of random size distributed across the space, and one static particle in the center
# that forms the seed for the fractal growth. As moving particles collide with the seed, or any particle that previously
# collided with the seed, it is stuck and contributes to the fractal. As a particle gets stuck, another one is created at a
# circular border around the center to continue fractal growth.
using Agents, LinearAlgebra
using Random # hide
Random.seed!(42) # hide

# We use the `@agent` macro to conveniently define a `Particle` agent. Each agent
# has a radius, representing the particle size, a boolean to define whether it is stuck and part of the fractal,
# and an axis around which it spins (elaborated on later). In addition, the `@agent` macro also provides each
# agent with fields for `id`, `pos` (its position in space) and `vel` (its velocity).
@agent Particle ContinuousAgent{2} begin
    radius::Float64
    is_stuck::Bool
    spin_axis::Array{Float64,1}
end

# A custom contructor allows convenient creation of agents.
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

# We also define a couple utility functions for ease of implementation.
# `rand_circle` returns a random point on the unit circle. `particle_radius`
# generates a random radius for a particle, within given range defined by `min_radius`
# and `max_radius`. If `max_radius < min_radius`. this returns `min_radius`, allowing
# a fixed particle size to be specified.
rand_circle() = (θ = rand(0.0:0.1:359.9); (cos(θ), sin(θ)))
particle_radius(min_radius::Float64, max_radius::Float64) =
    min_radius <= max_radius ? rand(min_radius:0.01:max_radius) : min_radius

# The `initialize_model` function returns a new model containing particles placed
# randomly in the given space and one seed particle at the center.
function initialize_model(;
    initial_particles::Int = 100,   ## initial particles in the model, not including the seed
    space_extents::NTuple{2,Float64} = (150.0, 150.0), ## size of the space in which particles exist
    speed = 0.5,    ## speed of particle movement
    vibration = 0.55,   ## amplitude of particle vibration
    attraction = 0.45,  ## velocity of particles towards the center
    spin = 0.55, ## tangential velocity with which particles orbit the center
    clockwise_fraction = 0.,    ## fraction of particles orbiting clockwise. The rest are anticlockwise
    min_radius = 1.,    ## minimum radius of any particle
    max_radius = 2.,    ## maximum radius of any particle
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
    ## space is periodic to allow particles going off one edge to wrap around to the opposite
    space = ContinuousSpace(space_extents, 1.0; periodic = true)
    model = ABM(Particle, space; properties)
    center = space_extents ./ 2.0
    for i = 1:initial_particles
        particle = Particle(
            i,
            particle_radius(min_radius, max_radius),
            rand() < clockwise_fraction,
        )
        ## `add_agent!` automatically gives the particle a random position in the space
        add_agent!(particle, model)
    end
    ## create the seed particld
    particle = Particle(
        initial_particles + 1,
        particle_radius(min_radius, max_radius),
        true;
        pos = center,
        is_stuck = true,
    )
    ## `add_agent_pos!` will use the position of the agent passed in, instead of assigning it
    ## to a random value
    add_agent_pos!(particle, model)
    return model
end

# The `agent_step!` function simulates particles moving around in space. Stuck particles
# are not simulated. For each particle, we first perform a crude distance check to all other
# particles. If the current particle intersects any particle in the fractal, it also becomes
# part of the fractal and is not simulated further. Agent velocity has a radial component that
# attracts it towards the center, a tangential component that makes it orbit around the center,
# and a random component that simulates vibration of the particle. The velocity is scaled
# to be inversely proportional to the square of the particle's radius, so that larger particles
# move slower. The `speed` parameter is implemented as the time difference between successive
# steps of the simulation. A larger value causes particles to move more per step, but leads to
# inaccuracies as particles do not move through the intervening space.
function agent_step!(agent::Particle, model)
    agent.is_stuck && return

    for id in nearby_ids(agent.pos, model, agent.radius)
        if model[id].is_stuck
            agent.is_stuck = true
            ## increment count to make sure another particle is spawned as this one gets stuck
            model.spawn_count += 1
            return
        end
    end
    ## radial vector towards the center of the space
    radial = model.space.extent ./ 2.0 .- agent.pos
    radial = radial ./ norm(radial)
    ## tangential vector in the direction of orbit of the particle
    tangent = Tuple(cross([radial..., 0.0], agent.spin_axis)[1:2])
    agent.vel =
        (
            radial .* model.attraction .+ tangent .* model.spin .+
            rand_circle() .* model.vibration
        ) ./ (agent.radius^2.0)
    move_agent!(agent, model, model.speed)
end

# The `model_step!` function serves the sole purpose of spawning additional particles
# as they get stuck to the growing fractal.
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

# # Running the model

# We run the model using the `InteractiveDynamics` package with `GLMakie` backend so
# the fractal growth can be visualised as it happens, and simulation parameters can be tweaked
# dynamically. This makes use of the `abm_data_exploration` function.
model = initialize_model()

using InteractiveDynamics, GLMakie
## Particles that are stuck and part of the fractal are shown in red, for visual distinction
particle_color(a::Particle) = a.is_stuck ? :red : :blue
## The visual size of particles corresponds to their radius, and has been calculated
## for the default value of `space_extents` of the `initialize_model` function. It will
## not look accurate on other values.
particle_size(a::Particle) = 3.8 * a.radius
## `params` defines the range in which different parameter values can be adjusted through
## sliders.
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
