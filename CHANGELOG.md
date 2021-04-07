# v4.2 (UNRELEASED)
## New features
- Pathfinding using the A* algorithm is now possible!
- Deprecate `aggname` in favor of `dataname` for naming of columns in collection dataframes
- Extend `dataname` (formerly `aggname`) to provide unique column names in collection dataframes when using anonymous functions
- Fixed omission which did not enable updating properties of a model when `model.properties` is a `struct`.
- New function `ensemblerun!` for running ensemble model simulations.

## Deprecated
- Keyword `replicates` of `run!` is deprecated in favor of `ensemblerun!` and will be invalid in a future version.
- `paramscan` with `replicates` is deprecated and will be invalid in a future version.

# v4.1.2
- Plotting with Plots.jl and `plotabm` is deprecated in favor of InteractiveDynamics.jl, Makie.jl and `abm_plot`.

# v4.1
- A new example: Fractal Growth, explores `ContinuousSpace` and interactive plotting.
- Models now supply a random number generator pool that is used in all random-related functions like `random_position`. Access it with `model.rng` and seed it with `seed!(model, seed)`.
- Higher-order agent grouping utilities to facilitate complex interactions, see e.g. `iter_agent_groups`.
- Several documentation improvements targeting newcomers.

# v4.0, Major new release!

