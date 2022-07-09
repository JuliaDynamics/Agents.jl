# # Schelling's segregation model

# ```@raw html
# <video width="auto" controls autoplay loop>
# <source src="../schelling.mp4" type="video/mp4">
# </video>
# ```

# In this introductory example we parallelize the main [Tutorial](@ref) while building
# the following definition of Schelling's segregation model:

# * Agents belong to one of two groups (0 or 1).
# * The agents live in a two-dimensional grid. Only one agent per position is allowed.
# * For each agent we care about
#   finding all of its 8 nearest neighbors (cardinal and diagonal directions).
#   To do this, we will create a [`GridSpaceSingle`](@ref)
#   with a Chebyshev metric, and when searching for nearby agents we will use a radius
#   of 1 (which is also the default).
#   This leads to 8 neighboring positions per position (except at the edges of the grid).
# * If an agent has at least `k=3` neighbors belonging to the same group, then it is happy.
# * If an agent is unhappy, it keeps moving to new locations until it is happy,
#   while respecting the 1-agent-per-position rule.

# Schelling's model shows that even small preferences of agents to have neighbors
# belonging to the same group (e.g. preferring that at least 3/8 of neighbors to
# be in the same group) could still lead to total segregation of neighborhoods.

# This model is also available as [`Models.schelling`](@ref).

# ## Creating a space

using Agents

space = GridSpaceSingle((10, 10); periodic = false)
# Notice that by default the `GridSpaceSingle` has `metric = Chebyshev()`,
# which is what we want.
# Agents existing in this type of space must have a position field that is a
# `NTuple{2, Int}`. We ensure this below.

# ## Defining the agent type

mutable struct SchellingAgent <: AbstractAgent
    id::Int             # The identifier number of the agent
    pos::NTuple{2, Int} # The x, y location of the agent on a 2D grid
    mood::Bool          # whether the agent is happy in its position. (true = happy)
    group::Int          # The group of the agent, determines mood as it interacts with neighbors
end

# We added two more fields for this model, namely a `mood` field which will
# store `true` for a happy agent and `false` for an unhappy one, and an `group`
# field which stores `0` or `1` representing two groups.

# Notice also that we could have taken advantage of the macro [`@agent`](@ref) (and in
# fact, this is recommended), and defined the same agent as:
# ```julia
# @agent SchellingAgent GridAgent{2} begin
#     mood::Bool
#     group::Int
# end
# ```

# ## Creating an ABM

# To make our model we follow the instructions of [`AgentBasedModel`](@ref).
# We also want to include a property `min_to_be_happy` in our model, and so we have:

properties = Dict(:min_to_be_happy => 3)
schelling = ABM(SchellingAgent, space; properties)

# Here we used the default scheduler (which is also the fastest one) to create
# the model. We could instead try to activate the agents according to their
# property `:group`, so that all agents of group 1 act first.
# We would then use the scheduler [`Schedulers.ByProperty`](@ref) like so:

schelling2 = ABM(
    SchellingAgent,
    space;
    properties = properties,
    scheduler = Schedulers.ByProperty(:group),
)

# Notice that `Schedulers.ByProperty` accepts an argument and returns a struct,
# which is why we didn't just give `Schedulers.ByProperty` to `scheduler`.

# ## Creating the ABM through a function

# Here we put the model instantiation in a function so that
# it will be easy to recreate the model and change its parameters.

# In addition, inside this function, we populate the model with some agents.
# We also change the scheduler to [`Schedulers.Randomly`](@ref).
# Because the function is defined based on keywords,
# it will be of further use in [`paramscan`](@ref) below.

using Random # for reproducibility
function initialize(; numagents = 320, griddims = (20, 20), min_to_be_happy = 3, seed = 125)
    space = GridSpaceSingle(griddims, periodic = false)
    properties = Dict(:min_to_be_happy => min_to_be_happy)
    rng = Random.MersenneTwister(seed)
    model = ABM(
        SchellingAgent, space;
        properties, rng, scheduler = Schedulers.Randomly()
    )

    ## populate the model with agents, adding equal amount of the two types of agents
    ## at random positions in the model
    for n in 1:numagents
        agent = SchellingAgent(n, (1, 1), false, n < numagents / 2 ? 1 : 2)
        add_agent_single!(agent, model)
    end
    return model
end

# Notice that the position that an agent is initialized does not matter
# in this example.
# This is because we use [`add_agent_single!`](@ref), which places the agent in a random,
# empty location on the grid, thus updating its position.

# ## Defining a step function

# Finally, we define a _step_ function to determine what happens to an
# agent when activated.
# For the purpose of this implementation of Schelling's segregation model,
# we only need an agent step function and not a model stepping function.

