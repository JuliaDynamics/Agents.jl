# v3.0

## Breaking changes
* Deprecated `Space` in favor of the individual spaces: `Nothing, GridSpace, GraphSpace, ContinuousSpace`.
* The `n::Function` argument of `step!` now takes two arguments.
* Reworked the public API of `GridSpace` to be simpler: position must be `NTuple{Int}`. As a result `vertex2coord` and stuff no longer exported, since they are obsolete.
* It is now mandatory to provide a concrete type when initializing an `ABM` (for type stability and performance)

## Additions
* Added `ContinuousSpace` as a space option!!!
* new function `space_neighbors`, which works for any space. It always and consistently returns the **IDs** of neighbors irrespectively
  of the spatial structure.
* `when` of `step!` can now be `true`.

# v2.1
* Renamed the old scheduler `as_added` to `by_id`, to reflect reality.
* Added a scheduler public API.
* Added two new schedulers: `partial_activation`, `property_activation`.
* It is now possible to `step!` until a boolean condition is met.
# v2.0
Changelog is kept with respect to version 2.0.
