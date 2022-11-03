# # Integrating Agents.jl with CellListMap.jl

# ```@raw html
# <video width="auto" controls autoplay loop>
# <source src="../celllistmap.mp4" type="video/mp4">
# </video>
# ```

# This example illustrates how to integrate Agents.jl with
# [CellListMap.jl](https:://github.com/m3g/CellListMap.jl), to accelerate the
# computation of short-ranged (within a cutoff) interactions in 2D and 3D continuous
# spaces. CellListMap.jl is a package that allows the computation of pairwise interactions
# using an efficient and parallel implementation of [cell lists](https://en.wikipedia.org/wiki/Cell_lists).

# ## The system simulated
#
# The example will illustrate how to simulate a set of particles in 2 dimensions, interaction
# through a simple repulsive potential of the form:
#
# $U(r) = k_i k_j\left[r^2 - (r_i+r_j)^2\right]^2~~~\textrm{for}~~~r \leq (r_i+r_j)$
#
# $U(r) = 0.0~~~\textrm{for}~~~r \gt (r_i+r_j)$
#
# where $r_i$ and $r_j$ are the radii of the two particles involved, and
# $k_i$ and $k_j$ are constants associated to each particle. The potential
# energy function is a smoothly decaying potential with a maximum when
# the particles overlap.
#
# Thus, if the maximum sum of radii between particles is much smaller than the size
# of the system, cell lists can greatly accelerate the computation of the pairwise forces.
#
# Each particle will have different radii and different repulsion force constants and masses.
using Agents

# Below we define the `Particle` type, which represents the agents of the
# simulation. The `Particle` type, for the `ContinousAgent{2}` space, will have additionally
# an `id` and `pos` (positon) and `vel` (velocity) fields, which are automatically added
# by the `@agent` macro.
@agent Particle ContinuousAgent{2} begin
    r::Float64 # radius
    k::Float64 # repulsion force constant
    mass::Float64
end
Particle(; id, pos, vel, r, k, mass) = Particle(id, pos, vel, r, k, mass)

# ## Required and data structures for CellListMap.jl 
#
# We will use the high-level interface provided by the `PeriodicSystems` module
# (requires version ≥0.7.22):
using CellListMap.PeriodicSystems
using StaticArrays
# `StaticArrays` provides the `SVector` type, which is practical for the representation of
# various vector types (e.g., positions or velocities) in small amount of dimensions.
# Agents.jl uses `NTuple{D, Float64}` for that, which does not support vector operations
# out of the box. In the future, Agents.jl may also switch the `pos` type to a static vector.

# Two auxiliary arrays will be created on model initialization, to be passed to
# the `PeriodicSystem` data structure:
#
# 1. `positions`: `CellListMap` requires a vector of (preferentially) static vectors as the positions
#    of the particles. To avoid creating this array on every call, a buffer to
#    which the `agent.pos` positions will be copied is stored in this data structure.
# 2. `forces`: In this example, the property to be computed using `CellListMap.jl` is 
#    the forces between particles, which are stored here in a `Vector{<:SVector}`, of
#    the same type as the positions. These forces will be updated by the `map_pairwise!`
#    function.
#
# Additionally, the computation with `CellListMap.jl` requires the definition of a `cutoff`,
# which will be twice the maximum interacting radii of the particles, and the geometry of the
# the system, given by the `unitcell` of the periodic box. 
# 
# More complex output data, variable system geometries and other options are supported, 
# according to the [CellListMap.PeriodicSystems](https://m3g.github.io/CellListMap.jl/stable/PeriodicSystems/) 
# user guide.
#
# ## Model initialization
# We create the model with a keyword-accepting function as is recommended in Agents.jl.
# The keywords here control number of particles and sizes.
function initialize_model(;
    number_of_particles=10_000,
    sides=SVector(500.0, 500.0),
    dt=0.001,
    max_radius=10.0,
    parallel=true
)
    ## initial random positions
    positions = [sides .* rand(SVector{2,Float64}) for _ in 1:number_of_particles]

    ## We will use CellListMap to compute forces, with similar structure as the positions
    forces = similar(positions)

    ## Space and agents
    space2d = ContinuousSpace(Tuple(sides); periodic=true)

    ## Initialize CellListMap periodic system
    system = PeriodicSystem(
        positions=positions,
        unitcell=sides,
        cutoff=2 * max_radius,
        output=forces,
        output_name=:forces, # allows the system.forces alias for clarity
        parallel=parallel,
    )

    ## define the model properties
    ## The clmap_system field contains the data required for CellListMap.jl
    properties = (
        dt=dt,
        number_of_particles=number_of_particles,
        system=system,
    )
    model = ABM(Particle,
        space2d,
        properties=properties
    )

    ## Create active agents
    for id in 1:number_of_particles
        add_agent_pos!(
            Particle(
                id=id,
                r=(0.5 + 0.9 * rand()) * max_radius,
                k=(10 + 20 * rand()), # random force constants
                mass=10.0 + 100 * rand(), # random masses
                pos=Tuple(positions[id]),
                vel=(100 * randn(), 100 * randn()), # initial velocities
            ),
            model)
    end

    return model