function agent_step!(agent, model)
    minhappy = model.min_to_be_happy
    count_neighbors_same_group = 0
    ## For each neighbor, get group and compare to current agent's group
    ## and increment `count_neighbors_same_group` as appropriately.
    ## Here `nearby_agents` (with default arguments) will provide an iterator
    ## over the nearby agents one grid point away, which are at most 8.
    for neighbor in nearby_agents(agent, model)
        if agent.group == neighbor.group
            count_neighbors_same_group += 1
        end
    end
    ## After counting the neighbors, decide whether or not to move the agent.
    ## If count_neighbors_same_group is at least the min_to_be_happy, set the
    ## mood to true. Otherwise, move the agent to a random position, and set
    ## mood to false.
    if count_neighbors_same_group ≥ minhappy
        agent.mood = true
    else
        agent.mood = false
        move_agent_single!(agent, model)
    end
    return
end

# When defining `agent_step!`, we used some of the built-in functions of Agents.jl,
# such as [`nearby_positions`](@ref) that returns the neighboring position
# on which the agent resides, [`ids_in_position`](@ref) that returns the
# IDs of the agents on a given position, and [`move_agent_single!`](@ref) which moves
# agents to random empty position on the grid. A full list of built-in functions
# and their explanations are available in the [API](@ref) page.

# ## Stepping the model

# Let's initialize the model with 370 agents on a 20 by 20 grid.

model = initialize()

# We can advance the model one step
step!(model, agent_step!)

# Or for three steps
step!(model, agent_step!, 3)

# ## Visualizing the data
# There is a dedicated tutorial for visualization, animation, and interaction for
# agent based models. See [Visualizations and Animations for Agent Based Models](@ref).

# We can use the [`abmplot`](@ref) function to plot the distribution of agents on a
# 2D grid at every generation, via the
# [InteractiveDynamics.jl](https://juliadynamics.github.io/InteractiveDynamics.jl/dev/) package
# and the [Makie.jl](http://makie.juliaplots.org/stable/) plotting ecosystem.

# Let's color the two groups orange and blue and make one a square and the other a circle.
using InteractiveDynamics
using CairoMakie # choosing a plotting backend
CairoMakie.activate!() # hide

groupcolor(a) = a.group == 1 ? :blue : :orange
groupmarker(a) = a.group == 1 ? :circle : :rect
figure, _ = abmplot(model; ac = groupcolor, am = groupmarker, as = 10)
figure # returning the figure displays it

# ## Animating the evolution

# The function [`abmvideo`](@ref) can be used to save an animation of the ABM into a
# video. You could of course also explicitly use `abmplot` in a `record` loop for
# finer control over additional plot elements.

model = initialize();
abmvideo(
    "schelling.mp4", model, agent_step!;
    ac = groupcolor, am = groupmarker, as = 10,
    framerate = 4, frames = 20,
    title = "Schelling's segregation model"
)

# ```@raw html
# <video width="auto" controls autoplay loop>
# <source src="../schelling.mp4" type="video/mp4">
# </video>
# ```

# ## Collecting data during time evolution

# We can use the [`run!`](@ref) function with keywords to run the model for
# multiple steps and collect values of our desired fields from every agent
# and put these data in a `DataFrame` object.
# We define a vector of `Symbols`
# for the agent fields that we want to collect as data
adata = [:pos, :mood, :group]

model = initialize()
data, _ = run!(model, agent_step!, 5; adata)
data[1:10, :] # print only a few rows

# We could also use functions in `adata`, for example we can define
x(agent) = agent.pos[1]
model = initialize()
adata = [x, :mood, :group]
data, _ = run!(model, agent_step!, 5; adata)
data[1:10, :]

# With the above `adata` vector, we collected all agent's data.
# We can instead collect aggregated data for the agents.
# For example, let's only get the number of happy individuals, and the
# average of the "x" (not very interesting, but anyway!)
using Statistics: mean
model = initialize();
adata = [(:mood, sum), (x, mean)]
data, _ = run!(model, agent_step!, 5; adata)
data

# Other examples in the documentation are more realistic, with more meaningful
# collected data. Don't forget to use the function [`dataname`](@ref) to access the
# columns of the resulting dataframe by name.

# ## Launching the interactive application
# Given the definitions we have already created for a normally plotting or animating the ABM
# it is almost trivial to launch an interactive application for it, through the function
# [`abmexploration`](@ref).

# We define a dictionary that maps some model-level parameters to a range of potential
# values, so that we can interactively change them.
parange = Dict(:min_to_be_happy => 0:8)

# We also define the data we want to collect and interactively explore, and also
# some labels for them, for shorter names (since the defaults can get large)
adata = [(:mood, sum), (x, mean)]
alabels = ["happy", "avg. x"]

model = initialize(; numagents = 300) # fresh model, noone happy

# ```julia
# using GLMakie # using a different plotting backend that enables interactive plots
#
# figure, adf, mdf = abmexploration(
#     model, agent_step!, dummystep, parange;
#     ac = groupcolor, am = groupmarker, as = 10,
#     adata, alabels
# )
# ```
#
# ```@raw html
# <video width="100%" height="auto" controls autoplay loop>
# <source src="https://raw.githubusercontent.com/JuliaDynamics/JuliaDynamics/master/videos/agents/schelling_app.mp4?raw=true" type="video/mp4">
# </video>
# ```

