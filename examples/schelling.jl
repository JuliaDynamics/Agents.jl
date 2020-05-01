# # Schelling's segregation model

# ![](schelling.gif)

# In this introductory example we demonstrate Agents.jl's architecture and
# features through building
# the following definition of Schelling's segregation model:

# * Agents belong to one of two groups (0 or 1).
# * The agents live in a two-dimensional Moore grid (8 neighbors per node).
# * If an agent is in the same group with at least three neighbors, then it is happy.
# * If an agent is unhappy, it keeps moving to new locations until it is happy.

# Schelling's model shows that even small preferences of agents to have neighbors
# belonging to the same group (e.g. preferring that at least 30% of neighbors to
# be in the same group) could lead to total segregation of neighborhoods.

# ## Defining the agent type

using Agents, AgentsPlots
gr() # hide

mutable struct SchellingAgent <: AbstractAgent
    id::Int # The identifier number of the agent
    pos::Tuple{Int,Int} # The x, y location of the agent on a 2D grid
    mood::Bool # whether the agent is happy in its node. (true = happy)
    group::Int # The group of the agent,  determines mood as it interacts with neighbors
end

# Notice that the position of this Agent type is a `Tuple{Int,Int}` because
# we will use a `GridSpace`.

# We added two more fields for this model, namely a `mood` field which will
# store `true` for a happy agent and `false` for an unhappy one, and an `group`
# field which stores `0` or `1` representing two groups.

# ## Creating a space

# For this example, we will be using a Moore 2D grid, e.g.

space = GridSpace((10, 10), moore = true)

# ## Creating an ABM

# To make our model we follow the instructions of [`AgentBasedModel`](@ref).
# We also want to include a property `min_to_be_happy` in our model, and so we have:

properties = Dict(:min_to_be_happy => 3)
schelling = ABM(SchellingAgent, space; properties = properties)


# Here we used the default scheduler (which is also the fastest one) to create
# the model. We could instead try to activate the agents according to their
# property `:group`, so that all agents of group 1 act first.
# We would then use the scheduler [`property_activation`](@ref) like so:

schelling2 = ABM(
    SchellingAgent,
    space;
    properties = properties,
    scheduler = property_activation(:group),
)

# Notice that `property_activation` accepts an argument and returns a function,
# which is why we didn't just give `property_activation` to `scheduler`.

# ## Creating the ABM through a function

# Here we put the model instantiation in a function so that
# it will be easy to recreate the model and change its parameters.

# In addition, inside this function, we populate the model with some agents.
# We also change the scheduler to [`random_activation`](@ref).
# Because the function is defined based on keywords,
# it will be of further use in [`paramscan`](@ref) below.

function initialize(; numagents = 320, griddims = (20, 20), min_to_be_happy = 3)
    space = GridSpace(griddims, moore = true)
    properties = Dict(:min_to_be_happy => min_to_be_happy)
    model =
        ABM(SchellingAgent, space; properties = properties, scheduler = random_activation)
    ## populate the model with agents, adding equal amount of the two types of agents
    ## at random positions in the model
    for n in 1:numagents
        agent = SchellingAgent(n, (1, 1), false, n < numagents / 2 ? 1 : 2)
        add_agent_single!(agent, model)
    end
    return model
end
nothing # hide

# Notice that the position that an agent is initialized does not matter
# in this example.
# This is because we use [`add_agent_single!`](@ref), which places the agent in a random,
# empty location on the grid, thus updating its position.

# ## Defining a step function

# Finally, we define a _step_ function to determine what happens to an
# agent when activated.

function agent_step!(agent, model)
    agent.mood == true && return # do nothing if already happy
    minhappy = model.min_to_be_happy
    neighbor_cells = node_neighbors(agent, model)
    count_neighbors_same_group = 0
    ## For each neighbor, get group and compare to current agent's group
    ## and increment count_neighbors_same_group as appropriately.
    for neighbor_cell in neighbor_cells
        node_contents = get_node_contents(neighbor_cell, model)
        ## Skip iteration if the node is empty.
        length(node_contents) == 0 && continue
        ## Otherwise, get the first agent in the node...
        agent_id = node_contents[1]
        ## ...and increment count_neighbors_same_group if the neighbor's group is
        ## the same.
        neighbor_agent_group = model[agent_id].group
        if neighbor_agent_group == agent.group
            count_neighbors_same_group += 1
        end
    end
    ## After counting the neighbors, decide whether or not to move the agent.
    ## If count_neighbors_same_group is at least the min_to_be_happy, set the
    ## mood to true. Otherwise, move the agent to a random node.
    if count_neighbors_same_group ≥ minhappy
        agent.mood = true
    else
        move_agent_single!(agent, model)
    end
    return
end
nothing # hide

# For the purpose of this implementation of Schelling's segregation model,
# we only need an agent step function.

# When defining `agent_step!`, we used some of the built-in functions of Agents.jl,
# such as [`node_neighbors`](@ref) that returns the neighboring nodes of the
# node on which the agent resides, [`get_node_contents`](@ref) that returns the
# IDs of the agents on a given node, and [`move_agent_single!`](@ref) which moves
# agents to random empty nodes on the grid. A full list of built-in functions
# and their explanations are available in the [API](@ref) page.

