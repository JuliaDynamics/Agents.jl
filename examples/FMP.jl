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

    
# define AgentBasedModel (ABM)
properties = Dict(:FMP_params=>FMP_Parameter_Init(),
                  :dt => 0.01,
                  :num_agents=>20,
                  :num_steps=>1000,
                  :step_inc=>2,
                 )

space2d = ContinuousSpace((1,1); periodic=true, update_vel! =FMP_Update_Vel)
model = ABM(FMP_Agent, space2d, properties=properties)

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
    #color = AgentInitColor(i, model.num_agents)
    color="#FFFFFF"
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
       # as = PlotABM_RadiusUtil,
       # ac = PlotABM_ColorUtil,
       # am = PlotABM_ShapeUtil,
        #showaxis = false,
        grid = false,
        xlims = (0, e[1]),
        ylims = (0, e[2]),
        aspect_ratio=:equal,
        #scheduler = PlotABM_Scheduler,
    )
    title!(p1, "FMP Simulation (step $(i))")
    
    # step model and progress counter
    step!(model, agent_step!, model.step_inc)
    next!(p)
end
gif(anim, "simresult.gif", fps = 100)

