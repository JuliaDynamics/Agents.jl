export run!, collect_agent_data!, collect_model_data!,
       init_agent_dataframe, init_model_dataframe, aggname,
       should_we_collect

###################################################
# Definition of the data collection API
###################################################
get_data(a, s::Symbol, obtainer::Function) = obtainer(getproperty(a, s))
get_data(a, f::Function, obtainer::Function) = obtainer(f(a))

get_data_missing(a, s::Symbol, obtainer::Function) =
    hasproperty(a, s) ? obtainer(getproperty(a, s)) : missing
function get_data_missing(a, f::Function, obtainer::Function)
    try
        obtainer(f(a))
    catch
        missing
    end
end

should_we_collect(s, model, when::AbstractVector) = s ∈ when
should_we_collect(s, model, when::Bool) = when
should_we_collect(s, model, when) = when(model, s)

"""
    run!(model, agent_step! [, model_step!], n::Integer; kwargs...) → agent_df, model_df
    run!(model, agent_step!, model_step!, n::Function; kwargs...) → agent_df, model_df

Run the model (step it with the input arguments propagated into [`step!`](@ref)) and collect
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
  This name doesn't play well with anonymous functions, but you can simply use
  `DataFrames.rename!` to change the returned dataframe's column names.

  **Notice:** Aggregating only works if there are agents to be aggregated over.
  If you remove agents during model run, you should modify the aggregating functions.
  *E.g.* instead of passing `mean`, pass `mymean(a) = isempty(a) ? 0.0 : mean(a)`.

* `mdata::Vector` means "model data to collect" and works exactly like `adata`.
  For the model, no aggregation is possible (nothing to aggregate over).

By default both keywords are `nothing`, i.e. nothing is collected/aggregated.

## Mixed-Models

  For mixed-models, the `adata` keyword has some additional options & properties.
  An additional column `agent_type` will be placed in the output
  dataframe.

  In the case that data is needed for one agent type that does not exist
  in a second agent type, `missing` values will be added to the dataframe.

  **Warning:** Since this option is inherently type unstable, try to avoid this
  in a performance critical situation.

  Aggregate functions will fail if `missing` values are not handled explicitly.
  If `a1.weight` but `a2` (type: Agent2) has no `weight`, use
  `a2(a) = a isa Agent2; adata = [(:weight, sum, a2)]` to filter out the missing results.

## Other keywords
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
* `parallel=false` : Only when `replicates>0`. Run replicate simulations in parallel
  using Julia's `Distributed.pmap`.
* `seeds = [rand(Int) for _ in 1:replicates]` : Only when `replicates>0`.
  What seeds to use in the model's random number generator, `rng`, see [`AgentBasedModel`](@ref).
  The seeds are added to the model via `seed!(model, seed)` if `rng isa MersenneTwister`.
* `agents_first=true` : Whether to update agents first and then the model, or vice versa.
"""
function run! end

run!(model::ABM, agent_step!, n::Int = 1; kwargs...) =
run!(model::ABM, agent_step!, dummystep, n; kwargs...)

function run!(model::ABM, agent_step!, model_step!, n;
  replicates::Int=0, parallel::Bool=false, kwargs...)

  r = replicates
  if r > 0
      TODO: FIX THIS!!!
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
               mdata=nothing, adata=nothing, obtainer = identity,
               agents_first=true)

    df_agent = init_agent_dataframe(model, adata)
    df_model = init_model_dataframe(model, mdata)
    if n isa Integer
        if when == true; for c in eachcol(df_agent); sizehint!(c, n); end; end
        if when_model == true; for c in eachcol(df_model); sizehint!(c, n); end; end
    end

    s = 0
    while until(s, n, model)
        if should_we_collect(s, model, when)
            collect_agent_data!(df_agent, model, adata, s; obtainer)
        end
        if should_we_collect(s, model, when_model)
            collect_model_data!(df_model, model, mdata, s; obtainer)
        end
        step!(model, agent_step!, model_step!, 1, agents_first)
        s += 1
    end
    if should_we_collect(s, model, when)
        collect_agent_data!(df_agent, model, adata, s; obtainer)
    end
    if should_we_collect(s, model, when_model)
        collect_model_data!(df_model, model, mdata, s; obtainer)
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

function init_agent_dataframe(model::ABM{S,A}, properties::AbstractArray) where {S,A<:AbstractAgent}
    nagents(model) < 1 && throw(ArgumentError(
        "Model must have at least one agent to initialize data collection",
    ))

    utypes = union_types(A)
    std_headers = length(utypes) > 1 ? 3 : 2

    headers = Vector{Symbol}(undef, std_headers + length(properties))
    headers[1] = :step
    headers[2] = :id

    for i in 1:length(properties)
        headers[i+std_headers] = Symbol(properties[i])
    end

    types = Vector{Vector}(undef, std_headers + length(properties))
    types[1] = Int[]
    types[2] = Int[]

    if std_headers == 3
        headers[3] = :agent_type
        multi_agent_types!(types, utypes, model, properties)
    else
        single_agent_types!(types, model, properties)
    end

    DataFrame(types, headers)
end

