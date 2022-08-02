# # Using CellListMap

# ```@raw html
# <video width="auto" controls autoplay loop>
# <source src="../celllistmap.mp4" type="video/mp4">
# </video>
# ```

# This example illustrates how to integrate `Agents.jl` with 
# [`CellListMap.jl`](https:://github.com/m3g/CellListMap.jl), to accelerate the
# computation of short-ranged (within a cutoff) interactions in 2D and 3D continuous 
# spaces. `CellListMap.jl` is a package that allows the computation of pairwise interactions
# using an efficient and parallel implementation of [cell lists](https://en.wikipedia.org/wiki/Cell_lists).

# ## The system simulated
#
# The example will illustrate how to simulate a set of particles in 2 dimensions, interaction 
# through a simple repulsive potential of the form:
#
# $U(r) = k_i k_j\left[r^2 - (ri+rj)^2\right]^2~~~$ for $~~~r \leq (ri+rj)$
#
# $U(r) = 0.0~~~$ for $~~~r \gt (ri+rj)$
#
# where $r_i$ and $r_j$ are the radii of the two particles involved, and
# $k_i$ and $k_j$ are constants associated to each particle. The potential 
# energy function is a smoothly decaying potential with a maximum when
# the particles overlap. The figure below illustrates the potential energy
# for a pair or particles with unitary radii and force constants.  
#
# ```@raw html
# <center>
# <img src="https://raw.githubusercontent.com/JuliaDynamics/Agents.jl/main/examples/cellistmap.svg">
# </center>
# ```
#
# Thus, if the maximum sum of radii between particles is much smaller than the size 
# of the system, cell lists can greatly accelerate the computation of the pairwise forces.
# 
# Each particle will have different radii and different repulsion force constants and masses.
# 
# ## Packages required and data structure
#
# We begin by loading the required packages. `StaticArrays` provides the `SVector` 
# types which are practical for the representation of coordinates of 
# points in 2 and 3 dimensions. We `import` the `CellListMap` package because 
# it exports some functions with conflicting names with `Agents`. 

using Agents
import CellListMap
using StaticArrays
#
# Below we define the `Particle` type, which will contain the agents of the 
# simulation. The `Particle` type, for the `ContinousAgent{2}` space, will have additionally
# an `id` and `pos` (positon) and `vel` (velocity) fields, which are automatically added
# by the `@agent` macro. 
# 
@agent Particle ContinuousAgent{2} begin
    r::Float64 # radius
    k::Float64 # repulsion force constant
    mass::Float64
end
Particle(; id, pos, vel, r, k, mass) = Particle(id, pos, vel, r, k, mass)

#
# The `CellListMap` data structure contains the necessary data for the fast 
# computation of interactions using `CellListMap`. The structure must be mutable,
# because it is expected that the `box` and `cell_list` fields, which will contain
# immutable data structures, will be updated at each simulation step.
# 
# Five data structures are necessary:
#
# 1. `positions`: `CellListMap` requires a vector of vectors as the positions
# of the particles. To avoid creating this array on every call, a buffer to
# which the `agent.pos` positions will be copied is stored in this data structure.
# 
# 2. `box`: is the `CellListMap.Box` data structure containing the size of the system
# (generally with periodicity), and the cutoff that is used for pairwise interactions.
# 
# 3. `cell_list`: will contain the cell lists obtained with the `CellListMap.CellList` 
# constructor. 
# 
# The next two auxiliary structures necessary for parallel runs, but for simplicity they will always be
# defined:
# 
# 4. `aux`: is a data structure that is built with the `CellListMap.AuxThreaded` constructor,
# and contains auxiliary arrays to paralellize the construction of the cell lists.
# 
# 5. `output_threaded`: is a vector containing copies of the output of the mapped function,
# for parallelization.
#
# To each field a parametric type is associated, to make the fields concrete without
# having to write their types explicitly. 
# 
mutable struct CellListMapData{B,C,A,O}
    positions::Vector{SVector{2,Float64}}
    box::B
    cell_list::C
    aux::A
    output_threaded::O
end

# 
# ## Model properties.
# 
# The `forces` between particles are stored in a `Vector{SVector{2}}`, and will be updated
# at each simulation step by the `CellListMap.map_pairwise!` function.
# 
# The `cutoff` is the maximum possible distance between particles with non-null interactions,
# meaning, here, twice the maximum radius that the particles may have.
# 
# The `clmap` field will store the data required for `CellListMap`, and again we 
# use a parametric type to guarantee the concrectness of the types, aoviding type
# instabilities.  
#
# A `parallel` boolean flag is included to activate or deactivate the parallel 
# execution of the `CellListMap` functions. 
# 
Base.@kwdef struct Properties{CL<:CellListMapData}
    dt::Float64 = 0.01
    number_of_particles::Int64 = 0
    forces::Vector{SVector{2,Float64}}
    cutoff::Float64
    clmap::CL # CellListMap data
    parallel::Bool
