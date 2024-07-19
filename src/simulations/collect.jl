export run!, offline_run!, collect_agent_data!, collect_model_data!,
       init_agent_dataframe, init_model_dataframe, dataname

###################################################
# Definition of the data collection API
###################################################
"""
    run!(model::ABM, t::Union{Real, Function}; kwargs...)

Run the model (call [`step!`](@ref)`(model, t)` and collect
data specified by the keywords, explained one by one below. Return the data as
two `DataFrame`s, `agent_df, model_df`,
one for agent-level data and one for model-level data.

See also [`offline_run!`](@ref) to write data to file while running the model.

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

  The resulting data name columns use the function [`dataname`](@ref). They create something
  like `:mean_weight` or `:maximum_f_x_pos`. In addition, you can use anonymous functions
  in a list comprehension to assign elements of an array into different columns:
  `adata = [(a)->(a.interesting_array[i]) for i=1:N]`. Column names can also be renamed
  with `DataFrames.rename!` after data is collected.

  **Notice:** Aggregating only works if there are agents to be aggregated over.
  If you remove agents during model run, you should modify the aggregating functions.
  *E.g.* instead of passing `mean`, pass `mymean(a) = isempty(a) ? 0.0 : mean(a)`.

* `mdata::Vector` means "model data to collect" and works exactly like `adata`.
  For the model, no aggregation is possible (nothing to aggregate over).

  Alternatively, `mdata` can also be a function. This is a "generator" function,
  that accepts `model` as input and provides a `Vector` that represents `mdata`.
  Useful in combination with an [`ensemblerun!`](@ref) call that
  requires a generator function.

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

* `when = 1`: at which times to perform the data collection and processing.
  A lot of flexibility is offered based on the type of `when`. Let
  `t = abmtime(model)` (which is updated throughout the `run!` process).
  - `when::Real`: data are collected each time the model is evolved for at least `when`
     units of time. For discrete time models like [`StandardABM`](@ref) this must be an
     integer and in essence it means how many steps to evolve between each data collection.
     For continuous time models like [`EventQueueABM`](@ref) `when` is the _least_ amount
     of time to evolve the model (with maximum being until an upcoming event is triggered).
  - `when::AbstractVector`: data are collected for `t ∈ when`.
  - `when::Function`: data are collected whenever `when(model, t)` returns `true`.
* `when_model = when`: same as `when` but for model data.
* `init = true`: Whether to collect data at the initial model state before it is stepped.
* `dt = 0.01`: minimum stepping time for continuous time models between data collection
  checks of `when` and possible data recording time.
  If `when isa Real` then it must hold `dt ≤ minimum(when, when_model)`.
  This keyword is ignored for discrete time models as it is 1 by definition.
* `obtainer = identity`: method to transfer collected data to the `DataFrame`.
  Typically only change this to [`copy`](https://docs.julialang.org/en/v1/base/base/#Base.copy)
  if some data are mutable containers (e.g. `Vector`) which change during evolution,
  or [`deepcopy`](https://docs.julialang.org/en/v1/base/base/#Base.deepcopy) if some data are
  nested mutable containers. Both of these options have performance penalties.
* `showprogress=false`: Whether to show progress.
"""
function run! end

function run!(model::ABM, n::Union{Function, Real};
        when = 1,
        when_model = when,
        mdata = nothing,
        adata = nothing,
        obtainer = identity,
        showprogress = false,
        init = true,
        dt = 0.01,
    )
    if discretimeabm(model)
        dt = 1
    else
        w1 = when isa Real ? when : Inf
        w2 = when_model isa Real ? when : Inf
        if dt > min(w1, w2)
            throw(ArgumentError("Given `dt` in `run!` is larger than `when/when_model`"))
        end
    end

    # Set-up part
    df_agent = init_agent_dataframe(model, adata)
    df_model = init_model_dataframe(model, mdata)
    if n isa Integer
        if when == 1
            for c in eachcol(df_agent)
                sizehint!(c, n)
            end
        end
        if when_model == 1
            for c in eachcol(df_model)
                sizehint!(c, n)
            end
        end
    end

    if init
        collect_agent_data!(df_agent, model, adata; obtainer)
        collect_model_data!(df_model, model, mdata; obtainer)
    end

    p = if typeof(n) <: Int
        ProgressMeter.Progress(n; enabled=showprogress, desc="run! progress: ")
    else
        ProgressMeter.ProgressUnknown(desc="run! steps done: ", enabled=showprogress)
    end

    # introduce function barrier for the collection loop.
    _run!(model, df_agent, df_model, n, when, when_model,
        mdata, adata, obtainer, dt, p
    )
