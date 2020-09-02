export run!, collect_agent_data!, collect_model_data!,
       init_agent_dataframe, init_model_dataframe, aggname,
       should_we_collect

###################################################
# Definition of the data collection API
###################################################
get_data(a, s::Symbol, obtainer::Function) = obtainer(getproperty(a, s))
get_data(a, f::Function, obtainer::Function) = obtainer(f(a))

should_we_collect(s, model, when::AbstractVector) = s ∈ when
should_we_collect(s, model, when::Bool) = when
should_we_collect(s, model, when) = when(model, s)

"""
    run!(model, agent_step! [, model_step!], n; kwargs...) → agent_df, model_df

Run the model (step it with the input arguments propagated into `step!`) and collect
data specified by the keywords, explained one by one below. Return the data as
two `DataFrame`s, one for agent-level data and one for model-level data.

## Data-deciding keywords
* `adata::Vector` means "agent data to collect". If an entry is a `Symbol`, e.g. `:weight`,
  then the data for this entry is agent's field `weight`. If an entry is a `Function`, e.g.
  `f`, then the data for this entry is just `f(a)` for each agent `a`.
  The resulting dataframe columns are named with the input symbol (here `:weight, :f`).

* `adata::Vector{<:Tuple}`: if `adata` is a vector of tuples instead,
  data aggregation is done over the agent properties.

  For each 2-tuple, the first entry is the "key" (any entry like the ones mentioned above,
  e.g. `:weight, f`). The second entry is an aggregating function that aggregates the key,
  e.g. `mean, maximum`. So, continuing from the above example, we would have
  `adata = [(:weight, mean), (f, maximum)]`.

  It's also possible to provide a 3-tuple, with the third entry being a conditional
  function (returning a `Bool`), which assesses if each agent should be included in the
  aggregate. For example: `x_pos(a) = a.pos[1]>5` with `(:weight, mean, x_pos)` will result
  in the average weight of agents conditional on their x-position being greater than 5.

  The resulting data name columns use the function [`aggname`](@ref), and create something
  like `:mean_weight` or `:maximum_f_x_pos`.
  This name doesn't play well with anonymous functions!

  **Notice:** Aggregating only works if there are agents to be aggregated over.
  If you remove agents during model run, you should modify the aggregating functions.
  *E.g.* instead of passing `mean`, pass `mymean(a) = isempty(a) ? 0.0 : mean(a)`.

* `mdata::Vector` means "model data to collect" and works exactly like `adata`.
  For the model, no aggregation is possible (nothing to aggregate over).

By default both keywords are `nothing`, i.e. nothing is collected/aggregated.

### Other keywords
* `when=true` : at which steps `s` to perform the data collection and processing.
  A lot of flexibility is offered based on the type of `when`. If `when::Vector`,
  then data are collect if `s ∈ when`. Otherwise data are collected if `when(model, s)`
  returns `true`. By default data are collected in every step.
* `when_model = when` : same as `when` but for model data.
* `obtainer = identity` : method to transfer collected data to the `DataFrame`.
Typically only change this to [`copy`](https://docs.julialang.org/en/v1/base/base/#Base.copy)
if some data are mutable containers (e.g. `Vector`) which change during evolution,
or [`deepcopy`](https://docs.julialang.org/en/v1/base/base/#Base.deepcopy) if some data are
nested mutable containers.
Both of these options have performance penalties.
* `replicates=0` : Run `replicates` replicates of the simulation.
* `parallel=false` : Only when `replicates>0`. Run replicate simulations in parallel.
"""
function run! end

run!(model::ABM, agent_step!, n::Int = 1; kwargs...) =
run!(model::ABM, agent_step!, dummystep, n; kwargs...)

function run!(model::ABM, agent_step!, model_step!, n;
  replicates::Int=0, parallel::Bool=false, kwargs...)

  r = replicates
  if r > 0
    if parallel
      return parallel_replicates(model, agent_step!, model_step!, n, r; kwargs...)
    else
      return series_replicates(model, agent_step!, model_step!, n, r; kwargs...)
    end
  else
    return _run!(model, agent_step!, model_step!, n; kwargs...)
  end
end

