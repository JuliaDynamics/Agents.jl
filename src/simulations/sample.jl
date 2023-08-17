export sample!, replicate!
using StatsBase: sample, Weights

"""
    sample!(model::ABM, n [, weight]; kwargs...)

Replace the agents of the `model` with a random sample of the current agents with
size `n`.

Optionally, provide a `weight`: Symbol (agent field) or function (input agent
out put number) to weight the sampling.
This means that the higher the `weight` of the agent, the higher the probability that
this agent will be chosen in the new sampling.

# Keywords
* `replace = true` : whether sampling is performed with replacement, i.e. all agents can
be chosen more than once.

Example usage in [Wright-Fisher model of evolution](https://juliadynamics.github.io/AgentsExampleZoo.jl/dev/examples/wright-fisher/).
"""
function sample!(
    model::ABM,
    n::Int,
    weight = nothing;
    replace = true,
)
    nagents(model) == 0 && return nothing
    org_ids = collect(allids(model))
    if weight !== nothing
        weights = Weights([get_data(a, weight, identity) for a in allagents(model)])
        newids = sample(abmrng(model), org_ids, weights, n, replace = replace)
    else
        newids = sample(abmrng(model), org_ids, n, replace = replace)
    end
    add_newids!(model, org_ids, newids)
end

#Used in sample!
function add_newids!(model, org_ids, newids)
    # `counter` counts the number of occurencies for each item, it comes from DataStructure.jl
    count_newids = counter(newids)
    for id in org_ids
        noccurances = count_newids[id]
        agent = model[id]
        if noccurances == 0
            remove_agent!(agent, model)
        else
            for _ in 2:noccurances
                replicate!(agent, model)
            end
        end
    end
end

"""
    replicate!(agent, model; kwargs...) 

Add a new agent to the `model` copying the values of the fields of the given agent. 
With the `kwargs` it is possible to override the values by specifying new ones for 
some fields (except for the `id` field which is set to a new one automatically). 
Return the new agent instance.

## Example
```julia
using Agents
@agent A GridAgent{2} begin
    k::Float64
    w::Float64
end

model = ABM(A, GridSpace((5, 5)))
a = A(1, (2, 2), 0.5, 0.5)
b = replicate!(a, model; w = 0.8)
```
"""
function replicate!(agent::A, model; kwargs...) where {A<:AbstractAgent}
    args = new_args(agent::A, model; kwargs...) 
    newagent = A(nextid(model), args...)
    add_agent_pos!(newagent, model)
    return newagent
end

function new_args(agent::A, model; kwargs...) where {A<:AbstractAgent}
    # the id is always the first field
    fields_no_id = fieldnames(A)[2:end]
    if isempty(kwargs)
        new_args = (deepcopy(getfield(agent, x)) for x in fields_no_id)
    else
        kwargs_nt = NamedTuple(kwargs)
        new_args = (choose_arg(x, kwargs_nt, agent) for x in fields_no_id)
    end
end

function choose_arg(x, kwargs_nt, agent)
    return deepcopy(getfield(hasproperty(kwargs_nt, x) ? kwargs_nt : agent, x))
end
