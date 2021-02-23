# # Force Based Motion Planning
# ![](circle_output.gif) 
#
# This is an example implementation of the [Force Based Motion Planning (FMP)](https://arxiv.org/pdf/1909.05415.pdf) algorithm. The algorithm is a decentralized motion
# planning algorithm where individual agents experience attractive forces towards
# a goal position and repulsive forces from other agents or objects in the environment. 

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
    # NOTE: if you change anything in this you need to restart the REPL
    # (I think it is the precompilation step)
end


"""
    BONE - do simple circle swap
"""
# define AgentBasedModel (ABM)
properties = Dict(:FMP_params=>FMP_Parameter_Init(),
                  :dt => 0.01,
                  :num_agents=>20,
                  :num_steps=>1000,
                  :step_inc=>2,
                 )

space2d = ContinuousSpace((1,1); periodic = true, update_vel! = FMP_Update_Vel)
model = ABM(FMP_Agent, space2d, properties=properties)
    
# append obstacles into obstacle_list
for agent in allagents(model)
    if agent.type == :O
        append!(model.obstacle_list, agent.id)
    end
end

gr()
cd(@__DIR__)

# init model
agent_step!(agent, model) = move_agent!(agent, model, model.dt)

# add agents to model
# determine circle params
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
    ##tau = (x/2,y/2)
    type = :A
    radius = model.FMP_params.d/2
    color = AgentInitColor(i, model.num_agents)
    add_agent!(pos, model, vel, tau, color, :A, radius, model.space.extent)
    add_agent!(tau, model, vel, tau, color, :T, radius, model.space.extent)
end

# init state space
e = model.space.extent
step_range = 1:model.step_inc:model.num_steps

# setup prog/update_velress meter counter
p = Progress(round(Int,model.num_steps/model.step_inc))
anim = @animate for i in step_range
    
    # step model including plot stuff
    FMP_Update_Interacting_Pairs(model)
    p1 = AgentsPlots.plotabm(
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
gif(anim, "circleswap.gif", fps = 100)

"""
BONE DO MOVING LINE SIM
"""


# define some helper functions
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
