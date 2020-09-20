# # Continuous space social distancing for COVID-19
# ![](socialdist5.gif)

# This is a model similar to our [SIR model for the spread of COVID-19](@ref).
# But instead of having different cities, we let agents move in one continuous
# space and transfer the disease if they come into contact with one another.
# This model is partly inspired by
# [this article](https://www.washingtonpost.com/graphics/2020/world/corona-simulator/),
# and can complement the SIR graph model. The graph model can model virus transfer between
# cities, whilst this model can be used to study what happens within a city.

# The example here serves additionally as an introduction to using continuous space, modelling
# billiard-like collisions in that space, and animating the agent motion in the space.
# Notice that a detailed description of the basics of the model regarding disease spreading
# exists in the SIR example, and is not repeated here.

# It is also available from the `Models` module as [`Models.social_distancing`](@ref).

# ## Moving agents in continuous space

# Let us first create a simple model where balls move around in a continuous space.
# We need to create agents that comply with [`ContinuousSpace`](@ref), i.e.
# they have a `pos` and `vel` fields, both of which are tuples of float numbers.

using Agents, Random, AgentsPlots, Plots
gr() # hide
cd(@__DIR__) #src
mutable struct Agent <: AbstractAgent
    id::Int
    pos::NTuple{2,Float64}
    vel::NTuple{2,Float64}
    mass::Float64
end

# The `mass` field will come in handy later on, when we implement social isolation
# (i.e. that some agents don't move and can't be moved).

# Let's also initialize a trivial model with continuous space
function ball_model(; speed = 0.002)
    space2d = ContinuousSpace(2; periodic = true, extend = (1, 1))
    model = ABM(Agent, space2d, properties = Dict(:dt => 1.0))

    ## And add some agents to the model
    Random.seed!(42) # hide
    for ind in 1:500
        pos = Tuple(rand(2))
        vel = sincos(2π * rand()) .* speed
        add_agent!(pos, model, vel, 1.0)
    end
    index!(model)
    return model
end

model = ball_model()

# We took advantage of the functionality of [`add_agent!`](@ref) that creates the
# agents automatically. For now all agents have the same absolute `speed`, and `mass`.
# We `index!` the model, to make finding nearby agents faster.

# The agent step function for now is trivial. It is just [`move_agent!`](@ref) in
# continuous space
agent_step!(agent, model) = move_agent!(agent, model, model.dt)
nothing # hide

# `dt` is our time resolution, but we will talk about this more later!
# Cool, let's see now how this model evolves.

e = model.space.extend
anim = @animate for i in 1:2:100
    p1 = plotabm(
        model,
        as = 4,
        showaxis = false,
        grid = false,
        xlims = (0, e[1]),
        ylims = (0, e[2]),
    )

    title!(p1, "step $(i)")
    step!(model, agent_step!, 2)
end
gif(anim, "socialdist1.gif", fps = 25)

# As you can see the agents move in a straight line in periodic space.
# There is no interaction yet. Let's change that.

# ## Billiard-like interaction
# We will model the agents as balls that collide with each other.
# To this end, we will use two functions from the continuous space API:
# 1. [`interacting_pairs`](@ref)
# 1. [`elastic_collision!`](@ref)

# We want all agents to interact in one go, and we want to avoid double interactions
# (as instructed by [`interacting_pairs`](@ref)), so we define a model step and re-run the
# animation.
function model_step!(model)
    for (a1, a2) in interacting_pairs(model, 0.012, :nearest)
        elastic_collision!(a1, a2, :mass)
    end
end

model2 = ball_model()

e = model.space.extend
anim = @animate for i in 1:2:100
    p1 = plotabm(
        model2,
        as = 4,
        showaxis = false,
        grid = false,
        xlims = (0, e[1]),
        ylims = (0, e[2]),
    )
    title!(p1, "step $(i)")
    step!(model2, agent_step!, model_step!, 2)
end
gif(anim, "socialdist2.gif", fps = 25)

# Alright, this works great so far!

# !!! warning "Agents.jl is not a billiards simulator!"
#     Please understand that Agents.jl does not accurately simulate billiard systems.
#     This is the job of Julia packages [HardSphereDynamics.jl](https://github.com/JuliaDynamics/HardSphereDynamics.jl)
#     or [DynamicalBilliards.jl](https://juliadynamics.github.io/DynamicalBilliards.jl/dev/).
#     In Agents.jl we only provide an approximating function `elastic_collision!`. The
#     accuracy of this simulation increases as the time resolution `dt` decreases,
#     but even in the limit `dt → 0` we still don't reach the accuracy of proper billiard packages.
#
#     Also notice that the plotted size of the circles representing agents is not
#     deduced from the `interaction_radius` (as it should).
#     We only eye-balled it to look similar enough.

