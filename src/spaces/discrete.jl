#=
This file implements functions shared by all discrete spaces.
Discrete spaces are by definition spaces with a finite amount of possible positions.
=#
# const DiscreteSpace = Union{GraphSpace, GridSpace}

#######################################################################################
# %% Further discrete space  functions
#######################################################################################
export nodes
function nodes(model::ABM{<:AbstractAgent, <:DiscreteSpace})
    x = CartesianIndices(model.space.s)
    return (Tuple(y) for y in x)
end

function nodes(model::ABM{<:AbstractAgent, <:DiscreteSpace}, by)
    itr = collect(nodes(model))
    if by == :random
        shuffle!(itr)
    elseif by == :id
        # TODO: By id is wrong...?
        sort!(itr)
    else
        error("unknown `by`")
    end
    return itr
end

function get_node_contents(pos::ValidPos, model::ABM{<:AbstractAgent, <:DiscreteSpace})
    return model.space.s[pos...]
end

function find_empty_nodes(model::ABM{<:AbstractAgent, <:DiscreteSpace})
	Iterators.filter(i -> length(get_node_contents(i, model)) == 0, nodes(pos))
end
