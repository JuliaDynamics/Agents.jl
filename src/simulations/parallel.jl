export parallel_replicates

"""
A function to be used in `pmap` in `parallel_replicates`. It runs the `step!` function, but has a `dummyvar` parameter that does nothing, but is required for the `pmap` function.
"""
function parallel_step_dummy!(model::ABM, agent_step!, model_step!, n::Int, properties, when::AbstractArray{V}, step0::Bool, dummyvar) where {V<:Integer}
  data = step!(deepcopy(model), agent_step!, model_step!, n, properties, when=when, step0=step0);
  return data
end

"""
    parallel_replicates(agent_step!, model::ABM, n::Integer, agent_properties::Array{Symbol}, when::AbstractArray{Integer}, replicates::Integer)

Runs `replicates` number of simulations in parallel and returns a `DataFrame`.
"""
function parallel_replicates(model::ABM, agent_step!, model_step!, n::T, properties;
  when::AbstractArray{T}, replicates::T, step0::Bool) where {T<:Integer}

  all_data = pmap(j-> parallel_step_dummy!(model, agent_step!, model_step!, n,
  properties, when, step0, j), 1:replicates)

  dd = DataFrame()
  for (rep, d) in enumerate(all_data)
    d[!, :replicate] = [rep for i in 1:size(d, 1)]
    dd = vcat(dd, d)
  end

  return dd

end