end
function _run!(model, df_agent, df_model, n, when, when_model,
        mdata, adata, obtainer, dt, p
    )

    t0 = s = abmtime(model)
    # here we need to trackers of elapsed time since last collect:
    # one for model and one for agents dataframes. They are used only
    # if `when :: Real`.
    s_last_collect = s
    s_last_collect_model = s

    while until(s, t0, n, model)
        # we are first stepping and then collecting, as there is a dedicated
        # `init` step in the previous setup function.
        step!(model, dt)
        s = abmtime(model)
        if should_we_collect(s, s - s_last_collect, model, when)
            s_last_collect = s
            collect_agent_data!(df_agent, model, adata; obtainer)
        end
        if should_we_collect(s, s - s_last_collect_model, model, when_model)
            s_last_collect_model = s
            collect_model_data!(df_model, model, mdata; obtainer)
        end
        ProgressMeter.next!(p)
    end
    ProgressMeter.finish!(p)
    return df_agent, df_model
end

get_data(a, s::Symbol, obtainer::Function = identity) = obtainer(getproperty(a, s))
get_data(a, f::Function, obtainer::Function = identity) = obtainer(f(a))

get_data_missing(a, s::Symbol, obtainer::Function) =
    hasproperty(a, s) ? obtainer(getproperty(a, s)) : missing
function get_data_missing(a, f::Function, obtainer::Function)
    try
        obtainer(f(a))
    catch
        missing
    end
end

should_we_collect(s, ds, model, when::Real) = ds ≥ when
should_we_collect(s, ds, model, when::AbstractVector) = s ∈ when
should_we_collect(s, ds, model, when::Function) = when(model, s)


"""
    offline_run!(model, t::Union{Real, Function}; kwargs...)

Do the same as [`run`](@ref), but instead of collecting all the data into an in-memory
dataframe, write the output to a file after collecting data `writing_interval` times and
empty the dataframe after each write.
Useful when the amount of collected data is expected to exceed the memory available
during execution.

## Keywords

* `backend=:csv` : backend to use for writing data.
  Currently supported backends: `:csv`, `:arrow`.
* `adata_filename="adata.\$backend"` : a file to write agent data on.
  Appends to the file if it already exists, otherwise creates the file.
* `mdata_filename="mdata.\$backend"`: a file to write the model data on.
  Appends to the file if it already exists, otherwise creates the file.
* `writing_interval=1` : write to file every `writing_interval` times data 
  collection is triggered (which is set by the `when` and `when_model` keywords).
- All other keywords are propagated to [`run!`](@ref).
"""
function offline_run! end

# TODO: This whole function can be merged with `run!` by adding
# an additional dispatch to `collect_agent_data!` that has more arguments........
function offline_run!(model::ABM, n::Union{Function, Real};
        when = true,
        when_model = when,
        mdata = nothing,
        adata = nothing,
        obtainer = identity,
        showprogress = false,
        backend::Symbol = :csv,
        adata_filename = "adata.$backend",
        mdata_filename = "mdata.$backend",
        writing_interval = 1,
        init = true,
        dt = 0.01,
    )
    if discretimeabm(model)
        dt = 1
    else
        w1 = when isa Real ? when : Inf
        w2 = when_model isa Real ? when : Inf
        if dt > min(w1, w2)
            throw(ArgumentError("Given `dt` in `run!` is larger than `when/when_model`"))
        end
    end
    df_agent = init_agent_dataframe(model, adata)
    df_model = init_model_dataframe(model, mdata)
    if n isa Integer
        if when == true
            for c in eachcol(df_agent)
                sizehint!(c, n)
            end
        end
        if when_model == true
            for c in eachcol(df_model)
                sizehint!(c, n)
            end
        end
    end

    writer = get_writer(backend)
    run_and_write!(model, df_agent, df_model, n;
        when, when_model,
        mdata, adata,
        obtainer,
        showprogress,
        writer, adata_filename, mdata_filename, writing_interval, init, dt
    )
