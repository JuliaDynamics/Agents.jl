# # Force Based Motion Planning
# ![](circle_swap_pretty.gif) 

# This is an example implementation of the [Force Based Motion Planning (FMP)](https://arxiv.org/pdf/1909.05415.pdf) algorithm. The algorithm is a decentralized motion
# planning algorithm where individual agents experience attractive forces towards
# a goal position and repulsive forces from other agents or objects in the environment. 
# The FMP algorithm is included as a predefined `update_vel` function for use
# with [`ContinuousSpace`](@ref).


# ## Defining the Agent

# First we need to define an `AbstractAgent` struct that has the necessary
# information for the FMP algorithm to run. `pos`, and `vel` are position and
# velocity, respectively. `tau` is an agents goal position. `color` is an
# optional parameter for plotting used in this example. `type` is the agent
# type: `:A` is an agent, `:O` is an obstacle, and `:T` is a target. `radius`
# is the radius of the agent. `SSdims` is an optional parameter used for
# plotting purposes.
#
# Agent types have the following distinctions:
# - :A = agent (has velocity, subject to repulsive forces)
# - :O = object (has no velocity, cannot move, agents must go around)
# - :T = target (no velocity, just a projection of agent target zone)

using Agents, Random, Plots, LinearAlgebra, Colors, ProgressMeter

gr()
cd(@__DIR__)

mutable struct FMP_Agent <: AbstractAgent
    id::Int
    pos::NTuple{2, Float64}
    vel::NTuple{2, Float64}
    tau::NTuple{2, Float64}
    color::String
    type::Symbol
    radius::Float64
    SSdims::NTuple{2, Float64}  ## include this for plotting
end

# ## Defining the Model

# Next, we define the model. The FMP algorithm has several parameters defined
# in the original paper which are stored in a struct. Typical values can be
# generated using the `FMP_Parameter_Init` function and loaded into the model
# properties. 

# Additionally, note that we pass in `FMP_Update_Vel` as the `update_vel!`
# keyword argument when we initialize our `ContinuousSpace`.

## define AgentBasedModel (ABM)

function FMP_Model()
    properties = Dict(:FMP_params=>FMP_Parameter_Init(),
                      :dt => 0.01,
                      :num_agents=>20,
                      :num_steps=>1500,
                      :step_inc=>2,
                     )

    space2d = ContinuousSpace((1,1); periodic = true, update_vel! = FMP_Update_Vel)
    model = ABM(FMP_Agent, space2d, properties=properties)
    return model
end

# ## Adding Agents to the Model

# Now that we have defined a model, lets add some agents into it. In the
# following example, we add agents around the perimeter of a circle. We add
# their target position (tau) across the circle from each agent. Note that the
# arguments passed to `add_agent!` correspond to the `AbstractAgent` struct
# we defined earlier. Note that `:A` (agent types) experience navigational
# forces and repulsive forces. `:T` (target types) do not experience any
# forces.

# Also note that the `color` parameter doesn't do anything unless we use some
# plotting functionalities (described later in this tutorial)

## add agents to model
## determine circle params
model = FMP_Model()

x, y = model.space.extent
r = 0.9*(min(x,y)/2)

for i in 1:model.num_agents

    ## compute position around circle
    theta_i = (2*π/model.num_agents)*i
    xi = r*cos(theta_i)+x/2
    yi = r*sin(theta_i)+y/2
    
    xitau = r*cos(theta_i+π)+x/2
    yitau = r*sin(theta_i+π)+y/2

    ## set agent params
    pos = (xi, yi)
    vel = (0,0)
    tau = (xitau, yitau)  ## goal is on opposite side of circle
    radius = model.FMP_params.d/2
    agent_color = "nothing for now"
    add_agent!(pos, model, vel, tau, agent_color, :A, radius, model.space.extent)
    add_agent!(tau, model, vel, tau, agent_color, :T, radius, model.space.extent)
end


# ## Running a Simulation

# Now that we've defined our agent type, our model, and added agents into the
# model, we are ready to simulate. First we define a method for `agent_step!`.
# Note that `agent_step!` takes into account our `update_vel` function during
# simulation at each time step.

