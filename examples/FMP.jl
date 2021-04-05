# # Force Based Motion Planning
# ```@raw html
# <video width="auto" controls autoplay loop>
# <source src="../output2.mp4" type="video/mp4">
# </video>
# ```

# This is an example implementation of the [Force Based Motion Planning (FMP)](https://arxiv.org/pdf/1909.05415.pdf) algorithm. The algorithm is a decentralized motion
# planning algorithm where individual agents experience attractive forces towards
# a goal position and repulsive forces from other agents or obstacles in the environment. 
#
# ## Defining the Agent

# First we need to define an `AbstractAgent` struct that has the necessary
# information for the FMP algorithm to run. `pos`, and `vel` are position and
# velocity, respectively. `tau` is an agents goal position. `color` is an
# optional parameter for plotting used in this example. 
# `radius` is the radius of the agent.
# `type` is the agent type: 
# - :A = agent (has velocity, subject to repulsive forces)
# - :O = obstacle (has no velocity, cannot move, agents must go around)
# - :T = target (no velocity, just a projection of agent target zone)

using Agents, Random, LinearAlgebra, Colors, InteractiveDynamics
import CairoMakie

@agent FMP_Agent ContinuousAgent{2} begin
    tau::NTuple{2, Float64}
    color::String
    type::Symbol
    radius::Float64
    SSdims::NTuple{2, Float64}  ## include this for plotting
    Ni::Array{Int64} ## array of tuples with agent ids and agent positions
    Gi::Vector{Int64} ## array of neighboring goal IDs
end

# ## Defining the Model

# Next, we define the model. The FMP algorithm has several parameters defined
# in the original paper which are stored in a struct. Typical values can be
# generated using the [`fmp_parameter_init!`](@ref) function and loaded into the model
# properties. 

## define AgentBasedModel (ABM)

function FMP_Model()
    properties = Dict(:FMP_params=>fmp_parameter_init(),
                      :dt => 0.01,
                      :num_agents=>30,
                      :num_steps=>1500,
                     )

    space2d = ContinuousSpace((1,1); periodic = true)
    model = ABM(FMP_Agent, space2d, properties=properties)
    return model
end

# ## Adding Agents to the Model

# Now that we have defined a model, lets add some agents into it. In the
# following example, we add agents around the perimeter of a circle. We add
# their target position (`tau`) across the circle from each agent. Note that the
# arguments passed to `add_agent!` correspond to the `AbstractAgent` struct
# we defined earlier. Also recognize that agent types `:A` experience navigational
# forces and repulsive forces. Target types `:T` do not experience any
# forces. Obstacle types `:O` experience navigational forces but not repulsive
# forces.

# Also note that the `color` parameter doesn't do anything unless we use some
# plotting functionalities (described later in this tutorial)

## add agents to model
model = FMP_Model()

## lets start by defining a helper function that takes a model and some
## placement functions to place agents

function agent_placement_helper!(model, agent_placer, goal_placer, color_select)
    x, y = model.space.extent

    for i in 1:model.num_agents

        pos = agent_placer(x, y, i, model.num_agents)
        tau = goal_placer(x, y, i, model.num_agents)

        vel = (0,0)
        radius = model.FMP_params.d/2

        if color_select != "none"
            color = color_select(i, model.num_agents)
        else
            color = "none"
        end

        if agent_placer != "none"
            add_agent!(pos, model, vel, tau, color, :A, radius, model.space.extent, [], [])
        end

        if goal_placer != "none"
            add_agent!(tau, model, vel, tau, color, :T, radius, model.space.extent, [], [])
        end
    end
end

## place agents around circle, place targets opposite of agents
circle_agents(x, y, i, num_agents) = (0.45*cos((2*π/num_agents)*i)+x/2, 
                                     0.45*sin((2*π/num_agents)*i)+y/2
                                    )
circle_goals(x, y, i, num_agents) = (0.45*cos((2*π/num_agents)*i+π)+x/2, 
                                     0.45*sin((2*π/num_agents)*i+π)+y/2
                                    )

## place agents
agent_placement_helper!(model, circle_agents, circle_goals, "none")

# ## Running a Simulation

# Now that we've defined our agent type, our model, and added agents into the
# model, we are ready to simulate. First we define a method for `agent_step!`.
# Note that our definition of `agent_step!` uses [`fmp_update_vel!`](@ref) 
# at each time step.

# Also note the inclusion of the call to [`fmp_update_interacting_pairs!`](@ref) 
# in the `model_step!` function. This
# function occurrs once during each model time step and calls the
# [`interacting_pairs`](@ref) function to see if agents are within an
# interactive radius of one another. If they are, they the FMP algorithm
# computes their attractive/repulsive forces. 

agent_step!(agent, model) = move_agent!(agent, model, model.dt)

function model_step!(model)
    fmp_update_interacting_pairs!(model)
    for agent_id in keys(model.agents)
        fmp_update_vel!(model.agents[agent_id], model)
    end
