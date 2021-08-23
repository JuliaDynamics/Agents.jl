# # Point Vortex Model
# This example demonstrates how to implement a custom agent stepper utilising higher-order timestep integration in
# a 'ContinuousSpace' by solving the infinite plane point vortex model. It also shows some methods to manipulate and
# extract data from the DataFrame object returned by 'Agents.run!'

# The PVM is an idealised model to study the dynamics of point vortices in a 2D incompressible inviscid fluid. Typically,
# it is used to investigate quantum vortex dynamics in 2D Bose-Einstein condensates. Each pointlike vortex has an associated
# polarity and imparts a force on all other vortices with a force that falls off quadratically with distance.

using Agents
using Random
using InteractiveDynamics
using CairoMakie
using Query

mutable struct PointVortex <: AbstractAgent
    id::Int
    pos::NTuple{2,Float64}
    vel::NTuple{2,Float64}
    polarity::Int
end

function move_agent_rk4!(
    agent::A,
    model::ABM{<:ContinuousSpace,A},
    dt::Real = 1.0,
) where {A<:AbstractAgent}
    model.space.update_vel!(agent, model)
    # Runge-Kutta 4th order integration scheme
    K1 = agent.vel
    K2 = agent.vel .+ 0.5.*dt.*K1
    K3 = agent.vel .+ 0.5.*dt.*K2
    K4 = agent.vel .+ dt.*K3
    pos = agent.pos .+ dt .* (K1 .+ 2.0.*K2 .+ 2.0.*K3 .+ K4)./6.0
    move_agent!(agent, pos, model)
    return agent.pos
end

# Generate alternating polarity vortices around a circle with random jitter
function NPointsCircle(model, npts, extent)
    x,y,Γ = zeros(npts),zeros(npts),zeros(npts)
    for j=0:npts-1
    x[j+1] = (model.properties["sigma"]+model.properties["η"]*randn(model.rng,1)[1])*cos(j*2π/(npts)) + extent[1]/2
    y[j+1] = (model.properties["sigma"]+model.properties["η"]*randn(model.rng,1)[1])*sin(j*2π/(npts)) + extent[2]/2
    Γ[j+1] = (-1)^j
    end
    return Tuple(collect(zip(x,y))), Γ
end

function initialize(;
    numagents = 50, # Number of point vortices
    seed = 1234, # Seed for reproducibility
    properties = Dict("dt" => 0.001, "sigma" => 10.0, "η" => 2),
    extent = (2500,2500), # Bounding box (simulation fails if vortex exits)
    spacing = min(extent...) /200, # Setup for Continuous space
    )
    rng = Random.MersenneTwister(seed)
    space = ContinuousSpace(extent, spacing)
    model = ABM(PointVortex, space; rng, properties)
    posits, circ = NPointsCircle(model,numagents,extent)
    # Assign positions and polaraties to velocities, with zero velocity.
    for n in 1:numagents
        vel = Tuple(zeros(2))
        pos = posits[n]
        polarity = circ[n]
        add_agent!(pos, model, vel, polarity)
    end
    return model
end

function agent_step!(PointVortex, model)
    # For each vortex, sum contributing forces from all other vortices (excluding self)
    c = (1/sqrt(2π)) # Quantum of circulation
    for a in allagents(model)
        a.vel = (0.0,0.0)
            for b in allagents(model)
            if a.id != b.id
                a.vel = a.vel .+ (-c*b.polarity*(a.pos[2] - b.pos[2])/edistance(a,b,model)^2,
                                   c*b.polarity*(a.pos[1] - b.pos[1])/edistance(a,b,model)^2)
            end
        end
    end
    move_agent_rk4!(PointVortex, model, model.properties["dt"])
    return
end


time = 10   # Time to propagate over
dt = 0.001  # Timestep to use in RK4 integration
σ = 3       # Initial seperation of cluster
η = 1       # Randomness amplitude to cluster

steps = Int(round(time/dt))
props = Dict("dt" => dt, "sigma" => σ, "η" => η)
model = initialize(properties=props) # Initialise model
adata = [:pos, :polarity] # Choose traits to track through simulation data
agent_df,model_df = Agents.run!(model, agent_step!, steps; adata)

# Plot initial positions of each vortex as a green cross
fig,ax = scatter(agent_df.pos[1:model.agents.count];
    color=:green,
    marker=:cross,
    label="",
    show_axis = false
)

# Remove Decorations from plot for cleaner look
hidedecorations!(ax)  # hides ticks, grid and lables
hidespines!(ax)  # hide the frame

# For each vortex, query its path throughout simulation and plot it
for j=1:model.agents.count

# Harvest negative vortex paths
vpathN =  @from i in agent_df begin
            @where i.id == j
            @where i.polarity == -1
            @select i.pos
            @collect
            end

# Harvest positive vortex paths
vpathP =  @from i in agent_df begin
            @where i.id == j
            @where i.polarity == 1
            @select i.pos
            @collect
            end

# Plot negative vortex path with varying alpha to better illustrate motion
plot!(vpathN;
color=tuple.(:red, sin.(LinRange(π/4,π/2,steps+1))),
markersize=1,
label=""
)

# Plot positive vortex path with varying alpha to better illustrate motion
plot!(vpathP;
color=tuple.(:blue, sin.(LinRange(π/8,π/2,steps+1))),
markersize=1,
label=""
)

end

# Harvest final positions of negative vortices
EptsN =  @from i in agent_df begin
                        @where i.step == steps
                        @where i.polarity == -1
                        @select i.pos
                        @collect
                        end

# Harvest final positions of positive vortices
EptsP =  @from i in agent_df begin
            @where i.step == steps
            @where i.polarity == 1
            @select i.pos
            @collect
            end

# Plot final positions with circulation indications
scatter!(EptsP, color=:blue, marker=:utriangle)
scatter!(EptsN, color=:red, marker=:circle)

# Display figure
display(fig)

