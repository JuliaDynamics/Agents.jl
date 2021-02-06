# # Force Based Motion Planning
# ![](circle_output.gif) 
#
# This is an example implementation of the [Force Based Motion Planning (FMP)](https://arxiv.org/pdf/1909.05415.pdf) algorithm. The algorithm is a decentralized motion
# planning algorithm where individual agents experience attractive forces towards
# a goal position and repulsive forces from other agents or objects in the environment. 
# ## Defining the Model

# We start by defining the two fundamental model components: the model space itself
# and the agent struct. Start by loading the necessary dependencies by defining the `FMP_Agent` struct:

using Agents, Random, AgentsPlots, Plots, LinearAlgebra, Colors, ProgressMeter

mutable struct FMP_Agent <: AbstractAgent
    id::Int
    pos::NTuple{2, Float64}
    vel::NTuple{2, Float64}
    tau::NTuple{2, Float64}
    color::String
    type::Symbol
    radius::Float64
    SSdims::NTuple{2, Float64}  # include this for plotting
end

# `pos`/`vel` are the agents starting position and velocity respectively. 
# `tau` is the agents target position. `type` is the type of the agent - 
# either Agent, Target, or Object. Different agent types have different 
# collision properties. 
# Next, we define the FMP model. All keyword arguments 
# are FMP model hyperparameters based on the original paper. Model properties 
# are assigned based on the keyword argument hyperparameters. We define the 
# model space continuously. 

"""
Initialization function for FMP simulation. Contains all model parameters.
"""
function FMP_Model(simtype;
                   rho = 7.5e6,
                   rho_obstacle = 7.5e6,
                   step_inc = 2,
                   dt = 0.01,
                   num_agents = 20,
                   SS_dims = (1, 1),  ## x,y should be equal for proper plot scaling
                   num_steps = 1500,
                   terminal_max_dis = 0.01,
                   c1 = 10,
                   c2 = 10,
                   vmax = 0.1,
                   d = 0.02, ## distance from centroid to centroid
                   r = (3*vmax^2/(2*rho))^(1/3)+d,
                   obstacle_list = [],
                  )

    ## define AgentBasedModel (ABM)
    properties = Dict(:rho=>rho,
                      :rho_obstacle=>rho_obstacle,
                      :step_inc=>step_inc,
                      :r=>r,
                      :d=>d,
                      :dt=>dt,
                      :num_agents=>num_agents,
                      :num_steps=>num_steps,
                      :terminal_max_dis=>terminal_max_dis,
                      :c1=>c1,
                      :c2=>c2,
                      :vmax=>vmax,
                      :obstacle_list=>obstacle_list,
                     )
    
    space2d = ContinuousSpace(SS_dims; periodic=true)
    model = ABM(FMP_Agent, space2d, properties=properties)
    AgentPositionInit(model, num_agents; type=simtype)

    ## append obstacles into obstacle_list
    for agent in allagents(model)
        if agent.type == :O
            append!(model.obstacle_list, agent.id)
        end
    end
    
    return model

end

# ## Defining the FMP Algorithm

# Next we define the actual FMP Algorithm. In general, three forces are
# computed:
# 
# 1) attractive force to target position
# 2) inter-agent repulsive forces
# 3) object repulsive forces
#
# The overall force is computed using simple vector addition over all the
# forces computed.
#
# The FMP algorithm is implemented in 3 "layers":
#
# - `FMP()` is a function that takes the positions of each agent in the ABM and
# finds which agents are within proximity to one another. Agents that are
# within proximity "interact" and experience repulsive forces. The `FMP()`
# function uses this interacting agent information in the sub-function `UpdateVelocity()`
# - `UpdateVelocity()` is a function that takes the interacting agent list and
# computes the component velocity forces from attractive and repulsive forces.
# - `RepulsiveForce()`/`NavigationalFeedback()`/`ObstactleFeedback()` are the
# functions that compute the component velocities that are summed into the
# overall agent velocity vector. `CapVelocity()` is a function that caps the
# velocity of an agent based on model hyperparameters.
#