###################################################
# Core data collection loop
###################################################
"""
  _run!(model, agent_step!, model_step!, n; kwargs...)
Core function that loops over stepping a model and collecting data at each step.
"""
function _run!(model, agent_step!, model_step!, n;
               when = true, when_model = when,
               agent_properties=nothing, model_properties=nothing,
               mdata=model_properties, adata=agent_properties, obtainer = identity)

    agent_properties ≠ nothing && @warn "use `adata` instead of `agent_properties`"
    model_properties ≠ nothing && @warn "use `mdata` instead of `model_properties`"
    df_agent = init_agent_dataframe(model, adata)
    df_model = init_model_dataframe(model, mdata)
    if n isa Integer
        if when == true; for c in eachcol(df_agent); sizehint!(c, n); end; end
        if when_model == true; for c in eachcol(df_model); sizehint!(c, n); end; end
    end

    s = 0
    while until(s, n, model)
        if should_we_collect(s, model, when)
            collect_agent_data!(df_agent, model, adata, s; obtainer = obtainer)
        end
        if should_we_collect(s, model, when_model)
            collect_model_data!(df_model, model, mdata, s; obtainer = obtainer)
        end
        step!(model, agent_step!, model_step!, 1)
        s += 1
    end
    if should_we_collect(s, model, when)
        collect_agent_data!(df_agent, model, adata, s; obtainer = obtainer)
    end
    if should_we_collect(s, model, when_model)
        collect_model_data!(df_model, model, mdata, s; obtainer = obtainer)
    end
    return df_agent, df_model
end

###################################################
# core data collection functions per step
###################################################
"""
    init_agent_dataframe(model, adata) → agent_df
Initialize a dataframe to add data later with [`collect_agent_data!`](@ref).
"""
init_agent_dataframe(model, properties::Nothing) = DataFrame()

"""
    collect_agent_data!(df, model, properties, step = 0; obtainer = identity)
Collect and add agent data into `df` (see [`run!`](@ref) for the dispatch rules
of `properties` and `obtainer`). `step` is given because the step number information
is not known.
"""
collect_agent_data!(df, model, properties::Nothing, step::Int=0; kwargs...) = df

function init_agent_dataframe(model::ABM, properties::AbstractArray)
    nagents(model) < 1 && throw(ArgumentError("Model must have at least one agent to "*
    "initialize data collection"))

    headers = Vector{Symbol}(undef, 2+length(properties))
    headers[1] = :step
    headers[2] = :id
    for i in 1:length(properties); headers[i+2] = Symbol(properties[i]); end

    types = Vector{Vector}(undef, 2+length(properties))
    types[1] = Int[]
    types[2] = Int[]
    a = random_agent(model)
    for (i, k) in enumerate(properties)
        current_type = typeof(get_data(a, k, identity))
        isconcretetype(current_type) || warn("Type is not concrete when using $(k)"*
        "on agents. Consider narrowning the type signature of $(k).")
        types[i+2] = current_type[]
    end
    DataFrame(types, headers)
end

function collect_agent_data!(df, model, properties::Vector, step::Int=0; obtainer = identity)
    alla = sort!(collect(values(model.agents)), by=a->a.id)
    dd = DataFrame()
    dd[!, :step] = fill(step, length(alla))
    dd[!, :id] = map(a->a.id, alla)
    for fn in properties
        dd[!, Symbol(fn)] = collect(get_data(a, fn, obtainer) for a in alla)
    end
    append!(df, dd)
    return df
end

# Aggregating version
function init_agent_dataframe(model::ABM, properties::Vector{<:Tuple})
    nagents(model) < 1 && throw(ArgumentError("Model must have at least one agent to "*
    "initialize data collection"))
    headers = Vector{String}(undef, 1+length(properties))
    types = Vector{Vector}(undef, 1+length(properties))
    alla = allagents(model)

    headers[1] = "step"
    types[1] = Int[]

    for (i, property) in enumerate(properties)
        k, agg = property
        headers[i+1] = aggname(property)
        # This line assumes that `agg` can work with iterators directly
        current_type = typeof( agg( get_data(a, k, identity) for a in Iterators.take(alla,1) ) )
        isconcretetype(current_type) || warn("Type is not concrete when using function $(agg) "*
            "on key $(k). Consider using type annotation, e.g. $(agg)(a)::Float64 = ...")
        types[i+1] = current_type[]
    end
    DataFrame(types, headers)
end

