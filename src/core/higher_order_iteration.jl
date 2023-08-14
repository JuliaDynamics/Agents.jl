
export iter_agent_groups, map_agent_groups, index_mapped_groups

"""
    iter_agent_groups(order::Int, model::ABM; scheduler = Schedulers.by_id)

Return an iterator over all agents of the model, grouped by order. When `order = 2`, the
iterator returns agent pairs, e.g `(agent1, agent2)` and when `order = 3`: agent triples,
e.g. `(agent1, agent7, agent8)`. `order` must be larger than `1` but has no upper bound.

Index order is provided by the model scheduler by default,
but can be altered with the `scheduler` keyword.
"""
iter_agent_groups(order::Int, model::ABM; scheduler = abmscheduler(model)) =
    Iterators.product((map(i -> model[i], scheduler(model)) for _ in 1:order)...)

"""
    map_agent_groups(order::Int, f::Function, model::ABM; kwargs...)
    map_agent_groups(order::Int, f::Function, model::ABM, filter::Function; kwargs...)

Applies function `f` to all grouped agents of an [`iter_agent_groups`](@ref) iterator.
`kwargs` are passed to the iterator method.
`f` must take the form `f(NTuple{O,AgentType})`, where the dimension `O` is equal to
`order`.

Optionally, a `filter` function that accepts an iterable and returns a `Bool` can be
applied to remove unwanted matches from the results. **Note:** This option cannot keep
matrix order, so should be used in conjunction with [`index_mapped_groups`](@ref) to
associate agent ids with the resultant data.
"""
map_agent_groups(order::Int, f::Function, model::ABM; kwargs...) =
    (f(idx) for idx in iter_agent_groups(order, model; kwargs...))
map_agent_groups(order::Int, f::Function, model::ABM, filter::Function; kwargs...) =
    (f(idx) for idx in iter_agent_groups(order, model; kwargs...) if filter(idx))

"""
    index_mapped_groups(order::Int, model::ABM; scheduler = Schedulers.by_id)
    index_mapped_groups(order::Int, model::ABM, filter::Function; scheduler = Schedulers.by_id)
Return an iterable of agent ids in the model, meeting the `filter` criteria if used.
"""
index_mapped_groups(order::Int, model::ABM; scheduler = Schedulers.by_id) =
    Iterators.product((scheduler(model) for _ in 1:order)...)
index_mapped_groups(order::Int, model::ABM, filter::Function; scheduler = Schedulers.by_id) =
    Iterators.filter(filter, Iterators.product((scheduler(model) for _ in 1:order)...))
