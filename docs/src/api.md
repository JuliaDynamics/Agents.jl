# API

The core API is defined by [`AgentBasedModel`](@ref), [`Space`](@ref), [`AbstractAgent`](@ref) and [`step!`](@ref), which are described in the [Tutorial](@ref) page. The functionality described here builds on top of the core API.

## Model and space information
```@docs
nv(::ABM)
ne(::ABM)
has_empty_nodes
find_empty_nodes
```

## Content from a node
```@docs
node_neighbors
pick_empty
get_node_contents
isempty(::Integer, ::ABM)
```

## Agent information and retrieval
```@docs
nagents
id2agent
random_agent
```

## Model-Agent interaction
```@docs
add_agent!
add_agent_pos!
add_agent_single!
move_agent!
move_agent_single!
kill_agent!
genocide!
```

## Simulations
The central simulation function is [`step!`](@ref), which is mentioned in our [Tutorial](@ref).
But there are other functions that are related to simulations listed here.
```@docs
paramscan
sample!
```

## Iteration
```@docs
NodeIterator
nodes
```

## Schedulers
The schedulers of Agents.jl have a very simple interface. All schedulers are functions,
that take as an input the ABM and return an iterator over agent IDs.
Notice that this iterator can be a "true" iterator or can be just a standard vector of IDs.
You can define your own scheduler according to this API and use it when making an [`AgentBasedModel`](@ref).
```@docs
fastest
by_id
random_activation
partial_activation
property_activation
```

## Utilities

```@docs
coord2vertex
vertex2coord
```

## Parallelization

```@docs
parallel_replicates
```

## Plotting
Plotting functionality comes from `AgentsPlots`, which uses Plots.jl. You need to install both `AgentsPlots`, as well as a plotting backend (we use GR) to use the following functions.

```@docs
plot2D
plot_CA1D
plot_CA2D
plot_CA2Dgif
```
