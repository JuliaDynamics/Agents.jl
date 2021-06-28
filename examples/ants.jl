# # Ants 

# This is a implementation of the original ants netlogo model (https://ccl.northwestern.edu/netlogo/models/Ants),
# with some adaptations to work with a grid similar to the mesa model in (https://github.com/mgoadric/ants-mesa)

# This model describes a colony of ants that wander off from the colony and find food to bring back.
# The ants move around randomly at first, and when encountering food, return to their colony leaving a pheromone trail
# Other ants when moving randomly could also follow the pheromone trail in the strongest direction

using Agents: isempty
using Base: String, Float32, Float64
using Agents, AgentsPlots
using Gadfly: plot as ggplot, Geom, inch, SVG
using GLMakie
using InteractiveDynamics
using Match
using ImageFiltering
using DataFrames: rename!, stack


"""
Agent that represents the colony
"""
mutable struct Colony <: AbstractAgent
    "The identifier number of the agent"
    id::Int
    "The x, y location of the agent on a 2D grid"
    pos::Tuple{Int,Int}
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
    pos::Tuple{Int,Int}
    "food cache that the agent belongs to"
    cache_id::Int
    "amount of food that this agent holds"
    amount::Int
end


"""
Ants that wander around looking for food to bring back to the colony
"""
mutable struct Ant <: AbstractAgent
    "the identifier number of the agent"
    id::Int
    "The x, y location of the agent on a 2D grid"
    pos::Tuple{Int,Int}
    "one of the allowed_angles"
    angle::Float64
    "state of the agent `:foraging` or `:going_home`"
    state::Symbol
    "amount of food that the agent is carrying"
    amount::Int
    "pheromone amount that the agent is dropping"
    drop::Float32
end

# Utils for direction calculations

"""
Given an input angle in radians returns the closest angle 
"""
function closest_turn_angle(raw_angle)
    diffs = abs.(raw_angle .- turn_angles)
    return turn_angles[argmin(diffs)]
end

"""
Given an angle return the direction of the neighbor that the angle points to.
"""
function grid_direction(angle)
    return cmp.((cospi(angle/pi), sinpi(angle/pi)), 0)
end

"""
Random turn angle considering a maximum absolute value `max_turn_angle`
"""
function random_angle(max_turn_angle)
    allowed_angles = turn_angles[abs.(turn_angles) .<= max_turn_angle]
    return rand(allowed_angles)
end

function random_direction(max_turn_angle)
    return grid_direction(random_angle(max_turn_angle))
end

"""
Rotates the `angle` by `turn_angle`. 

The angle and rotations must be one of the turn angles,
with this, we keep the rotated angle in the same 'ring' of angles
"""
function rotate_angle(angle, turn_angle)
    angle_pos = findfirst(isequal(angle), turn_angles)
    turns = round(Int, turn_angle/(pi/4))
    new_angle_pos = mod1(angle_pos + turns, length(turn_angles))

    return turn_angles[new_angle_pos]
end

"""
Given two positions in the grid, return the closest `turn_angle` between them
"""
function angle_between(orig_pos, dest_pos)
    direction = dest_pos .- orig_pos
    
    #adjust_angle
    raw_angle = atan(direction[2], direction[1])
    raw_angle = raw_angle > pi ? pi - raw_angle : raw_angle

    return closest_turn_angle(raw_angle)
end

# setup

"""possible angles that the ant can rotate, 8 of them"""
turn_angles = Vector(-3*pi/4:pi/4:pi);  # multiples of pi/4

"""cache positions, fractions relative to the world dims"""
cache_positions = [
    (3/5, 1/2), (1/5, 2/5), (1/5, 4/5)]  # fractions relative to the world dims

"""directions in tuple format (x, y) ej. (1,-1)"""
turn_directions = grid_direction.(turn_angles)

