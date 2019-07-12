"""
    batchrunner(agent_step, model_step, model::AbstractModel, nsteps::Integer, properties::Array{Symbol}, aggregators::AbstractVector{T}, steps_to_collect_data::Array{Int64}, replicates::Integer) where T<:Function

Runs `replicates` number of simulation replicates and returns a `DataFrame`.
"""
function batchrunner(agent_step, model_step, model::AbstractModel, nsteps::Integer, properties::Array{Symbol}, aggregators::AbstractVector{T}, steps_to_collect_data::Array{Int64}, replicates::Integer) where T<:Function
  dataall = step!(agent_step, model_step, model, nsteps, properties, aggregators, steps_to_collect_data)
  for i in 2:replicates
    data = step!(agent_step, model_step, model, nsteps, properties, aggregators, steps_to_collect_data)
    dataall = join(dataall, data, on=:step, kind=:outer, makeunique=true)
  end
  return dataall
end

"""
    batchrunner(agent_step, model_step, model::AbstractModel, nsteps::Integer, properties::Array{Symbol}, steps_to_collect_data::Array{Int64}, replicates::Integer)

Runs `replicates` number of simulation replicates and returns a `DataFrame`.
"""
function batchrunner(agent_step, model_step, model::AbstractModel, nsteps::Integer, properties::Array{Symbol}, steps_to_collect_data::Array{Int64}, replicates::Integer)
  dataall = step!(agent_step, model_step, model, nsteps, properties, steps_to_collect_data)
  for i in 2:replicates
    data = step!(agent_step, model_step, model, nsteps, properties, steps_to_collect_data)
    dataall = join(dataall, data, on=:id, kind=:outer, makeunique=true)
  end
  return dataall
end

"""
    batchrunner(agent_step, model::AbstractModel, nsteps::Integer, properties::Array{Symbol}, aggregators::AbstractVector{T}, steps_to_collect_data::Array{Int64}, replicates::Integer) where T<:Function

Runs `replicates` number of simulation replicates and returns a `DataFrame`.
"""
function batchrunner(agent_step, model::AbstractModel, nsteps::Integer, properties::Array{Symbol}, aggregators::AbstractVector{T}, steps_to_collect_data::Array{Int64}, replicates::Integer) where T<:Function
  dataall = step!(agent_step, model, nsteps, properties, aggregators, steps_to_collect_data)
  for i in 2:replicates
    data = step!(agent_step, model, nsteps, properties, aggregators, steps_to_collect_data)
    dataall = join(dataall, data, on=:step, kind=:outer, makeunique=true)
  end
  return dataall
end

"""
    batchrunner(agent_step, model::AbstractModel, nsteps::Integer, properties::Array{Symbol}, steps_to_collect_data::Array{Int64}, replicates::Integer)

Runs `replicates` number of simulation replicates and returns a `DataFrame`.
"""
function batchrunner(agent_step, model::AbstractModel, nsteps::Integer, properties::Array{Symbol}, steps_to_collect_data::Array{Int64}, replicates::Integer)
  dataall = step!(agent_step, model, nsteps, properties, steps_to_collect_data)
  for i in 2:replicates
    data = step!(agent_step, model, nsteps, properties, steps_to_collect_data)
    dataall = join(dataall, data, on=:id, kind=:outer, makeunique=true)
  end
  return dataall
end


"""
A function to be used in `pmap` in `batchrunner_parallel`. It runs the `step!` function, but has a `dummyvar` parameter that does nothing, but is required for the `pmap` function.
"""
function parallel_step_dummy!(agent_step!, model, nsteps, agent_properties, steps_to_collect_data, dummyvar)
  data = step!(agent_step!, model, nsteps, agent_properties, steps_to_collect_data);
  return data
end

function parallel_step_dummy!(agent_step!, model, nsteps, agent_properties, aggregators, steps_to_collect_data, dummyvar)
  data = step!(agent_step!, model, nsteps, agent_properties, aggregators, steps_to_collect_data);
  return data
end

function parallel_step_dummy!(agent_step!, model_step!, model, nsteps, properties, steps_to_collect_data, dummyvar)
  data = step!(agent_step!, model_step!, deepcopy(model), nsteps, properties, steps_to_collect_data);
  return data
