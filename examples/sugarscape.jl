# # Sugarscape
# **Growing Artificial Societies**

# ```@raw html
# <video width="auto" controls autoplay loop>
# <source src="../sugarvis.mp4" type="video/mp4">
# </video>
# ```

# (Descriptions below are from [this page](http://jasss.soc.surrey.ac.uk/12/1/6/appendixB/EpsteinAxtell1996.html))

# ---

# "Growing Artificial Societies" (Epstein & Axtell 1996) is a reference book for scientists
# interested in agent-based modelling and computer simulation. It represents one of the most
# paradigmatic and fascinating examples of the so-called generative approach to social science
# (Epstein 1999). In their book, Epstein & Axtell (1996) present a computational model where
# a heterogeneous population of autonomous agents compete for renewable resources that are
# unequally distributed over a 2-dimensional environment. Agents in the model are autonomous
# in that they are not governed by any central authority and they are heterogeneous in that
# they differ in their genetic attributes and their initial environmental endowments (e.g.
# their initial location and wealth). The model grows in complexity through the different
# chapters of the book as the agents are given the ability to engage in new activities such
# as sex, cultural exchange, trade, combat, disease transmission, etc. The core of Sugarscape
# has provided the basis for various extensions to study e.g. norm formation through cultural
# diffusion (Flentge et al. 2001) and the emergence of communication and cooperation in
# artificial societies (Buzing et al. 2005). Here we analyse the model described in the
# second chapter of Epstein & Axtell's (1996) book within the Markov chain framework.

# ## Rules of sugarscape

# The first model that Epstein & Axtell (1996) present comprises a finite population of
# agents who live in an environment. The environment is represented by a two-dimensional
# grid which contains sugar in some of its cells, hence the name Sugarscape. Agents' role
# in this first model consists in wandering around the Sugarscape harvesting the greatest
# amount of sugar they can find.

# ### Environment

# The environment is a 50×50 grid that wraps around forming a torus. Grid positions have
# both a sugar level and a sugar capacity c. A cell's sugar level is the number of units of
# sugar in the cell (potentially none), and its sugar capacity c is the maximum value the
# sugar level can take on that cell. Sugar capacity is fixed for each individual cell and
# may be different for different cells. The spatial distribution of sugar capacities depicts
# a sugar topography consisting of two peaks (with sugar capacity c = 4) separated by a
# valley, and surrounded by a desert region of sugarless cells (see Figure 1). Note,
# however, that the grid wraps around in both directions.

# The Sugarscape obbeys the following rule:

# Sugarscape growback rule G$\alpha$:
# At each position, sugar grows back at a rate of $\alpha$ units per time-step up to the cell's capacity c.

# ### Agents

# Every agent is endowed with individual (life-long) characteristics that condition her
# skills and capacities to survive in the Sugarscape. These individual attributes are:

# * A vision _v_, which is the maximum number of positions the agent can see in each of
# the four principal lattice directions: north, south, east and west.
# * A metabolic rate _m_, which represents the units of sugar the agent burns per time-step.
# * A maximum age _max-age_, which is the maximum number of time-steps the agent can live.

# Agents also have the capacity to accumulate sugar wealth _w_. An agent's sugar wealth
# is incremented at the end of each time-step by the sugar collected and decremented by the
# agent's metabolic rate. __Two agents are not allowed to occupy the same position in the grid.__

# The agents' behaviour is determined by the following two rules:

# #### Agent movement rule _M_:

# Consider the set of unoccupied positions within your vision (including the one you are
# standing on), identify the one(s) with the greatest amount of sugar, select the nearest one
# (randomly if there is more than one), move there and collect all the sugar in it.
# At this point, the agent's accumulated sugar wealth is incremented by the sugar collected
# and decremented by the agent's metabolic rate _m_. If at this moment the agent's sugar
# wealth is not greater than zero, then the agent dies.

# #### Agent replacement rule _R_:

# Whenever an agent dies it is replaced by a new agent of age 0 placed on a randomly chosen unoccupied position, having random attributes _v_, _m_ and _max-age_, and random initial wealth w0. All random numbers are drawn from uniform distributions with ranges specified in Table 1 below.

# ### Scheduling of events

# Scheduling is determined by the order in which the different rules _G_, _M_ and _R_ are fired in the model. Environmental rule _G_ comes first, followed by agent rule _M_ (which is executed by all agents in random order) and finally agent rule _R_ is executed (again, by all agents in random order).

# ### Parameterisation

# Our analysis corresponds to a model used by Epstein & Axtell (1996, pg. 33) to study the emergent wealth distribution in the agent population. This model is parameterised as indicated in Table 1 below (where U[a,b] denotes a uniform distribution with range [a,b]).

# Initially, each position of the Sugarscape contains a sugar level equal to its sugar capacity c, and the 250 agents are created at a random unoccupied initial location and with random attributes (using the uniform distributions indicated in Table 1).

# __Table 1__

