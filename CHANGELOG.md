# v4.0
**Major new release!**
## New features:
- `GridSpace` has been re-written from scratch! It now supports **any dimensionality** and is about a **full order of magnitude faster** than the previous version!
- Agents.jl now defines a clear API for new spaces types. To create a fundamentally different type of space you have to define the space structure and extend only 5 methods.
- `GraphSpace` and `GridSpace` are completely separated entities, reducing complexity of source code dramatically, and removing unnecessary functions like `vertex2coord` and `coord2vertex`.
- Many things have been renamed to have clearer name that indicates their meaning
  (see Breaking changes).
- `GraphSpace` now allows to dynamically mutate the underlying graph via `add_node!`, `rem_node!`.
- Performance increase of finding neighbors in GraphSpace with r > 1.
- New wrapping function `nearby_agents` that returns an iterable of neighboring agents.

## Breaking changes
All changes in this section (besides changes to default values) are deprecated and
therefore are not "truly breaking".

- Keyword `moore` of `GridSpace` doesn't exist anymore. Use `metric` instead.
- Default arguments for `GridSpace` are now `periodc = false, metric = :chebyshev`.
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