end

function run_and_write!(model, df_agent, df_model, n;
        when, when_model,
        mdata, adata,
        obtainer,
        showprogress,
        writer, adata_filename, mdata_filename, writing_interval, init, dt
    )
    p = if typeof(n) <: Int
        ProgressMeter.Progress(n; enabled=showprogress, desc="run! progress: ")
    else
        ProgressMeter.ProgressUnknown(desc="run! steps done: ", enabled=showprogress)
    end

    # this part of the data collection is practically identical to `run!`
    if init
        collect_agent_data!(df_agent, model, adata; obtainer)
        collect_model_data!(df_model, model, mdata; obtainer)
    end

    agent_count_collections = 0
    model_count_collections = 0

    t0 = s = abmtime(model)
    s_last_collect = s
    s_last_collect_model = s
    while until(abmtime(model), t0, n, model)
        step!(model, dt)
        s = abmtime(model)

        if should_we_collect(s, s - s_last_collect, model, when)
            s_last_collect = s
            collect_agent_data!(df_agent, model, adata; obtainer)
            agent_count_collections += 1
            if agent_count_collections % writing_interval == 0
                writer(adata_filename, df_agent, isfile(adata_filename))
                empty!(df_agent)
            end
        end
        if should_we_collect(s, s - s_last_collect_model, model, when_model)
            s_last_collect_model = s
            collect_model_data!(df_model, model, mdata; obtainer)
            model_count_collections += 1
            if model_count_collections % writing_interval == 0
                writer(mdata_filename, df_model, isfile(mdata_filename))
                empty!(df_model)
            end
        end
        ProgressMeter.next!(p)
    end
    ProgressMeter.finish!(p)
    return nothing
end

"""
    get_writer(backend)

Return a function to write to file using a given `backend`.
The returned writer function will take three arguments:
filename, data to write, whether to append to existing file or not.
"""
function get_writer(backend)
    @assert backend in (:csv, :arrow) "Backend $backend not supported."
    if backend == :csv
        return writer_csv
    elseif backend == :arrow
        return writer_arrow
    end
end

writer_csv(filename, data, append) = AgentsIO.CSV.write(filename, data; append)

function writer_arrow end

###################################################
# core data collection functions per step
###################################################

"""
    init_agent_dataframe(model, adata) → agent_df
Initialize a dataframe to add data later with [`collect_agent_data!`](@ref).
"""
init_agent_dataframe(model, properties::Nothing) = DataFrame()
function init_agent_dataframe(model::ABM, properties::AbstractArray)
    nagents(model) < 1 && throw(ArgumentError("Model must have at least one agent to initialize data collection",))
    A = agenttype(model)
    utypes = union_types(A)
    std_headers = length(utypes) > 1 ? 3 : 2

    headers = Vector{String}(undef, std_headers + length(properties))
    headers[1] = "time"
    headers[2] = "id"

    for i in 1:length(properties)
        headers[i+std_headers] = dataname(properties[i])
    end

    types = Vector{Vector}(undef, std_headers + length(properties))
    if model isa EventQueueABM
        types[1] = Float64[]
    else
        types[1] = Int[]
    end
    types[2] = Int[]

    if std_headers == 3
        headers[3] = "agent_type"
        multi_agent_types!(types, utypes, model, properties)
    else
        single_agent_types!(types, model, properties)
    end

    DataFrame(types, headers)
end
function init_agent_dataframe(model::ABM, properties::Vector{<:Tuple})
    nagents(model) < 1 && throw(ArgumentError(
        "Model must have at least one agent to initialize data collection",
    ))
    headers = Vector{String}(undef, 1 + length(properties))
    types = Vector{Vector}(undef, 1 + length(properties))
    A = agenttype(model)
    utypes = union_types(A)

    headers[1] = "time"
    if model isa EventQueueABM
        types[1] = Float64[]
    else
        types[1] = Int[]
    end

    if length(utypes) > 1
        multi_agent_agg_types!(types, utypes, headers, model, properties)
    else
        single_agent_agg_types!(types, headers, model, properties)
    end
    DataFrame(types, headers)
end

