# API

The core API is defined by [`AgentBasedModel`](@ref), [Space](@ref Space), [`AbstractAgent`](@ref) and [`step!`](@ref), which are described in the [Tutorial](@ref) page. The functionality described here builds on top of the core API.

## Agent information and retrieval
```@docs
space_neighbors
random_agent
nagents
allagents
allids
nextid
```

## Model-Agent interaction
The following API is mostly universal across all types of [Space](@ref Space).
Only some specific methods are exclusive to a specific type of space, but we think
this is clear from the documentation strings (if not, please open an issue!).
```@docs
add_agent!
add_agent_pos!
add_agent_single!
move_agent!
move_agent_single!
kill_agent!
genocide!
sample!
```

## Discrete space exclusives
```@docs
fill_space!
node_neighbors
nv(::ABM)
ne(::ABM)
has_empty_nodes
find_empty_nodes
pick_empty
get_node_contents
get_node_agents
isempty(::Integer, ::ABM)
NodeIterator
nodes
coord2vertex
vertex2coord
```

## Continuous space exclusives
```@docs
interacting_pairs
nearest_neighbor
elastic_collision!
index!
update_space!
```

## Data collection
The central simulation function is [`run!`](@ref), which is mentioned in our [Tutorial](@ref).
But there are other functions that are related to simulations listed here.
```@docs
init_agent_dataframe
collect_agent_data!
init_model_dataframe
collect_model_data!
aggname
paramscan
```

For example, the core loop of `run!` is just
```julia
df_agent = init_agent_dataframe(model, adata)
df_model = init_model_dataframe(model, mdata)

s = 0
while until(s, n, model)
  if should_we_collect(s, model, when)
      collect_agent_data!(df_agent, model, adata, s)
  end
  if should_we_collect(s, model, when_model)
      collect_model_data!(df_model, model, mdata, s)
  end
  step!(model, agent_step!, model_step!, 1)
  s += 1
end
return df_agent, df_model
```
(here `until` and `should_we_collect` are internal functions)

## [Schedulers](@id Schedulers)
The schedulers of Agents.jl have a very simple interface.
All schedulers are functions, that take as an input the ABM and return an iterator over agent IDs.
Notice that this iterator can be a "true" iterator (non-allocated) or can be just a standard vector of IDs.
You can define your own scheduler according to this API and use it when making an [`AgentBasedModel`](@ref).

Also notice that you can use [Function-like-objects](https://docs.julialang.org/en/v1.5/manual/methods/#Function-like-objects) to make your scheduling possible of arbitrary events.
For example, imagine that after the `n`-th step of your simulation you want to fundamentally change the order of agents. To achieve this you can define
```julia
mutable struct MyScheduler
    n::Int # step number
    w::Float64
end
```
and then define a calling method for it like so
```julia
function (ms::MyScheduler)(model::ABM)
    ms.n += 1 # increment internal counter by 1 each time its called
              # be careful to use a *new* instance of this scheduler when plotting!
    if ms.n < 10
        return keys(model.agents) # order doesn't matter in this case
    else
        ids = collect(allids(model))
        # filter all ids whose agents have `w` less than some amount
        filter!(id -> model[id].w < ms.w, ids)
        return ids
    end
end
```
and pass it to e.g. `step!` by initializing it
```julia
ms = MyScheduler(100, 0.5)
run!(model, agentstep, modelstep, 100; scheduler = ms)
```

### Predefined schedulers
Some useful schedulers are available below as part of the Agents.jl public API:
```@docs
fastest
by_id
random_activation
partial_activation
property_activation
by_type
```

## Plotting
Plotting functionality comes from `AgentsPlots`, which uses Plots.jl. You need to install both `AgentsPlots`, as well as a plotting backend (we use GR) to use the following functions.

The version of `AgentsPlots` is:
```@example versions
using Pkg
Pkg.status("AgentsPlots")
```

```@docs
plotabm
```
