
"""
A function to be used in `pmap` in `parallel_replicates`. It runs the `step!` function, but has a `dummyvar` parameter that does nothing, but is required for the `pmap` function.
"""
function parallel_step_dummy!(model::AbstractModel, agent_step!::T, model_step!::T, n::Int, properties, when::AbstractArray{V}, dummyvar) where {T<:Function, V<:Integer}
  data = step!(deepcopy(model), agent_step!, model_step!, n, properties, when=when);
  return data
end

"""
    parallel_replicates(agent_step!, model::AbstractModel, n::Integer, agent_properties::Array{Symbol}, when::AbstractArray{Integer}, nreplicates::Integer)

Runs `nreplicates` number of simulations in parallel and returns a `DataFrame`.
"""
function parallel_replicates(model::AbstractModel, agent_step!::V, model_step!::V, n::T, properties::Array{Symbol}; when::AbstractArray{T}, nreplicates::T) where {V<:Function, T<:Integer}
  dd = step!(deepcopy(model), agent_step!, model_step!, n, properties, when=when);
  all_data = pmap(j-> parallel_step_dummy!(model, agent_step!, model_step!, n, properties, when, j), 1:nreplicates)
  for d in all_data
    dd = join(dd, d, on=:id, kind=:outer, makeunique=true)
  end
  return dd
end