# Note the inclusion of the call to `FMP_Update_Interacting_Pairs`. This
# function occurrs once during each model time step and calls the
# [`interacting_pairs`](@ref) function to see if agents are within an
# interactive radius of one another. If they are, they the FMP algorithm
# computes their attractive/repulsive forces. 

agent_step!(agent, model) = move_agent!(agent, model, model.dt)

## helpful sim params
e = model.space.extent
step_range = 1:model.step_inc:model.num_steps

## setup progress meter counter (this is optional but convenient for simulation
p = Progress(round(Int,model.num_steps/model.step_inc))  ## optional
anim = @animate for i in step_range
    
    ## step model
    FMP_Update_Interacting_Pairs(model) ## this is really important
    p1 = plotabm(
        model,
        grid = false,
        xlims = (0, e[1]),
        ylims = (0, e[2]),
        aspect_ratio=:equal,
    )
    title!(p1, "FMP Simulation (step $(i))")
    
    ## step model and progress counter
    step!(model, agent_step!, model.step_inc)
    next!(p)  ## optional
end
gif(anim, "circle_swap_ugly.gif", fps = 100)

# ## Plotting Utilities

# The above animation isn't very pretty looking - luckily we can pass in some
# plotting parameters. This section defines some plotting utilities that help
# with make the generated plot look a little more convincing. 

# First, lets define a function that assigns color based on agent type.

using Colors
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

# Next, lets define a function that changes the plotted marker type based on
# agent type. This is for display purposes only, all objects/agents/targets are
# treated as objects with repulsive/forces based on distance between object
# centroids (e.g. the FMP algorithm doesn't understand square objects without
# modification)

"""
This function is a utility function for assigning agent display type based on agent type.
"""
function PlotABM_ShapeUtil(a::AbstractAgent)
    # potential options here:
    # https://gr-framework.org/julia-gr.html (search for "marker type")
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

# Next, lets define a function that changes agent plot size to be a little more
# realistic.
"""
This function is a utility function for setting agent plot size - note that this is for display purposes only and does not impact calculations involving agent radius. 
"""
function PlotABM_RadiusUtil(a::AbstractAgent)
    # this is for display purposes only and does not impact FMP algorithm results
    # the scaling values are empirically selected
    # the object scale is based on the agent scaling
    
    # magic number appears to be scaling factor for plotting
    #   ex, an agent/object with radius=1 place in center of SS
    #   would take up the entire state space. This was empirically
    #   tested. The 1/a.SSdims is also tested and works well.

    SS_scale = 380*1/minimum(a.SSdims)  # technically a.SSdims[1] and [2] should be equal but just in case.
    
    if a.type == :O
        return a.radius*SS_scale
    else
        return a.radius*SS_scale
    end
end

# Finally, lets define two utility functions to make sure that draw order and
# agent colors look pretty.

"""
This function is a scheduler to determine draw order of agents. Draw order (left to right) is :T, :O, :A
"""
function PlotABM_Scheduler(model::ABM)

    # init blank lists
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

    # make composite list [targets, objects, agents]
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

# Now that we've defined the plot utilities, lets re-run our simulation with
# some additional options. We do this by redefining the model, re-adding the
# agents but this time with a color parameter that is actually used. 

model = FMP_Model()

x, y = model.space.extent
r = 0.9*(min(x,y)/2)

for i in 1:model.num_agents

    ## compute position around circle
    theta_i = (2*π/model.num_agents)*i
    xi = r*cos(theta_i)+x/2
    yi = r*sin(theta_i)+y/2
    
    xitau = r*cos(theta_i+π)+x/2
    yitau = r*sin(theta_i+π)+y/2

    ## set agent params
    pos = (xi, yi)
    vel = (0,0)
    tau = (xitau, yitau)  ## goal is on opposite side of circle
    radius = model.FMP_params.d/2
    agent_color = AgentInitColor(i, model.num_agents)  ## This is new
    add_agent!(pos, model, vel, tau, agent_color, :A, radius, model.space.extent)
    add_agent!(tau, model, vel, tau, agent_color, :T, radius, model.space.extent)
end

