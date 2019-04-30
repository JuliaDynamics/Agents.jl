
"""
Define your agents to be a subtype of AbstractAgent. Your agent type has to have the following fields: `id`, `pos`

e.g.

```
mutable struct MyAgent <: AbstractAgent
  id::Integer
  pos::Tuple{Integer, Integer, Integer}
end
```

Agents should have an `id` and a `pos` (position) field. If your space is a grid, the position should accept a `Tuple{Integer, Integer, Integer}` or a `Tuple{Integer, Integer}` representing x, y, and optionally z coordinates.
"""
abstract type AbstractAgent end