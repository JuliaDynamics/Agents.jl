# v6 - New Major release!

## Major and/or BREAKING

_We tried to deprecate every major change, resulting in practically no breakage from v5 to v6. However, in version v6.2 we will remove all deprecations (and hence un-updated code will break)_

- Deprecations that were in place in v5 (see section `# v5` of this CHANGELOG) have been removed.
- The way the evolution rule (`agent_step!, model_step!`) is handled has changed. Now, the stepping functions must be given to the agent based model during construction of the model instead of given to `step!, run!, abmplot, ...`. This change is important and allows us to:
  - Have Agents.jl have the same mental model as DifferentialEquations.jl, DynamicalSystems.jl, and other dynamical modelling packages, where the evolution rules are part of the central simulation struct.
  - Allows us to develop new types of models that may have rules that are defined differently, without being based on e.g., two particular functions.
  - Allows us to develop (in the future) a new model type that is optimized for multi-agent simulations.
- The `@agent` macro has been rewritten to support fields with default and const values. It has a new usage syntax now that parallelizes more Julia's native `struct` declaration. The old macro version still works but it's deprecated. Since now the macro supports these features, using `@agent` is the only supported way to create agent types for Agents.jl.
- The `UnremovableABM` type is deprecated, instead `container = Vector` should be passed when creating the model.
- The `step` argument is not needed anymore when using `collect_model_data!, collect_agent_data!` since the time of the
model is used automatically.
- Manually setting or altering the ids of agents is no longer allowed. The agent id is now considered a read-only field, and is set internally by Agents.jl to enable hidden optimizations in the future. Due to this, the `nextid` function is no longer public API. As a consequence, new constructor of agents which accept the model as first argument have been created with the agent macro e.g. `A(model, pos)`, so that to handle the id assignment automatically.
- `add_agent_pos!` has been deprecated in favor of the more descriptive `add_agent_own_pos!`.
- Agent types in `ContinuousSpace` now use `SVector` for their `pos` and `vel` fields rather than `NTuple`. `NTuple` usage in `ContinuousSpace` is officially deprecated, but backward compatibility is *mostly* maintained. Known breakages include the comparison of agent position and/or velocity with user-defined tuples, e.g., doing `agent.pos == (0.5, 0.5)`. This will always be `false` in v6 as `agent.pos` is an `SVector`. The rest of the functionality should all work without problems, such as moving agents to tuple-based positions etc.

## New features

- Grid and continuous spaces support boundaries with mixed periodicity, specified by tuples with a `Bool` value for each dimension, e.g. `GridSpace((5,5); periodic=(true,false))` is periodic along the first dimension but not along the second.
- Two new functions `random_id_in_position` and `random_agent_in_position` can be used to select a random id/agent in a position in discrete spaces (even with filtering).
- A new function `swap_agents` can be used to swap an agents couple in a discrete space.
- The model time/step is tracked automatically, accessible through `abmtime(model)`.

## Performance Improvements

- A new argument `alloc` can be used to select a more performant version in relation to the expensiveness of the filtering for all random methods selecting ids/agents/positions.
- The `random_agent` function is now much faster than before. The functions `random_nearby_position`, `random_nearby_id` and `random_nearby_agent` are up to 2 times faster thanks to a faster sampling function.
- The `nearby_agents` function for `ContinuousSpace` and `GridSpace` is now 1.5x faster than before.
- The `sample!` function is much faster than before.


# v5.17

- New function `replicate!` allows to create a new instance of a given agent at the same position with the possibility to specify some
  fields with new values.
- The `sample!` function is 3x faster than before.

# v5.16

