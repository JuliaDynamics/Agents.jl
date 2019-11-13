
"""
A function to be used in `pmap` in `parallel_replicates`. It runs the `step!` function, but has a `dummyvar` parameter that does nothing, but is required for the `pmap` function.
"""
function parallel_step_dummy!(model::ABM, agent_step!, model_step!, n::Int, properties, when::AbstractArray{V}, dummyvar) where {V<:Integer}
  data = step!(deepcopy(model), agent_step!, model_step!, n, properties, when=when);
  return data
end

"""
    parallel_replicates(agent_step!, model::ABM, n::Integer, agent_properties::Array{Symbol}, when::AbstractArray{Integer}, replicates::Integer)

Runs `replicates` number of simulations in parallel and returns a `DataFrame`.
"""
function parallel_replicates(model::ABM, agent_step!, model_step!, n::T, properties; when::AbstractArray{T}, replicates::T, single_df::Bool) where {T<:Integer}

  if single_df
    dd = step!(deepcopy(model), agent_step!, model_step!, n, properties, when=when);

    all_data = pmap(j-> parallel_step_dummy!(model, agent_step!, model_step!, n, properties, when, j), 2:replicates)

    for d in all_data
      dd = join(dd, d, on=:step, kind=:outer, makeunique=true)
    end
    
    return dd
  else
    dd = pmap(j-> parallel_step_dummy!(model, agent_step!, model_step!, n, properties, when, j), 1:replicates)
    return dd
  end
end
