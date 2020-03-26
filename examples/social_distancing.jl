# # Continuous space social distancing for COVID-19

# This is a model similar to our [SIR model for the spread of COVID-19](@ref).
# But instead of having different cities, we let agents move in one continuous
# space and transfer the disease if they come into contact with one another.
# This model is partly inspired by
# [this article](https://www.washingtonpost.com/graphics/2020/world/corona-simulator/),
# and can complement the SIR graph model. The graph model can model virus transfer between
# cities, while the current model can be used to study what happens within a city.

# This example serves also as an introduction to using continuous space, modelling
# billiard-like collisions in that space, and animating the agent motion in the space.
# Notice that a detailed description of the basics of the model regarding disease spreading
# exists in the SIR example, and is not repeated here.

# ## Moving agents in continuous space

# Let us first create a simple model were balls move around in a continuous space.
# We need to create agents that comply with [`ContinuousSpace`](@ref), i.e.
# they have a `pos` and `vel` fields, both of which are tuples of float numbers.

using Agents, Random, AgentsPlots, Plots

mutable struct Agent <: AbstractAgent
    id::Int
    pos::NTuple{2, Float64}
    vel::NTuple{2, Float64}
    mass::Float64
end

# The `mass` field will come in handy later on, when we implement social isolation
# (i.e. that some agents don't move and can't be moved).

# Let's also initialize a trivial model with continuous space
const space2d = ContinuousSpace(2; periodic = true, extend = (1, 1))
model = ABM(Agent, space2d, properties = Dict(:dt => 1.0));

# And add some agents to the model
const speed = 0.002
Random.seed!(42)
for ind in 1:100
    pos = Tuple(rand(2))
    vel = sincos(2π*rand()) .* speed
    add_agent!(pos, model, vel, 1.0)
end
index!(model)

# We took advantage of the functionality of [`add_agent!`](@ref) that creates the
# agents automatically. For now all agents have the same absolute `speed`, and `mass`.
# We `index!` the model, to make finding space neighbors faster.

# The agent step function for now is trivial. It is just [`move_agent!`](@ref) in
# continuous space
agent_step!(agent, model) =  move_agent!(agent, model, model.properties[:dt])

# `dt` is our time resolution, but we will talk about this more later!
# Cool, let's see now how this model evolves.

# TODO: Put this to AgentsPlots
function AgentsPlots.plotabm(model::ABM{A, <: ContinuousSpace}, c = x -> "#765db4", s = x -> 1)
    colors = [c(a) for a in allagents(model)]
    xs = [a.pos[1] for a in allagents(model)]
    ys = [a.pos[2] for a in allagents(model)]
    e = model.space.extend
    p1 = scatter(xs, ys, label="", color=colors, xlims=(0,e[1]), ylims=(0,e[2]))
end

anim = @animate for i ∈ 1:100
    p1 = plotabm(model)
    title!(p1, "step $(i)")
    step!(model, agent_step!, 1)
end
gif(anim, "socialdist1.gif", fps = 45);

# ![](socialdist1.gif)

# As you can see the agents move in a straight line in periodic space.
# There is no interaction yet. Let's change that.

# ## Billiard-like interaction
# We will model the agents as balls that collide with each other.
# To this end, we will use two functions from the continuous space API:
# 1. [`interacting_pairs`](@ref)
# 1. [`elastic_collision`](@ref)

# We want all agents to interact in one go, and we want to avoid double interactions
# (as instructed by [`interacting_pairs`](@ref)), so we define a model step
function model_step!(model)
    for (a1, a2) in interacting_pairs(model, 0.015)
    elastic_collision!(a1, a2, :mass)
    end
end

model = ABM(BallyAgent, space2d, properties = Dict(:dt => 1.0));

anim = @animate for i ∈ 1:100
    p1 = plotabm(model)
    title!(p1, "step $(i)")
    step!(model, agent_step!, model_step!, 1)
end
gif(anim, "socialdist2.gif", fps = 45);

# ![](socialdist2.gif)

# Alright, this works great so far!

# !!! warn "Agents.jl is not a billiards simulator!"
#     Please understand that Agents.jl does not accurately simulate billiard systems.
#     This is the job of Julia packages [HardSphereDynamics.jl](https://github.com/JuliaDynamics/HardSphereDynamics.jl)
#     or [DynamicalBilliards.jl](https://juliadynamics.github.io/DynamicalBilliards.jl/dev/).
#     In Agents.jl we only provide an approximating function `elastic_collision!`. The
#     accuracy of this simulation increases as the time resolution `dt` decreases, and **only**
#     in the limit `dt → 0` we reach the accuracy of proper billiard packages.

# ## Immovable agents
# For the following social distancing example, it will become crucial that some
# agents don't move, and can't be moved (i.e. they stay "isolated"). This is
# very easy to do with the [`elastic_collision!`] function, we only have to make
# some agents have infinite mass

model2 = ABM(Agent, space2d, properties = Dict(:dt => 1.0));

Random.seed!(42)
for ind in 1:100
    pos = Tuple(rand(2))
    vel = sincos(2π*rand()) .* speed
    mass = ind < 40 ? Inf : 1.0
    add_agent!(pos, model, vel, mass)
end

# let's animate this again

anim = @animate for i ∈ 1:100
    p1 = plotabm(model2)
    title!(p1, "step $(i)")
    step!(model2, agent_step!, model_step!, 1)
end
gif(anim, "socialdist3.gif", fps = 45);