end
@info "Plotting simulation 1..."
InteractiveDynamics.abm_video(
    "examples/output1.mp4",
    model,
    agent_step!,
    model_step!,
    title = "FMP Simulation",
    frames = model.num_steps,
    framerate = 100,
    resolution = (600, 600),
    equalaspect=true,
   )
# ```@raw html
# <video width="auto" controls autoplay loop>
# <source src="../output1.mp4" type="video/mp4">
# </video>
# ```

# The above animation isn't very pretty looking; lets plot using some color
# and shape/scaling utilities. Additionally we want a certain draw order so we
# define a plotting scheduler.


function plot_scheduler(model::ABM)

    ## init blank lists
    agent_list = []
    obstacle_list = []
    target_list = []
    for agent in values(model.agents)

        ## append to list based on draw order (:T, :O, :A in this example)
        if agent.type == :A
            append!(agent_list, agent.id)
        elseif agent.type == :T
            append!(target_list, agent.id)
        elseif agent.type == :O
            append!(obstacle_list, agent.id)
        end
    end

    ## make composite list [targets, obstacles, agents]
    draw_order = []
    append!(draw_order, target_list)
    append!(draw_order, obstacle_list)
    append!(draw_order, agent_list)

    return draw_order
end

function agent_init_color(i, num_agents)
    color_range = range(HSV(0,1,1), stop=HSV(-360,1,1), length=num_agents)
    agent_color = color_range[i]
    return string("#", hex(agent_color))
end

# Now that we've defined the plot utilities, lets re-run our simulation with
# some additional options. We do this by redefining the model, re-adding the
# agents but this time with a color parameter that is actually used. 

model = FMP_Model()  # reset the model to remove previously added agents
agent_placement_helper!(model, circle_agents, circle_goals, agent_init_color) 

# We also define a few plotting helper functions
as_f(a) = 1200*1/minimum(a.SSdims)*a.radius  ## this was defined empirically
ac_f(a) = a.type in (:A, :O) ? a.color : "#ffffff"
am_f(a) = a.type in (:A, :O, :T) ? :circle : :circle

# Now we run the simulation with some helper functions to access the agent parameters.

@info "Plotting simulation 2..."
InteractiveDynamics.abm_video(
    "examples/output2.mp4",
    model,
    agent_step!,
    model_step!,
    title = "FMP Simulation",
    frames = model.num_steps,
    framerate = 100,
    resolution = (600, 600),
    as = as_f,
    ac = ac_f,
    am = am_f,
    equalaspect=true,
    scheduler = plot_scheduler,
   )

# ```@raw html
# <video width="auto" controls autoplay loop>
# <source src="../output2.mp4" type="video/mp4">
# </video>
# ```
# ## Adding Obstacles

# Now that we've plotted some agents and made the resultant simulation output
# look pretty, lets see how the FMP algorithm handles obstacles. The process is
# very similar to what we've been doing up until this point. We start by
# redefining the model and adding in agents. 

model = FMP_Model()
line_agent(x, y, i, num_agents) = (0.5*x, 
                                   y - (0.1*y+0.9*y/(num_agents)*(i-1)))
agent_placement_helper!(model, line_agent, line_agent, agent_init_color)  # place goals at agent starting positions

# Now that we've added some agents to the state space, lets add an obstacle.
# Obstacles are just like agents except they don't experience repulsive forces,
# only attractive ones.

x,y = model.space.extent
xio = 0.1*x
yio = 0.5*y
obstacle_pos = (xio, yio)
obstacle_vel = (0,0)
obstacle_tau = (x-0.1*x, 0.5*y)
obstacle_radius = 0.1
agent_color = "#ff0000"
add_agent!(obstacle_pos, model, obstacle_vel, obstacle_tau, agent_color, :O, obstacle_radius, model.space.extent, [], [])  # add obstacle
add_agent!(obstacle_tau, model, obstacle_vel, obstacle_tau, agent_color, :T, obstacle_radius, model.space.extent, [], [])  # add target

# Now that we've added an obstacle to the state space, we need to take one
# special step - adding the obstacle to the obstacle list for use by the FMP
# algorithm.

## append obstacles into obstacle_list
for agent in allagents(model)
    if agent.type == :O
        append!(model.FMP_params.obstacle_list, agent.id)
    end
end

# After adding in the obstacles, we can run the simulation.

@info "Plotting simulation 3..."
InteractiveDynamics.abm_video(
    "examples/output3.mp4",
    model,
    agent_step!,
    model_step!,
    title = "FMP Simulation",
    frames = model.num_steps,
    framerate = 100,
    resolution = (600, 600),
    as = as_f,
    ac = ac_f,
    am = am_f,
    equalaspect=true,
    scheduler = plot_scheduler,
   )
# ```@raw html
# <video width="auto" controls autoplay loop>
# <source src="../output3.mp4" type="video/mp4">
# </video>
# ```