end
#
# ## Model initialization
#
# By default the model will be generated with 10_000 particles in a 2D system
# with sides 1000.0. The maximum possible radius of the particles is set to 10.0, and
# each particle will have a random radius assigned between 1 and 10. Random 
# initial velocities and force constants will also be generated. 
#
function initialize_model(;
    number_of_particles=10_000,
    sides=SVector(500.0, 500.0),
    dt=0.001,
    max_radius=10.0,
    parallel=true,
)
    ## initial random positions
    positions = [sides .* rand(SVector{2,Float64}) for _ in 1:number_of_particles]

    ## Space and agents
    space2d = ContinuousSpace(Tuple(sides); periodic=true)

    ## initialize array of forces
    forces = zeros(SVector{2,Float64}, number_of_particles)

    ## default maximum radius is 10.0 thus cutoff is 20.0
    cutoff = 2*max_radius

    ## Define cell list structure
    box = CellListMap.Box(sides, cutoff)
    cl = CellListMap.CellList(positions, box; parallel=parallel)
    aux = CellListMap.AuxThreaded(cl)
    output_threaded = [copy(forces) for _ in 1:CellListMap.nbatches(cl)]
    clmap = CellListMapData(positions, box, cl, aux, output_threaded)

    ## define the model properties
    properties = Properties(
        dt=dt,
        number_of_particles=number_of_particles,
        cutoff=cutoff,
        forces=forces,
        clmap=clmap,
        parallel=parallel,
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
                r = (0.1 + 0.9*rand())*max_radius,
                k=1.0 + 10*rand(), # random force constants
                mass=10.0 + 100*rand(), # random masses
                pos=Tuple(positions[id]),
                vel=(100*randn(), 100*randn()), # initial velocities
            ),
        model)
    end

    return model
end

#
# ## Computing the pairwise particle forces
#
# To follow the `CellListMap` interface, we first need a function that
# computes the force between a single pair of particles. This function
# receives the positions of the two particles (already considering 
# the periodic boundary conditions), `x` and `y`, their indices in the 
# array of coordinates, `i` and `j`, the squared distance between them, `d2`,
# the `forces` array to be updated and the `model` properties. 
#
# Given these input parameters, the function obtains the properties of 
# each particle from the model, and computes the force between the particles
# as (minus) the gradient of the potential energy function defined above.
#
# The function *must* return the `forces` array, to follow the `CellListMap` API.
#
function calc_forces!(x, y, i, j, d2, forces, model)
    pᵢ = model.agents[i]
    pⱼ = model.agents[j]
    d = sqrt(d2)
    if d ≤ (pᵢ.r + pⱼ.r)
        dr = y - x
        fij = 2 * (pᵢ.k * pⱼ.k) * (d2 - (pᵢ.r + pⱼ.r)^2) * (dr / d)
        forces[i] += fij
        forces[j] -= fij
    end
    return forces
end

# 
# The `model_step!` function will use `CellListMap` to update the 
# forces for all particles, given the function above. It starts by
# updating the cell lists, given the current positions of the particles.
# Next, we reset the `forces` array and the auxiliary arrays used to
# store the forces for each parallel task. In this example, the default
# reduction function can be used, for more complex output data, custom
# reduction functions can be provided.
#
# Finally, the `CellListMap.map_pairwise!` function is called to 
# update the `model.forces` array. The first argument of the call is 
# the function to be computed for each pair of particles, which closes-over 
# the `model` data to call the `calc_forces!` function defined above.
# 
function model_step!(model::ABM)
    ## update cell lists
    model.clmap.cell_list = CellListMap.UpdateCellList!(
        model.clmap.positions, # current positions
        model.clmap.box,
        model.clmap.cell_list,
        model.clmap.aux;
        parallel=model.parallel
    )
    ## reset forces at this step, and auxiliary threaded forces array
    fill!(model.forces, zeros(eltype(model.forces)))
    for i in eachindex(model.clmap.output_threaded)
        fill!(model.clmap.output_threaded[i], zeros(eltype(model.forces)))
    end
    ## calculate pairwise forces at this step
    CellListMap.map_pairwise!(
        (x, y, i, j, d2, forces) -> calc_forces!(x, y, i, j, d2, forces, model),
        model.forces,
        model.clmap.box,
        model.clmap.cell_list;
        output_threaded=model.clmap.output_threaded,
        parallel=model.parallel
    )
    return nothing
end

#
# ## Update agent positions and velocities 
# 
# The `agent_step!` function will update the particle positons and velocities,
# given the forces, which are computed in the `model_step!` function. A simple
# Euler step is used here for simplicity. We need to convert the static vectors
# to tuples to conform the `Agents` API for the positions and velocities
# of the agents.
#
function agent_step!(agent, model::ABM)
    id = agent.id
    f = model.forces[id]
    x = SVector{2,Float64}(agent.pos)
    v = SVector{2,Float64}(agent.vel)
    dt = model.properties.dt
    a = f / agent.mass
    x_new = x + v * dt + (a / 2) * dt^2
    v_new = v + f * dt
    model.clmap.positions[id] = x_new
    agent.vel = Tuple(v_new)
    x_new = normalize_position(Tuple(x_new), model)
    move_agent!(agent, x_new, model)
    return nothing
end

#
# ## The simulation
#
# Finally, the function below runs an example simulation, for 1000 steps.
#
function simulate(; model=nothing, nsteps=1_000, number_of_particles=10_000)
    if isnothing(model) 
        model = initialize_model(number_of_particles=number_of_particles)
    end
    Agents.step!(
        model, agent_step!, model_step!, nsteps, false,
    )
end
#
# Which should be quite fast. Compilation time should be irrelevant
# for longer runs:
#
@time simulate()
#
# and let's make a nice video with less particles, 
# to see them bouncing around. The marker size is set by the 
# radius of each particle, and the marker color by the
# corresponding repulsion constant.
#
using InteractiveDynamics
using CairoMakie
CairoMakie.activate!() # hide
model = initialize_model(number_of_particles=1000)
abmvideo(
    "celllistmap.mp4", model, agent_step!, model_step!;
    framerate = 20, frames = 200, spf=5,
    title = "Bouncing particles",
    as = p -> p.r, # marker size
    ac = p -> p.k, # marker size
)
#
# The final video is shown at the top of this page.
#