# | Parameter                                | Value        |
# |------------------------------------------|--------------|
# | Lattice length L                         | 50           |
# | Number of sugar peaks                    | 2            |
# | Growth rate $\alpha$                     | 1            |
# | Number of agents N                       | 250          |
# | Agents' initial wealth w0 distribution   | U[5,25]      |
# | Agents' metabolic rate m distribution    | U[1,4]       |
# | Agents' vision v distribution            | U[1,6]       |
# | Agents' maximum age max-age distribution | U[60,100]    |

# ## Creating the ABM

using Agents, Random

mutable struct SugarSeeker <: AbstractAgent
    id::Int
    pos::Dims{2}
    vision::Int
    metabolic_rate::Int
    age::Int
    max_age::Int
    wealth::Int
end

# Functions `distances` and `sugar_caps` produce a matrix for the distribution of sugar capacities."

function distances(pos, sugar_peaks, max_sugar)
    all_dists = Array{Int,1}(undef, length(sugar_peaks))
    for (ind, peak) in enumerate(sugar_peaks)
        d = round(Int, sqrt(sum((pos .- peak) .^ 2)))
        all_dists[ind] = d
    end
    return minimum(all_dists)
end

function sugar_caps(dims, sugar_peaks, max_sugar, dia = 4)
    sugar_capacities = zeros(Int, dims)
    for i in 1:dims[1], j in 1:dims[2]
        sugar_capacities[i, j] = distances((i, j), sugar_peaks, max_sugar)
    end
    for i in 1:dims[1]
        for j in 1:dims[2]
            sugar_capacities[i, j] = max(0, max_sugar - (sugar_capacities[i, j] ÷ dia))
        end
    end
    return sugar_capacities
end

"Create a sugarscape ABM"
function sugarscape(;
    dims = (50, 50),
    sugar_peaks = ((10, 40), (40, 10)),
    growth_rate = 1,
    N = 250,
    w0_dist = (5, 25),
    metabolic_rate_dist = (1, 4),
    vision_dist = (1, 6),
    max_age_dist = (60, 100),
    max_sugar = 4,
    seed = 42
)
    sugar_capacities = sugar_caps(dims, sugar_peaks, max_sugar, 6)
    sugar_values = deepcopy(sugar_capacities)
    space = GridSpace(dims)
    properties = Dict(
        :growth_rate => growth_rate,
        :N => N,
        :w0_dist => w0_dist,
        :metabolic_rate_dist => metabolic_rate_dist,
        :vision_dist => vision_dist,
        :max_age_dist => max_age_dist,
        :sugar_values => sugar_values,
        :sugar_capacities => sugar_capacities,
    )
    model = AgentBasedModel(
        SugarSeeker,
        space,
        scheduler = random_activation,
        properties = properties,
        rng = MersenneTwister(seed)
    )
    for ag in 1:N
        add_agent_single!(
            model,
            rand(model.rng, vision_dist[1]:vision_dist[2]),
            rand(model.rng, metabolic_rate_dist[1]:metabolic_rate_dist[2]),
            0,
            rand(model.rng, max_age_dist[1]:max_age_dist[2]),
            rand(model.rng, w0_dist[1]:w0_dist[2]),
        )
    end
    return model
end

model = sugarscape()

# Let's plot the spatial distribution of sugar capacities in the Sugarscape.
using CairoMakie
CairoMakie.activate!() # hide

fig = Figure(resolution = (600, 600))
ax, hm = heatmap(fig[1,1], model.sugar_capacities; colormap=cgrad(:thermal))
Colorbar(fig[1, 2], hm, width = 20)
fig

# ## Defining stepping functions

# Now we define the stepping functions that handle the time evolution of the model

function model_step!(model)
    ## At each position, sugar grows back at a rate of $\alpha$ units
    ## per time-step up to the cell's capacity c.
    togrow = findall(
        x -> model.sugar_values[x] < model.sugar_capacities[x],
        1:length(positions(model)),
    )
    model.sugar_values[togrow] .+= model.growth_rate
end

function movement!(agent, model)
    newsite = agent.pos
    ## find all unoccupied position within vision
    neighbors = nearby_positions(agent.pos, model, agent.vision)
    empty = collect(empty_positions(model))
    if length(empty) > 0
        ## identify the one(s) with greatest amount of sugar
        available_sugar = (model.sugar_values[x,y] for (x, y) in empty)
        maxsugar = maximum(available_sugar)
        if maxsugar > 0
            sugary_sites_inds = findall(x -> x == maxsugar, collect(available_sugar))
            sugary_sites = empty[sugary_sites_inds]
            ## select the nearest one (randomly if more than one)
            for dia in 1:(agent.vision)
                np = nearby_positions(agent.pos, model, dia)
                suitable = intersect(np, sugary_sites)
                if length(suitable) > 0
                    newsite = rand(model.rng, suitable)
                    break
                end
            end
            ## move there and collect all the sugar in it
            newsite != agent.pos && move_agent!(agent, newsite, model)
        end
    end
    ## update wealth (collected - consumed)
    agent.wealth += (model.sugar_values[newsite...] - agent.metabolic_rate)
    model.sugar_values[newsite...] = 0
    ## age
    agent.age += 1
