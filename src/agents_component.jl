
"""
Define your agents to be a subtype of AbstractAgent. Your agent type has to have the following fields: `id`, `pos`

e.g.

```
mutable struct MyAgent <: AbstractAgents
  id::Integer
  pos::Tuple{Integer, Integer, Integer}
end
```

Agents should have an `id` and a `pos` (position) field. If your space is a grid, the position should accept a `Tuple{Integer, Integer, Integer}` representing x, y, z coordinates. Your grid does not have to be 3D, and can keep `z=1`.
"""
abstract type AbstractAgent end