"""
Wrapper function which updates agent velocities at each simulation time step. The function modifies the model in place so this function doesn't return anything.

The wrapper function determines which pairs are proximal to each other based on model parameters then computes the updated velocity for each agent accordingly.
"""
function FMP(model::AgentBasedModel)

    ## get list of interacting_pairs within some radius
    agent_iter = interacting_pairs(model, model.r, :all)

    ## construct interaction_array which is (num_agents x num_agents)
    ##   array where interaction_array[i,j] = 1 implies that
    ##   agent_i and agent_j are within the specified interaction radius
    interaction_array = falses( nagents(model), nagents(model))
    agents = agent_iter.agents
    for pair in agent_iter.pairs

        i, j = pair
        if agents[i].type == :A && agents[j].type == :A
            interaction_array[i, j] = true
            interaction_array[j, i] = true
        end

    end

    ## determine object ids


    ## loop through agents and update velocities
   for i in keys(agents)
        Ni = findall(x->x==1, interaction_array[i, :])
        ## move_this_agent_to_new_position(i) in FMP paper
        UpdateVelocity(model, i, Ni, agents)
    end
end

"""
Sub-wrapper function that updates the agent velocity based on the velocity subcomponents described in the FMP paper. The three forces included are:

- Repulsive force: analogous to a "magnetic" repulsion based on proximity of agent and other agents in the state space.
- Navigational force: an attractive force drawing an agent to its goal position
- Obstacle force: similar to repulsive force but generated by proximity to objects in the state space

After computing the resultant vectors from each component, an overall resultant vector is computed. This is then capped based on the global max velocity constraint.
"""
function UpdateVelocity(model::AgentBasedModel, i, Ni, agents)

    ## compute forces and resultant velocities
    fiR = RepulsiveForce(model, agents, i, Ni)
    fiGamma = NavigationalFeedback(model, agents, i)
    fiObject = ObstactleFeedback(model, agents, i)
    ui = fiR .+ fiGamma .+ fiObject
    vi = agents[i].vel .+ ui .* model.dt
    vi = CapVelocity(model.vmax, vi)

    ## update agent velocities
    agents[i].vel = vi

end

"""
Function to calculate the resultant velocity vector from the repulsive component of the FMP
algorithm.
"""
function RepulsiveForce(model::AgentBasedModel, agents, i, Ni)
    ## compute repulsive force for each agent
    ## note the "." before most math operations, required for component wise tuple math
    f = ntuple(i->0, length(agents[i].vel))
    for j in Ni
        dist = norm(agents[j].pos .- agents[i].pos)
        if dist < model.r
            force = -model.rho * (dist - model.r)^2
            distnorm = (agents[j].pos .- agents[i].pos) ./dist
            f = f .+ (force .* distnorm)
        end
    end

    ## targets/objects do not experience repulsive feedback
    if agents[i].type == :O || agents[i].type == :T
        return  ntuple(i->0, length(agents[i].vel))
    else
        return f
    end
end

"""
Function to calculate the resultant velocity vector from the navigational component of the FMP
algorithm.
"""
function NavigationalFeedback(model::AgentBasedModel, agents, i)
    ## compute navigational force for each agent
    ## note the "." before most math operations, required for component wise tuple math
    f = (-model.c1 .* (agents[i].pos .- agents[i].tau)) .+ (- model.c2 .* agents[i].vel)
    if agents[i].type == :T
        return  ntuple(i->0, length(agents[i].vel))  ## targets to not experience navigational feedback
    else
        return f
    end
end

"""
Function to calculate the resultant velocity vector from the obstacle avoidance component
of the FMP algorithm.
"""
function ObstactleFeedback(model::AgentBasedModel, agents, i)
    ## determine obstacle avoidance feedback term
    ## note the "." before most math operations, required for component wise tuple math
    f = ntuple(i->0, length(agents[i].vel))

    for id in model.obstacle_list
        ## the original paper defines z as p_j-r_j-p_i in equation 17/18
        ##   in the paper r_j is treated a vector, however it makes more sense to
        ##   treat as a scalar quantity so we take the norm, then subtract the radius
        ##   (j is obstacle (id) and i is agent (i))
        dist = norm(agents[id].pos  .- agents[i].pos) - agents[id].radius
        if dist < agents[i].radius
            force = -model.rho_obstacle * (dist - agents[id].radius)^2
            distnorm = (agents[id].pos .- agents[i].pos) ./ norm(agents[id].pos .- agents[i].pos)
            f = f .+ (force .* distnorm)
        end
    end
    if agents[i].type == :O || agents[i].type == :T
        return ntuple(i->0, length(agents[i].vel))
    else
        return f
    end
