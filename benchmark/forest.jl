using Agents
using BenchmarkTools
using Random

# Define new space model
mutable struct Tree <: AbstractAgent
    id::Int
    pos::Tuple{Int,Int}
    status::Bool  # true is green and false is burning
end
function forest_fire_array(; f = 0.02, d = 0.9, p = 0.01,
    griddims = (20, 20), seed = 111, periodic = true, metric = :chebyshev)
    Random.seed!(seed)
    space = GridSpace(griddims; periodic, metric)
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
        ids = ids_in_position(pos, forest)
        ## the position is empty, maybe a tree grows here
        if length(ids) == 0
            rand() ≤ forest.p && add_agent!(pos, forest, true)
        else
            tree = forest[ids[1]] # by definition only 1 agent per position
            if tree.status == false  # if it is has been burning, remove it.
                kill_agent!(tree, forest)
            else
                if rand() ≤ forest.f  # the tree ignites spontaneously
                    tree.status = false
                else  # if any neighbor is on fire, set this tree on fire too
                    neighbors = nearby_ids(tree, forest)
                    if any(n -> !(model[n].status), neighbors)
                        tree.status = false
                    end
                end
            end
        end
    end
end

function iterate_over_nearby_ids(a, model)
    s::Int = 0
    for x in nearby_ids(a, model)
        s::Int += x
    end
    return s
end
function iterate_over_nearby_ids2(aa::Vector, model)
    s::Int = 0
    for a in aa
    for x in nearby_ids(a, model)
        s::Int += x
    end
    end
    return s
end

# %% ARRAY VERSION
println("\n\nTimes of NEW grid")
println("Full model stepping")
@btime step!($model, $agent_step!, $model_step!, 500) setup=((model, agent_step!, model_step!) = forest_fire_array())

(model, agent_step!, model_step!) = forest_fire_array(;periodic=false, metric=:chebyshev)
step!(model, agent_step!, model_step!, 1)
a = random_agent(model)
aa = [random_agent(model) for i in 1:100]
sleep(1e-9)

println("Nearby Agents")
@btime nearby_ids($a, $model);
println("Iterate over nearby agents")
@btime iterate_over_nearby_ids($a, $model);
println("Iterate over nearby agents with position")
@btime iterate_over_nearby_ids($a.pos, $model);
println("Iterate over nearby agents2")
@btime iterate_over_nearby_ids2($aa, $model);
println("nearby positions")
@btime nearby_positions($a.pos, $model);


println("Move agent")
@btime move_agent!($a, $model);
println("Move agent single")
@btime move_agent_single!($a, $model);
println("Add agent")
@btime add_agent!($model, true)
