# # Conway's game of life

# ```@raw html
# <video width="auto" controls autoplay loop>
# <source src="../game of life.mp4" type="video/mp4">
# </video>
# ```

# [Game of life on wikipedia](https://en.wikipedia.org/wiki/Conway%27s_Game_of_Life).

# It is also available from the `Models` module as [`Models.game_of_life`](@ref).

using Agents, Random

# ## 1. Define the rules

# Conway's game of life is a *cellular automaton*, where each cell of the discrete space
# contains one agent only.

# The rules of Conway's game of life are defined based on four numbers:
# Death, Survival, Reproduction, Overpopulation, grouped as (D, S, R, O)
# Cells die if the number of their living neighbors is <D or >O,
# survive if the number of their living neighbors is ≤S,
# come to life if their living neighbors are  ≥R and ≤O.
rules = (2, 3, 3, 3) # (D, S, R, O)
nothing # hide

# ## 2. Build the model

# First, define an agent type. It needs to have the compulsary `id` and `pos` fields,
# as well as a `status` field that is `true` for cells that are alive and `false` otherwise.

mutable struct Cell <: AbstractAgent
    id::Int
    pos::Dims{2}
    status::Bool
end

# The following function builds a 2D cellular automaton given some `rules`.
# `dims` is a tuple of integers determining the width and height of the grid environment.
# `metric` specifies how to measure distances in the space, and in our example
# it actually decides whether cells connect to their diagonal neighbors.

# This function creates a model where all cells are dead.
function build_model(; rules::Tuple, dims = (100, 100), metric = :chebyshev, seed = 120)
    space = GridSpace(dims; metric)
    properties = Dict(:rules => rules)
    model = ABM(Cell, space; properties, rng = MersenneTwister(seed))
    idx = 1
    for x in 1:dims[1]
        for y in 1:dims[2]
            add_agent_pos!(Cell(idx, (x, y), false), model)
            idx += 1
        end
    end
    return model
end
nothing # hide

# Now we define a stepping function for the model to apply the rules to agents.
# We will also perform a synchronous agent update (meaning that the value of all
# agents changes after we have decided the new value for each agent individually).
function ca_step!(model)
    new_status = fill(false, nagents(model))
    for agent in allagents(model)
        n = alive_neighbors(agent, model)
        if agent.status == true && (n ≤ model.rules[4] && n ≥ model.rules[1])
            new_status[agent.id] = true
        elseif agent.status == false && (n ≥ model.rules[3] && n ≤ model.rules[4])
            new_status[agent.id] = true
        end
    end

    for id in allids(model)
        model[id].status = new_status[id]
    end
end

function alive_neighbors(agent, model) # count alive neighboring cells
    c = 0
    for n in nearby_agents(agent, model)
        if n.status == true
            c += 1
        end
    end
    return c
end
nothing # hide

# now we can instantiate the model:
model = build_model(rules = rules, dims = (50, 50))

# Let's make some random cells on
for i in 1:nagents(model)
    if rand(model.rng) < 0.2
        model.agents[i].status = true
    end
end

# ## 3. Animate the model

# We use the [`InteractiveDynamics.abm_video`](@ref) for creating an animation and saving it to an mp4

using InteractiveDynamics
import CairoMakie

ac(x) = x.status == true ? :black : :white
am(x) = x.status == true ? '■' : '□'
abm_video(
    "game of life.mp4",
    model,
    dummystep,
    ca_step!;
    title = "Game of Life",
    ac = :black,
    as = 12,
    am,
    framerate = 5,
)
nothing # hide
# ```@raw html
# <video width="auto" controls autoplay loop>
# <source src="../game of life.mp4" type="video/mp4">
# </video>
# ```