# ## Immovable agents
# For the following social distancing example, it will become crucial that some
# agents don't move, and can't be moved (i.e. they stay "isolated"). This is
# very easy to do with the [`elastic_collision!`](@ref) function, we only have to make
# some agents have infinite mass

model3 = ball_model()

for id in 1:400
    agent = model3[id]
    agent.mass = Inf
    agent.vel = (0.0, 0.0)
end

# let's animate this again

e = model.space.extend
anim = @animate for i in 1:2:100
    p1 = plotabm(
        model3,
        as = 4,
        showaxis = false,
        grid = false,
        xlims = (0, e[1]),
        ylims = (0, e[2]),
    )
    title!(p1, "step $(i)")
    step!(model3, agent_step!, model_step!, 2)
end
gif(anim, "socialdist3.gif", fps = 25)

# ## Adding Virus spread (SIR)
# We now add more functionality to these agents, according to the SIR model
# (see previous example).
# They can be infected with a disease and transfer the disease to other agents around them.

mutable struct PoorSoul <: AbstractAgent
    id::Int
    pos::NTuple{2,Float64}
    vel::NTuple{2,Float64}
    mass::Float64
    days_infected::Int  # number of days since is infected
    status::Symbol  # :S, :I or :R
    β::Float64
end

# Here `β` is the transmission probability, which we choose to make an
# agent parameter instead of a model parameter. It reflects the level of hygiene
# of an individual. In a realistic scenario, the actual virus transmission
# would depend on the `β` value of both agents, but we don't do that here for
# simplicity.

# We also significantly modify the model creation, to have SIR-related parameters.
# Each step in the model corresponds to one hour.

const steps_per_day = 24

using DrWatson: @dict
function sir_initiation(;
    infection_period = 30 * steps_per_day,
    detection_time = 14 * steps_per_day,
    reinfection_probability = 0.05,
    isolated = 0.0, # in percentage
    interaction_radius = 0.012,
    dt = 1.0,
    speed = 0.002,
    death_rate = 0.044, # from website of WHO
    N = 1000,
    initial_infected = 5,
    seed = 42,
    βmin = 0.4,
    βmax = 0.8,
)

    properties = @dict(
        infection_period,
        reinfection_probability,
        detection_time,
        death_rate,
        interaction_radius,
        dt,
    )
    space = ContinuousSpace(2)
    model = ABM(PoorSoul, space, properties = properties)

    ## Add initial individuals
    Random.seed!(seed)
    for ind in 1:N
        pos = Tuple(rand(2))
        status = ind ≤ N - initial_infected ? :S : :I
        isisolated = ind ≤ isolated * N
        mass = isisolated ? Inf : 1.0
        vel = isisolated ? (0.0, 0.0) : sincos(2π * rand()) .* speed

        ## very high transmission probability
        ## we are modelling close encounters after all
        β = (βmax - βmin) * rand() + βmin
        add_agent!(pos, model, vel, mass, 0, status, β)
    end

    Agents.index!(model)
    return model
end
nothing # hide

# Notice the constant `steps_per_day`, which approximates how many model steps
# correspond to one day (since the parameters we used in the previous graph SIR example
# were given in days).

# To visualize this model, we will use black color for the susceptible, red for
# the infected infected and green for the recovered, leveraging [`plotabm`](@ref).

sir_model = sir_initiation()

sir_colors(a) = a.status == :S ? "#2b2b33" : a.status == :I ? "#bf2642" : "#338c54"

e = model.space.extend
plotabm(
    sir_model;
    ac = sir_colors,
    as = 4,
    msc=:auto,
    showaxis = false,
    grid = false,
    xlims = (0, e[1]),
    ylims = (0, e[2]),
)

# We have increased the size of the model 10-fold (for more realistic further analysis)

# To actually spread the virus, we modify the `model_step!` function,
# so that individuals have a probability to transmit the disease as they interact.

function transmit!(a1, a2, rp)
    ## for transmission, only 1 can have the disease (otherwise nothing happens)
    count(a.status == :I for a in (a1, a2)) ≠ 1 && return
    infected, healthy = a1.status == :I ? (a1, a2) : (a2, a1)

    rand() > infected.β && return

    if healthy.status == :R
        rand() > rp && return
    end
    healthy.status = :I
end

function sir_model_step!(model)
    r = model.interaction_radius
    for (a1, a2) in interacting_pairs(model, r, :nearest)
        transmit!(a1, a2, model.reinfection_probability)
        elastic_collision!(a1, a2, :mass)
    end
