#=
This file implements functions shared by all discrete spaces.
Discrete spaces are by definition spaces with a finite amount of possible positions.

All these functions are granted "for free" to discrete spaces by simply extending:
- nodes(model)
- get_node_contents(position, model)
=#
const DiscreteSpace = Union{GraphSpace, GridSpace}

export nodes, find_empty_nodes, pick_empty

"""
    nodes(model::ABM{A, <:DiscreteSpace}) → ns
Return an iterator over all positions of a model with a discrete space (called nodes).

	nodes(model::ABM{A, <:DiscreteSpace}, by::Symbol) → ns
Return all positions of a model with a discrete space (called nodes), sorting them
using the argument `by` which can be:
* `:random` - randomly sorted
* `:population` - nodes are sorted depending on how many agents they accommodate.
  The more populated nodes are first.
"""
function nodes(model::ABM{<:AbstractAgent, <:DiscreteSpace}, by::Symbol)
    itr = collect(nodes(model))
    if by == :random
        shuffle!(itr)
	elseif by == :population
	  sort!(itr, by = i -> length(get_node_contents(i, model)), rev = true)
	  return c
    else
        error("unknown `by`")
    end
    return itr
end

function find_empty_nodes(model::ABM{<:AbstractAgent, <:DiscreteSpace})
	collect(Iterators.filter(i -> length(get_node_contents(i, model)) == 0, nodes(model)))
end

"""
    isempty(position, model::ABM{A, <:DiscreteSpace})
Return `true` if there are no agents in `node`.
"""
Base.isempty(pos, model::ABM) = isempty(get_node_contents(pos, model))


"""
    pick_empty(model::ABM{A, <:DiscreteSpace})

Return a random position of an empty node or `nothing` if there are no empty nodes.
"""
function pick_empty(model::ABM{<:AbstractAgent, <:DiscreteSpace})
	empty_nodes = find_empty_nodes(model)
	isempty(empty_nodes) && return nothing
	rand(empty_nodes)
end
