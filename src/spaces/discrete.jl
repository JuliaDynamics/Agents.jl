#=
This file implements functions shared by all discrete spaces.
Discrete spaces are by definition spaces with a finite amount of possible positions.
=#
# const DiscreteSpace = Union{GraphSpace, GridSpace}

#######################################################################################
# %% Further discrete space  functions
#######################################################################################
export nodes

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
function nodes(model::ABM{<:AbstractAgent, <:DiscreteSpace}, by)
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
	Iterators.filter(i -> length(get_node_contents(i, model)) == 0, nodes(model))
end