function single_agent_types!(types::Vector{Vector{T} where T}, model::ABM, properties::AbstractArray)
    a = random_agent(model)
    for (i, k) in enumerate(properties)
        current_type = typeof(get_data(a, k, identity))
        isconcretetype(current_type) || warn(
            "Type is not concrete when using $(k) " *
            "on agents. Consider narrowning the type signature of $(k).",
        )
        types[i+2] = current_type[]
    end
end

function multi_agent_types!(types::Vector{Vector{T} where T}, utypes::Tuple, model::ABM, properties::AbstractArray)
    types[3] = Symbol[]

    for (i, k) in enumerate(properties)
        current_types = DataType[]
        for atype in utypes
            a = first(Iterators.filter(a -> a isa atype, allagents(model)))
            if k isa Symbol
                current_type =
                    hasproperty(a, k) ? typeof(get_data(a, k, identity)) : Missing
            else
                current_type = try
                    typeof(get_data(a, k, identity))
                catch
                    Missing
                end
            end
            isconcretetype(current_type) || warn(
                "Type is not concrete when using $(k) " *
                "on $(atype) agents. Consider narrowning the type signature of $(k).",
            )
            push!(current_types, current_type)
        end
        unique!(current_types)
        if length(current_types) == 1
            current_types[1] <: Missing && error("$(k) does not yield a valid agent property.")
            types[i+3] = current_types[1][]
        else
            types[i+3] = Union{current_types...}[]
        end
    end
end

function collect_agent_data!(df, model, properties::Vector, step::Int=0; kwargs...)
    alla = sort!(collect(values(model.agents)), by = a -> a.id)
    dd = DataFrame()
    dd[!, :step] = fill(step, length(alla))
    dd[!, :id] = map(a -> a.id, alla)
    if :agent_type ∈ propertynames(df)
        dd[!, :agent_type] = map(a -> Symbol(typeof(a)), alla)
    end

    for fn in properties
        _add_col_data!(dd, eltype(df[!, Symbol(fn)]), fn, alla; kwargs...)
    end
    append!(df, dd)
    return df
end

function _add_col_data!(dd::DataFrame, col::Type{T}, property, agent_iter; obtainer = identity) where {T}
    dd[!, Symbol(property)] = collect(get_data(a, property, obtainer) for a in agent_iter)
end

function _add_col_data!(dd::DataFrame, col::Type{T}, property, agent_iter; obtainer = identity) where {T>:Missing}
    dd[!, Symbol(property)] = collect(get_data_missing(a, property, obtainer) for a in agent_iter)
end


# Aggregating version
function init_agent_dataframe(model::ABM{S,A}, properties::Vector{<:Tuple}) where {S,A<:AbstractAgent}
    nagents(model) < 1 && throw(ArgumentError(
        "Model must have at least one agent to " * "initialize data collection",
    ))
    headers = Vector{String}(undef, 1 + length(properties))
    types = Vector{Vector}(undef, 1 + length(properties))

    utypes = union_types(A)

    headers[1] = "step"
    types[1] = Int[]

    if length(utypes) > 1
        multi_agent_agg_types!(types, utypes, headers, model, properties)
    else
        single_agent_agg_types!(types, headers, model, properties)
    end
    DataFrame(types, headers)
end

function single_agent_agg_types!(types::Vector{Vector{T} where T}, headers::Vector{String}, model::ABM, properties::AbstractArray)
    for (i, property) in enumerate(properties)
        k, agg = property
        headers[i+1] = aggname(property)
        # This line assumes that `agg` can work with iterators directly
        current_type =
            typeof(agg(get_data(a, k, identity) for a in Iterators.take(allagents(model), 1)))
        isconcretetype(current_type) || warn(
            "Type is not concrete when using function $(agg) " *
            "on key $(k). Consider using type annotation, e.g. $(agg)(a)::Float64 = ...",
        )
        types[i+1] = current_type[]
    end
end

function multi_agent_agg_types!(types::Vector{Vector{T} where T}, utypes::Tuple, headers::Vector{String}, model::ABM, properties::AbstractArray)
    for (i, property) in enumerate(properties)
        k, agg = property
        headers[i+1] = aggname(property)
        current_types = DataType[]
        for atype in utypes
            a = first(Iterators.filter(a -> a isa atype, allagents(model)))
            if k isa Symbol
                current_type =
                    hasproperty(a, k) ? typeof(agg(get_data(a, k, identity))) : Missing
            else
                current_type = try
                    typeof(agg(get_data(a, k, identity)))
                catch
                    Missing
                end
            end
            isconcretetype(current_type) || warn(
                "Type is not concrete when using function $(agg) " *
                "on key $(k) for $(atype) agents. Consider using type annotation, e.g. $(agg)(a)::Float64 = ...",
            )
            push!(current_types, current_type)
        end
        unique!(current_types)
        filter!(t -> !(t <: Missing), current_types) # Ignore missings here
        if length(current_types) == 1
            types[i+1] = current_types[1][]
        elseif length(current_types) > 1
            error("Multiple types found for aggregate function $(agg) on key $(k).")
        else
            error("No possible aggregation for $(k) using $(agg)")
        end
    end
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

function collect_agent_data!(df, model::ABM, properties::Vector{<:Tuple}, step::Int=0; kwargs...)
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