# ## Saving/loading the model state
# It is often useful to save a model after running it, so that multiple branching
# scenarios can be simulated from that point onwards. For example, once most of
# the population is happy, let's see what happens if some more agents occupy the
# empty cells. The new agents could all be of one group, or belong to a third, new, group.
# Simulating this needs multiple copies of the model. Agents.jl provides the
# functions [`AgentsIO.save_checkpoint`](@ref) and [`AgentsIO.load_checkpoint`](@ref)
# to save and load models to JLD2 files respectively.

# First, let's create a model with 200 agents and run it for 40 iterations.
@eval Main __atexample__named__schelling = $(@__MODULE__) # hide

model = initialize(numagents = 200, min_to_be_happy = 5, seed = 42)
run!(model, agent_step!, 40)

figure, _ = abmplot(model; ac = groupcolor, am = groupmarker, as = 10)
figure

# Most of the agents have settled happily. Now, let's save the model.
AgentsIO.save_checkpoint("schelling.jld2", model)

# Note that we can now leave the REPL, and come back later to run the model,
# right from where we left off.
model = AgentsIO.load_checkpoint("schelling.jld2"; scheduler = Schedulers.Randomly())

# Since functions are not saved, the scheduler has to be passed while loading
# the model. Let's now verify that we loaded back exactly what we saved.
figure, _ = abmplot(model; ac = groupcolor, am = groupmarker, as = 10)
figure

# For starters, let's see what happens if we add 100 more agents of group 1
for i in 1:100
    agent = SchellingAgent(nextid(model), (1, 1), false, 1)
    add_agent_single!(agent, model)
end

# Let's see what our model looks like now.
figure, _ = abmplot(model; ac = groupcolor, am = groupmarker, as = 10)
figure

# And then run it for 40 iterations.
run!(model, agent_step!, 40)

figure, _ = abmplot(model; ac = groupcolor, am = groupmarker, as = 10)
figure

# It looks like the agents eventually cluster again. What if the agents are of a new group?
# We can start by loading the model back in from the file, thus resetting the
# changes we made.
model = AgentsIO.load_checkpoint("schelling.jld2"; scheduler = Schedulers.Randomly())

for i in 1:100
    agent = SchellingAgent(nextid(model), (1, 1), false, 3)
    add_agent_single!(agent, model)
end

# To visualize the model, we need to redefine `groupcolor` and `groupmarker`
# to handle a third group.
groupcolor(a) = (:blue, :orange, :green)[a.group]
groupmarker(a) = (:circle, :rect, :cross)[a.group]

figure, _ = abmplot(model; ac = groupcolor, am = groupmarker, as = 10)
figure

# The new agents are scattered randomly, as expected. Now let's run the model.
run!(model, agent_step!, 40)

figure, _ = abmplot(model; ac = groupcolor, am = groupmarker, as = 10)
figure

# The new agents also form their own clusters, despite being completely scattered.
# It's also interesting to note that there is minimal rearrangement among the existing
# groups. The new agents simply occupy the remaining space.

rm("schelling.jld2") # hide

# ## Ensembles and distributed computing

# We can run ensemble simulations and collect the output of every member in a single `DataFrame`.
# To that end we use the [`ensemblerun!`](@ref) function.
# The function accepts a `Vector` of ABMs, each (typically) initialized with a different
# seed and/or agent distribution. For example we can do
models = [initialize(seed = x) for x in rand(UInt8, 3)];

# and then
adf, = ensemblerun!(models, agent_step!, dummystep, 5; adata)
adf[(end - 10):end, :]

# It is possible to run the ensemble in parallel.
# For that, we should start julia with `julia -p n` where `n` is the number
# of processing cores. Alternatively, we can define the number of cores from
# within a Julia session:

# ```julia
# using Distributed
# addprocs(4)
# ```

# For distributed computing to work, all definitions must be preceded with
# `@everywhere`, e.g.

# ```julia
# using Distributed
# @everywhere using Agents
# @everywhere mutable struct SchellingAgent ...
# @everywhere agent_step!(...) = ...
# ```

# Then we can tell the `ensemblerun!` function to run the ensemble in parallel
# using the keyword `parallel = true`:

# ```julia
# adf, = ensemblerun!(models, agent_step!, dummystep, 5; adata, parallel = true)
# ```

# ## Scanning parameter ranges

# We often are interested in the effect of different parameters on the behavior of an
# agent-based model. `Agents.jl` provides the function [`paramscan`](@ref) to automatically explore
# the effect of different parameter values.

# We have already defined our model initialization function as `initialize`.
# We now also define a processing function, that returns the percentage of
# happy agents:

happyperc(moods) = count(moods) / length(moods)
adata = [(:mood, happyperc)]

parameters = Dict(
    :min_to_be_happy => collect(2:5), # expanded
    :numagents => [200, 300],         # expanded
    :griddims => (20, 20),            # not Vector = not expanded
)

adf, _ = paramscan(parameters, initialize; adata, agent_step!, n = 3)
adf

# We nicely see that the larger `:min_to_be_happy` is, the slower the convergence to
# "total happiness".