end

function replacement!(agent, model)
    ## If the agent's sugar wealth become zero or less, it dies
    if agent.wealth <= 0 || agent.age >= agent.max_age
        kill_agent!(agent, model)
        ## Whenever an agent dies, a young one is added to a random pos.
        ## New agent has random attributes
        add_agent_single!(
            model,
            rand(model.rng, model.vision_dist[1]:model.vision_dist[2]),
            rand(model.rng, model.metabolic_rate_dist[1]:model.metabolic_rate_dist[2]),
            0,
            rand(model.rng, model.max_age_dist[1]:model.max_age_dist[2]),
            rand(model.rng, model.w0_dist[1]:model.w0_dist[2]),
        )
    end
end

function agent_step!(agent, model)
    movement!(agent, model)
    replacement!(agent, model)
end

# ## Plotting & Animating

# We can plot the ABM and the sugar distribution side by side using [`abm_plot`](@ref)
# and standard Makie.jl commands like so
using InteractiveDynamics

model = sugarscape()
fig, abmstepper = abm_plot(model; resolution = (800, 600))
ax, hm = heatmap(fig[1,2], model.sugar_values; colormap=cgrad(:thermal), colorrange=(0,4))
ax.aspect = AxisAspect(1) # equal aspect ratio for heatmap
Colorbar(fig[1, 3], hm, width = 15, tellheight=false)
rowsize!(fig.layout, 1, ax.scene.px_area[].widths[2]) # Colorbar height = axis height
fig


# To animate them both however, we will use the approach Makie.jl suggests for animations,
# which is based on `Observables`. We start similarly with a call to `abm_plot`,
# but now make the plotted heatmap an obsrvable
fig, abmstepper = abm_plot(model; resolution = (800, 600))
obs_heat = Observable(model.sugar_values)
ax, hm = heatmap(fig[1,2], obs_heat; colormap=cgrad(:thermal), colorrange=(0,4))
ax.aspect = AxisAspect(1) # equal aspect ratio for heatmap
Colorbar(fig[1, 3], hm, width = 15, tellheight=false)
rowsize!(fig.layout, 1, ax.scene.px_area[].widths[2]) # Colorbar height = axis height

# and also add a title for good measure
s = Observable(0) # counter of current step, also observable
t = lift(x -> "Sugarscape, step = $x", s)
supertitle = Label(fig[0, :], t, textsize = 24, halign = :left)
fig

# We animate the evolution of both the ABM and the sugar distribution using the following
# simple loop involving the abm stepper
record(fig, "sugarvis.mp4"; framerate = 3) do io
    for j in 0:50 # = total number of frames
        recordframe!(io) # save current state
        ## This updates the abm plot:
        Agents.step!(abmstepper, model, agent_step!, model_step!, 1)
        ## This updates the heatmap:
        obs_heat[] = model.sugar_values
        ## This updates the title:
        s[] = s[] + 1
    end
end

# ```@raw html
# <video width="auto" controls autoplay loop>
# <source src="../sugarvis.mp4" type="video/mp4">
# </video>
# ```


# ### Distribution of wealth across individuals
# First we produce some data that include the wealth
model2 = sugarscape()
adata, _ = run!(model2, agent_step!, model_step!, 20, adata = [:wealth])
adata[1:10,:]

# And now we animate the evolution of the distribution of wealth
figure = Figure(resolution = (600, 600))
title_text = Observable("Wealth distribution of individuals\nStep 1")
figure[1, 1] = Label(figure, title_text; textsize=30, tellwidth=false)
ax = figure[2, 1] = Axis(figure; xlabel="Wealth", ylabel="Number of agents")
histdata = Observable(adata[adata.step .== 20, :wealth])
hist!(ax, histdata; bar_position=:step)
record(figure, "sugarhist.mp4", 0:20; framerate=3) do i
    histdata[] = adata[adata.step .== i, :wealth]
    title_text[] = "Wealth distribution of individuals, step = $i"
    xlims!(ax, (0, max(histdata[]...)))
    ylims!(ax, (0, 50))
end
nothing # hide

# We see that the distribution of wealth shifts from a more or less uniform distribution to a skewed distribution.

# ```@raw html
# <video width="auto" controls autoplay loop>
# <source src="../sugarhist.mp4" type="video/mp4">
# </video>
# ```

# ## References

# BUZING P, Eiben A & Schut M (2005) Emerging communication and cooperation in evolving agent societies. Journal of Artificial Societies and Social Simulation 8(1)2. http://jasss.soc.surrey.ac.uk/8/1/2.html.

# EPSTEIN J M (1999) Agent-Based Computational Models And Generative Social Science. Complexity 4(5), pp. 41-60.

# EPSTEIN J M & Axtell R L (1996) Growing Artificial Societies: Social Science from the Bottom Up. The MIT Press.

# FLENTGE F, Polani D & Uthmann T (2001) Modelling the emergence of possession norms using memes. Journal of Artificial Societies and Social Simulation 4(4)3. http://jasss.soc.surrey.ac.uk/4/4/3.html.