end

"""
Function to bound computed velocities based on globally set vmax parameter.
"""
function CapVelocity(vmax, vel)
    ## bound velocity by vmax
    ## note the "." before most math operations, required for component wise tuple math
    if norm(vel) > vmax
        vi = (vel ./ norm(vel)) .* vmax
        return vi
    else
        return vel
    end
end


# ## Utility Functions, etc

# These are some utility functions and simulation scenarios that are useful for
# demonstration but not integral to the actual FMP algorithm.

# We define the agent placement functions that correspond to the options
# we can simulate using the `FMP_Simulation()` function. We provide a wrapper
# functon `AgentPositionInit()` for convenience.

"""
Wrapper function for generating agent and object positions/targets. Different position functions share common inputs:

type = type of agent
    :A = agent (has velocity, subject to repulsive forces)
    :O = object (has no velocity, cannot move, agents must go around)
    :T = target (no velocity, just a projection of agent target zone)
radius = model.d/2 because model.d describes the minimum distance from agent centroid to agent centroid. Assuming that agents are circular and the same size, this means that model.d is also the diameter of the agent. Thus we use a radius of model.d/2
"""
function AgentPositionInit(model, num_agents; type="random")

    if type == "circle"
        return CirclePositions(model, num_agents)
    elseif type == "circle_object"
        return CirclePositionsObject(model, num_agents)
    elseif type == "line"
        return LinePositions(model, num_agents)
    elseif type == "centered_line_object"
        return CenteredLineObject(model, num_agents)
    elseif type == "moving_line"
        return CenteredObjectMovingLine(model, num_agents)
    elseif type == "random"
        return RandomPositions(model, num_agents)
    else
        @warn "Invalid simulation type; simulating random"
        return RandomPositions(model, num_agents)  ## return random anyways
    end
end

"""
Simulation where agents start on one side of the state space and move in a vertical line from left to right.
"""
function LinePositions(model, num_agents)

    x, y = model.space.extent
    for i in 1:num_agents
        xi = 0.1*x
        yi = y - (0.1*y+0.9*y/(num_agents)*(i-1))

        pos = (xi, yi)
        vel = (0,0)
        tau = pos .+ (0.8*x, 0)
        radius = model.d/2
        color = AgentInitColor(i, num_agents)
        add_agent!(pos, model, vel, tau, color, :A, radius, model.space.extent)  ## add agents
        add_agent!(tau, model, vel, tau, color, :T, radius, model.space.extent)  ## add targets

    end
    return model

end

"""
Simulation with unmoving vertical line of agents in middle of state space. A moving object is moving from left to right through line of agents. Agents must move around object and attempt to reorient themselves in the vertical line.
"""
function CenteredLineObject(model, num_agents)
    
    x, y = model.space.extent
    for i in 1:num_agents
        xi = 0.5*x
        yi = y - (0.1*y+0.9*y/(num_agents)*(i-1))

        pos = (xi, yi)
        vel = (0,0)
        tau = pos 
        radius = model.d/2
        color = AgentInitColor(i, num_agents)
        add_agent!(pos, model, vel, tau, color, :A, radius, model.space.extent)  ## add agents
        
    end

    xio = 0.1*x
    yio = 0.5*y
    object_pos = (xio, yio)
    object_vel = (0,0)
    object_tau = (x-0.1*x, 0.5*y)
    object_radius = 0.1
    color = "#ff0000"
    add_agent!(object_pos, model, object_vel, object_tau, color, :O, object_radius, model.space.extent)  ## add object
    add_agent!(object_tau, model, object_vel, object_tau, color, :T, object_radius, model.space.extent)  ## add object target

    return model

end

