# API

The API of Agents.jl is defined on top of the fundamental structures  [`AgentBasedModel`](@ref), [Space](@ref Space), [`AbstractAgent`](@ref) which are described in the [Tutorial](@ref) page.
In this page we list the remaining API functions, which constitute the bulk of Agents.jl functionality.

## `@agent` macro
The [`@agent`](@ref) macro makes defining agent types within Agents.jl simple.

```@docs
@agent
GraphAgent
GridAgent
ContinuousAgent
OSMAgent
```

## Agent/model retrieval and access
```@docs
getindex(::ABM, ::Integer)
getproperty(::ABM, ::Symbol)
seed!
random_agent
nagents
allagents
allids
```

## Available spaces
Here we list the spaces that are available "out of the box" from Agents.jl. To create your own, see [Creating a new space type](@ref).

### Discrete spaces
```@docs
GraphSpace
GridSpace
```

### Continuous spaces
```@docs
ContinuousSpace
OpenStreetMapSpace
```

## Model-agent interaction
The following API is mostly universal across all types of [Space](@ref Space).
Only some specific methods are exclusive to a specific type of space, but these are described further below in this page.

### Adding agents
```@docs
add_agent!
add_agent_pos!
nextid
random_position
```

### Moving agents
```@docs
move_agent!
walk!
```

### Removing agents
```@docs
kill_agent!
genocide!
sample!
```

## Discrete space exclusives
```@docs
positions
ids_in_position
agents_in_position
fill_space!
has_empty_positions
empty_positions
random_empty
add_agent_single!
move_agent_single!
isempty(::Integer, ::ABM)
```

## Continuous space exclusives
```@docs
interacting_pairs
nearest_neighbor
elastic_collision!
```

## OpenStreetMap space exclusives
```@docs
osm_latlon
osm_intersection
osm_road
osm_random_road_position
osm_plan_route
osm_random_route!
osm_road_length
osm_is_stationary
osm_map_coordinates
```

## Graph space exclusives
```@docs
add_edge!
add_node!
rem_node!
```

## Movement with paths
For [`OpenStreetMapSpace`](@ref), and [`GridSpace`](@ref)s using [`Pathfinder`](@ref), a special
movement method is available.

```@docs
move_along_route!
```

## Local area
```@docs
nearby_ids
nearby_agents
nearby_positions
edistance
```

## A note on iteration

Most iteration in Agents.jl is **dynamic** and **lazy**, when possible, for performance reasons.

**Dynamic** means that when iterating over the result of e.g. the [`ids_in_position`](@ref) function, the iterator will be affected by actions that would alter its contents.
Specifically, imagine the scenario
```@example docs
using Agents
mutable struct Agent <: AbstractAgent
    id::Int
    pos::NTuple{4, Int}
end

model = ABM(Agent, GridSpace((5, 5, 5, 5)))
add_agent!((1, 1, 1, 1), model)
add_agent!((1, 1, 1, 1), model)
add_agent!((2, 1, 1, 1), model)
for id in ids_in_position((1, 1, 1, 1), model)
    kill_agent!(id, model)
end
collect(allids(model))
```
You will notice that only 1 agent got killed. This is simply because the final state of the iteration of `ids_in_position` was reached unnaturally, because the length of its output was reduced by 1 *during* iteration.
To avoid problems like these, you need to `collect` the iterator to have a non dynamic version.

**Lazy** means that when possible the outputs of the iteration are not collected and instead are generated on the fly.
A good example to illustrate this is [`nearby_ids`](@ref), where doing something like
```julia
a = random_agent(model)
sort!(nearby_ids(random_agent(model), model))
```
leads to error, since you cannot `sort!` the returned iterator. This can be easily solved by adding a `collect` in between:
```@example docs
a = random_agent(model)
sort!(collect(nearby_agents(a, model)))
```

## Higher-order interactions

There may be times when pair-wise, triplet-wise or higher interactions need to be
accounted for across most or all of the model's agent population. The following methods
provide an interface for such calculation.

These methods follow the conventions outlined above in [A note on iteration](@ref).

```@docs
iter_agent_groups
map_agent_groups
index_mapped_groups
```


## Parameter scanning
```@docs
paramscan
```

## Data collection
The central simulation function is [`run!`](@ref), which is mentioned in our [Tutorial](@ref).
But there are other functions that are related to simulations listed here.
Specifically, these functions aid in making custom data collection loops, instead of using the `run!` function.

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

`run!` uses the following functions:

```@docs
init_agent_dataframe
collect_agent_data!
init_model_dataframe
collect_model_data!
aggname
```

## [Schedulers](@id Schedulers)
The schedulers of Agents.jl have a very simple interface.
All schedulers are functions, that take as an input the ABM and return an iterator over agent IDs.
Notice that this iterator can be a "true" iterator (non-allocated) or can be just a standard vector of IDs.
You can define your own scheduler according to this API and use it when making an [`AgentBasedModel`](@ref).
You can also use the function `schedule(model)` to obtain the scheduled ID list, if you prefer to write your own `step!`-like loop.

Notice that schedulers can be given directly to model creation, and thus become the "default" scheduler a model uses, but they can just as easily be incorporated in a `model_step!` function as shown in [Advanced stepping](@ref).


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

### Advanced scheduling
You can use [Function-like-objects](https://docs.julialang.org/en/v1.5/manual/methods/#Function-like-objects) to make your scheduling possible of arbitrary events.
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
        return allids(model) # order doesn't matter in this case
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
step!(model, agentstep, modelstep, 100; scheduler = ms)
```

## Path-finding
In addition to the direct movement functions listed above, [`GridSpace`](@ref) has the additional benefit of path planning.

You can enable path-finding and set it's options by passing an instance of a [`Pathfinder`](@ref) struct to the `pathfinder`
parameter of the [`GridSpace`](@ref) constructor. During the simulation, call [`set_target!`](@ref) to set the target
destination for an agent. This triggers the algorithm to calculate a path from the agent's current position to the one
specified. You can alternatively use [`set_best_target!`](@ref) to choose the best target from a list. Once a target has
been set, you can move an agent one step along its precalculated path using the [`move_along_route!`](@ref) function.
Refer to the [Maze Solver](@ref) and [Mountain Runners](@ref) examples for further instruction on how to use the API.
```@docs
Pathfinder
set_target!
set_best_target!
is_stationary
walkmap
heightmap
```

### Metrics
```@docs
DirectDistance
MaxDistance
HeightMap
```

Building a custom metric is straightforward, if the provided ones do not suit your purpose.
See the [Developer Docs](@ref) for details.