end
nothing # hide

# Notice that it is not necessary that the transmission interaction radius is the same
# as the billiard-ball dynamics. We only have them the same here for convenience,
# but in a real model they will probably differ.

# We also modify the `agent_step!` function, so that we keep track of how long the
# agent has been infected, and whether they have to die or not.

function sir_agent_step!(agent, model)
    move_agent!(agent, model, model.dt)
    update!(agent)
    recover_or_die!(agent, model)
end

update!(agent) = agent.status == :I && (agent.days_infected += 1)

function recover_or_die!(agent, model)
    if agent.days_infected ≥ model.infection_period
        if rand() ≤ model.death_rate
            kill_agent!(agent, model)
        else
            agent.status = :R
            agent.days_infected = 0
        end
    end
end
nothing # hide

# Alright, now we can animate this process for default parameters

sir_model = sir_initiation()

e = model.space.extend
anim = @animate for i in 1:2:100
    p1 = plotabm(
        sir_model;
        ac = sir_colors,
        as = 4,
        msc=:auto,
        showaxis = false,
        grid = false,
        xlims = (0, e[1]),
        ylims = (0, e[2]),
    )
    title!(p1, "step $(i)")
    step!(sir_model, sir_agent_step!, sir_model_step!, 2)
end
gif(anim, "socialdist4.gif", fps = 25)

# ## Exponential spread
# We can all agree that these animations look interesting, but let's do some actual
# analysis of this model. The quantity we wish to look at
# is the number of infected over time, so let's calculate this, similarly with
# the graph SIR model.

infected(x) = count(i == :I for i in x)
recovered(x) = count(i == :R for i in x)
adata = [(:status, infected), (:status, recovered)]
nothing # hide

# Let's do the following runs, with different parameters probabilities
r1, r2 = 0.04, 0.33
β1, β2 = 0.5, 0.1
sir_model1 = sir_initiation(reinfection_probability = r1, βmin = β1)
sir_model2 = sir_initiation(reinfection_probability = r2, βmin = β1)
sir_model3 = sir_initiation(reinfection_probability = r1, βmin = β2)

data1, _ = run!(sir_model1, sir_agent_step!, sir_model_step!, 2000; adata = adata)
data2, _ = run!(sir_model2, sir_agent_step!, sir_model_step!, 2000; adata = adata)
data3, _ = run!(sir_model3, sir_agent_step!, sir_model_step!, 2000; adata = adata)

data1[(end - 10):end, :]

# Now, we can plot the number of infected versus time

p = plot(
    data1[:, aggname(:status, infected)],
    label = "r=$r1, beta=$β1",
    ylabel = "Infected",
)
plot!(p, data2[:, aggname(:status, infected)], label = "r=$r2, beta=$β1")
plot!(p, data3[:, aggname(:status, infected)], label = "r=$r1, beta=$β2")
p

# Exponential growth is evident in all cases.

# ## Social distancing
# Of course in reality a dampening mechanism will (hopefully) happen before all
# of the population is infected: a vaccine. This effectively introduces a 4th type
# of status, `:V` for vaccinated. This type can't get infected, and thus all remaining
# individuals that are already infected will (hopefully) survive or die out.

# Until that point, social distancing is practiced.
# The best way to model social distancing is to make some agents simply not move
# (which feels like it approximates reality better).

sir_model = sir_initiation(isolated = 0.8)

e = model.space.extend
anim = @animate for i in 0:2:1000
    p1 = plotabm(
        sir_model;
        ac = sir_colors,
        as = 4,
        msc=:auto,
        showaxis = false,
        grid = false,
        xlims = (0, e[1]),
        ylims = (0, e[2]),
    )
    title!(p1, "step $(i)")
    step!(sir_model, sir_agent_step!, sir_model_step!, 2)
end
gif(anim, "socialdist5.gif", fps = 25)

# Here we let some 20% of the population *not* be isolated, probably teenagers still partying,
# or anti-vaxers / flat-earthers that don't believe in science.
# Still, you can see that the spread of the virus is dramatically contained.

# Let's look at the actual numbers, because animations are cool,
# but science is even cooler.

r4 = 0.04
sir_model4 = sir_initiation(reinfection_probability = r4, βmin = β1, isolated = 0.8)

data4, _ = run!(sir_model4, sir_agent_step!, sir_model_step!, 2000; adata = adata)

plot!(p, data4[:, aggname(:status, infected)], label = "r=$r4, social distancing")
p

# Here you can see the characteristic "flattening the curve" phrase you hear all over the
# news.