p = Progress(round(Int,model.num_steps/model.step_inc))
anim = @animate for i in step_range

    # step model including plot stuff
    FMP_Update_Interacting_Pairs(model)
    p1 = plotabm(
        model,
        as = PlotABM_RadiusUtil,
        ac = PlotABM_ColorUtil,
        am = PlotABM_ShapeUtil,
        #showaxis = false,
        grid = false,
        xlims = (0, e[1]),
        ylims = (0, e[2]),
        aspect_ratio=:equal,
        scheduler = PlotABM_Scheduler,
    )
    title!(p1, "FMP Simulation (step $(i))")

    # step model and progress counter
    step!(model, agent_step!, model.step_inc)
    next!(p)
end
gif(anim, "circle_swap_pretty.gif", fps = 100)

# ## Adding Obstacles

# Now that we've plotted some agents and made the resultant simulation output
# look pretty, lets see how the FMP algorithm handles obstacles. The process is
# very similar to what we've been doing up until this point. We start by
# redefining the model and adding in agents. 

model = FMP_Model()

x, y = model.space.extent
for i in 1:model.num_agents
    ## add agents into vertical line
    xi = 0.5*x
    yi = y - (0.1*y+0.9*y/(model.num_agents)*(i-1))

    pos = (xi, yi)
    vel = (0,0)
    tau = pos  ## agent starting position = goal so they initially stay in place
    radius = model.FMP_params.d/2
    agent_color = AgentInitColor(i, model.num_agents)
    add_agent!(pos, model, vel, tau, agent_color, :A, radius, model.space.extent)  # add agents

end
# Now that we've added some agents to the state space, lets add an obstacle.
# Obstacles are just like agents except they don't experience repulsive forces,
# only attractive ones.

xio = 0.1*x
yio = 0.5*y
object_pos = (xio, yio)
object_vel = (0,0)
object_tau = (x-0.1*x, 0.5*y)
object_radius = 0.1
agent_color = "#ff0000"
add_agent!(object_pos, model, object_vel, object_tau, agent_color, :O, object_radius, model.space.extent)  # add object
add_agent!(object_tau, model, object_vel, object_tau, agent_color, :T, object_radius, model.space.extent)  # add object target

# Now that we've added an obstacle to the state space, we need to take one
# special step - adding the obstacle to the obstacle list for use by the FMP
# algorithm.

## append obstacles into obstacle_list
for agent in allagents(model)
    if agent.type == :O
        append!(model.FMP_params.obstacle_list, agent.id)
    end
end

# After adding in the obstacles, we can run the simulation

p = Progress(round(Int,model.num_steps/model.step_inc))
anim = @animate for i in step_range

    # step model including plot stuff
    FMP_Update_Interacting_Pairs(model)
    p1 = plotabm(
        model,
        as = PlotABM_RadiusUtil,
        ac = PlotABM_ColorUtil,
        am = PlotABM_ShapeUtil,
        #showaxis = false,
        grid = false,
        xlims = (0, e[1]),
        ylims = (0, e[2]),
        aspect_ratio=:equal,
        scheduler = PlotABM_Scheduler,
    )
    title!(p1, "FMP Simulation (step $(i))")

    # step model and progress counter
    step!(model, agent_step!, model.step_inc)
    next!(p)
end
gif(anim, "agent_line_moving_object.gif", fps = 100)

# ## Other Simulation Types

# These simulations are included as a "recipe booklet" for other ways that the
# FMP algorithm has been implemented. No new functionality is introduced; these
# examples are meant as working examples to build off of. 

## Centered Object Moving Line
model = FMP_Model()
x, y = model.space.extent
for i in 1:model.num_agents
    xi = 0.1*x
    yi = y - (0.1*y+0.9*y/(model.num_agents)*(i-1))

    pos = (xi, yi)
    vel = (0,0)
    tau = (0.8*x,0) .+ pos
    radius = model.FMP_params.d/2
    agent_color = AgentInitColor(i, model.num_agents)
    add_agent!(tau, model, vel, tau, agent_color, :T, radius, model.space.extent)  # add object target
    add_agent!(pos, model, vel, tau, agent_color, :A, radius, model.space.extent)  # add agents

end

xio = 0.3*x
yio = 0.5*y
object_pos = (xio, yio)
object_vel = (0,0)
object_tau = object_pos
object_radius = 0.2
agent_color = "#ff0000"
add_agent!(object_pos, model, object_vel, object_tau, agent_color, :O, object_radius, model.space.extent)  # add object