"""
    init_model_dataframe(model, mdata) → model_df
Initialize a dataframe to add data later with [`collect_model_data!`](@ref).
`mdata` can be a `Vector` or generator `Function`.
"""
function init_model_dataframe(model::ABM, properties::Vector)
    headers = Vector{String}(undef, 1 + length(properties))
    headers[1] = "time"
    for i in 1:length(properties)
        headers[i+1] = dataname(properties[i])
    end

    types = Vector{Vector}(undef, 1 + length(properties))
    if model isa EventQueueABM
        types[1] = Float64[]
    else
        types[1] = Int[]
    end
    for (i, k) in enumerate(properties)
        types[i+1] = if typeof(k) <: Symbol
            current_props = abmproperties(model)
            # How the properties are accessed depends on the type
            if typeof(current_props) <: Dict || typeof(current_props) <: Tuple
                typeof(current_props[k])[]
            else
                typeof(getfield(current_props, k))[]
            end
        else
            current_type = typeof(k(model))
            isconcretetype(current_type) || @warn(
                "Type is not concrete when using $(k)" *
                "on the model. Considering narrowing the type signature of $(k).",
            )
            current_type[]
        end
    end
    DataFrame(types, headers)
end
init_model_dataframe(model::ABM, properties::Function) =
    init_model_dataframe(model, properties(model))
init_model_dataframe(model::ABM, properties::Nothing) = DataFrame()

"""
    collect_agent_data!(df, model, properties; obtainer = identity)
Collect and add agent data into `df` (see [`run!`](@ref) for the dispatch rules
of `properties` and `obtainer`).
"""
collect_agent_data!(df, model, properties::Nothing, step::Int = 0; kwargs...) = df
function collect_agent_data!(df, model, properties::Vector, step::Int = 0; kwargs...)
    if step != 0
        @warn "Passing the `step` argument to `collect_agent_data!` is deprecated,
             now `abmtime(model)` is used automatically" maxlog=1
    end
    alla = sort!(collect(allagents(model)), by = a -> a.id)
    dd = DataFrame()
    dd[!, :time] = fill(abmtime(model), length(alla))
    dd[!, :id] = map(a -> a.id, alla)
    if :agent_type ∈ propertynames(df)
        dd[!, :agent_type] = map(a -> Symbol(typeof(a)), alla)
    end

    for fn in properties
        _add_col_data!(dd, eltype(df[!, dataname(fn)]), fn, alla; kwargs...)
    end
    append!(df, dd)
    return df
end
function collect_agent_data!(
    df,
    model::ABM,
    properties::Vector{<:Tuple},
    step::Int = 0;
    kwargs...,
)
    if step != 0
        @warn "Passing the `step` argument to `collect_agent_data!` is deprecated,
             now `abmtime(model)` is used automatically" maxlog=1
    end
    alla = allagents(model)
    push!(df[!, 1], abmtime(model))
    for (i, prop) in enumerate(properties)
        _add_col_data!(df[!, i+1], prop, alla; kwargs...)
    end
    return df
end

"""
    collect_model_data!(df, model, properties, obtainer = identity)
Same as [`collect_agent_data!`](@ref) but for model data instead.
`properties` can be a `Vector` or generator `Function`.
"""
function collect_model_data!(
    df,
    model,
    properties::Vector,
    step::Real = 0;
    obtainer = identity,
)
    if step != 0
        @warn "Passing the `step` argument to `collect_model_data!` is deprecated,
             now `abmtime(model)` is used automatically" maxlog=1
    end
    push!(df[!, :time], abmtime(model))
    for fn in properties
        push!(df[!, dataname(fn)], get_data(model, fn, obtainer))
    end
    return df
end
collect_model_data!(df, model, properties::Function, step::Real = 0; kwargs...) =
    collect_model_data!(df, model, properties(model), step; kwargs...)
collect_model_data!(df, model, properties::Nothing, step::Real = 0; kwargs...) = df

function single_agent_types!(types::Vector{<:Vector}, model::ABM, properties::AbstractArray)
    a = first(allagents(model))
    for (i, k) in enumerate(properties)
        current_type = typeof(get_data(a, k, identity))
        isconcretetype(current_type) || @warn(
            "Type is not concrete when using $(k) " *
            "on agents. Consider narrowing the type signature of $(k).",
        )
        types[i+2] = current_type[]
    end
end