end

# ## Computing the pairwise particle forces
# To follow the `CellListMap` interface, we first need a function that
# computes the force between a single pair of particles. This function
# receives the positions of the two particles (already considering
# the periodic boundary conditions), `x` and `y`, their indices in the
# array of positions, `i` and `j`, the squared distance between them, `d2`,
# the `forces` array to be updated and the `model` properties.
#
# Given these input parameters, the function obtains the properties of
# each particle from the model, and computes the force between the particles
# as (minus) the gradient of the potential energy function defined above.
#
# The function *must* return the `forces` array, to follow the `CellListMap` API.
#
function calc_forces!(x, y, i, j, d2, forces, model)
    pᵢ = model[i]
    pⱼ = model[j]
    d = sqrt(d2)
    if d ≤ (pᵢ.r + pⱼ.r)
        dr = y - x
        fij = 2 * (pᵢ.k * pⱼ.k) * (d2 - (pᵢ.r + pⱼ.r)^2) * (dr / d)
        forces[i] += fij
        forces[j] -= fij
    end
    return forces
end

# The `model_step!` function will use `CellListMap` to update the
# forces for all particles. The first argument of the call is
# the function to be computed for each pair of particles, which closes-over
# the `model` data to call the `calc_forces!` function defined above.
# 
function model_step!(model::ABM)
    ## Update the pairwise forces at this step
    map_pairwise!(
        (x, y, i, j, d2, forces) -> calc_forces!(x, y, i, j, d2, forces, model),
        model.system,
    )
    return nothing
end

# ## Update agent positions and velocities
# The `agent_step!` function will update the particle positons and velocities,
# given the forces, which are computed in the `model_step!` function. A simple
# Euler step is used here for simplicity. We need to convert the static vectors
# to tuples to conform the `Agents` API for the positions and velocities
# of the agents. Finally, the positions within the `CellListMap.PeriodicSystem`
# structure are updated.
function agent_step!(agent, model::ABM)
    id = agent.id
    dt = model.properties.dt
    ## Retrieve the forces on agent id
    f = model.system.forces[id]
    a = f / agent.mass
    ## Update positions and velocities
    v = SVector(agent.vel) + a * dt
    x = SVector(agent.pos) + v * dt + (a / 2) * dt^2
    x = normalize_position(Tuple(x), model)
    agent.vel = Tuple(v)
    move_agent!(agent, x, model)
    ## !!! IMPORTANT: Update positions in the CellListMap.PeriodicSystem
    model.system.positions[id] = SVector(agent.pos)
    return nothing
end

# ## The simulation
# Finally, the function below runs an example simulation, for 1000 steps.
function simulate(model=nothing; nsteps=1_000, number_of_particles=10_000)
    if isnothing(model)
        model = initialize_model(number_of_particles=number_of_particles)
    end
    Agents.step!(
        model, agent_step!, model_step!, nsteps, false,
    )
end
# Which should be quite fast
model = initialize_model()
simulate(model) # compile
@time simulate(model)

# and let's make a nice video with less particles,
# to see them bouncing around. The marker size is set by the
# radius of each particle, and the marker color by the
# corresponding repulsion constant.
using InteractiveDynamics
using CairoMakie
CairoMakie.activate!() # hide
model = initialize_model(number_of_particles=1000)
abmvideo(
    "celllistmap.mp4", model, agent_step!, model_step!;
    framerate=20, frames=200, spf=5,
    title="Bouncing particles with CellListMap.jl acceleration",
    as=p -> p.r, # marker size
    ac=p -> p.k # marker color
)

# ```@raw html
# <video width="auto" controls autoplay loop>
# <source src="../celllistmap.mp4" type="video/mp4">
# </video>
# ```
