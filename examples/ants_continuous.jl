# # Ants 

# This is a implementation of the original ants netlogo model (https://ccl.northwestern.edu/netlogo/models/Ants),
# with some adaptations to work with a grid similar to the mesa model in (https://github.com/mgoadric/ants-mesa)

# This model describes a colony of ants that wander off from the colony and find food to bring back.
# The ants move around randomly at first, and when encountering food, return to their colony leaving a pheromone trail
# Other ants when moving randomly could also follow the pheromone trail in the strongest direction

using Base: String, Float64, Tuple
using Agents, AgentsPlots
using GLMakie
using InteractiveDynamics
using ImageFiltering: imfilter as matrix_correlation
using DataFrames: rename!, stack
using LinearAlgebra: normalize
using Distributions: Uniform


"""
Agent that represents the colony
"""
mutable struct Colony <: AbstractAgent
    "The identifier number of the agent"
    id::Int
    "The x, y location of the agent on a 2D grid"
    pos::Tuple{Float64,Float64}
    "amount of food brought back by the ants"
    amount::Int
end


"""
Agent that represents food
"""
mutable struct Food <: AbstractAgent
    "The identifier number of the agent"
    id::Int
    "The x, y location of the agent on a 2D grid"
    pos::Tuple{Float64,Float64}
    "food cache that the agent belongs to"
    cache_id::Int
    "amount of food that this agent holds"
    amount::Int
end


"""
Ants that wander around looking for food to bring back to the colony
"""
@agent Ant ContinuousAgent{2} begin
    state::Symbol
    amount::Int
    drop::Float32
end

# Utils for direction calculations

"""
Given two positions in the grid, return the closest `turn_angle` between them
"""
function unitv_angle(v::Tuple)
    raw_angle = atan(v[2], v[1])
    return raw_angle > pi ? pi - raw_angle : raw_angle
end

function unitv_between(orig_pos::NTuple{D,Float64}, dest_pos::NTuple{D,Float64}) where {D}
    diffv = dest_pos .- orig_pos
    unitv = normalize([diffv...])
    return Tuple(unitv)
end

function angle_between(agent::Ant, dest_pos)
    diff_unitv = unitv_between(agent.pos, dest_pos)
    return unitv_angle(diff_unitv) - unitv_angle(agent.vel)
end

function random_vel()
    v = normalize(randn(2))
    return Tuple(v)
end

function rotate_v(v::Tuple, a::Float64)
    R = [cospi(a) -sinpi(a); sinpi(a) cospi(a)]
    Rv = R*[v...]
    return Tuple(Rv)
end

"""cache positions, fractions relative to the world dims"""
cache_positions = [
    (3/5, 1/2), (1/5, 2/5), (1/5, 4/5)];  # fractions relative to the world dims


"""
Initializes ABM

# Arguments
- `num_ants::Integer`: total of ants agents.
- `griddims::Tuple[Int]`: dimensions of the ant world.
- `max_turn_angle::Int`: maximum angle that the ant is allowed to turn, 
the direction is not specified so the ant will turn between ``[-max_turn_angle, max_turn_angle]``.
- `evaporation_r::Float64`: evaporation rate of the pheromones.
- `diffusion_r::Float64`: diffusion rate of the pheromones, 
which is the portion of the tile that is spread across neighbors.
- `init_drop::Integer`: Initial pheromone drop once the ant starts going back to the colony.
- `drop_rate::Float64`: Decaying rate of the pheromone drop each step.
- `random_move_prob::Float64`: probability of ignoring pheromones when foraging.
"""
function initialize(; 
    num_ants = 100, 
    extent = (200, 200),
    visual_distance = 5,
    spacing = visual_distance,
    max_turn_angle=pi/4, 
    evaporation_r=0.2, diffusion_r=0.2, 
    init_drop = 60, drop_rate=0.99, 
    random_move_prob = 0.1
    )
    
    space = ContinuousSpace(extent, spacing)

    griddims = Int.(extent ./ spacing)

    properties = (
        visual_distance = visual_distance,
        max_turn_angle = max_turn_angle,
        evaporation_r = evaporation_r, 
        diffusion_r=diffusion_r, 
        init_drop = init_drop,
        drop_rate=drop_rate,
        random_move_prob = random_move_prob,
        ant_pheromone = zeros(Float16, griddims),
        colony_distance = zeros(Float16, griddims)
    )
    
    model = ABM(Union{Ant, Colony, Food}, space;
                properties = properties, scheduler = random_activation)

    # add colony
    center_pos = extent ./ 2.0
    setup_colony!(0, center_pos, model)

    # initialize the ants
    for _ in 1:num_ants
        agent = Ant(nextid(model), center_pos, random_vel(), :foraging, 0, 0)
        add_agent_pos!(agent, model)
    end

    for (cid, center_ratio) in enumerate(cache_positions)
        center_pos = center_ratio .* extent
        setup_cache!(cid, center_pos, 5, model)
    end
    return model
