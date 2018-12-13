
# Built-in functions

## Scheduler functions

```@docs
as_added
random_activation
```

## Space functions

```@docs
grid(dims::Tuple{Integer, Integer, Integer}, periodic=false, triangle=false)
gridsize
add_agent_to_grid!
move_agent_on_grid!
add_agent_to_grid_single!
move_agent_on_grid_single!
find_empty_nodes
coord_to_vertex
vertex_to_coord
get_node_contents
id_to_agent
node_neighbors
```

## Model functions

```@docs
nagents
kill_agent!
step!
```