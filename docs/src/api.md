# API

## Model and space information
```@docs
nagents
has_empty_nodes
fid_empty_nodes
node_neighbors
nv(::ABM)
ne(::ABM)
```

## Content from a node
```@docs
node_neighbors
pick_empty
get_node_contents
```

## Agent information
```@docs
id2agent
```

## Model-Agent interaction
```@docs
add_agent!
move_agent!
add_agent_single!
move_agent_single!
```

## Iteration
```@docs
NodeIterator
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

## Data collectors

```@docs
combine_columns!
write_to_file
data_collector
```

## Batch runner

```@docs
batchrunner
```

## Visualization functions

```@docs
agents_plots_complete
visualize_data
visualize_2D_agent_distribution
visualize_1DCA
visualize_2DCA
```