function single_agent_agg_types!(
    types::Vector{Vector{T} where T},
    headers::Vector{String},
    model::ABM,
    properties::AbstractArray,
)
    for (i, property) in enumerate(properties)
        k, agg = property
        headers[i+1] = dataname(property)
        # This line assumes that `agg` can work with iterators directly
        current_type = typeof(agg(
            get_data(a, k, identity) for a in Iterators.take(allagents(model), 1)
        ))
        isconcretetype(current_type) || @warn(
            "Type is not concrete when using function $(agg) " *
            "on key $(k). Consider using type annotation, e.g. $(agg)(a)::Float64 = ...",
        )
        types[i+1] = current_type[]
    end
end

function multi_agent_types!(
    types::Vector{Vector{T} where T},
    utypes::Tuple,
    model::ABM,
    properties::AbstractArray,
)
    types[3] = Symbol[]

    for (i, k) in enumerate(properties)
        current_types = DataType[]
        for atype in utypes
            a = try
                first(Iterators.filter(a -> a isa atype, allagents(model)))
            catch
                nothing
            end

            if k isa Symbol
                current_type = if hasproperty(a, k)
                    typeof(get_data(a, k, identity))
                else
                    hasfield(atype, k) ? fieldtype(atype, k) : Missing
                end
            else
                current_type = try
                    typeof(get_data(a, k, identity))
                catch
                    Missing
                end
            end
            isconcretetype(current_type) || @warn(
                "Type is not concrete when using $(k) " *
                "on $(atype) agents. Consider narrowing the type signature of $(k).",
            )
            push!(current_types, current_type)
        end
        unique!(current_types)
        if length(current_types) == 1
            current_types[1] <: Missing &&
                error(lazy"$(k) does not yield a valid agent property.")
            types[i+3] = current_types[1][]
        else
            types[i+3] = Union{current_types...}[]
        end
    end
end

function multi_agent_agg_types!(
    types::Vector{Vector{T} where T},
    utypes::Tuple,
    headers::Vector{String},
    model::ABM,
    properties::AbstractArray,
)
    for (i, property) in enumerate(properties)
        k, agg = property
        headers[i+1] = dataname(property)
        current_types = DataType[]
        for atype in utypes
            a = try
                first(Iterators.filter(a -> a isa atype, allagents(model)))
            catch
                nothing
            end

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
            isconcretetype(current_type) || @warn(
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
            error(lazy"Multiple types found for aggregate function $(agg) on key $(k).")
        else
            error(lazy"No possible aggregation for $(k) using $(agg)")
        end
    end
end

"""
    dataname(k) → name

Return the name of the column of the `i`-th collected data where `k = adata[i]`
(or `mdata[i]`).
`dataname` also accepts tuples with aggregate and conditional values.
"""
dataname(x::Tuple) =
    join(vcat([dataname(x[2]), dataname(x[1])], [dataname(s) for s in x[3:end]]), "_")
dataname(x::Union{Symbol,String}) = string(x)
# This takes care to include fieldnames and values in the column name to make column names unique
# if the same function is used with different values of outer scope variables.
dataname(x::Function) = join(
    vcat([string(x)], ["$(prop)=$(getproperty(x, prop))" for prop in propertynames(x)]),
    "_",
)

function _add_col_data!(
    dd::DataFrame,
    col::Type{T},
    property,
    agent_iter;
    obtainer = identity,
) where {T}
    dd[!, dataname(property)] = collect(get_data(a, property, obtainer) for a in agent_iter)
end
function _add_col_data!(
    dd::DataFrame,
    col::Type{T},
    property,
    agent_iter;
    obtainer = identity,
) where {T>:Missing}
    dd[!, dataname(property)] =
        collect(get_data_missing(a, property, obtainer) for a in agent_iter)
end
# Normal aggregates
function _add_col_data!(
    col::AbstractVector{T},
    property::Tuple{K,A},
    agent_iter;
    obtainer = identity,
) where {T,K,A}
    k, agg = property
    res::T = agg(get_data(a, k, obtainer) for a in agent_iter)
    push!(col, res)
end
# Conditional aggregates
function _add_col_data!(
    col::AbstractVector{T},
    property::Tuple{K,A,C},
    agent_iter;
    obtainer = identity,
) where {T,K,A,C}
    k, agg, condition = property
    res::T = agg(get_data(a, k, obtainer) for a in Iterators.filter(condition, agent_iter))
    push!(col, res)
end