"""
    aggname(k) → name
    aggname(k, agg) → name
    aggname(k, agg, condition) → name

Return the name of the column of the `i`-th collected data where `k = adata[i]`
(or `mdata[i]`).
`aggname` also accepts tuples with aggregate and conditional values.
"""
aggname(k, agg) = string(agg)*"_"*string(k)
aggname(k, agg, condition) = string(agg)*"_"*string(k)*"_"*string(condition)
aggname(x::Tuple{K,A}) where {K,A} = aggname(x[1], x[2])
aggname(x::Tuple{K,A,C}) where {K,A,C} = aggname(x[1], x[2], x[3])
aggname(x::Union{Function, Symbol, String}) = string(x)

function collect_agent_data!(df, model, properties::Vector{<:Tuple}, step::Int=0; kwargs...)
    alla = allagents(model)
    push!(df[!, 1], step)
    for (i, prop) in enumerate(properties)
        _add_col_data!(df[!, i+1], prop, alla; kwargs...)
    end
    return df
end

# Normal aggregates
function _add_col_data!(col::AbstractVector{T}, property::Tuple{K,A}, agent_iter; obtainer = identity) where {T,K,A}
    k, agg = property
    res::T = agg(get_data(a, k, obtainer) for a in agent_iter)
    push!(col, res)
end

# Conditional aggregates
function _add_col_data!(col::AbstractVector{T}, property::Tuple{K,A,C}, agent_iter; obtainer = identity) where {T,K,A,C}
    k, agg, condition = property
    res::T = agg(get_data(a, k, obtainer) for a in Iterators.filter(condition, agent_iter))
    push!(col, res)
end

# Model data
"""
    init_model_dataframe(model, mdata) → model_df
Initialize a dataframe to add data later with [`collect_model_data!`](@ref).
"""
function init_model_dataframe(model::ABM, properties::Vector)
    headers = Vector{Symbol}(undef, 1+length(properties))
    headers[1] = :step
    for i in 1:length(properties); headers[i+1] = Symbol(properties[i]); end

    types = Vector{Vector}(undef, 1+length(properties))
    types[1] = Int[]
    for (i,k) in enumerate(properties)
        types[i+1] =
            if typeof(k) <: Symbol
                typeof(model.properties[k])[]
            else
                current_type = typeof(k(model))
                isconcretetype(current_type) || warn("Type is not concrete when using $(k)"*
                "on the model. Considering narrowing the type signature of $(k).")
                current_type[]
            end
    end
    DataFrame(types, headers)
end

init_model_dataframe(model::ABM, properties::Nothing) = DataFrame()

"""
    collect_model_data!(df, model, properties, step = 0, obtainer = identity)
Same as [`collect_agent_data!`](@ref) but for model data instead.
"""
function collect_model_data!(df, model, properties::Vector, step::Int=0; obtainer = identity)
  push!(df[!, :step], step)
  for fn in properties
    push!(df[!, Symbol(fn)], get_data(model, fn, obtainer))
  end
  return df
end

collect_model_data!(df, model, properties::Nothing, step::Int=0; kwargs...) = df


###################################################
# Parallel / replicates
###################################################
function replicate_col!(df, rep)
  df[!, :replicate] = [rep for i in 1:size(df, 1)]
end

"Run replicates of the same simulation"
function series_replicates(model, agent_step!, model_step!, n, replicates; kwargs...)

  df_agent, df_model = _run!(deepcopy(model), agent_step!, model_step!, n; kwargs...)
  replicate_col!(df_agent, 1)
  replicate_col!(df_model, 1)

  for rep in 2:replicates
    df_agentTemp, df_modelTemp = _run!(deepcopy(model), agent_step!, model_step!, n; kwargs...)
    replicate_col!(df_agentTemp, rep)
    replicate_col!(df_modelTemp, rep)

    append!(df_agent, df_agentTemp)
    append!(df_model, df_modelTemp)
  end
  return df_agent, df_model
end

"Run replicates of the same simulation in parallel"
function parallel_replicates(model::ABM, agent_step!, model_step!, n, replicates; kwargs...)

  all_data = pmap(j -> _run!(deepcopy(model), agent_step!, model_step!, n; kwargs...),
                  1:replicates)

  df_agent = DataFrame()
  df_model = DataFrame()
  for (rep, d) in enumerate(all_data)
    replicate_col!(d[1], rep)
    replicate_col!(d[2], rep)
    append!(df_agent, d[1])
    append!(df_model, d[2])
  end

  return df_agent, df_model
end