"""
Initializes ABM

# Arguments
- `num_ants::Integer`: total of ants agents.
- `griddims::Tuple[Int]`: dimensions of the ant world.
- `max_turn_angle::Int`: maximum angle that the ant is allowed to turn, 
the direction is not specified so the ant will turn between ``\[-max_turn_angle, max_turn_angle\]``.
- `evaporation_r::Float64`: evaporation rate of the pheromones.
- `diffusion_r::Float64`: diffusion rate of the pheromones, 
which is the portion of the tile that is spread across neighbors.
- `init_drop::Integer`: Initial pheromone drop once the ant starts going back to the colony.
- `drop_rate::Float64`: Decaying rate of the pheromone drop each step.
- `random_move_prob::Float64`: probability of ignoring pheromones when foraging.
"""
function initialize(; 
    num_ants = 200, 
    griddims = (71, 71), 
    max_turn_angle=2*pi/4, 
    evaporation_r=0.2, diffusion_r=0.2, 
    init_drop = 60, drop_rate=0.99, 
    random_move_prob = 0.1)
    
    space = GridSpace(griddims, periodic=false, metric=:chebyshev)
    properties = (
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
    center_pos = div.(griddims, 2)
    setup_colony!(0, center_pos, model)

    # initialize the ants
    for _ in 1:num_ants
        agent = Ant(nextid(model), center_pos, random_angle(pi), :foraging, 0, 0)
        add_agent_pos!(agent, model)
    end

    for (cid, center_ratio) in enumerate(cache_positions)
        center_pos = floor.(Int, center_ratio .* griddims)
        setup_cache!(cid, center_pos, 5, model)
    end
    return model
end

"""Places the colony agent"""
function setup_colony!(id, pos, model)
    agent = Colony(id, pos, 0)
    add_agent_pos!(agent, model)

    @inbounds for p in positions(model) # we don't have to enable bound checking
        model.colony_distance[p...] = sqrt(sum((pos .- p).^2))
    end
end

"""Places the cache agents"""
function setup_cache!(cid, center, radius, model)
    agent = Food(nextid(model), center, cid, rand([1,2]))
    add_agent_pos!(agent, model)

    for pos in nearby_positions(center, model, radius)
        agent = Food(nextid(model), pos, cid, rand([1,2]))
        add_agent_pos!(agent, model)
    end
end

# Movement actions

"""
Moves the agent 1 step to the grid position in the direction of the `new_angle`
"""
function walk_to_angle!(agent, new_angle, model)
    agent.angle = new_angle
    new_direction = grid_direction(new_angle)
    walk!(agent, new_direction, model)
end

"""
Randomly moves the agent to one of the neighboring positions
"""
function random_move!(agent, model)
    new_angle = rotate_angle(agent.angle, random_angle(model.max_turn_angle))
    walk_to_angle!(agent, new_angle, model)
end

"""
Moves the agent 1 cell closer towards the colony
"""
function homing_move!(agent, model)
    neighbors = collect(nearby_positions(agent, model))
    distances = [model.colony_distance[p...] for p in neighbors]

    home_angle = angle_between(agent.pos, neighbors[argmin(distances)])
    walk_to_angle!(agent, home_angle, model)
end

"""
Agent performs a foraging move.
- if it detects pheromones on the current position and its not oversaturated,
the ant follows the pheromones with probability (`1-model.random_move_prob`)
- the ant will only try to follow the trail on its front (think of a 45 cone to both sides, so the 3 tiles in front)
- if there are no pheromones on the front, the ant also moves randomly 
"""
function foraging_move!(agent, model)
    current_pheromones = model.ant_pheromone[agent.pos...]

    if (current_pheromones > 0.05) & (current_pheromones <2) & (rand() > model.random_move_prob)
        # scans pheromones in front
        (pheromones, _, nearby_angles) = sense_pheromones(agent, model)
        
        if !isempty(pheromones)
            # follows the stronger pheromones in front
            best_angle = nearby_angles[argmax(pheromones)]
            walk_to_angle!(agent, best_angle, model)
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
    nearby = collect(nearby_positions(agent, model))
    nearby_angles = angle_between.([agent.pos], nearby)
    angle_differences = abs.(agent.angle .- nearby_angles)

    positions_in_front = nearby[angle_differences .<= pi/4]  # 45 degree cone
    angles_in_front = nearby_angles[angle_differences .<= pi/4]  # 45 degree cone
    
    pheromones = [model.ant_pheromone[p...] for p in positions_in_front]
    return (pheromones, positions_in_front, angles_in_front)
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
    agents = collect(agents_in_position(agent.pos, model))
    dinner_array = filter!(x -> isa(x, Food), agents)

    if !isempty(dinner_array)
        food = dinner_array[0]
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
    agents = collect(agents_in_position(agent.pos, model))
    colony_array = filter!(x -> isa(x, Colony), agents)

    if isempty(colony_array)
        drop_pheromone!(agent, model)
        homing_move!(agent, model)
    else
        colony = colony_array[1]
        colony.amount += agent.amount

        agent.amount = 0
        agent.angle = rotate_angle(agent.angle, pi) # turn back
        agent.state = :foraging
    end
end

"""
The ant drops a pheromone on the current position, and reduces the amount of pheromone it will drop next
"""
function drop_pheromone!(agent, model)
    model.ant_pheromone[agent.pos...] += agent.drop
    agent.drop *= model.drop_rate
end

"""
the ant takes an amount of 1 of the food source, if then the food is depleted, the food agent is deleted
"""
function eat!(agent::Ant, food, model)    
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

    diffused_grid = imfilter(model.ant_pheromone, diffusion_kernel) # diffuse with kernel
    diffused_grid = (1-model.evaporation_r) .* diffused_grid  # evaporate
    diffused_grid[diffused_grid.<= 0.05] .= 0  # if its too low make it zero
    diffused_grid[model[0].pos...] = 0  # no pheromones inside the colony
    
    @inbounds for p in positions(model) # we don't have to enable bound checking
        model.ant_pheromone[p...] = diffused_grid[p...]
    end
end

# Plotting

groupcolor(_::Ant) = :black;
groupcolor(_::Colony) = RGBA(24/255, 48/255, 60/255, 0.6);
groupcolor(a::Food) = @match a.amount begin 
        0 => :black
        _ => :green
    end;

groupmarker(a) = @match a begin
        a::Ant => '⚫'
        c::Colony => '■'
        f::Food => '■'
    end;

grasscolor(model) = model.ant_pheromone;
heatkwargs = (colormap = [:white, :blue], colorrange = (0, 10));

plotkwargs = (
    ac = groupcolor, am = groupmarker, as = 6, 
    heatarray = grasscolor, heatkwargs = heatkwargs,
    scheduler=Schedulers.randomly
)

# generate video of the model
model = initialize();

function make_video(model)
    abm_video(
        "ants_video.mp4",
        model, agent_step!, model_step!;
        frames = 1000,
        framerate = 8,
        plotkwargs...,)
end

make_video(model);


# generate data to further analysis of the food amounts in the caches

# helper functions for adata
food_cache(cid) = a -> a isa Food && a.cache_id==cid;

is_cache_number(a, cid) = a isa Food && a.cache_id==cid
nansum(x) = isempty(x) ? 0.0 : sum(x)

# initializes model and adata
model = initialize();
adata = [(:amount, nansum, a -> is_cache_number(a, cid)) for cid in 1:3];

# runs the model and collects data
max_steps = 1000
data, _ = run!(
    model, agent_step!, model_step!, max_steps; 
    adata = adata, when = 0:10:max_steps);

rename!(data, [:step, :amount_cache_1, :amount_cache_2, :amount_cache_3]);

# wide to long format
data_melt = stack(
    data, 
    [:amount_cache_1, :amount_cache_2, :amount_cache_3], [:step]; 
    variable_name=:cache_number, value_name=:amount);

p = ggplot(data_melt, x=:step, y=:amount, color=:cache_number, Geom.line)
p|> SVG("cache_amounts.svg")