end

"""Places the colony agent"""
function setup_colony!(id, pos, model)
    agent = Colony(id, pos, 0)
    add_agent_pos!(agent, model)
end

"""Places the cache agents"""
function setup_cache!(cid, center, radius, model)
    agent = Food(nextid(model), center, cid, rand([1,2]))
    add_agent_pos!(agent, model)

    for pos in nearby_positions(center, model, radius)
        continuous_pos = pos .* model.space.spacing
        agent = Food(nextid(model), continuous_pos, cid, rand([1,2]))
        add_agent_pos!(agent, model)
    end
end

# Movement actions

"""
Rotates the agent by rotating its `vel` vector
"""
function rotate!(agent::Ant, a::Float64)
    agent.vel = rotate_v(agent.vel, a)
end

"""
Randomly moves the agent to one of the neighboring positions
"""
function random_move!(agent, model)
    rotation_angle = rand(Uniform(-model.max_turn_angle, model.max_turn_angle))
    rotate!(agent, rotation_angle)
    move_agent!(agent, model, model.visual_distance)
end

"""
Moves the agent 1 cell closer towards the colony
"""
function homing_move!(agent, model)
    colony = model[1]  # the colony is always the first_agent

    agent.pos == colony.pos && return

    agent.vel = unitv_between(agent.pos, colony.pos)
    move_agent!(agent, model, model.visual_distance)
end

grid_pos(agent::AbstractAgent, model::ABM{<:ContinuousSpace}) = ceil.(Int, agent.pos ./ model.space.spacing);
grid_pos(space_pos::Tuple{Float64,Float64}, model::ABM{<:ContinuousSpace}) = ceil.(Int, space_pos ./ model.space.spacing);

"""
Agent performs a foraging move.
- if it detects pheromones on the current position and its not oversaturated,
the ant follows the pheromones with probability (`1-model.random_move_prob`)
- the ant will only try to follow the trail on its front (think of a 45 cone to both sides, so the 3 tiles in front)
- if there are no pheromones on the front, the ant also moves randomly 
"""
function foraging_move!(agent, model)
    agent_grid_pos = grid_pos(agent, model)
    current_pheromones = model.ant_pheromone[agent_grid_pos...]

    if (current_pheromones > 0.05) & (current_pheromones <2) & (rand() > model.random_move_prob)
        # scans pheromones in front
        (pheromones, ph_positions) = sense_pheromones(agent, model)
        
        if !isempty(pheromones)
            # follows the stronger pheromones in front
            best_pos = ph_positions[argmax(pheromones)]
            agent.vel = unitv_between(agent.pos, best_pos)
            move_agent!(agent, model, model.visual_distance)
        else
            # no detected pheromones in front
            random_move!(agent, model)
        end
    else
        random_move!(agent, model)
    end
end

"""
senses pheromones in a cone directly in fron of the ant, 
this helps avoid turning back every time the ant detects pheromones
"""
function sense_pheromones(agent, model)
    nearby = nearby_positions(agent, model, model.visual_distance)
    nearby = map(p -> p .* model.space.spacing, nearby)  # coordinates relative to extent
    angle_diffs = abs.([angle_between(agent, n) for n in nearby])

    positions_in_front = nearby[angle_diffs .<= pi/4]  # 45 degree cone
    
    pheromones = [model.ant_pheromone[grid_pos(p, model)...] for p in positions_in_front]
    return (pheromones, positions_in_front)
end

# agent actions
"""
agent step for the ant, depenfing on the state it eithers forages or returns home
"""
function agent_step!(agent::Ant, model)
    if agent.state == :foraging
        agent_forage!(agent, model)
    else
        agent_go_home!(agent, model)
    end
end

"""
Foraging action, if food is detected on the same position, 
the ant eats it and starts to go back to the colony. 
If no food is present the ant does a foraging move, trying to sense pheromones
"""
function agent_forage!(agent::Ant, model)
    agents = collect(nearby_agents(agent, model, model.space.spacing/2))  # 1 tile close
    dinner_array = filter!(x -> isa(x, Food), agents)

    if !isempty(dinner_array)
        food = dinner_array[1]
        eat!(agent, food, model)
        agent.drop = model.init_drop
        agent.state = :going_home
    else
        foraging_move!(agent, model)
    end
end

