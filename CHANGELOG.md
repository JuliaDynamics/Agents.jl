# v3.0
* Added `ContinuousSpace` as a space option!!!
* Deprecated `Space` in favor of the individual spaces: `Nothing, GridSpace, GraphSpace, ContinuousSpace`.
* new function `space_neighbors`, which works for any space. It always and consistently returns the **IDs** of neighbors irrespectively
  of the spatial structure.
* Reworked the public API of `GridSpace` to be simpler: position must be `NTuple{Int}`. As a result `vertex2coord` and stuff no longer exported, since they are obsolete.
* New convenience function `allagents`
* New continuous space functions `nearest_neighbor` and `elastic_collision!`
* New iterator `interacting_pairs`
- `AgentBasedModel` now allows you to pass in an `AbstractAgent` type, or an instance of your agent.
- `AgentBasedModel` checks the construction of your agent and will return errors when it is malformed (no `id` or `pos` when required, incorrect types). Warnings when possible problems may occur (immutable agents, types which are not concrete, `vel` not of the correct type when using `ContinuousSpace`).
- Warnings produced by `AgentBasedModel` may be suppressed via the boolean flag `warn`.
* Version of `add_agent!` now has keyword propagation as well (in case you make your types with `@kwdef` or Parameters.jl)

# v2.1
* Renamed the old scheduler `as_added` to `by_id`, to reflect reality.
* Added a scheduler public API.
* Added two new schedulers: `partial_activation`, `property_activation`.
* It is now possible to `step!` until a boolean condition is met.
# v2.0
Changelog is kept with respect to version 2.0.