for agent in allagents(model)
    if agent.type == :O
        append!(model.FMP_params.obstacle_list, agent.id)
    end
end

p = Progress(round(Int,model.num_steps/model.step_inc))
anim = @animate for i in step_range

    # step model including plot stuff
    FMP_Update_Interacting_Pairs(model)
    p1 = plotabm(
        model,
        as = PlotABM_RadiusUtil,
        ac = PlotABM_ColorUtil,
        am = PlotABM_ShapeUtil,
        #showaxis = false,
        grid = false,
        xlims = (0, e[1]),
        ylims = (0, e[2]),
        aspect_ratio=:equal,
        scheduler = PlotABM_Scheduler,
    )
    title!(p1, "FMP Simulation (step $(i))")

    # step model and progress counter
    step!(model, agent_step!, model.step_inc)
    next!(p)
end
gif(anim, "centered_object_moving_line.gif", fps = 100)

## Circle Positions w/ Object

# determine circle params
model = FMP_Model()
x, y = model.space.extent
r = 0.9*(min(x,y)/2)

for i in 1:model.num_agents

    # compute position around circle
    theta_i = (2*π/model.num_agents)*i
    xi = r*cos(theta_i)+x/2
    yi = r*sin(theta_i)+y/2

    xitau = r*cos(theta_i+π)+x/2
    yitau = r*sin(theta_i+π)+y/2

    # set agent params
    pos = (xi, yi)
    vel = (0,0)
    tau = (xitau, yitau)  # goal is on opposite side of circle
    #tau = (x/2,y/2)
    type = :A
    radius = model.FMP_params.d/2
    agent_color = AgentInitColor(i, model.num_agents)
    add_agent!(pos, model, vel, tau, agent_color, :A, radius, model.space.extent)
    add_agent!(tau, model, vel, tau, agent_color, :T, radius, model.space.extent)
end

object_radius = 0.1
add_agent!((x/2,y/2), model, (0,0), (x/2,y/2), "#ff0000", :O, object_radius, model.space.extent)  # add object in middle

for agent in allagents(model)
    if agent.type == :O
        append!(model.FMP_params.obstacle_list, agent.id)
    end
end

p = Progress(round(Int,model.num_steps/model.step_inc))
anim = @animate for i in step_range

    # step model including plot stuff
    FMP_Update_Interacting_Pairs(model)
    p1 = plotabm(
        model,
        as = PlotABM_RadiusUtil,
        ac = PlotABM_ColorUtil,
        am = PlotABM_ShapeUtil,
        #showaxis = false,
        grid = false,
        xlims = (0, e[1]),
        ylims = (0, e[2]),
        aspect_ratio=:equal,
        scheduler = PlotABM_Scheduler,
    )
    title!(p1, "FMP Simulation (step $(i))")

    # step model and progress counter
    step!(model, agent_step!, model.step_inc)
    next!(p)
end
gif(anim, "circle_swap_object.gif", fps = 100)

## Random Positions
model = FMP_Model()

Random.seed!(42)
for i in 1:model.num_agents
    pos = Tuple(rand(2))
    vel = Tuple(rand(2))
    tau = Tuple(rand(2))
    type = :A
    radius = model.FMP_params.d/2
    agent_color = AgentInitColor(i, model.num_agents)
    add_agent!(pos, model, vel, tau, agent_color, type, radius, model.space.extent)
end

p = Progress(round(Int,model.num_steps/model.step_inc))
anim = @animate for i in step_range

    # step model including plot stuff
    FMP_Update_Interacting_Pairs(model)
    p1 = plotabm(
        model,
        as = PlotABM_RadiusUtil,
        ac = PlotABM_ColorUtil,
        am = PlotABM_ShapeUtil,
        #showaxis = false,
        grid = false,
        xlims = (0, e[1]),
        ylims = (0, e[2]),
        aspect_ratio=:equal,
        scheduler = PlotABM_Scheduler,
    )
    title!(p1, "FMP Simulation (step $(i))")

    # step model and progress counter
    step!(model, agent_step!, model.step_inc)
    next!(p)
end
gif(anim, "random_positions.gif", fps = 100)
