
"""
Define your agents to be a subtype of AbstractAgent. Your agent type has to have the following fields: `id`, `pos`

e.g.

```
mutable struct MyAgent <: AbstractAgents
  id::Integer
  pos::Tuple{Integer, Integer, Integer}
end
```

Agents should have an id.
"""
abstract type AbstractAgent end