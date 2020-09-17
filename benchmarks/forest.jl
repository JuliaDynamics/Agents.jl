using Agents
using BenchmarkTools
using Random

# Define new space model
mutable struct Tree <: AbstractAgent
    id::Int
    pos::Tuple{Int,Int}
    status::Bool  # true is green and false is burning
end
function forest_fire_array(; f = 0.02, d = 0.8, p = 0.01, griddims = (100, 100), seed = 111)
    Random.seed!(seed)
    space = ArraySpace(griddims, true)
    properties = Dict(:f => f, :d => d, :p => p)
    forest = AgentBasedModel(Tree, space; properties = properties)

    ## create and add trees to each pos with probability d,
    ## which determines the density of the forest
    for pos in positions(forest)
        if rand() ≤ forest.d
            add_agent!(pos, forest, true)
        end
    end
    return forest, dummystep, forest_model_step_array!
end

function forest_model_step_array!(forest)
    for pos in positions(forest, :random)
        nc = get_node_contents(pos, forest)
        ## the cell is empty, maybe a tree grows here
        if length(nc) == 0
            rand() ≤ forest.p && add_agent!(pos, forest, true)
        else
            tree = forest[nc[1]] # by definition only 1 agent per pos
            if tree.status == false  # if it is has been burning, remove it.
                kill_agent!(tree, forest)
            else
                if rand() ≤ forest.f  # the tree ignites spontaneously
                    tree.status = false
                else  # if any neighbor is on fire, set this tree on fire too
                    neighbors = space_neighbors(tree, forest)
                    if any(n -> !(model[n].status), neighbors)
                        tree.status = false
                    end
                end
            end
        end
    end
end


# %%
println("Times of old grid")

# println("Standard stepping")
# @btime step!(model, agent_step!, model_step!, 500) setup=((model, agent_step!, model_step!) = Models.forest_fire())

model, agent_step!, model_step! = Models.forest_fire()
a = random_agent(model)

sleep(1e-9)

println("Move agent")
@btime move_agent!($a, $model);

println("Space neighbors")
@btime space_neighbors($a, $model);

println("node neighbors")
@btime node_neighbors($a.pos, $model);

println("Add agent")
@btime add_agent!($model, true)


# %% ARRAY VERSION
println("Times of new grid")

(model, agent_step!, model_step!) = forest_fire_array()
step!(model, agent_step!, model_step!, 10)

# println("Standard stepping")
# @btime step!($model, $agent_step!, $model_step!, 500) setup=((model, agent_step!, model_step!) = forest_fire_array())

(model, agent_step!, model_step!) = forest_fire_array()
a = random_agent(model)
sleep(1e-9)

println("Move agent")
@btime move_agent!($a, $model);

println("node neighbors")
@btime node_neighbors($a.pos, $model);

println("Space neighbors")
@btime space_neighbors($a, $model);

println("Add agent")
@btime add_agent!($model, true)
