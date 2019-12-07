# API

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
add_agent_single!
move_agent!
move_agent_single!
kill_agent!
```

## Iteration
```@docs
NodeIterator
nodes
```

## Schedulers
```@docs
as_added
random_activation
partial_activation
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
