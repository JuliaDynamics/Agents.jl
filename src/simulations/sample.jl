export rsample, sample!, replicate!
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
        new_ids = sample(abmrng(model), org_ids, weights, n, replace = replace)
    else
        new_ids = sample(abmrng(model), org_ids, n, replace = replace)
    end
    add_newids!(model, org_ids, new_ids)
end

#Used in sample!
function add_newids!(model, org_ids, new_ids)
    sort!(org_ids)
    sort!(new_ids)
    i, L = 1, length(new_ids)
    sizehint!(agent_container(model), L)
    id_new = new_ids[1]
    for id in org_ids
        agent = model[id]
        if id_new != id
            remove_agent!(agent, model)
        else
            i += 1
            while i <= L && new_ids[i] == id
                replicate!(agent, model)
                i += 1
            end
            i <= L && (id_new = new_ids[i])
        end
    end
    return
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
    args = new_args(agent, model; kwargs...) 
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

#######################################################################################
# %% sampling functions
#######################################################################################

# rsample(iter, rng, [condition])
# rsample(iter, rng, [n, condition])

function rsample(iter, rng; alloc = false)
    if alloc 
        sampling_single(iter, rng)
    else
        resorvoir_sampling_single(iter, rng)
    end
end

function rsample(iter, rng, condition; alloc = false)
    if alloc 
        sampling_with_condition_single(iter, rng, condition)
    else
        iter_filtered = Iterators.filter(x -> condition(x), iter)
        resorvoir_sampling_single(iter_filtered, rng)
    end
end

function rsample(iter, rng, n::Int; alloc = true, iter_type = Any)
    if alloc 
        sampling_multi(iter, rng, n)
    else
        resorvoir_sampling_multi(iter, rng, n, iter_type)
    end
end

function rsample(iter, rng, n, condition; alloc = true, iter_type = Any)
    if alloc 
        sampling_with_condition_multi(iter, rng, n, condition)
    else
        iter_filtered = Iterators.filter(x -> condition(x), iter)
        resorvoir_sampling_multi(iter_filtered, rng, n, iter_type)
    end
end

function sampling_single(iter, rng)
    pop = collect(iter)
    isempty(pop) && return nothing
    return rand(rng, pop)
end

function sampling_with_condition_single(iter, rng, condition)
    pop = collect(iter)
    n_p = length(pop)
    while n_p != 0
        idx = rand(rng, 1:n_p)
        el = pop[idx]
        condition(el) && return el
        pop[idx], pop[n_p] = pop[n_p], pop[idx]
        n_p -= 1
    end
    return nothing
end

function resorvoir_sampling_single(iter, rng)
    res = iterate(iter)
    isnothing(res) && return nothing
    w = rand(rng)
    while true
        choice, state = res
        skip_counter = floor(log(rand(rng))/log(1-w))
        while skip_counter != 0
            skip_res = iterate(iter, state)
            isnothing(skip_res) && return choice
            state = skip_res[2]
            skip_counter -= 1
        end
        res = iterate(iter, state)
        isnothing(res) && return choice
        w *= rand(rng)
    end
end

function sampling_multi(iter, rng, n)
    pop = collect(iter)
    pop <= n && return pop
    return sample(rng, pop, n; replace=false)  
end

function sampling_with_condition_multi(iter, rng, n, condition)
    pop = collect(iter)
    n_p = length(pop)
    n_p <= n && return filter(el -> condition(el), pop)
    res = Vector{eltype(pop)}(undef, n)
    i = 0
    while n_p != 0
        idx = rand(rng, 1:n_p)
        el = pop[idx]
        if condition(el)
            i += 1
            res[i] = el
            i == n && return res       
        end
        pop[idx], pop[n_p] = pop[n_p], pop[idx]
        n_p -= 1
    end
    return res[1:i] 
end

function resorvoir_sampling_multi(iter, rng, n, iter_type = Any)
    it = iterate(iter)
    isnothing(it) && return iter_type[]
    el, state = it
    reservoir = Vector{iter_type}(undef, n)
    reservoir[1] = el
    for i in 2:n
        it = iterate(iter, state)
        isnothing(it) && return reservoir[1:i-1]
        el, state = it
        reservoir[i] = el
    end
    w = rand(rng)^(1/n)
    while true
        skip_counter = floor(log(rand(rng))/log(1-w))
        while skip_counter != 0
            skip_it = iterate(iter, state)
            isnothing(skip_it) && return reservoir
            state = skip_it[2]
            skip_counter -= 1
        end
        it = iterate(iter, state)
        isnothing(it) && return reservoir
        el, state = it
        reservoir[rand(rng, 1:n)] = el 
        w *= rand(rng)^(1/n)
    end
end