"""
Simulation similar to "Line Positions" with object in middle of state space that agents must navigate around.
"""
function CenteredObjectMovingLine(model, num_agents)
    
    x, y = model.space.extent
    for i in 1:num_agents
        xi = 0.1*x
        yi = y - (0.1*y+0.9*y/(num_agents)*(i-1))

        pos = (xi, yi)
        vel = (0,0)
        tau = (0.8*x,0) .+ pos 
        radius = model.d/2
        color = AgentInitColor(i, num_agents)
        add_agent!(tau, model, vel, tau, color, :T, radius, model.space.extent)  ## add object target
        add_agent!(pos, model, vel, tau, color, :A, radius, model.space.extent)  ## add agents
        
    end

    xio = 0.3*x
    yio = 0.5*y
    object_pos = (xio, yio)
    object_vel = (0,0)
    object_tau = object_pos
    object_radius = 0.2
    color = "#ff0000"
    add_agent!(object_pos, model, object_vel, object_tau, color, :O, object_radius, model.space.extent)  ## add object

    return model

end

"""
Agents start around the perimeter of a circle and attempt to move to a position on the opposite side of the circle - all agents end up driving towards the center.
"""
function CirclePositions(model, num_agents)

    ## determine circle params
    x, y = model.space.extent
    r = 0.9*(min(x,y)/2)

    for i in 1:num_agents

        ## compute position around circle
        theta_i = (2*π/num_agents)*i
        xi = r*cos(theta_i)+x/2
        yi = r*sin(theta_i)+y/2
        
        xitau = r*cos(theta_i+π)+x/2
        yitau = r*sin(theta_i+π)+y/2

        ## set agent params
        pos = (xi, yi)
        vel = (0,0)
        tau = (xitau, yitau)  ## goal is on opposite side of circle
        ##tau = (x/2,y/2)
        type = :A
        radius = model.d/2
        color = AgentInitColor(i, num_agents)
        add_agent!(pos, model, vel, tau, color, :A, radius, model.space.extent)
        add_agent!(tau, model, vel, tau, color, :T, radius, model.space.extent)
    end

    return model

end


"""
Agents start around the perimeter of a circle and attempt to move to a position on the opposite side of the circle - all agents end up driving towards the center. There is also an object in the middle.
"""
function CirclePositionsObject(model, num_agents)

    ## determine circle params
    x, y = model.space.extent
    r = 0.9*(min(x,y)/2)

    for i in 1:num_agents

        ## compute position around circle
        theta_i = (2*π/num_agents)*i
        xi = r*cos(theta_i)+x/2
        yi = r*sin(theta_i)+y/2
        
        xitau = r*cos(theta_i+π)+x/2
        yitau = r*sin(theta_i+π)+y/2

        ## set agent params
        pos = (xi, yi)
        vel = (0,0)
        tau = (xitau, yitau)  ## goal is on opposite side of circle
        ##tau = (x/2,y/2)
        type = :A
        radius = model.d/2
        color = AgentInitColor(i, num_agents)
        add_agent!(pos, model, vel, tau, color, :A, radius, model.space.extent)
        add_agent!(tau, model, vel, tau, color, :T, radius, model.space.extent)
    end

    object_radius = 0.1
    add_agent!((x/2,y/2), model, (0,0), (x/2,y/2), "#ff0000", :O, object_radius, model.space.extent)  ## add object in middle
    return model

end

"""
Agents start in random positions with random velocities and seek a random target position.
"""
function RandomPositions(model, num_agents)
    Random.seed!(42)
    for i in 1:num_agents
        pos = Tuple(rand(2))
        vel = Tuple(rand(2))
        tau = Tuple(rand(2))
        type = :A
        radius = model.d/2
        color = AgentInitColor(i, num_agents)
        add_agent!(pos, model, vel, tau, color, type, radius, model.space.extent)
    end

    return model

end

# These are some plotting utilities that assign color, marker type, plot order,
# etc:

"""
This function is a utility function that takes an agent and overwrites its color if it is of type :T (target) and gives it a grey color for display purposes.
"""
function PlotABM_ColorUtil(a::AbstractAgent)
    if a.type == :A || a.type == :O
        return a.color
    else
        return "#ffffff"
    end
end

"""
This function is a utility function for assigning agent display type based on agent type.
"""
function PlotABM_ShapeUtil(a::AbstractAgent)
    ## potential options here:
    ## https://gr-framework.org/julia-gr.html (search for "marker type")
    if a.type == :A
        return :circle
    elseif a.type == :O
        return :circle
    elseif a.type == :T
        return :circle
    else
        return :circle
    end
end