# ## Adding Virus spread (SIR)
# We now add more functionality to these agents, according to the SIR model
# (see previous example).
# They can be infected with a disease and transfer the disease to other agents around them.

mutable struct PoorSoul <: AbstractAgent
    id::Int
    pos::NTuple{2, Float64}
    vel::NTuple{2, Float64}
    mass::Float64
    days_infected::Int  # number of days since is infected
    status::Symbol  # :S, :I or :R
    β::Float64
end

# Here `β` is the transmission probability, which we choose to make a
# agent parameter instead of model parameter

# And we also significantly modify the model creation, to have SIR-related parameters
using DrWatson: @dict

function sir_initiation(;
        infection_period = 30, reinfection_probability = 0.05, isolated = 0,
        interaction_radius = 0.015, dt = 1.0,
        detection_time = 14, death_rate = 0.04, N=1000,
        speed=0.005, initial_infected=N/100, seed=42
    )

    properties = @dict(
        infection_period, reinfection_probability,
        detection_time, death_rate, interaction_radius, dt,
    )
    space = ContinuousSpace(2; periodic = true, extend = (1, 1))
    model = ABM(PoorSoul, space, properties=properties)

    ## Add initial individuals
    Random.seed!(seed)
    for ind in 1:N
        pos = Tuple(rand(2))
        vel = sincos(2π*rand()) .* speed
        status = ind ≤ initial_infected ? :I : :S
        mass = ind ≤ isolated ? Inf : 1.0
        β = 0.1rand() + 0.8 # high transmission probability
        add_agent!(pos, model, vel, mass, 0, status, β)
    end

    Agents.index!(model)
    return model
end

sir_model = sir_initiation()

# To visualize this model, we will use different colors for the infected, recovered
# and susceptible, leveraging [`plotabm`](@ref).

sir_colors(a) = a.status == :S ? "black" : a.status == :I ? "red" : "green"

plotabm(sir_model, sir_colors)

# To actually spread the virus, we modify the `model_step!` function,
# so that individuals have a probability to transmit the disease as they interact.

function transmit!(a1, a2)
    ## for transmission, only 1 can have the disease (otherwise nothing happens)
    count(a.status == :I, (a1, a2)) ≠ 1 && return
    infected, healthy = a1.status == :I ? (a1, a2) : (a2, a1)

    rand() ≤ infected.β || return

    if healthy.status == :R
        rand() ≤ model.properties[:reinfection_probability] || return
    end
    healthy.status == :I
end

function model_step!(model)
    r = model.properties[:interaction_radius]
    for (a1, a2) in interacting_pairs(model, r)
        transmit!(a1, a2)
        elastic_collision!(a1, a2, :mass)
    end
end

# Notice that it is not necessary that the transmission interaction radius is the same
# as the billiard-ball dynamics. We only have them here the same for convenience,
# but in a real model they will probably differ.

# We also modify the `agent_step!` function, so that we keep track of how long the
# agent has been infected, and whether they have to die or not.

function sir_agent_step!(agent, model)
    move_agent!(agent, model, model.properties[:dt])
    update!(agent)
    recover_or_die!(agent, model)
end

update!(agent) = agent.status == :I && (agent.days_infected += 1)

function recover_or_die!(agent, model)
    if agent.days_infected ≥ model.properties[:infection_period]
        if rand() ≤ model.properties[:death_rate]
            kill_agent!(agent, model)
        else
            agent.status = :R
            agent.days_infected = 0
        end
    end
end

# Alright, now we can animate this process for default parameters
anim = @animate for i ∈ 1:1000
    p1 = plotabm(sir_model)
    title!(p1, "step $(i)")
    step!(sir_model, sir_agent_step!, sir_model_step!, 1)
end
gif(anim, "socialdist4.gif", fps = 45);


# ## Exponential spread

#TODO


# ## Social distancing
# To battle a virus, there are many ways. If e.g. a vaccine is discovered, then many parameters
# are affected. For example `β` will drop dramatically, and so will the spread.

# Lets observe disease spread with different amounts of agent movements. First, agents move with a probability of 0.9.

model = model_initiation(N=400,moveprob = 0.9, initial_infected=30);
colordict = Dict(:I=>"red", :S=>"black", :R=>"green")
anim = @animate for i ∈ 1:200
  xs = [a.pos[1] for a in values(model.agents)];
  ys = [a.pos[2] for a in values(model.agents)];
  colors = [colordict[a.status] for a in values(model.agents)];
  p1 = scatter(xs, ys, color=colors, label="", xlims=[0,1], ylims=[0, 1], xgrid=false, ygrid=false,xaxis=false, yaxis=false)
  title!(p1, "Day $(i)")
  step!(model, agent_step!, 1)
end
gif(anim, "social_distancing0.9.gif", fps = 8);

# ![](social_distancing0.9.gif)

# And now reduce the movement probability to 0.5.

model = model_initiation(N=400,moveprob = 0.5, initial_infected=30);
anim = @animate for i ∈ 1:200
  xs = [a.pos[1] for a in values(model.agents)];
  ys = [a.pos[2] for a in values(model.agents)];
  colors = [colordict[a.status] for a in values(model.agents)];
  p1 = scatter(xs, ys, color=colors, label="", xlims=[0,1], ylims=[0, 1], xgrid=false, ygrid=false,xaxis=false, yaxis=false)
  title!(p1, "Day $(i)")
  step!(model, agent_step!, 1)
end
gif(anim, "social_distancing0.5.gif", fps = 8);

# ![](social_distancing0.5.gif)

# The number of infected clearly reduces.