"""
Homing action, the ant will move one step closer to the colony. 
It also drops pheromones along the way

If the ant is on the colony, it drops the carry and goes back to foraging
"""
function agent_go_home!(agent::Ant, model)
    agents = collect(nearby_agents(agent, model, model.space.spacing/2))
    colony_array = filter!(x -> isa(x, Colony), agents)

    if isempty(colony_array)
        drop_pheromone!(agent, model)
        homing_move!(agent, model)
    else
        colony = colony_array[1]
        colony.amount += agent.amount

        agent.amount = 0
        rotate!(agent, 1.0) # go back 1 is a rotation of pi*1
        agent.state = :foraging
    end
end

"""
The ant drops a pheromone on the current position, and reduces the amount of pheromone it will drop next
"""
function drop_pheromone!(agent, model)
    model.ant_pheromone[grid_pos(agent, model)...] += agent.drop
    agent.drop *= model.drop_rate
end

"""
the ant takes an amount of 1 of the food source, if then the food is depleted, the food agent is deleted
"""
function eat!(agent::Ant, food::Food, model)    
    agent.amount += 1
    food.amount -= 1
    
    if food.amount<=0
        kill_agent!(food, model)
    end
end

"""
Agent step for the other agent types, blank because they do no action
"""
function agent_step!(_, _) 
end

# model actions
"""
Step for the model, diffuses the pheromones
"""
function model_step!(model)
    diffuse!(model)
end

"""
Diffuses pheromones giving 1/8 of the `diffusion_r*ant_pheromone` in the tile to each neighbor

Also evaporates the pheromones with rate `1 - evaporation_r`
"""
function diffuse!(model)
    diffusion_kernel = (1/8) * model.diffusion_r .* ones(3,3)
    diffusion_kernel[2,2] = 1 - model.diffusion_r

    new_pheromones = matrix_correlation(model.ant_pheromone, diffusion_kernel) # diffuse with kernel
    new_pheromones .*= (1-model.evaporation_r)  # evaporate
    new_pheromones[new_pheromones.<= 0.05] .= 0  # if its too low make it zero
    
    @inbounds for p in positions(model) # we don't have to enable bound checking
        model.ant_pheromone[p...] = new_pheromones[p...]
    end
end


# Plotting and results

groupcolor(_::Ant) = :black;
groupcolor(_::Colony) = RGBA(24/255, 48/255, 60/255, 0.6);
groupcolor(_::Food) = :green;

const ant_polygon = Polygon(Point2f0[(-0.5, -0.5), (1, 0), (-0.5, 0.5)]);
const sq_polygon = Polygon(Point2f0[(-0.5, -0.5), (-0.5, 0.5), (0.5,0.5), (0.5, -0.5)]);

groupmarker(_::Colony) = sq_polygon;
groupmarker(_::Food) = sq_polygon;
function groupmarker(a::Ant)
    φ = atan(a.vel[2], a.vel[1]) #+ π/2 + π
    return scale(rotate2D(ant_polygon, φ), 2)
end

grasscolor(model) = model.ant_pheromone;
heatkwargs = (colormap = [:white, :blue], colorrange = (0, 10));

plotkwargs = (
    ac = groupcolor, am = groupmarker, as = 6, 
    #heatarray = grasscolor, heatkwargs = heatkwargs
)

# generate video of the model
model = initialize();

figure, = abm_plot(model; plotkwargs...)
figure

function make_video(model)
    abm_video(
        "ants_video_continuous.mp4",
        model, agent_step!, model_step!;
        scheduler=Schedulers.randomly,
        frames = 100,
        framerate = 8,
        plotkwargs...,)
end

#make_video(model)


# generate data to further analysis of the food amounts in the caches

# helper functions for adata
food_cache(cid) = a -> a isa Food && a.cache_id==cid;

is_cache_number(a, cid) = a isa Food && a.cache_id==cid;
nansum(x) = isempty(x) ? 0.0 : sum(x);

# model initialization and running
model = initialize();
adata = [(:amount, nansum, a -> is_cache_number(a, cid)) for cid in 1:3];

max_steps = 1000
data, _ = run!(
    model, agent_step!, model_step!, max_steps; 
    adata = adata, when = 0:10:max_steps);

figure2, = abm_plot(model; plotkwargs...)
figure2

rename!(data, [:step, :amount_cache_1, :amount_cache_2, :amount_cache_3]);

function plot_food_timeseries(data)
    figure = Figure(resolution = (1200, 800))
    ax = figure[1, 1] = Axis(figure; xlabel = "Step", ylabel = "Food in cache")
    c1 = lines!(ax, data.step, data.amount_cache_1, color = :blue)
    c2 = lines!(ax, data.step, data.amount_cache_2, color = :orange)
    c3 = lines!(ax, data.step, data.amount_cache_3, color = :green)
    figure[1, 2] = Legend(figure, [c1, c2, c3], ["Cache 1", "Cache 2", "Cache 3"])
    return figure
end

food_figure = plot_food_timeseries(data)
food_figure