end

function parallel_step_dummy!(agent_step!, model_step!, model, nsteps, properties, aggregators, steps_to_collect_data, dummyvar)
  data = step!(agent_step!, model_step!, deepcopy(model), nsteps, properties, aggregators, steps_to_collect_data);
  return data
end

"""
    batchrunner_parallel(agent_step!, model::AbstractModel, nsteps::Integer, agent_properties::Array{Symbol}, steps_to_collect_data::AbstractArray{Integer}, nreplicates::Integer)    

Runs `nreplicates` number of simulations in parallel and returns a `DataFrame`.
"""
function batchrunner_parallel(agent_step!::V, model::AbstractModel, nsteps::T, agent_properties::Array{Symbol}, steps_to_collect_data::AbstractArray{T}, nreplicates::T) where {V<:Function, T<:Integer}
  dd = step!(agent_step!, deepcopy(model), nsteps, agent_properties, steps_to_collect_data);
  all_data = pmap(j-> parallel_step_dummy!(agent_step!, model, nsteps, agent_properties, steps_to_collect_data, j), 1:nreplicates)
  for d in all_data
    dd = join(dd, d, on=:id, kind=:outer, makeunique=true)
  end
  return dd
end


"""
    batchrunner_parallel(agent_step!::T, model::AbstractModel, nsteps::V, properties::Array{Symbol}, aggregators::AbstractVector{T}, steps_to_collect_data::AbstractArray{V}, replicates::V) where {T<:Function, V<:Integer}

"""
function batchrunner_parallel(agent_step!::T, model::AbstractModel, nsteps::V, properties::Array{Symbol}, aggregators::AbstractVector{T}, steps_to_collect_data::AbstractArray{V}, replicates::V) where {T<:Function, V<:Integer}
  dd = step!(agent_step!, deepcopy(model), nsteps, properties, aggregators, steps_to_collect_data)
  all_data = pmap(j-> parallel_step_dummy!(agent_step!, model, nsteps, properties, aggregators, steps_to_collect_data, j), 1:nreplicates)
  for d in all_data
    dd = join(dd, d, on=:step, kind=:outer, makeunique=true)
  end
  return dd
end


"""
    batchrunner_parallel(agent_step!::T, model_step!::U, model::AbstractModel, nsteps::V, properties::Array{Symbol}, steps_to_collect_data::AbstractArray, replicates::V) where {T<:Function, U<:Function, V<:Integer}

"""
function batchrunner_parallel(agent_step!::T, model_step!::U, model::AbstractModel, nsteps::V, properties::Array{Symbol}, steps_to_collect_data::AbstractArray, replicates::V) where {T<:Function, U<:Function, V<:Integer}
  dd = step!(agent_step!, model_step!, deepcopy(model), nsteps, properties, steps_to_collect_data)
  all_data = pmap(j-> parallel_step_dummy!(agent_step!, model_step!, model, nsteps, properties, steps_to_collect_data, j), 1:nreplicates)
  for d in all_data
    dd = join(dd, d, on=:id, kind=:outer, makeunique=true)
  end
  return dd
end


"""
    batchrunner(agent_step!::U, model_step!::V, model::AbstractModel, nsteps::Integer, properties::Array{Symbol}, aggregators::AbstractVector{T}, steps_to_collect_data::AbstractArray{X}, replicates::Integer) where {T<:Function,U<:Function,V<:Function,X<:Integer}

"""
function batchrunner(agent_step!::U, model_step!::V, model::AbstractModel, nsteps::Integer, properties::Array{Symbol}, aggregators::AbstractVector{T}, steps_to_collect_data::AbstractArray{X}, replicates::Integer) where {T<:Function,U<:Function,V<:Function,X<:Integer}
  dd = step!(agent_step!, model_step!, deepcopy(model), nsteps, properties, aggregators, steps_to_collect_data)
  all_data = pmap(j-> parallel_step_dummy!(agent_step!, model_step!, model, nsteps, properties, aggregators, steps_to_collect_data, j), 1:nreplicates)
  for d in all_data
    dd = join(dd, d, on=:step, kind=:outer, makeunique=true)
  end
  return dd
end