This new release brings not only a lot of new features but also a lot of performance improvements and quality of life improvements. Worth seeing is also the new [Comparison](https://juliadynamics.github.io/Agents.jl/dev/comparison/) section of our docs, which compares Agents.jl with other existing software, showing that Agents.jl outmatches all current standards.

## New features:
- `GridSpace` has been re-written from scratch! It now supports **any dimensionality** and is about a **full order of magnitude faster** than the previous version!
- `ContinuousSpace` has been re-written from scratch! It is now at least 3 times faster!
- A new, continuous `OpenStreetMapSpace` which lets agents traverse real world locations via planned routes based on the Open Street Map initiative.
- `GraphSpace` now allows to dynamically mutate the underlying graph via `add_node!`, `rem_node!`.
- Agents.jl now defines a clear API for new spaces types. To create a fundamentally different type of space you have to define the space structure and extend only 5 methods.
- `GraphSpace` and `GridSpace` are completely separated entities, reducing complexity of source code dramatically, and removing unnecessary functions like `vertex2coord` and `coord2vertex`.
- Many things have been renamed to have clearer name that indicates their meaning
  (see Breaking changes).
- Performance increase of finding neighbors in GraphSpace with r > 1.
- New wrapping function `nearby_agents` that returns an iterable of neighboring agents.
- Positions and neighbors on `GridSpace` can now be searched in each direction separately by accepting `r` as a tuple.
- Neighbors on non-periodic chebyshev spaces can also be searched per dimension over a specific range.
- New public `schedule` function for writing custom loops.
- Mixed models are supported in data collection methods.
- `random_agent(model, condition)` allows obtaining random agents that satisfy given condition.
- New `walk!` utility function for `GridSpace` and `ContinuousSpace`s, providing turtle-like agent movement and random walks.
- The Battle Royal example explores using categorical neighbor searching in a high dimensional `GridSpace`.
- An `@agent` macro provides a quick way of creating agent structs for any space.

## Breaking changes
Most changes in this section (besides changes to default values) are deprecated and
therefore are not "truly breaking".

- New `ContinuousSpace` now only supports Euclidean metric.
- Keyword `moore` of `GridSpace` doesn't exist anymore. Use `metric` instead.
- Default arguments for `GridSpace` are now `periodic = true, metric = :chebyshev`.
- Internal structure of the fundamental types like `ABM, GraphSpace`, etc. is now explicitly not part of the public API, and the provided functions like `getindex` and `getproperty` have to be used. This will allow performance updates in the future that may change internals but not lead to breaking changes.
- `vertex2coord, coord2vertex` do not exist anymore because they are unnecessary in the new design.
- API simplification and renaming:
  - `space_neighbors` -> `nearby_ids`
  - `node_neighbors` -> `nearby_positions`
  - `get_node_contents` -> `ids_in_position`
  - `get_node_agents` -> `agents_in_position`
  - `pick_empty` -> `random_empty`
  - `find_empty_nodes` -> `empty_positions`
  - `has_empty_nodes` -> `has_empty_positions`
  - `nodes` -> `positions`

## Non-breaking changes
- `GridSpace` agents now use `Dims` rather than `Tuple{N,Int}` for their `pos`ition in all examples and pre-defined models.

# v3.7
- Add the ability to decide whether the agent step or the model step should be performed first using the `agents_first` argument.
# v3.6
- Add ability to customise `run!` such that mutation on containers and nested structures does not affect data collection.

# v3.5
- Aggregation data for agents is now possible to do conditionally.
- Example on how to integrate Agents.jl with BlackBoxOptim.jl.

# v3.4
- Added interactivity examples for Schelling and Daisyworld.
- Example on how to integrate Agents.jl with DifferentialEquations.jl.
- Dropped support for Julia 1.0, will be targeting LTS for v1.6 in the future.

# v3.3
- New `fill_space!` function for discrete spaces.
- The Daisyworld example now uses multi-agent approach (surface is agent).
- New `allids` function.

# v3.2
- New `Models` submodule, that conveniently allows loading a model from the examples.
# v3.1
- Extend `interacting_pairs` to allow interactions of disparate types when using mixed models.

# v3.0
## Additions
* Added `ContinuousSpace` as a space option. Supports Euclidean and Cityblock metrics. Several new API functions were added for continuous space.
* Universal plotting function `plotabm` that works for models with any kind of space.
* new function `space_neighbors`, which works for any space. It always and consistently returns the **IDs** of neighbors irrespectively of the spatial structure.
* `AgentBasedModel` now allows you to pass in an `AbstractAgent` type, or an instance of your agent.
* New convenience function `allagents`.
* New continuous space functions `nearest_neighbor` and `elastic_collision!`.
* New iterator `interacting_pairs`.
* Agents can be accessed from the model directly. `model[id]` is equivalent with `model.agents[id]` and replaces `id2agent`.
* If `model.properties` is a dictionary with key type Symbol, then the
  convenience syntax `model.prop` returns `model.properties[:prop]`.
* Version of `add_agent!` now has keyword propagation as well (in case you make your types with `@kwdef` or Parameters.jl).
* New function `nextid`
* Cool new logo.
* `node_neighbors` now accepts a `neighbor_type` keyword for working with directed graphs.
* Added examples of flocking birds and bacterial growth in `ContinuousSpace`, daisyworld and predator-prey in `GridSpace`.
- Collection of model and agent data simultaneously is now possible using the `mdata` and `adata` keywords (respectively) used in conjunction with the revamped data collection scheme (see below).
- Better support for mixed-ABMs and a new `by_type` scheduler.

## Breaking Changes
* Deprecated `Space` in favor of the individual spaces: `Nothing, GridSpace, GraphSpace, ContinuousSpace`.
* Reworked the public API of `GridSpace` to be simpler: position must be `NTuple{Int}`. As a result `vertex2coord` and stuff no longer exported, since they are obsolete.
- Data collection has been completely overhauled. The main function to evolve an ABM and collect data is now `run!`. This function serves most situations, however multiple low level functions are exposed via the API for power users. See the Data Collection section in the documentation for full details.
- `AgentBasedModel` checks the construction of your agent and will return errors when it is malformed (no `id` or `pos` when required, incorrect types). Warnings when possible problems may occur (immutable agents, types which are not concrete, `vel` not of the correct type when using `ContinuousSpace`).
- `id2agent` is deprecated in favor of `getindex(model, id) == model[id]`.
* Function `plot2D` doesn't exist any more in favor of `plotabm`.

# v2.1
* Renamed the old scheduler `as_added` to `by_id`, to reflect reality.
* Added a scheduler public API.
* Added two new schedulers: `partial_activation`, `property_activation`.
* It is now possible to `step!` until a boolean condition is met.
# v2.0
Changelog is kept with respect to version 2.0.