- New function `offline_run!` allows writing data to file at predefined intervals during `run!` instead of storing it in memory. Currently supports [CSV](https://csv.juliadata.org/stable/) and [Arrow](https://apache.github.io/arrow-julia/stable/) files.

# v5.15
- Agents.jl moved to Julia 1.9+, and now exports visualization
  and interactive applications automatically once Makie (or Makie backends
  such as GLMakie) come into scope, using the new package extension system.
  The only downside of this is that now to visualize ABMs on open street
  maps, the package OSMMakie.jl must be explicitly loaded as well.
- Nearby look-ups with `nearby_positions`, `nearby_ids` and derivatives are now incrementally faster than before more the radius increases.
- The `randomwalk!` function is now supported for any number of dimensions in ContinuousSpace when used to create isotropic/uniform random walks. For all type of `AbstractGridSpace`, the `randomwalk!` function supports a new keyword `force_motion`, which is false by default. See the docs to be informed on the effect of setting this keyword. Besides, in the continuous space default case random walks are up to 2 times faster than before.
- Adding agents through `properties...` is an order of magnitude faster, now matching the performance of the other versions.
- The `ByProperty` scheduler can now accept any type of (ordered) properties, while before it was restricted to only floats. The `ByID` scheduler of an `UnremovableABM` is now as fast as the `Fastest` scheduler since in this case they are actually equivalent.

# v5.14

- New optional filtering functionality to restrict the sampling added to `random_nearby_position`, `random_nearby_id` and `random_nearby_agent`.

# v5.13

- `random_nearby_position`, `random_nearby_id` and `random_nearby_agent` are up to 2 times faster thanks to a faster sampling function.

# v5.12

- The `random_nearby_position` function is now much faster for GridSpaces.

# v5.11

- Iterating in neighborhood searches (with `nearby_ids` and derivative functions) in `GridSpace` and `ContinuousSpace` is now about 2 times faster than before.

# v5.10

- `FixedMassABM` is now deprecated and will be removed in future versions. Turns out, there is no performance benefit of using it over `UnremovableABM`. In fact, there is a performance **deficit** in doing so.

# v5.9

- `sample!` is now much faster than before when the size of the sample is big, with a size of 1 million agents the function is now 1000x faster.
- A memory bug about offsets calculation has been solved; besides, the `calculate_offsets` function has been sped-up by a significant amount.
- The following renames have been done (with deprecations):
  - `genocide! -> remove_all!`
  - `kill_agent! -> remove_agent!`
  - `UnkillableABM -> UnremovableABM`
- New function `random_nearby_position` that returns a random neighbouring position.
- New function `empty_nearby_positions` that returns an iterable of all empty neighboring positions.

# v5.8
- `random_agent` is now faster and has two options on how to find a random agent, each of which can offer a different performance benefit depending on the density of agents that satisfy the clause.
- New function `randomwalk!` replaces `walk!(agent, rand, model)` (now deprecated), allowing easier creation of random walks in both discrete and continuous spaces. Random walks in continuous space also allow users to specify the reorientation distributions: `polar` in 2D; `polar` and `azimuthal` in 3D. This way, correlated random walks can be produced.
- Thanks to the use of a new algorithm, the `nearby_positions` function for graphspaces is now much faster.
- Huge improvement of performance of the `get_direction` function in the periodic case.
- `normalize_position` is now 50x faster for the case of a non-periodic grid.

# v5.7
- Internals of `AgentBasedModel` got reworked. It is now an abstract type, defining an abstract interface that concrete implementations may satisfy. This paves the way for flexibly defining new variants of `AgentBasedModel` that are more specialized in their applications.
- The old `AgentBasedModel` is now `StandardABM`.
- Two new variants of agent based models: `UnkillableABM` and `FixedMassABM`: they yield huge performance benefits (up to twice the speed!!!) on iterating over agents if the agents can't get killed, or even added, during model evolution!
- Huge memory performance increase in continuous space by fixing a memory leak bug.
- `multi_agents_type!` has been updated to handle edge case where agents of one (or more) type are absent at the beginning of the simulation.
- New function `npositions` that returns the number of positions of a model with a discrete space.

# v5.6
- `add_node!` and `rem_node!` have been renamed to `add_vertex!` and `rem_vertex!` extending Graphs.jl homonymous methods to help standardise names across ecosystems. Therefore `add_node!` and `rem_node!` have been deprecated.
- The signature of `add_edge!` has been generalised with `args...` and `kwargs...` to be compatible with all the implementations the underlying graph supports.
- New function `rem_edge!` that removes an edge from the graph.

# v5.5
- The `@agent` macro has been re-written and is now more general and more safe.
  It now also allows inheriting fields from any other type.
- The `@agent` macro is now THE way to create agent types for Agents.jl simulations.
  Directly creating structs by hand is no longer mentioned in the documentation at all. This will allow us in the future to utilize additional fields that the user does not have to know about, which may bring new features or performance gains by being part of the agent structures.
  - EDIT: This has been _retracted_ in future versions. `@agent` is the recommended way, but manual creation is also valid.
- The minimal agent types like `GraphAgent` can be used normally as standard agent
  types that only have the mandatory fields. This is now clear in the docs.
  (this was possible also before v5.4, just not clear)
- In the future, making agent types manually (without `@agent`) may be completely disallowed, resulting in error. Therefore, making agent types manually is considered deprecated.
- New function `normalize_position` that normalizes a position according to the model space.
- New function `spacesize` that returns the size of the space.

# v5.4
This is a huge release!

## Performance improvements
- Internal representation of grid spaces has been completely overhauled. For `GridSpace` this lead to about 30% performance increase in `nearby_stuff` and 100% decrease in memory allocations.
- Significant performance increase for `nearest_neighbor` in `ContinuousSpace`.
- Because of the new grid spaces internals, `nearby_stuff` searches in `ContinuousSpace` are 2-5 times faster.
- Much more efficient distributed computing in `ensemblerun!` and `paramscan` functions, like 5x performance gain. Thanks to user Matt Turner `mt-digital`. [#624](https://github.com/JuliaDynamics/Agents.jl/pull/624)

## New space
- New space `GridSpaceSingle` that is the same as `GridSpace` but only allows for one agent per position only. It utilizes this knowledge for massive performance benefits over `GridSpace`, **being about 3x faster than the new `GridSpace`**, all across the board. ID = 0 is a reserved ID for this space and cannot be used by users.

## Additions to existing API
- New keyword `showprogress` in `run!` function that displays a progress bar.
- New keyword `showprogress` in `ensemblerun!` and `paramscan` that displays a progress bar over total amount of simulations done.
- New function `OSM.route_length`.
- New `:manhattan` metric for `GridSpace` models.
- New `manhattan_distance` utility function.
- New keyword `nearby_f = nearby_ids_exact` in `interacting_pairs` which decides whether to use the exact or approximate algorithm for nearest neighbors.

## Breaking or Deprecated
- [**Will be breaking**] In the near future, **agent ID = 0 will be a reserved ID by Agents.jl**. This means that users should not use ID = 0 for _any agent_. They can use all the negative and positive integers as usual. If you were adding agents with any of the default ways that Agents.jl provides, such as `add_agents!(pos, model, agent_properties...)`, then you were already using only the positive integers.
- [**Maybe breaking?**] In `ContinuousSpace` `spacing` was documented to be a keyword but in code it was specified as a positional argument. Now it is also a keyword in code as intended.
- [**Maybe breaking?**] Keyword `spacing` in `ContinuousSpace` is now `minimum(extent)/20` from `/10`
  by default, increasing accuracy of `nearby_ids` (which is the fastest way to iterate over neighbors). This decreases a bit the performance of `move_agent!`, but in the typical scenario a neighbor search is much more costly than moving an agent.
- [**Maybe breaking?**] There was an ambiguity in the function `move_agent!(agent, model)`. It typically means to move an agent to a random position. However, in `ContinuousSpace` this function was overwritten by the signature `move_agent(agent, model, dt::Real = 1)`. To resolve the ambiguity, now `move_agent!(agent, model)` **always moves the agent to a random position** even in `ContinuousSpace`. To use the continuous space version that moves an agent using its velocity, users must explicitly provide the third argument `dt`.
- [**Will be breaking**] Keyword `exact` in `nearby_ids` for `ContinuousSpace` is deprecated, because now the exact version returns different type than the non-exact, hence leading to type instabilities. Use `nearby_ids_exact` instead. Same for `nearby_agents`.

# v5.3
- Rework schedulers to prefer returning iterators over arrays, resulting in fewer allocations and improved performance. Most scheduler names are now types instead of functions:
  - `Schedulers.by_id` is now `Schedulers.ByID`
  - `Schedulers.randomly` is now `Schedulers.Randomly`
  - `Schedulers.partially` is now `Schedulers.Partially`
  - `Schedulers.by_property` is now `Schedulers.ByProperty`
  - `Schedulers.by_type` is now `Schedulers.ByType`

# v5.2
- Add `random_nearby_id` and `random_nearby_agent` for efficient random agent access
- Stop condition for `step!` allows using `Integer`s

# v5
- Agents.jl + InteractiveDynamics.jl now support native plotting for
  open street map spaces, which is integrated in all interactive apps as well!
- Most examples have been moved to AgentsExampleZoo.jl. Additional examples will now be added there.

## BREAKING
- Plotting, animating, and interacting GUIs based on InteractiveDynamics.jl have changed. Please see online docs for the new format.
- LightGraphs.jl dependency is now replaced by Graphs.jl
- OpenStreetMapX.jl dependency now replaced by LightOSM.jl. This mean initializing the space is different, and some API methods have changed. Check documentation for more details. Note that this also means checkpoints using the old `OpenStreetMapSpace` cannot be read in this version.
- Functions for planning and moving along routes have had their names unified across Pathfinding and OpenStreetMap modules. The names now are `plan_route!` and `move_along_route!` and are accessible from the top level scope.
- `OSM.intersection` is renamed to `OSM.nearest_node`
- `OSM.road` is renamed to `OSM.nearest_road`
- `latlon` is removed in favor of `OSM.lonlat`

# v4.5.4
- Previously `nearby_ids` with `r=0` for `GraphSpace` was undefined. Now it returns ids only in the same position as given.

# v4.5.3
- Performance enhancements for `random_empty`.

# v4.5
## New features and fixes
- Add `get_spatial_property` and `get_spatial_index` for easier usage of spatially distributed properties in `ContinuousSpace`.
- Rework the pathfinding system to be more streamlined and offer greater control over the its details.
- Add support for pathfinding in `ContinuousSpace`.
- New utility functions `nearby_walkable` and `random_walkable` for use in models with pathfinding.
- Fixed bug where there was no differentiation between empty paths and paths to unreachable nodes.

## BREAKING
- The old pathfinding system is now deprecated. Pathfinding structs are not saved as part of the
  space, and instead are stored by the user.

# v4.4
## New features and fixes
- Provide a generator function to collect `mdata` in `run!` and `ensemblerun!`.
- Save/load entire models using `save_checkpoint` and `load_checkpoint`
- New functions `get_spatial_property` and `get_spatial_index` that allows better handling of spatial fields present in `ContinuousSpace` that are represented via the forms of discretization over the space.

# v4.3
## New features and fixes
- Save and load agent information from CSV files.

# v4.2
## New features and fixes
- Self-contained features of Agents.jl will from now own exist in their own submodules. This will make the public API less cluttered and functionality more contained. Currently the new submodules are `Schedulers, Pathfinding, OSM`.
- Pathfinding using the A* algorithm is now possible! Available for `GridSpace`.
- Extend `dataname` (formerly `aggname`) to provide unique column names in collection dataframes when using anonymous functions
- Fixed omission which did not enable updating properties of a model when `model.properties` is a `struct`.
- New function `ensemblerun!` for running ensemble model simulations.
- Scheduler `Schedulers.by_property` (previously `property_activation`) now allows as input arbitrary functions besides symbols.

## Deprecated
- Deprecate `aggname` in favor of `dataname` for naming of columns in collection dataframes
- Keyword `replicates` of `run!` is deprecated in favor of `ensemblerun!`.
- `paramscan` with `replicates` is deprecated. If you want to parameter scan and at the same time run multiple simulations at each parameter combination, simply use `seed` as a parameter, which tunes the model's initial random seed.
- All the scheduler names have been deprecated in favor of a `Schedulers` module: `fastest` to `Schedulers.fastest`, `by_id` to `Schedulers.by_id`, `random_activation` to `Schedulers.randomly`, `partial_activation` to `Schedulers.partially`, `property_activation` to `Schedulers.by_property`, `by_type` to `Schedulers.by_type`.

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