"""
This function is a utility function for setting agent plot size - note that this is for display purposes only and does not impact calculations involving agent radius. 
"""
function PlotABM_RadiusUtil(a::AbstractAgent)
    ## this is for display purposes only and does not impact FMP algorithm results
    ## the scaling values are empirically selected
    ## the object scale is based on the agent scaling
    
    ## magic number appears to be scaling factor for plotting
    ##   ex, an agent/object with radius=1 place in center of SS
    ##   would take up the entire state space. This was empirically
    ##   tested. The 1/a.SSdims is also tested and works well.

    SS_scale = 380*1/minimum(a.SSdims)  ## technically a.SSdims[1] and [2] should be equal but just in case.
    
    if a.type == :O
        return a.radius*SS_scale
    else
        return a.radius*SS_scale
    end
end

"""
This function is a scheduler to determine draw order of agents. Draw order (left to right) is :T, :O, :A
"""
function PlotABM_Scheduler(model::ABM)

    ## init blank lists
    agent_list = []
    object_list = []
    target_list = []
    for agent in values(model.agents)
        if agent.type == :A
            append!(agent_list, agent.id)
        elseif agent.type == :T
            append!(target_list, agent.id)
        elseif agent.type == :O
            append!(object_list, agent.id)
        end
    end

    ## make composite list [targets, objects, agents]
    draw_order = []
    append!(draw_order, target_list)
    append!(draw_order, object_list)
    append!(draw_order, agent_list)

    return draw_order
end

"""
This function is a utility function for coloring agents.
"""
function AgentInitColor(i, num_agents)
    color_range = range(HSV(0,1,1), stop=HSV(-360,1,1), length=num_agents)
    agent_color = color_range[i]
    return string("#", hex(agent_color))

end

# ## Running Simulations

# Now that we have implemented the actual FMP algorithm, we set up some
# functions to help with simulation. First, we define the simulation wrapper:

"""
Simulation wrapper for FMP simulations. 

Initializes model based on "type" parameter which dictates type of simulation to perform. Different simulation descriptions can be found in `/multiagent/simulation_init.jl`.

Possible inputs include:
- `circle` have agents move/swap places around perimeter of a circle
- `circle_object` have agents move/swap places around perimeter of a circle with an object in the middle
- `line` have agents move left to right in vertical line
- `centered_line_object` have agents remain stationary in vertical line and an object move through them
- `moving_line` have agents move left to right in vertical line past an object
- `random` have agents start in random positions with random velocities

Next it loops through the number of simulation steps (specified in model params) and create simulation display using `plotabm()`.

Finished by saving at the location specified by `outputpath` variable. 
"""
function FMP_Simulation(simtype::String; outputpath = "simresult.gif")
    gr()
    cd(@__DIR__)
    
    ## init model
    model = FMP_Model(simtype)
    agent_step!(agent, model) = move_agent!(agent, model, model.dt)
    
    ## init state space
    e = model.space.extent
    step_range = 1:model.step_inc:model.num_steps

    mean_norms = Array{Float64}(undef,1,)

    ## setup progress meter counter
    p = Progress(round(Int,model.num_steps/model.step_inc))
    anim = @animate for i in step_range
        
        ## step model including plot stuff
        FMP(model)
        p1 = plotabm(
            model,
            as = PlotABM_RadiusUtil,
            ac = PlotABM_ColorUtil,
            am = PlotABM_ShapeUtil,
            ##showaxis = false,
            grid = false,
            xlims = (0, e[1]),
            ylims = (0, e[2]),
            aspect_ratio=:equal,
            scheduler = PlotABM_Scheduler,
        )
        title!(p1, "FMP Simulation (step $(i))")
        
        ## step model and progress counter
        step!(model, agent_step!, model.step_inc)
        next!(p)
    end
    gif(anim, outputpath, fps = 100)

end

# Now we use the simulation wrapper to create some output
FMP_Simulation("circle", outputpath="_circle_output.gif")
FMP_Simulation("circle_object", outputpath="_circle_object_output.gif")
FMP_Simulation("line", outputpath="_line_output.gif")
FMP_Simulation("centered_line_object", outputpath="_centered_line_object_output.gif")
FMP_Simulation("moving_line", outputpath="_moving_line_output.gif")
FMP_Simulation("random", outputpath="_random_output.gif")