# ## Stepping the model

# Let's initialize the model with 370 agents on a 20 by 20 grid.

model = initialize()

# We can advance the model one step
step!(model, agent_step!)

# Or for three steps
step!(model, agent_step!, 3)

# ## Running the model and collecting data

# We can use the [`run!`](@ref) function with keywords to run the model for
# multiple steps and collect values of our desired fields from every agent
# and put these data in a `DataFrame` object.
# We define vector of `Symbols`
# for the agent fields that we want to collect as data
properties = [:pos, :mood, :group]

model = initialize()
data, _ = run!(model, agent_step!, 5; adata = properties)
data[1:10, :] # print only a few rows

# We could also use functions in `properties`, for example we can define
x(agent) = agent.pos[1]
model = initialize()
properties = [x, :mood, :group]
data, _ = run!(model, agent_step!, 5; adata = properties)
data[1:10, :]

# With the above `properties` vector, we collected all agent's data.
# We can instead collect aggregated data for the agents.
# For example, let's only get the number of happy individuals, and the
# maximum of the "x" (not very interesting, but anyway!)

model = initialize();
properties = [(:mood, sum), (x, maximum)]
data, _ = run!(model, agent_step!, 5; adata = properties)
data

# Other examples in the documentation are more realistic, with a much more meaningful
# collected data. Don't forget to use the function [`aggname`](@ref) to access the
# columns of the resulting dataframe by name.

# ## Visualizing the data

# We can use the [`plotabm`](@ref) function to plot the distribution of agents on a
# 2D grid at every generation, via the
# [AgentsPlots](https://github.com/JuliaDynamics/AgentsPlots.jl) package.
# Let's color the two groups orange and blue and make one a square and the other a circle.
groupcolor(a) = a.group == 1 ? :blue : :orange
groupmarker(a) = a.group == 1 ? :circle : :square
plotabm(model; ac = groupcolor, am = groupmarker, as = 4)

# ## Animating the evolution

# The function [`plotabm`](@ref) can be used to make your own animations
cd(@__DIR__) #src
model = initialize();
anim = @animate for i in 0:10
    p1 = plotabm(model; ac = groupcolor, am = groupmarker, as = 4)
    title!(p1, "step $(i)")
    step!(model, agent_step!, 1)
end

gif(anim, "schelling.gif", fps = 2)

# ## Replicates and parallel computing

# We can run replicates of a simulation and collect all of them in a single `DataFrame`.
# To that end, we only need to specify `replicates` in the `run!` function:

model = initialize(numagents = 370, griddims = (20, 20), min_to_be_happy = 3)
data, _ = run!(model, agent_step!, 5; adata = properties, replicates = 3)
data[(end - 10):end, :]

# It is possible to run the replicates in parallel.
# For that, we should start julia with `julia -p n` where is the number
# of processing cores. Alternatively, we can define the number of cores from
# within a Julia session:

# ```julia
# using Distributed
# addprocs(4)
# ```

# For distributed computing to work, all definitions must be preceded with
# `@everywhere`, e.g.

# ```julia
# @everywhere using Agents
# @everywhere mutable struct SchellingAgent ...
# ```

# Then we can tell the `run!` function to run replicates in parallel:

# ```julia
# data, _ = run!(model, agent_step!, 2, adata=properties,
#                replicates=5, parallel=true)
# ```

# ## Scanning parameter ranges

# We often are interested in the effect of different parameters on the behavior of an
# agent-based model. `Agents.jl` provides the function [`paramscan`](@ref) to automatically explore
# the effect of different parameter values.

# We have already defined our model initialization function as `initialize`.
# We now also define a processing function, that returns the percentage of
# happy agents:

happyperc(moods) = count(x -> x == true, moods) / length(moods)

adata = [(:mood, happyperc)]
parameters =
    Dict(:min_to_be_happy => collect(2:5), :numagents => [200, 300], :griddims => (20, 20))

data, _ = paramscan(parameters, initialize; adata = adata, n = 3, agent_step! = agent_step!)
data

# `paramscan` also allows running replicates per parameter setting:

data, _ = paramscan(
    parameters,
    initialize;
    adata = adata,
    n = 3,
    agent_step! = agent_step!,
    replicates = 3,
)

data[(end - 10):end, :]

# We can combine all replicates with an aggregating function, such as mean, using
# the `aggregate` function from the `DataFrames` package:

using DataFrames: aggregate, Not, select!
using Statistics: mean
data_mean = aggregate(data, [:step, :min_to_be_happy, :numagents], mean)
select!(data_mean, Not(:replicate_mean))

# Note that the second argument takes the column names on which to split the data,
# i.e., it denotes which columns should not be aggregated. It should include
# the `:step` column and any parameter that changes among simulations. But it should
# not include the `:replicate` column.
# So in principle what we are doing here is simply averaging our result across the replicates.

